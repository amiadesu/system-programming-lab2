#!/usr/bin/env bash
#   ./measure.sh [-e] <програма> [аргументи...]
set -u
export LC_ALL=C

ENERGY=0
[[ ${1:-} == -e ]] && { ENERGY=1; shift; }
[[ $# -eq 0 ]] && { echo "usage: $0 [-e] <програма> [аргументи]"; exit 1; }

OUT=${OUT:-results/$(basename "$1")-$(date +%H%M%S)}
mkdir -p "$OUT"

"$@" >/dev/null 2>&1 # прогрів для забезпечення гарячого запуску, результат викидаємо

# --- п.2.1 ---
/usr/bin/time -v "$@" >/dev/null 2> "$OUT/time-v.txt"
# --- п.2.2 ---
perf stat -d -r 3 "$@" >/dev/null 2> "$OUT/perf-stat.txt"
# --- п.2.3 ---
perf record -F 999 -g --call-graph dwarf -o "$OUT/perf.data" "$@" >/dev/null 2>&1
perf report -i "$OUT/perf.data" --stdio --no-children > "$OUT/perf-report.txt"

cat "$OUT/time-v.txt" "$OUT/perf-stat.txt"
grep -E '^\s+[0-9]' "$OUT/perf-report.txt" | head -10

# --- п.3 ---
(( ENERGY )) || exit 0
R=/sys/class/powercap/intel-rapl:0/energy_uj
[[ -r $R ]] || { echo "RAPL недоступний (потрібен sudo / фізична машина)"; exit 1; }

e0=$(cat $R); sleep 5; e1=$(cat $R); idle=$(( (e1-e0)/5 ))   # мкВт

e0=$(cat $R); t0=$(date +%s.%N)
"$@" >/dev/null
e1=$(cat $R); t1=$(date +%s.%N)

awk -v e=$((e1-e0)) -v i="$idle" -v t0="$t0" -v t1="$t1" 'BEGIN{
  t=t1-t0; E=e/1e6; Pi=i/1e6
  printf "t       = %.3f с\nE_total = %.2f Дж   (п.3.1)\nP_avg   = %.2f Вт\nP_idle  = %.2f Вт\nE_prog  = %.2f Дж   (п.3.2)\n", t,E,E/t,Pi,E-Pi*t
}' | tee "$OUT/energy.txt"
