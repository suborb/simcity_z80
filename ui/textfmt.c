#include "textfmt.h"

extern void bcd24(uint8_t *p) __z88dk_fastcall;       /* numfmt.asm */

uint8_t fmt_dec3(char *b, uint8_t *t)
{
    uint8_t n = 0, i, d, half;

    bcd24(t);                               /* t[3..6]: the digits, two a byte */
    for (i = 6; i >= 3; --i)
        for (half = 0; half < 2; ++half) {
            d = half ? (uint8_t)(t[i] & 15) : (uint8_t)(t[i] >> 4);
            if (d || n || (i == 3 && half))   /* no leading zeros, but a lone 0 */
                b[n++] = (char)('0' + d);
        }
    return n;
}

uint8_t fmt_dec(char *b, uint32_t v)
{
    uint8_t t[7];

    t[0] = (uint8_t)v;
    t[1] = (uint8_t)(v >> 8);
    t[2] = (uint8_t)(v >> 16);
    return fmt_dec3(b, t);
}

#ifdef HAVE_FIELDS
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

static const uint8_t kind_bytes[8] = { 0, 0, 1, 2, 3, 3, 3, 3 };     /* how many bytes each kind of number is */

void fmt_fields(const struct field *f, uint8_t n)
{
    char b[41], d[8], *q;
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
        q = b + f->col;
        if (k == F_TEXT) {
            fmt_str(q, 0, (const char *)p);
        } else if (k == F_STR) {
            fmt_str(q, 0, *(const char *const *)p);
        } else {
            for (i = 0; i < 3; ++i)                 /* the value as 24 bits */
                t[i] = i < kind_bytes[k] ? p[i] : 0;
            neg = k == F_S24 && (t[2] & 0x80);
            for (c = neg, i = 0; neg && i < 3; ++i) {   /* its magnitude: 0 - the value */
                len = (uint8_t)(~t[i] + c);
                c = c && !len;
                t[i] = len;
            }
            len = fmt_dec3(d, t);
            if (k >= F_L24) {                       /* left aligned */
                for (i = 0; i < len; ++i)
                    q[i] = d[i];
                if (k == F_K24 && (p[0] | p[1] | p[2]))
                    q[len] = q[len + 1] = q[len + 2] = '0';
            } else {
                q -= len;
                for (i = 0; i < len; ++i)
                    q[i] = d[i];
                if (neg)
                    q[-1] = '-';
                if (f->unit)
                    q[len] = f->unit;
            }
        }
    }
    if (row != 255)
        plat_text_puts(0, row, b);
}
#endif
