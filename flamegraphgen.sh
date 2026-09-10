#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Використання: $0 <input_file> <title> <output_file>"
    echo "Приклад: $0 O0/perf.data 'matmult -O0' flame_O0.svg"
    exit 1
fi

INPUT_FILE="$1"
TITLE="$2"
OUTPUT_FILE="$3"

perf script -i "$INPUT_FILE" | \
~/FlameGraph/stackcollapse-perf.pl | \
~/FlameGraph/flamegraph.pl --title "$TITLE" > "$OUTPUT_FILE"

echo "Flamegraph збережено до $OUTPUT_FILE"
