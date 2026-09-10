#!/bin/bash

if [ "$#" -ne 3 ]; then
    echo "Використання: $0 <perf_data_1> <perf_data_2> <output_file>"
    echo "Приклад: $0 O0/perf.data O3/perf.data flame_diff.svg"
    exit 1
fi

INPUT_FILE_1="$1"
INPUT_FILE_2="$2"
OUTPUT_FILE="$3"

FOLDED_1=$(mktemp)
FOLDED_2=$(mktemp)

echo "Обробка першого файлу ($INPUT_FILE_1)..."
perf script -i "$INPUT_FILE_1" | ~/FlameGraph/stackcollapse-perf.pl > "$FOLDED_1"

echo "Обробка другого файлу ($INPUT_FILE_2)..."
perf script -i "$INPUT_FILE_2" | ~/FlameGraph/stackcollapse-perf.pl > "$FOLDED_2"

echo "Генерація диференціального флеймграфа..."
~/FlameGraph/difffolded.pl "$FOLDED_1" "$FOLDED_2" | ~/FlameGraph/flamegraph.pl > "$OUTPUT_FILE"

rm "$FOLDED_1" "$FOLDED_2"

echo "Готово! Диференціальний флеймграф збережено у $OUTPUT_FILE"
