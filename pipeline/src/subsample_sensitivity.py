"""BINAQUAL sensitivity to sub-sample time offsets.

The conditioning stage removes integer transport latency; what remains is the
fractional part of each renderer's group delay, measured per variant as
``subsample_residual`` in the conditioning manifest. This script measures the
effect of offsets of that size on the BINAQUAL scores.

Method: for selected reference/test pairs from the conditioned 60 s set, the
test signal is delayed by a constant fractional offset (exact frequency-domain
phase ramp, applied per channel with zero-padding so no wrap-around energy
enters the analysis) and re-scored with the unmodified upstream BINAQUAL.
Offset 0 is scored as a control and must reproduce the pipeline's own numbers.

Pairs: per item, the reference against itself (the limiting near-transparent
case), the two variants rendered entirely within the workstation (5OA,
42pIKO), and the Atmos anchor for context.

Usage:
    python src/subsample_sensitivity.py \
        --prep-root <prepared stimulus tree>/prep_60s \
        --binaqual-dir <path to BINAQUAL> \
        --workdir <scratch directory for the delayed copies> \
        --out <data dir>/subsample_sensitivity.csv \
        [--shard 0 --n-shards 4]
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
import time
from pathlib import Path

import numpy as np
import soundfile as sf

ITEMS = ["BigBand", "DeusExMachina", "KWARTET"]
REF_VARIANT = "7OA"
TEST_VARIANTS = ["7OA", "5OA", "42pIKO", "Atmos"]
OFFSETS = [0.0, 0.125, 0.25, -0.25, 0.5]

FIELDS = ["item", "variant", "offset_samples", "vnsim_0", "vnsim_1",
          "LS", "seconds"]


def fractional_delay(x: np.ndarray, delta: float, pad: int = 8192) -> np.ndarray:
    """Delay x by delta samples (may be fractional) via an exact phase ramp.

    Zero-pads by ``pad`` samples before the FFT so the circular shift's
    wrap-around lands in the padding, then trims back to the input length.
    """
    n = len(x) + pad
    out = np.empty_like(x)
    freqs = np.fft.rfftfreq(n)
    ramp = np.exp(-2j * np.pi * freqs * delta)
    for ch in range(x.shape[1]):
        X = np.fft.rfft(x[:, ch], n)
        out[:, ch] = np.fft.irfft(X * ramp, n)[: len(x)]
    return out


def delayed_copy(src: Path, delta: float, workdir: Path) -> Path:
    """Write (or reuse) the fractionally delayed version of src."""
    tag = f"{delta:+.3f}".replace("+", "p").replace("-", "m").replace(".", "_")
    dst = workdir / f"{src.stem}__d{tag}.wav"
    if dst.exists():
        return dst
    x, fs = sf.read(src, always_2d=True, dtype="float64")
    info = sf.info(src)
    sf.write(dst, fractional_delay(x, delta), fs, subtype=info.subtype)
    return dst


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prep-root", required=True)
    ap.add_argument("--binaqual-dir", required=True)
    ap.add_argument("--workdir", required=True,
                    help="scratch directory for the delayed copies; they are "
                         "cached, so a re-run reuses them")
    ap.add_argument("--out", required=True)
    ap.add_argument("--shard", type=int, default=0)
    ap.add_argument("--n-shards", type=int, default=1)
    args = ap.parse_args()

    prep = Path(args.prep_root).expanduser()
    workdir = Path(args.workdir).expanduser()
    workdir.mkdir(parents=True, exist_ok=True)
    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)

    # Import the upstream model in place, exactly as run_binaqual.py does.
    bdir = str(Path(args.binaqual_dir).expanduser().resolve())
    sys.path.insert(0, bdir)
    os.chdir(bdir)
    from binaqual import calculate_binaqual        # noqa: E402

    jobs = [(item, v, d) for item in ITEMS for v in TEST_VARIANTS
            for d in OFFSETS]
    mine = [j for i, j in enumerate(jobs) if i % args.n_shards == args.shard]

    done: set[tuple] = set()
    if out.exists():
        with open(out, newline="", encoding="utf-8") as fh:
            done = {(r["item"], r["variant"], r["offset_samples"])
                    for r in csv.DictReader(fh)}
    ## Shards share one output file, so the header is written by whichever
    ## shard creates it, exclusively: opening "a" and testing for existence
    ## lets two shards started together both write a header, which lands
    ## interleaved among the rows.
    try:
        with open(out, "x", newline="", encoding="utf-8") as fh:
            csv.DictWriter(fh, fieldnames=FIELDS).writeheader()
    except FileExistsError:
        pass

    with open(out, "a", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        for k, (item, variant, delta) in enumerate(mine, 1):
            key = (item, variant, f"{delta}")
            if key in done:
                continue
            ref = prep / item / f"{item}_{REF_VARIANT}.wav"
            test_src = prep / item / f"{item}_{variant}.wav"
            test = (test_src if delta == 0.0
                    else delayed_copy(test_src, delta, workdir))
            t0 = time.time()
            vnsim, ls = calculate_binaqual(ref, test)
            dt = time.time() - t0
            w.writerow({"item": item, "variant": variant,
                        "offset_samples": delta,
                        "vnsim_0": vnsim[0], "vnsim_1": vnsim[1],
                        "LS": ls, "seconds": round(dt, 1)})
            fh.flush()
            print(f"[shard {args.shard}] {k}/{len(mine)} {item}/{variant} "
                  f"d={delta:+.3f} LS={ls:.6f} ({dt:.0f}s)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
