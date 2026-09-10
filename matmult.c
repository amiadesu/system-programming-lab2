#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static unsigned long rng = 88172645463325252UL;

static unsigned long xorshift64(void) {
    rng ^= rng << 13;
    rng ^= rng >> 7;
    rng ^= rng << 17;
    return rng;
}

static float next_float(void) {
    return (float)((xorshift64() >> 40) / 16777216.0);
}

void fill_random(float *m, size_t n) {
    for (size_t i = 0; i < n; i++)
        m[i] = next_float();
}

void init_matrices(float *a, float *b, float *c, int n) {
    size_t sz = (size_t)n * n;
    fill_random(a, sz);
    fill_random(b, sz);
    memset(c, 0, sz * sizeof(float));
}

/* hot kernel: i-k-j order, inner loop over j is contiguous -> vectorizable */
void multiply(const float * restrict a, const float * restrict b,
              float * restrict c, int n) {
    for (int i = 0; i < n; i++) {
        for (int k = 0; k < n; k++) {
            float aik = a[(size_t)i * n + k];
            for (int j = 0; j < n; j++) {
                c[(size_t)i * n + j] += aik * b[(size_t)k * n + j];
            }
        }
    }
}

double checksum(const float *c, int n) {
    double s = 0.0;
    size_t sz = (size_t)n * n;
    for (size_t i = 0; i < sz; i++)
        s += c[i];
    return s;
}

static double now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

int main(int argc, char **argv) {
    int n    = (argc > 1) ? atoi(argv[1]) : 1024;
    int reps = (argc > 2) ? atoi(argv[2]) : 5;
    size_t sz = (size_t)n * n * sizeof(float);

    float *a = malloc(sz), *b = malloc(sz), *c = malloc(sz);
    if (!a || !b || !c) { fprintf(stderr, "alloc failed\n"); return 1; }

    double t0 = now();
    for (int r = 0; r < reps; r++) {
        init_matrices(a, b, c, n);
        multiply(a, b, c, n);
    }
    double t1 = now();

    double s = checksum(c, n);
    double flops = 2.0 * n * n * n * reps;
    printf("N=%d reps=%d  time=%.3f s  %.2f GFLOP/s  checksum=%.4f\n",
           n, reps, t1 - t0, flops / (t1 - t0) / 1e9, s);

    free(a); free(b); free(c);
    return 0;
}
