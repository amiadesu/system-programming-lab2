#!/usr/bin/env bash
# measure.sh -- п.2 (time -v, perf stat, perf report) + п.3 (енергія) за прапорцем -e
#   ./measure.sh [-e] <програма> [аргументи...]
set -u
export LC_ALL=C

ENERGY=0
[[ ${1:-} == -e ]] && { ENERGY=1; shift; }
[[ $# -eq 0 ]] && { echo "usage: $0 [-e] <програма> [аргументи]"; exit 1; }

OUT=${OUT:-results/$(basename "$1")-$(date +%H%M%S)}
BL=${BL:-5} # секунд на вимірювання фону
COOL=${COOL:-5} # секунд на охолодження перед енергопрогоном
mkdir -p "$OUT"

# CPU=2 ./measure.sh ... -- прив'язати до ядра, прибирає міграції між ядрами
RUN=(); [[ -n ${CPU:-} ]] && RUN=(taskset -c "$CPU")

HAVE_RAPL=0
if (( ENERGY )); then
  R=/sys/class/powercap/intel-rapl:0
  RE=$R/energy_uj
  RMAX=$R/max_energy_range_uj

  if [[ -r $RMAX ]]; then emax=$(cat "$RMAX"); else emax=0; fi

  # розрахунок ΔE з поправкою на можливе занулення лічильника
  ediff() {
    local a=$1 b=$2
    if   (( b >= a ));   then echo $(( b - a ))
    elif (( emax > 0 )); then echo $(( b - a + emax ))
    else echo 0
    fi
  }

  if [[ -e $RE ]] && sudo -v; then
    HAVE_RAPL=1
    rd(){ sudo cat "$RE"; }
    sync; sleep 2
    e0=$(rd); sleep "$BL"; e1=$(rd)
    idle=$(( $(ediff "$e0" "$e1") / BL ))   # мкВт
  else
    echo "RAPL недоступний (немає $RE або відмовлено в sudo)" > "$OUT/energy.txt"
  fi
fi

"${RUN[@]}" "$@" >/dev/null 2>&1 # прогрів задля гарячого запуску, результат викидаємо

# --- п.2.1 ---
/usr/bin/time -v "${RUN[@]}" "$@" >/dev/null 2> "$OUT/time-v.txt"
# --- п.2.2 ---
perf stat -d -r 3 "${RUN[@]}" "$@" >/dev/null 2> "$OUT/perf-stat.txt"
# --- п.2.3 ---
perf record -F 999 -g --call-graph dwarf -o "$OUT/perf.data" "${RUN[@]}" "$@" >/dev/null 2>&1
perf report -i "$OUT/perf.data" --stdio --no-children > "$OUT/perf-report.txt"

# --- п.3, крок 2: прогін під навантаженням ----------------------------
if (( ENERGY )) && (( HAVE_RAPL )); then
  sync; sleep "$COOL"

  e0=$(rd); t0=$(date +%s.%N)
  "${RUN[@]}" "$@" >/dev/null
  e1=$(rd); t1=$(date +%s.%N)
  e=$(ediff "$e0" "$e1")

  awk -v e="$e" -v i="$idle" -v t0="$t0" -v t1="$t1" 'BEGIN{
    t=t1-t0; E=e/1e6; Pi=i/1e6; Ep=E-Pi*t
    printf "t       = %.3f с\nE_total = %.2f Дж\nP_avg   = %.2f Вт\nP_idle  = %.2f Вт\nE_prog  = %.2f Дж\nEDP     = %.2f Дж*с\n", t,E,E/t,Pi,Ep,E*t
    if (Ep <= 0)
      printf "\nУВАГА: E_prog <= 0 -- P_idle завищений.\n       Закрийте фонові процеси, збільште COOL, повторіть.\n"
  }' > "$OUT/energy.txt"
fi

# зведений звіт: усі діагностики в одному файлі
{
  echo "########## $(basename "$1") ${*:2}"
  echo "дата : $(date -Is)"
  echo "хост : $(uname -srm)"
  echo "CPU  : $(grep -m1 'model name' /proc/cpuinfo | sed 's/.*: //')"
  echo "gov  : $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
  for f in time-v perf-stat perf-report energy; do
    [[ -s "$OUT/$f.txt" ]] || continue
    echo; echo "########## $f"
    if [[ $f == perf-report ]]; then
      grep -E '^\s+[0-9]' "$OUT/$f.txt" | head -15
    else
      cat "$OUT/$f.txt"
    fi
  done
} > "$OUT/report.txt"

# якщо скрипт запустили через sudo -- повернути теку користувачеві
[[ -n ${SUDO_USER:-} ]] && chown -R "$SUDO_USER:$SUDO_USER" "$OUT"

cat "$OUT/report.txt"
