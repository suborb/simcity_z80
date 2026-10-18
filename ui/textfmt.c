#include "textfmt.h"
#include "numfmt.h"
#include "platform.h"

uint8_t fmt_str(char *b, uint8_t n, const char *s)
{
    while (*s)
        b[n++] = *s++;
    return n;
}

void fmt_blank(char *b)
{
    uint8_t i;
    for (i = 0; i < 40; ++i)
        b[i] = ' ';
    b[40] = 0;
}

void fmt_fields(const struct field *f, uint8_t n)
{
    char b[41], d[8];
    uint8_t row = 255, k, t[7], len, neg, i, c;
    const uint8_t *p;

    for (; n; --n, ++f) {
        if (f->row != row) {
            if (row != 255)
                plat_text_puts(0, row, b);
            row = f->row;
            fmt_blank(b);
        }
        k = f->kind;
        p = f->p;
        if (k == F_TEXT) {
            fmt_str(b, f->col, (const char *)p);
        } else if (k == F_STR) {
            fmt_str(b, f->col, *(const char *const *)p);
        } else {
            t[0] = p[0];                            /* the value as 24 bits */
            t[1] = k == F_U8 ? 0 : p[1];
            t[2] = k < F_U24 ? 0 : p[2];
            neg = k == F_S24 && (t[2] & 0x80);
            if (neg) {                              /* its magnitude: 0 - the value */
                c = 1;
                for (i = 0; i < 3; ++i) {
                    len = (uint8_t)(~t[i] + c);
                    c = c && !len;
                    t[i] = len;
                }
            }
            len = fmt_dec3(d, t);
            if (k >= F_L24) {                       /* left aligned */
                for (i = 0; i < len; ++i)
                    b[f->col + i] = d[i];
                if (k == F_K24 && (p[0] | p[1] | p[2]))
                    b[f->col + len] = b[f->col + len + 1] = b[f->col + len + 2] = '0';
            } else {
                for (i = 0; i < len; ++i)
                    b[f->col - len + i] = d[i];
                if (neg)
                    b[f->col - len - 1] = '-';
                if (f->unit)
                    b[f->col] = f->unit;
            }
        }
    }
    if (row != 255)
        plat_text_puts(0, row, b);
}
