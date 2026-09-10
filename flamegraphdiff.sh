#!/usr/bin/env bash
# Диференціальний FlameGraph
#   ./flamegraphdiff.sh <до> <після> <вихід.svg>
#   приймає і perf.data, і готові .folded
set -euo pipefail
FG=${FG:-$HOME/FlameGraph}

if [ "$#" -ne 3 ]; then
    echo "Використання: $0 <до> <після> <output_file>"
    echo "Приклад: $0 flame_O0.folded flame_O3.folded flame_diff.svg"
    exit 1
fi

OUTPUT_FILE="$3"
TMP=()
trap 'rm -f "${TMP[@]:-}"' EXIT

fold() { # perf.data -> .folded, .folded -> як є
    if [[ "$1" == *.folded ]]; then
        echo "$1"
    else
        local t; t=$(mktemp); TMP+=("$t")
        perf script -i "$1" | "$FG/stackcollapse-perf.pl" > "$t"
        echo "$t"
    fi
}

F1=$(fold "$1")
F2=$(fold "$2")

echo "до    : $1  ($(awk '{s+=$NF} END{print s+0}' "$F1") семплів)"
echo "після : $2  ($(awk '{s+=$NF} END{print s+0}' "$F2") семплів)"

"$FG/difffolded.pl" -n "$F1" "$F2" | "$FG/flamegraph.pl" > "$OUTPUT_FILE"

echo "Готово! Диференціальний флеймграф збережено у $OUTPUT_FILE"
