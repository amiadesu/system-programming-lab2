gcc -O0 -g -fno-omit-frame-pointer -o matmult_O0 matmult.c
gcc -O3 -march=native -g -fno-omit-frame-pointer -o matmult_O3native matmult.c
gcc -O0 -S -masm=intel -fverbose-asm -o asm_O0.s matmult.c
gcc -O3 -march=native -S -masm=intel -fverbose-asm -o asm_O3.s matmult.c
