"""Render a TBE (Two Big Ears / FB360) file to binaural, headlessly.

Wraps the `tbe_render` helper, which drives the Audio360 SDK with its audio
device disabled.  This exists because the FB360 Spatial Workstation can only
render TBE binaurally from inside a DAW: that step is manual, unversioned, and
fails silently in a way that is easy to miss -- a bypassed Spatialiser yields a
file that is simply channels 1 and 2 of the TBE stream, which still looks like
a plausible stereo file.  The `--verify` check below tests for exactly that.

    python render_tbe.py in_TBE.wav out_binaural.wav [--verify ref_7OA.wav]

The SDK ships as an x86_64 dylib, so the helper is invoked through Rosetta on
Apple Silicon; this is handled automatically.
"""

from __future__ import annotations

import argparse
import platform
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
import soundfile as sf

HERE = Path(__file__).resolve().parent
HELPER = HERE / "tbe_render"


def _run_helper(x: np.ndarray, n_ch: int, fs: int, block: int) -> np.ndarray:
    with tempfile.TemporaryDirectory() as td:
        raw_in = Path(td) / "in.raw"
        raw_out = Path(td) / "out.raw"
        x.astype("<f4").tofile(raw_in)

        cmd = [str(HELPER), str(raw_in), str(raw_out), str(n_ch), str(fs), str(block)]
        if platform.machine() == "arm64":
            # libAudio360.dylib is x86_64 only.
            cmd = ["arch", "-x86_64"] + cmd
        proc = subprocess.run(cmd, capture_output=True, text=True)
        if proc.returncode != 0:
            raise RuntimeError(f"tbe_render failed ({proc.returncode}): {proc.stderr}")
        sys.stderr.write(proc.stderr)
        return np.fromfile(raw_out, dtype="<f4").reshape(-1, 2).astype(np.float64)


def verify(out: np.ndarray, src: np.ndarray, ref_path: str | None) -> None:
    """Sanity-check that a real binaural decode happened."""
    problems = []

    # 1. The failure mode that motivated this tool: output == raw TBE channels.
    n = min(len(out), len(src))
    for a in range(min(src.shape[1], 8)):
        for b in range(min(src.shape[1], 8)):
            if a == b:
                continue
            s = src[:n, [a, b]]
            denom = np.sqrt((s ** 2).mean())
            if denom <= 0:
                continue
            resid = np.sqrt(((out[:n] - s) ** 2).mean()) / denom
            if resid < 1e-3:
                problems.append(
                    f"output is a copy of TBE channels {a+1},{b+1} -- the decode did not run")

    lr = 20 * np.log10(np.sqrt((out[:, 0] ** 2).mean()) /
                       max(np.sqrt((out[:, 1] ** 2).mean()), 1e-30))
    iacc = float(np.corrcoef(out[:, 0], out[:, 1])[0, 1])
    print(f"  output L/R balance : {lr:+.2f} dB")
    print(f"  output IACC        : {iacc:+.3f}")
    if abs(lr) > 4.0:
        problems.append(f"implausible L/R imbalance ({lr:+.2f} dB) for a binaural render")

    if ref_path:
        ref, _ = sf.read(ref_path, always_2d=True)
        m = min(len(ref), len(out))
        rlr = 20 * np.log10(np.sqrt((ref[:m, 0] ** 2).mean()) /
                            max(np.sqrt((ref[:m, 1] ** 2).mean()), 1e-30))
        riacc = float(np.corrcoef(ref[:m, 0], ref[:m, 1])[0, 1])
        print(f"  reference L/R      : {rlr:+.2f} dB")
        print(f"  reference IACC     : {riacc:+.3f}")
        if abs(lr - rlr) > 4.0:
            problems.append("L/R balance departs sharply from the reference render")

    if problems:
        print("\nVERIFY FAILED:")
        for p in problems:
            print("  - " + p)
        raise SystemExit(1)
    print("  verify: OK")


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", help="TBE file: 10 ch (TBE_8_2) or 8 ch (TBE_8)")
    ap.add_argument("output", help="stereo binaural WAV to write")
    ap.add_argument("--verify", metavar="REF_WAV", default=None,
                    help="reference binaural render of the same item, for a plausibility check")
    ap.add_argument("--block", type=int, default=512)
    ap.add_argument("--subtype", default="FLOAT")
    args = ap.parse_args()

    if not HELPER.exists():
        raise SystemExit(f"helper not built: {HELPER}\nrun pipeline/tbe/build.sh first")

    x, fs = sf.read(args.input, always_2d=True, dtype="float32")
    if x.shape[1] not in (8, 10):
        raise SystemExit(f"{args.input}: {x.shape[1]} channels; expected 8 (TBE_8) or 10 (TBE_8_2)")
    print(f"{Path(args.input).name}: {x.shape[1]} ch, {len(x)/fs:.1f} s @ {fs} Hz")

    out = _run_helper(x, x.shape[1], fs, args.block)
    print(f"  rendered {len(out)/fs:.1f} s of binaural audio")

    verify(out, x.astype(np.float64), args.verify)

    sf.write(args.output, out, fs, subtype=args.subtype)
    print(f"  -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
