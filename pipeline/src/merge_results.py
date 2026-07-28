"""Step 4 -- merge BAM-Q and BINAQUAL shard outputs into one tidy table.

Produces a long-format CSV, one row per (item, anchor, variant), carrying every
model output together with the stimulus-conditioning metadata needed to audit
the result (measured latency, polarity correction, loudness gain).  This is the
file the R analysis reads and the one released as supplementary data.
"""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

BAMQ_COLS = ["SNR_dc", "SNR_ac", "SNR_dc_fix", "SNR_ac_fix", "OPM", "OPM_fix",
             "binQ", "ILDdiff", "ITDdiff", "IVSdiff", "overall_measure"]
BINAQUAL_COLS = ["vnsim_0", "vnsim_1", "LS", "LS_mean"]
COND_COLS = ["lag_samples", "lag_ms", "polarity", "gcc_corr", "gcc_peak_ratio",
             "residual_lag_samples", "lufs_before", "gain_db",
             "true_peak_dbtp_after", "analysed_duration_s"]


def read_shards(shard_dir: Path, prefix: str) -> dict[str, dict]:
    out: dict[str, dict] = {}
    files = sorted(shard_dir.glob(f"{prefix}_*.csv"))
    if not files:
        raise FileNotFoundError(f"no {prefix} shards in {shard_dir}")
    for f in files:
        with open(f, newline="", encoding="utf-8") as fh:
            for r in csv.DictReader(fh):
                if r["pair_id"] in out:
                    raise ValueError(f"duplicate pair_id {r['pair_id']} in {f}")
                out[r["pair_id"]] = r
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pairs", required=True)
    ap.add_argument("--manifest", required=True)
    ap.add_argument("--shard-dir", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    with open(args.pairs, newline="", encoding="utf-8") as fh:
        pairs = list(csv.DictReader(fh))
    with open(args.manifest, newline="", encoding="utf-8") as fh:
        cond = {(r["item"], r["variant"]): r for r in csv.DictReader(fh)}

    shard_dir = Path(args.shard_dir)
    bamq = read_shards(shard_dir, "bamq")
    binq = read_shards(shard_dir, "binaqual")

    missing = [p["pair_id"] for p in pairs
               if p["pair_id"] not in bamq or p["pair_id"] not in binq]
    if missing:
        print(f"WARNING: {len(missing)} incomplete pairs, e.g. {missing[:5]}")

    fields = (["pair_id", "item", "anchor", "variant", "label", "family", "chain",
               "ambisonic_order", "is_anchor"] + BAMQ_COLS + BINAQUAL_COLS + COND_COLS)
    rows = []
    for p in pairs:
        if p["pair_id"] in missing:
            continue
        b, q = bamq[p["pair_id"]], binq[p["pair_id"]]
        c = cond[(p["item"], p["variant"])]
        row = {k: p[k] for k in ("pair_id", "item", "anchor", "variant", "label",
                                 "family", "chain", "ambisonic_order", "is_anchor")}
        row.update({k: b[k] for k in BAMQ_COLS})
        row.update({k: q[k] for k in BINAQUAL_COLS})
        row.update({k: c[k] for k in COND_COLS})
        rows.append(row)

    Path(args.out).parent.mkdir(parents=True, exist_ok=True)
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)
    print(f"{len(rows)}/{len(pairs)} pairs -> {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
