"""Build a fractionally corrected copy of a prepared stimulus set.

Integer transport latency is removed by prepare_stimuli.py; the fractional
part of each renderer's group delay remains, measured per variant as
``subsample_residual`` in the conditioning manifest. This script applies that
last correction: every non-reference prepared file is delayed by its own
measured residual (the exact frequency-domain phase ramp defined in
subsample_sensitivity.py and checked against ground truth, together with the
sign used here, by subsample_selftest.py), reference files are copied
unchanged, and the corrected tree mirrors the input tree so make_pairs.py
and the scoring runners work on it as-is.

Because every file was aligned against the same 7OA reference, correcting
each file by its own residual also corrects every cross pair (5OA and Atmos
anchors included) to first order.

After writing each corrected file the residual is re-estimated with the
pipeline's own align.estimate; the new sub-sample residual is reported and
must be near zero.

Usage:
    python src/fractional_correct.py \
        --manifest <data dir>/conditioning_60s.csv \
        --prep-root <prepared stimulus tree>/prep_60s \
        --out-root  <prepared stimulus tree>/prep_60s_subsample
"""

from __future__ import annotations

import argparse
import csv
import shutil
import sys
from pathlib import Path

import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parent))
from align import estimate                      # noqa: E402
from subsample_sensitivity import fractional_delay  # noqa: E402


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--prep-root", required=True)
    ap.add_argument("--out-root", required=True)
    args = ap.parse_args()

    prep = Path(args.prep_root).expanduser()
    out = Path(args.out_root).expanduser()

    with open(args.manifest, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    refs = {r["item"]: r["prepared_file"] for r in rows if r["is_reference"] == "1"}

    for r in rows:
        src = prep / r["item"] / r["prepared_file"]
        dst = out / r["item"] / r["prepared_file"]
        dst.parent.mkdir(parents=True, exist_ok=True)
        resid = float(r["subsample_residual"])
        if r["is_reference"] == "1" or resid == 0.0:
            shutil.copy2(src, dst)
            print(f"{r['item']}/{r['variant']}: reference or zero residual, copied")
            continue
        x, fs = sf.read(src, always_2d=True, dtype="float64")
        info = sf.info(src)
        sf.write(dst, fractional_delay(x, resid), fs, subtype=info.subtype)

        ref, _ = sf.read(prep / r["item"] / refs[r["item"]],
                         always_2d=True, dtype="float64")
        y, _ = sf.read(dst, always_2d=True, dtype="float64")
        res = estimate(ref, y, fs=fs)
        print(f"{r['item']}/{r['variant']}: applied {resid:+.4f} smp; "
              f"re-estimated lag={res.lag} sub={res.subsample:+.4f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
