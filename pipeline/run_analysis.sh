#!/usr/bin/env bash
# Run the statistical analysis and regenerate every figure, data table and the
# values.tex macro file consumed by the manuscript.
#
#   ./run_analysis.sh
#
# Safe to re-run at any time; it only reads the scored metrics and overwrites
# its own outputs. If the overnight scoring run is still in progress this will
# analyse whatever is complete, so check the row counts it prints first.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
DATA="$PROJECT/data/revision"
FIGS="$PROJECT/plots/revision"
PAPER="$PROJECT/__Applied Acoustics 2026 - Benchmarking Immersive Formats"

for f in metrics_long.csv; do
  [ -f "$DATA/$f" ] || { echo "missing $DATA/$f -- has the scoring run finished?" >&2; exit 1; }
done

echo "scored pairs: $(tail -n +2 "$DATA/metrics_long.csv" | wc -l | tr -d ' ')"
[ -f "$DATA/metrics_long_noalign.csv" ] && \
  echo "control arm : $(tail -n +2 "$DATA/metrics_long_noalign.csv" | wc -l | tr -d ' ')"

cd "$HERE/analysis"
Rscript analysis.R "$DATA" "$FIGS" "$PAPER/values.tex"

# Publish the figures the manuscript includes.
mkdir -p "$PAPER/figures"
cp -f "$FIGS"/Fig_*.pdf "$PAPER/figures/" 2>/dev/null || true
echo "figures copied to $PAPER/figures"
