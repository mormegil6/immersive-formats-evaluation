#!/usr/bin/env bash
# Unattended scoring run.
#
# Sizing rationale: a single MATLAB process running GPSMq peaks at ~19.8 GB on
# a 90 s stereo excerpt, because the multi-resolution front end allocates
# transiently and scales with signal length.  On a 64 GB machine with swap
# disabled, that is ~13 GB at 60 s -- safe for ONE process and fatal for four.
# This script therefore runs BAM-Q strictly sequentially and keeps a watchdog
# on free memory.  Every stage is resumable, so a halt costs only the pair in
# flight.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"
PY="$HOME/.venvs/immersive-benchmarking/bin/python"
MATLAB="/Applications/MATLAB_R2025a.app/bin/matlab"
BAMQ_DIR="$PROJECT/Immersive Benchmarking/combinedaudioqualitymodel-master"
BINAQUAL_DIR="$PROJECT/Immersive Benchmarking/Binaqual"
OUT="$PROJECT/data/revision"
LOG="$OUT/logs/overnight.log"

MIN_FREE_GB="${MIN_FREE_GB:-8}"

mkdir -p "$OUT/shards" "$OUT/logs"

say() { echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG"; }

free_gb() {
  vm_stat | awk '/Pages free/{f=$3} /Pages inactive/{i=$3} /Pages speculative/{s=$3}
                 END{gsub(/\./,"",f); gsub(/\./,"",i); gsub(/\./,"",s);
                     printf "%d", (f+i+s)*16384/1073741824}'
}

# Run one command, watching memory; kill it if the machine gets close to the
# edge.  Returns 0 on clean exit, 99 if the watchdog intervened.
guarded() {
  "$@" &
  local pid=$! rc=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$(free_gb)" -lt "$MIN_FREE_GB" ]; then
      say "WATCHDOG: free memory below ${MIN_FREE_GB} GB -- halting current stage"
      kill -TERM "$pid" 2>/dev/null; sleep 5; kill -KILL "$pid" 2>/dev/null
      return 99
    fi
    sleep 10
  done
  wait "$pid"; rc=$?
  return $rc
}

bamq() {   # bamq <pairs> <shard_csv>
  guarded nice -n 10 "$MATLAB" -nodisplay -nosplash -sd "$HERE/src" -batch \
    "maxNumCompThreads(2); run_bamq('$1','$BAMQ_DIR','$2',0,1)"
}

binaqual() {  # binaqual <pairs> <shard_csv>
  guarded nice -n 10 "$PY" "$HERE/src/run_binaqual.py" \
    --pairs "$1" --binaqual-dir "$BINAQUAL_DIR" --out "$2" --shard 0 --n-shards 1
}

say "=== overnight run starting; free memory $(free_gb) GB ==="

# BINAQUAL first: it is cheap (~16 s/pair, ~2 GB) and gives a complete
# localisation-similarity dataset early, before the long BAM-Q phases.
say "--- phase 1/4: BINAQUAL, aligned (108 pairs)"
binaqual "$OUT/pairs_60s.csv" "$OUT/shards/binaqual_aligned.csv"
say "    phase 1 rc=$? rows=$(tail -n +2 "$OUT/shards/binaqual_aligned.csv" 2>/dev/null | wc -l | tr -d ' ')"

say "--- phase 2/4: BINAQUAL, no-align control (36 pairs)"
binaqual "$OUT/pairs_60s_noalign.csv" "$OUT/shards/binaqual_noalign.csv"
say "    phase 2 rc=$? rows=$(tail -n +2 "$OUT/shards/binaqual_noalign.csv" 2>/dev/null | wc -l | tr -d ' ')"

# BAM-Q: pairs_60s.csv is ordered so the 36 primary-anchor pairs come first,
# so the primary analysis is complete after roughly the first 75 minutes.
say "--- phase 3/4: BAM-Q, aligned (108 pairs, ~3.6 h)"
bamq "$OUT/pairs_60s.csv" "$OUT/shards/bamq_aligned.csv"
say "    phase 3 rc=$? rows=$(tail -n +2 "$OUT/shards/bamq_aligned.csv" 2>/dev/null | wc -l | tr -d ' ')"

say "--- phase 4/4: BAM-Q, no-align control (36 pairs, ~1.2 h)"
bamq "$OUT/pairs_60s_noalign.csv" "$OUT/shards/bamq_noalign.csv"
say "    phase 4 rc=$? rows=$(tail -n +2 "$OUT/shards/bamq_noalign.csv" 2>/dev/null | wc -l | tr -d ' ')"

say "--- merging"
mkdir -p "$OUT/shards_aligned" "$OUT/shards_noalign"
cp -f "$OUT/shards/bamq_aligned.csv"     "$OUT/shards_aligned/bamq_0.csv"     2>/dev/null
cp -f "$OUT/shards/binaqual_aligned.csv" "$OUT/shards_aligned/binaqual_0.csv" 2>/dev/null
cp -f "$OUT/shards/bamq_noalign.csv"     "$OUT/shards_noalign/bamq_0.csv"     2>/dev/null
cp -f "$OUT/shards/binaqual_noalign.csv" "$OUT/shards_noalign/binaqual_0.csv" 2>/dev/null

"$PY" "$HERE/src/merge_results.py" --pairs "$OUT/pairs_60s.csv" \
  --manifest "$OUT/conditioning_60s.csv" --shard-dir "$OUT/shards_aligned" \
  --out "$OUT/metrics_long.csv" 2>&1 | tee -a "$LOG"
"$PY" "$HERE/src/merge_results.py" --pairs "$OUT/pairs_60s_noalign.csv" \
  --manifest "$OUT/conditioning_60s_noalign.csv" --shard-dir "$OUT/shards_noalign" \
  --out "$OUT/metrics_long_noalign.csv" 2>&1 | tee -a "$LOG"

say "=== overnight run finished; free memory $(free_gb) GB ==="
