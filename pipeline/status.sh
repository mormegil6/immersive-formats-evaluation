#!/usr/bin/env bash
# Progress of every scoring arm, plus the memory headroom that actually
# constrains this pipeline.  Designed to be re-run continuously:
#
#     watch -n 20 -c pipeline/status.sh
#
# Memory matters more than CPU here: a single MATLAB process sits near 1 GB for
# most of a pair and then spikes to ~21 GB, so the machine can look idle right
# up until it runs out. The headroom line is the one to watch.

O="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data/revision"

rows() { tail -n +2 "$1" 2>/dev/null | wc -l | tr -d ' '; }
sum()  { local t=0; for f in "$@"; do t=$((t + $(rows "$f"))); done; echo "$t"; }

bar() { # bar <done> <total> [width]
  local d=$1 t=$2 w=${3:-28}
  local f=$(( t > 0 ? d * w / t : 0 )); ((f > w)) && f=$w
  printf "["
  printf "%0.s#" $(seq 1 $f) 2>/dev/null
  printf "%0.s." $(seq 1 $((w - f))) 2>/dev/null
  printf "] %4s/%-4s %3s%%" "$d" "$t" "$(( t > 0 ? d * 100 / t : 0 ))"
}

line() { printf "  %-34s %s\n" "$1" "$(bar "$2" "$3")"; }

echo "=============================================================================="
echo " immersive-formats scoring          $(date '+%a %H:%M:%S')"
echo "=============================================================================="
echo " 60 s centred analysis"
line "BAM-Q   aligned"        "$(rows "$O/shards/bamq_aligned.csv")"     108
line "BAM-Q   no-align ctrl"  "$(rows "$O/shards/bamq_noalign.csv")"      36
line "BINAQUAL aligned"       "$(rows "$O/shards/binaqual_aligned.csv")" 108
line "BINAQUAL no-align ctrl" "$(rows "$O/shards/binaqual_noalign.csv")"  36
echo
echo " 5-segment coverage"
line "BAM-Q   primary anchor" "$(sum "$O/shards/bamq_seg_0.csv" "$O/shards/bamq_seg_1.csv")" 180
line "BINAQUAL primary anchor" "$(rows "$O/shards/binaqual_segments.csv")" 180
line "BINAQUAL anchor sens."  "$(rows "$O/shards/binaqual_anchseg_merged.csv")" 360
echo
echo "------------------------------------------------------------------------------"

mat=$(pgrep -f 'maca64/MATLAB' 2>/dev/null | wc -l | tr -d ' ')
pyw=$(pgrep -f 'run_binaqual' 2>/dev/null | wc -l | tr -d ' ')
mrss=$(ps -Ao rss,comm | grep -i 'maca64/MATLAB' | awk '{s+=$1} END {printf "%.1f", s/1048576}')
[ -z "$mrss" ] && mrss=0.0
free=$(vm_stat | awk '/Pages free/{f=$3}/Pages inactive/{i=$3}/Pages speculative/{s=$3}
        END{gsub(/\./,"",f);gsub(/\./,"",i);gsub(/\./,"",s);printf "%.0f",(f+i+s)*16384/1073741824}')
printf "  workers   : %s MATLAB, %s BINAQUAL\n" "$mat" "$pyw"
printf "  MATLAB RSS: %s GB now   (peaks ~21 GB per process, transiently)\n" "$mrss"
printf "  headroom  : %s GB free+inactive" "$free"
if   [ "$free" -lt 10 ]; then echo "   <-- LOW"
elif [ "$free" -lt 20 ]; then echo "   <-- tight"
else echo ""; fi
printf "  load      : %s\n" "$(uptime | sed 's/.*averages: //')"

last=$(ls -t "$O/logs"/bamq_seg_*.log 2>/dev/null | head -1)
[ -n "$last" ] && printf "\n  latest    : %s\n" "$(grep '^\[shard' "$last" | tail -1 | cut -c1-72)"
echo "=============================================================================="
