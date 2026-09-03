"""Compare BINAQUAL scores on fractionally corrected stimuli with the baseline.

Merges the shard outputs of the sub-sample re-score (run_binaqual.py on the
tree written by fractional_correct.py), joins them to the published baseline
(metrics_long.csv), writes one tidy comparison table, and prints a summary:
per-pair change, ordering agreement per item and anchor, the format-family
gap under each anchor, and the number of items in which that gap reverses
between the scene-based and channel-based anchors.

Usage:
    python src/subsample_compare.py \
        --shards <data dir>/shards_subsample \
        --baseline <data dir>/metrics_long.csv \
        --out <data dir>/subsample_correction_comparison.csv
"""

from __future__ import annotations

import argparse
import csv
import glob
from itertools import combinations
from pathlib import Path

ANCHORS = ("7OA", "5OA", "Atmos")
ITEMS = ("BigBand", "DeusExMachina", "KWARTET")


def kendall(a, b):
    c = d = 0
    for i, j in combinations(range(len(a)), 2):
        s = (a[i] - a[j]) * (b[i] - b[j])
        c += s > 0
        d += s < 0
    return (c - d) / (c + d)


def family_gap(rows, score, item=None):
    """Mean Ambisonics score minus mean Channel/Object score.

    Variants that also serve as anchors are excluded from both means, so
    that the gap is computed over the same set of test formats whichever
    anchor the rows come from.
    """
    def sel(fam):
        return [r[score] for r in rows
                if r["family"] == fam and r["variant"] not in ANCHORS
                and (item is None or r["item"] == item)]
    a, c = sel("Ambisonics"), sel("Channel/Object")
    return sum(a) / len(a) - sum(c) / len(c)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--shards", required=True)
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    new = {}
    for f in sorted(glob.glob(str(Path(args.shards) / "binaqual_*.csv"))):
        with open(f, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                new[r["pair_id"]] = float(r["LS"])
    with open(args.baseline, newline="", encoding="utf-8") as fh:
        meta = {r["pair_id"]: r for r in csv.DictReader(fh)}

    ## Scoring is resumable and sharded, so an interrupted run is a normal
    ## state; comparing whatever happens to be present would understate the
    ## effect silently.
    missing = sorted(set(meta) - set(new))
    if missing:
        raise SystemExit(f"{len(missing)} of {len(meta)} baseline pairs were "
                         f"not re-scored, e.g. {missing[:3]}; finish the "
                         f"re-score before comparing")

    rows = []
    for k in sorted(set(new) & set(meta)):
        m = meta[k]
        b, n = float(m["LS"]), new[k]
        rows.append({"pair_id": k, "item": m["item"], "anchor": m["anchor"],
                     "variant": m["variant"], "family": m["family"],
                     "is_anchor": m["is_anchor"], "LS_baseline": b,
                     "LS_corrected": n, "dLS": n - b,
                     "rel_dLS_pct": (n - b) / b * 100 if b > 0 else 0.0})
    out = Path(args.out)
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        w.writeheader()
        w.writerows(rows)

    d = [r for r in rows if r["is_anchor"] != "1"]
    ar = sorted(abs(r["rel_dLS_pct"]) for r in d)
    aa = sorted(abs(r["dLS"]) for r in d)
    print(f"pairs compared: {len(rows)} ({len(d)} non-self)")
    print(f"|dLS|     median {aa[len(aa)//2]:.4f}  p90 {aa[int(0.9*len(aa))]:.4f}  max {aa[-1]:.4f}")
    print(f"|rel dLS| median {ar[len(ar)//2]:.2f}%  p90 {ar[int(0.9*len(ar))]:.2f}%  max {ar[-1]:.2f}%")
    print("Kendall tau, baseline vs corrected ordering:")
    for item in ITEMS:
        for anc in ANCHORS:
            g = [r for r in d if r["item"] == item and r["anchor"] == anc]
            print(f"  {item:14s} {anc:6s} {kendall([r['LS_baseline'] for r in g], [r['LS_corrected'] for r in g]):+.3f}")
    print("family gap (Ambisonics minus Channel/Object), baseline -> corrected:")
    for anc in ANCHORS:
        g = [r for r in rows if r["anchor"] == anc]
        print(f"  {anc:6s} {family_gap(g, 'LS_baseline'):+.4f} -> {family_gap(g, 'LS_corrected'):+.4f}")
    for score, label in (("LS_baseline", "baseline"), ("LS_corrected", "corrected")):
        flips = sum((family_gap([r for r in rows if r['anchor'] == '7OA'], score, it) > 0)
                    != (family_gap([r for r in rows if r['anchor'] == 'Atmos'], score, it) > 0)
                    for it in ITEMS)
        print(f"items reversing between 7OA and Atmos anchors ({label}): {flips}/{len(ITEMS)}")
    print(f"-> {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
