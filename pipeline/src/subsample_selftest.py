"""Self-test of the fractional-delay operator and the correction sign.

fractional_correct.py delays every rendered file by its own manifest
residual, so two things must hold: the phase-ramp operator
(subsample_sensitivity.fractional_delay) must realise a fractional delay
exactly, and the residual reported by align.estimate must be applied with
the right sign. Both are checked here against ground truth on real
programme material.

Method: the 7OA reference is delayed by a known fractional offset (+0.3
samples by default) and align.estimate is run on the pair, giving the
residual the conditioning manifest would carry. The delayed copy is then
corrected by that residual with each sign in turn (delayed further by
+residual, or by -residual) and the residual is re-estimated. Only the
correct sign drives it towards zero; the wrong one makes it worse. The
residual left by the correct sign is the accuracy of the whole chain,
operator plus estimator, on real programme material.

fractional_correct.py uses the "+" sign.

Usage:
    python src/subsample_selftest.py \
        --prep-root <prepared stimulus tree>/prep_60s \
        --out <data dir>/subsample_selftest.csv \
        [--items BigBand DeusExMachina KWARTET] [--injected 0.3]
"""

from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from align import estimate                          # noqa: E402
from subsample_sensitivity import ITEMS, fractional_delay  # noqa: E402

REF_VARIANT = "7OA"

FIELDS = ["item", "injected_samples", "measured_residual",
          "residual_after_plus", "residual_after_minus"]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prep-root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--items", nargs="+", default=ITEMS)
    ap.add_argument("--injected", type=float, default=0.3,
                    help="known delay in samples applied to the reference")
    args = ap.parse_args()

    prep = Path(args.prep_root).expanduser()
    out = Path(args.out).expanduser()
    out.parent.mkdir(parents=True, exist_ok=True)

    rows = []
    for item in args.items:
        ref, fs = sf.read(prep / item / f"{item}_{REF_VARIANT}.wav",
                          always_2d=True, dtype="float64")
        delayed = fractional_delay(ref, args.injected)
        r0 = estimate(ref, delayed, fs=fs)
        print(f"{item}: injected {args.injected:+.3f} -> measured "
              f"sub={r0.subsample:+.4f} (lag {r0.lag})")
        after = {}
        for sign, label in ((+1, "plus"), (-1, "minus")):
            corrected = fractional_delay(delayed, sign * r0.subsample)
            r1 = estimate(ref, corrected, fs=fs)
            after[label] = r1.subsample
            print(f"  shift by {'+' if sign > 0 else '-'}sub: residual now "
                  f"sub={r1.subsample:+.4f} (lag {r1.lag})")
        rows.append({"item": item, "injected_samples": args.injected,
                     "measured_residual": round(r0.subsample, 4),
                     "residual_after_plus": round(after["plus"], 4),
                     "residual_after_minus": round(after["minus"], 4)})

    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        w.writerows(rows)
    print(f"-> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
