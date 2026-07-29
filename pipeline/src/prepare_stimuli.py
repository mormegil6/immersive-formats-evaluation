"""Step 1 -- condition the binaural renderings before objective evaluation.

For every content item the script

  1. estimates each variant's constant transport delay and absolute polarity
     against that item's own 7OA reference (``align.estimate``),
  2. removes them,
  3. crops every variant of the item -- reference included -- to a single
     common valid region, so that no zero-padding introduced in step 2 ever
     reaches an objective model,
  4. normalises each cropped signal to a common integrated loudness
     (ITU-R BS.1770-4), removing programme level as a confound, and
  5. writes 32-bit float WAVs (no clipping, no requantisation) plus a manifest
     recording every correction that was applied.

Usage
-----
    python src/prepare_stimuli.py \
        --legacy-root   "<...>/bamq-binaqual/Stimuli" \
        --revision-root "<...>/benchmarking_renders_reviews/stimuli" \
        --out-root      "<...>/stimuli_prepared" \
        --manifest      "../data/revision/stimulus_conditioning.csv"
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
import align                                   # noqa: E402
from loudness import gain_to_target, integrated_lufs, true_peak_dbtp   # noqa: E402

TARGET_LUFS = -17.0     # matches the mean loudness of the originally submitted
                        # peak-normalised set, so the models keep operating at
                        # the same presentation level as in the first submission
CROP_MARGIN = 4800      # 100 ms of extra guard either side


def write_wav_deterministic(path: Path, x: np.ndarray, fs: int) -> None:
    """Write a float WAV whose bytes depend only on the audio.

    libsndfile stamps floating-point WAVs with a PEAK chunk carrying the wall
    clock time of the write, so two runs over identical input produce files
    that differ in two bytes.  The audio is unaffected, but it defeats
    checksum-based verification of a released pipeline, so the timestamp is
    zeroed after writing.
    """
    sf.write(str(path), x, fs, subtype="FLOAT")
    with open(path, "r+b") as fh:
        head = fh.read(4096)
        i = 12
        while i + 8 <= len(head):
            cid = head[i:i + 4]
            size = int.from_bytes(head[i + 4:i + 8], "little")
            if cid == b"PEAK":
                fh.seek(i + 12)          # timeStamp follows version(4)
                fh.write(b"\x00\x00\x00\x00")
                return
            if cid == b"data":
                return
            i += 8 + size + (size & 1)


def read_config(path: Path) -> list[dict]:
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--config", default=str(Path(__file__).parent.parent / "config" / "stimuli.csv"))
    ap.add_argument("--legacy-root", required=True)
    ap.add_argument("--revision-root", required=True)
    ap.add_argument("--out-root", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--target-lufs", type=float, default=TARGET_LUFS)
    ap.add_argument("--excerpt-s", type=float, default=0.0,
                    help="If > 0, analyse a centred excerpt of this many "
                         "seconds instead of the whole item. The excerpt is "
                         "taken after alignment and cropping, at the same "
                         "position in every variant of the item, and loudness "
                         "normalisation is then applied to the excerpt itself. "
                         "GPSMq's multi-resolution front end scales linearly "
                         "with signal length, so this is the control that keeps "
                         "peak memory bounded on long programme material.")
    ap.add_argument("--segment", type=int, default=None, metavar="K",
                    help="With --n-segments N, analyse the K-th (0-based) of N "
                         "consecutive excerpts tiling the item's valid region "
                         "instead of a centred one. Scoring every segment and "
                         "aggregating covers the whole recording while keeping "
                         "peak memory at the single-excerpt level, which is the "
                         "only way to analyse long items on a machine without "
                         "swap.")
    ap.add_argument("--n-segments", type=int, default=None)
    ap.add_argument("--skip-alignment", action="store_true",
                    help="Measure latency and polarity but do NOT correct them. "
                         "Cropping and loudness normalisation are applied exactly "
                         "as in the corrected run, so the two sets differ in "
                         "nothing but alignment. This produces the control arm "
                         "for the latency-sensitivity analysis.")
    args = ap.parse_args()

    roots = {"legacy": Path(args.legacy_root), "revision": Path(args.revision_root)}
    out_root = Path(args.out_root)
    rows = read_config(Path(args.config))
    items = sorted({r["item"] for r in rows}, key=lambda s: [r["item"] for r in rows].index(s))

    manifest: list[dict] = []

    for item in items:
        item_rows = [r for r in rows if r["item"] == item]
        ref_row = next(r for r in item_rows if r["is_reference"] == "1")
        ref_path = roots[ref_row["source_root"]] / ref_row["source_file"]
        ref, fs = sf.read(str(ref_path), always_2d=True, dtype="float64")
        print(f"\n=== {item}  ({len(ref)/fs:.1f} s, {fs} Hz) ref={ref_row['source_file']}")

        corrected: dict[str, np.ndarray] = {}
        results: dict[str, align.AlignmentResult] = {}

        for r in item_rows:
            path = roots[r["source_root"]] / r["source_file"]
            x, fs_x = sf.read(str(path), always_2d=True, dtype="float64")
            if fs_x != fs:
                raise ValueError(f"{path}: {fs_x} Hz, expected {fs} Hz")
            n = min(len(x), len(ref))
            if len(x) != len(ref):
                print(f"  ! {r['variant']}: length {len(x)} != reference {len(ref)}, "
                      f"truncating both views to {n}")
            x = x[:n]

            res = align.estimate(ref[:n], x, fs)
            corrected[r["variant"]] = (
                x.copy() if args.skip_alignment
                else align.shift(x * res.polarity, res.lag)
            )
            results[r["variant"]] = res

            flag = ""
            if res.polarity < 0:
                flag += "  POLARITY-INVERTED"
            if res.peak_ratio < 1.15:
                flag += f"  AMBIGUOUS(peak/2nd={res.peak_ratio:.2f})"
            if res.residual_lag != 0:
                flag += f"  RESIDUAL={res.residual_lag}"
            print(f"  {r['variant']:<18} lag={res.lag:>7} ({res.lag/fs*1e3:>8.2f} ms) "
                  f"r={res.corr:.3f} pk/2nd={res.peak_ratio:4.2f} "
                  f"agree={res.window_agreement:4.2f} sub={res.subsample:+.3f}{flag}")

        # One common crop for the whole item keeps a single reference file valid
        # for every pairwise comparison.
        crop = max(abs(res.lag) for res in results.values()) + CROP_MARGIN
        n = min(len(v) for v in corrected.values())
        lo, hi = crop, n - crop
        if hi - lo < fs * 10:
            raise ValueError(f"{item}: crop leaves less than 10 s of audio")
        if args.excerpt_s > 0:
            want = int(round(args.excerpt_s * fs))
            if want > hi - lo:
                raise ValueError(f"{item}: excerpt {args.excerpt_s}s exceeds "
                                 f"the {(hi-lo)/fs:.1f}s valid region")
            if args.segment is not None:
                if args.n_segments is None or not (0 <= args.segment < args.n_segments):
                    raise ValueError("--segment K requires --n-segments N with 0 <= K < N")
                # Tile the valid region; the last segment is flush with its end so
                # that the tiling covers the item even when it is not an exact
                # multiple of the excerpt length.
                span = hi - lo
                if args.n_segments == 1:
                    start = lo + (span - want) // 2
                else:
                    step = (span - want) / (args.n_segments - 1)
                    start = lo + int(round(args.segment * step))
                lo, hi = start, start + want
            else:
                mid = (lo + hi) // 2
                lo, hi = mid - want // 2, mid - want // 2 + want
        print(f"  crop {crop} samples ({crop/fs*1e3:.0f} ms) each end "
              f"-> {(hi-lo)/fs:.1f} s analysed"
              + ("" if args.excerpt_s <= 0 else
                 f" (segment {args.segment+1}/{args.n_segments}, "
                 f"{lo/fs:.0f}-{hi/fs:.0f} s)" if args.segment is not None else
                 f" (centred {args.excerpt_s:.0f} s excerpt)"))

        out_dir = out_root / item
        out_dir.mkdir(parents=True, exist_ok=True)

        for r in item_rows:
            v = r["variant"]
            y = corrected[v][lo:hi]
            y_n, before, gain_db = gain_to_target(y, fs, args.target_lufs)
            after = integrated_lufs(y_n, fs)
            tp = true_peak_dbtp(y_n, fs)
            out_path = out_dir / f"{item}_{v}.wav"
            write_wav_deterministic(out_path, y_n, fs)

            res = results[v]
            manifest.append({
                "item": item, "variant": v, "label": r["label"],
                "family": r["family"], "chain": r["chain"],
                "ambisonic_order": r["ambisonic_order"],
                "is_reference": r["is_reference"],
                "source_file": r["source_file"], "source_root": r["source_root"],
                "prepared_file": out_path.name,
                "fs_hz": fs,
                "lag_samples": res.lag,
                "lag_ms": round(res.lag / fs * 1e3, 4),
                "polarity": res.polarity,
                "gcc_corr": round(res.corr, 4),
                "gcc_peak_ratio": round(res.peak_ratio, 3),
                "window_lags": ";".join(str(w) for w in res.window_lags),
                "window_agreement": res.window_agreement,
                "subsample_residual": round(res.subsample, 4),
                "residual_lag_samples": res.residual_lag,
                "alignment_applied": int(not args.skip_alignment),
                "excerpt_s": args.excerpt_s,
                "segment": "" if args.segment is None else f"{args.segment}/{args.n_segments}",
                "segment_start_s": round(lo / fs, 3),
                "crop_samples_each_end": crop,
                "analysed_duration_s": round((hi - lo) / fs, 3),
                "lufs_before": round(before, 3),
                "lufs_after": round(after, 3),
                "gain_db": round(gain_db, 3),
                "true_peak_dbtp_after": round(tp, 3),
            })

    Path(args.manifest).parent.mkdir(parents=True, exist_ok=True)
    with open(args.manifest, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(manifest[0].keys()))
        w.writeheader()
        w.writerows(manifest)
    print(f"\nmanifest -> {args.manifest}  ({len(manifest)} rows)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
