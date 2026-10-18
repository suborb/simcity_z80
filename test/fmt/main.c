/* Decimal printing: fmt_dec on a list of values, read back by test/fmt/run.py. */
#include <stdint.h>
#include "textfmt.h"

#define N 24
uint32_t fmt_in[N] = {0, 1, 9, 10, 11, 99, 100, 101, 999, 1000, 9999, 10000, 12345, 99999, 100000,
                      999999, 1000000, 1234567, 9999999, 10000000, 12345678, 8388607, 8388608, 16777215};
char fmt_out[N][10];
uint8_t fmt_len[N];

int main(void)
{
    uint8_t i;

    for (i = 0; i < N; ++i) {
        fmt_len[i] = fmt_dec(fmt_out[i], fmt_in[i]);
        fmt_out[i][fmt_len[i]] = 0;
    }
    return 0;
}
