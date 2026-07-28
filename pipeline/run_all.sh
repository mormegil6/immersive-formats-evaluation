#!/usr/bin/env bash
# Full objective-evaluation pipeline for the Applied Acoustics revision.
#
#   ./run_all.sh [prepare|pairs|binaqual|bamq|merge|all]
#
# Every stage is idempotent and resumable: re-running skips work already done.
# Edit the paths in the CONFIG block (or export them) to relocate the study.
set -euo pipefail

# ----------------------------------------------------------------- CONFIG ---
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$(cd "$HERE/.." && pwd)"

# The virtual environment deliberately lives OUTSIDE the project tree: this
# project is stored in a cloud-synced folder (OneDrive), and macOS refuses to
# load compiled extension modules (.so) from such a folder once the sync client
# has rewritten them -- which is exactly why the original `BinaqualVenv` inside
# the repository no longer runs.  See pipeline/README.md, "Environment".
PYTHON="${PYTHON:-$HOME/.venvs/immersive-benchmarking/bin/python}"
MATLAB="${MATLAB:-/Applications/MATLAB_R2025a.app/bin/matlab}"

LEGACY_ROOT="${LEGACY_ROOT:-$PROJECT/Immersive Benchmarking/Stimuli}"
REVISION_ROOT="${REVISION_ROOT:-$HOME/Downloads/benchmarking_renders_reviews/stimuli}"
PREPARED_ROOT="${PREPARED_ROOT:-$HOME/Downloads/benchmarking_renders_reviews/stimuli_prepared}"

BINAQUAL_DIR="${BINAQUAL_DIR:-$PROJECT/Immersive Benchmarking/Binaqual}"
BAMQ_DIR="${BAMQ_DIR:-$PROJECT/Immersive Benchmarking/combinedaudioqualitymodel-master}"

OUT="$PROJECT/data/revision"
MANIFEST="$OUT/stimulus_conditioning.csv"
PAIRS="$OUT/pairs.csv"

N_BINAQUAL="${N_BINAQUAL:-4}"     # concurrent python workers
N_BAMQ="${N_BAMQ:-8}"             # concurrent MATLAB shards
MATLAB_THREADS="${MATLAB_THREADS:-2}"   # compute threads per MATLAB shard

mkdir -p "$OUT" "$OUT/shards" "$OUT/logs"

# ----------------------------------------------------------------- STAGES ---
stage_prepare() {
  echo ">>> conditioning stimuli (align, polarity, loudness)"
  "$PYTHON" "$HERE/src/prepare_stimuli.py" \
    --legacy-root "$LEGACY_ROOT" \
    --revision-root "$REVISION_ROOT" \
    --out-root "$PREPARED_ROOT" \
    --manifest "$MANIFEST" | tee "$OUT/logs/prepare.log"
}

stage_pairs() {
  echo ">>> enumerating pairs"
  "$PYTHON" "$HERE/src/make_pairs.py" \
    --manifest "$MANIFEST" --stimuli-root "$PREPARED_ROOT" --out "$PAIRS"
}

stage_binaqual() {
  echo ">>> BINAQUAL on $N_BINAQUAL workers"
  local pids=()
  for s in $(seq 0 $((N_BINAQUAL - 1))); do
    "$PYTHON" "$HERE/src/run_binaqual.py" \
      --pairs "$PAIRS" --binaqual-dir "$BINAQUAL_DIR" \
      --out "$OUT/shards/binaqual_$s.csv" \
      --shard "$s" --n-shards "$N_BINAQUAL" \
      > "$OUT/logs/binaqual_$s.log" 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p"; done
}

stage_bamq() {
  echo ">>> BAM-Q on $N_BAMQ shards x $MATLAB_THREADS threads"
  local pids=()
  for s in $(seq 0 $((N_BAMQ - 1))); do
    "$MATLAB" -nodisplay -nosplash -sd "$HERE/src" -batch \
      "maxNumCompThreads($MATLAB_THREADS); run_bamq('$PAIRS','$BAMQ_DIR','$OUT/shards/bamq_$s.csv',$s,$N_BAMQ)" \
      > "$OUT/logs/bamq_$s.log" 2>&1 &
    pids+=($!)
  done
  for p in "${pids[@]}"; do wait "$p"; done
}

stage_merge() {
  echo ">>> merging shards"
  "$PYTHON" "$HERE/src/merge_results.py" \
    --pairs "$PAIRS" --manifest "$MANIFEST" \
    --shard-dir "$OUT/shards" --out "$OUT/metrics_long.csv"
}

case "${1:-all}" in
  prepare)  stage_prepare ;;
  pairs)    stage_pairs ;;
  binaqual) stage_binaqual ;;
  bamq)     stage_bamq ;;
  merge)    stage_merge ;;
  all)      stage_prepare; stage_pairs; stage_binaqual; stage_bamq; stage_merge ;;
  *) echo "unknown stage: $1" >&2; exit 2 ;;
esac
echo "done: ${1:-all}"
