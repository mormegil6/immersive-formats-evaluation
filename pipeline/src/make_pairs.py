"""Step 2 -- enumerate the reference/test pairs to be scored.

The primary analysis anchors every comparison on the 7OA master of the same
content item.  Reviewer comment R2.1 asks what happens when that anchor
changes, so two further anchors are enumerated:

  5OA    -- a lower-order anchor from the same (scene-based) family, isolating
            the effect of anchor *fidelity* while holding the family constant;
  Atmos  -- the native 9.1.6 channel-based render, isolating the effect of
            anchor *family*, which is the specific bias the reviewer raises.

Each anchor is paired against all variants of its item, including itself: the
self-comparison is both the "reference" row of the figures and a determinism
check on the scoring pipeline.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

ANCHORS = ["7OA", "5OA", "Atmos"]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--manifest", required=True,
                    help="stimulus_conditioning.csv written by prepare_stimuli.py")
    ap.add_argument("--stimuli-root", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--anchors", default=",".join(ANCHORS))
    args = ap.parse_args()

    anchors = [a.strip() for a in args.anchors.split(",") if a.strip()]
    with open(args.manifest, newline="", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))

    root = Path(args.stimuli_root)
    items = []
    for r in rows:
        if r["item"] not in items:
            items.append(r["item"])

    pairs = []
    for item in items:
        item_rows = [r for r in rows if r["item"] == item]
        by_variant = {r["variant"]: r for r in item_rows}
        for anchor in anchors:
            if anchor not in by_variant:
                raise KeyError(f"{item}: anchor '{anchor}' not present in manifest")
            ref = by_variant[anchor]
            for t in item_rows:
                pairs.append({
                    "pair_id": f"{item}__{anchor}__{t['variant']}",
                    "item": item,
                    "anchor": anchor,
                    "variant": t["variant"],
                    "label": t["label"],
                    "family": t["family"],
                    "chain": t["chain"],
                    "ambisonic_order": t["ambisonic_order"],
                    "is_anchor": int(t["variant"] == anchor),
                    "ref_path": str(root / item / ref["prepared_file"]),
                    "test_path": str(root / item / t["prepared_file"]),
                    "duration_s": t["analysed_duration_s"],
                })

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=list(pairs[0].keys()))
        w.writeheader()
        w.writerows(pairs)

    total = sum(float(p["duration_s"]) for p in pairs)
    print(f"{len(pairs)} pairs -> {args.out}")
    print(f"  items={len(items)} anchors={anchors}")
    print(f"  total audio to score: {total/3600:.2f} h "
          f"(~{total*1.49/3600:.1f} h BAM-Q + ~{total*0.26/3600:.1f} h BINAQUAL, single core)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
