#!/usr/bin/env bash
set -e

# бінарники для профілювання
gcc -O0                -g -fno-omit-frame-pointer -o matmult_O0        matmult.c
gcc -O3 -march=native  -g -fno-omit-frame-pointer -o matmult_O3native  matmult.c

# проміжні рівні: драбинка скаляр -> SSE -> AVX2 (п.4.1.1)
gcc -O2                -g -fno-omit-frame-pointer -o matmult_O2        matmult.c
gcc -O3                -g -fno-omit-frame-pointer -o matmult_O3        matmult.c

# асемблер (Intel-синтаксис, з коментарями компілятора)
gcc -O0               -S -masm=intel -fverbose-asm -o asm_O0.s        matmult.c
gcc -O2               -S -masm=intel -fverbose-asm -o asm_O2.s        matmult.c
gcc -O3               -S -masm=intel -fverbose-asm -o asm_O3.s        matmult.c
gcc -O3 -march=native -S -masm=intel -fverbose-asm -o asm_O3native.s  matmult.c
