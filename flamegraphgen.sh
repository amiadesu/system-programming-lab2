#!/usr/bin/env bash
# Побудова FlameGraph з perf.data
#   ./flamegraphgen.sh <perf.data> <заголовок> <вихід.svg>
set -euo pipefail
FG=${FG:-$HOME/FlameGraph}

if [ "$#" -ne 3 ]; then
    echo "Використання: $0 <input_file> <title> <output_file>"
    echo "Приклад: $0 results/O0/perf.data 'matmult -O0' flame_O0.svg"
    exit 1
fi

INPUT_FILE="$1"
TITLE="$2"
OUTPUT_FILE="$3"
FOLDED="${OUTPUT_FILE%.svg}.folded"

perf script -i "$INPUT_FILE" | "$FG/stackcollapse-perf.pl" > "$FOLDED"
"$FG/flamegraph.pl" --title "$TITLE" "$FOLDED" > "$OUTPUT_FILE"

echo "Flamegraph збережено до $OUTPUT_FILE"
echo "Згорнуті стеки   : $FOLDED"
echo "Семплів усього   : $(awk '{s+=$NF} END{print s+0}' "$FOLDED")"
