"""Step 3a -- score every pair with BINAQUAL.

Wraps the reference implementation (Shariat Panah et al., 2025) without
modifying it: ``calculate_binaqual`` is imported from the upstream package so
that the numbers produced here are exactly those the published model yields.

The runner is shard-aware and resumable.  Results are appended row by row, so
an interrupted run can be restarted and will skip pairs already scored.

Usage
-----
    python src/run_binaqual.py --pairs ... --binaqual-dir ... --out ... \
                               [--shard 0 --n-shards 8]
"""

from __future__ import annotations

import argparse
import csv
import os
import sys
import time
from pathlib import Path

FIELDS = ["pair_id", "item", "anchor", "variant", "is_anchor",
          "vnsim_0", "vnsim_1", "LS", "LS_mean", "seconds"]


def load_done(path: Path) -> set[str]:
    if not path.exists():
        return set()
    with open(path, newline="", encoding="utf-8") as fh:
        return {r["pair_id"] for r in csv.DictReader(fh)}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pairs", required=True)
    ap.add_argument("--binaqual-dir", required=True,
                    help="directory containing the upstream binaqual.py / vnsim.py")
    ap.add_argument("--out", required=True)
    ap.add_argument("--shard", type=int, default=0)
    ap.add_argument("--n-shards", type=int, default=1)
    args = ap.parse_args()

    # Import the upstream model in place; its modules use flat imports.
    bdir = str(Path(args.binaqual_dir).resolve())
    sys.path.insert(0, bdir)
    os.chdir(bdir)
    from binaqual import calculate_binaqual        # noqa: E402

    with open(args.pairs, newline="", encoding="utf-8") as fh:
        pairs = list(csv.DictReader(fh))
    mine = [p for i, p in enumerate(pairs) if i % args.n_shards == args.shard]

    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    done = load_done(out)
    new_file = not out.exists()

    with open(out, "a", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        if new_file:
            w.writeheader()
        for k, p in enumerate(mine, 1):
            if p["pair_id"] in done:
                continue
            t0 = time.time()
            vnsim, ls = calculate_binaqual(Path(p["ref_path"]), Path(p["test_path"]))
            dt = time.time() - t0
            w.writerow({
                "pair_id": p["pair_id"], "item": p["item"], "anchor": p["anchor"],
                "variant": p["variant"], "is_anchor": p["is_anchor"],
                "vnsim_0": vnsim[0], "vnsim_1": vnsim[1], "LS": ls,
                "LS_mean": (vnsim[0] + vnsim[1]) / 2.0,
                "seconds": round(dt, 1),
            })
            fh.flush()
            print(f"[shard {args.shard}] {k}/{len(mine)} {p['pair_id']} "
                  f"LS={ls:.6f} ({dt:.0f}s)", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
