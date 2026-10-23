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
    for (i = 0; i < FMT_WIDTH; ++i)
        b[i] = ' ';
    b[FMT_WIDTH] = 0;
}

/* Called by the table drawing (fmtfields.asm) with a finished row. */
#ifdef MODAL_X
uint8_t fmt_col0;
#define FMT_COL0 fmt_col0
#else
#define FMT_COL0 0
#endif

void fmt_flush(const char *row) __z88dk_fastcall
{
    plat_text_puts(FMT_COL0, fmt_row, row);
}

#ifdef HAVE_TEXT_COLOUR
void fmt_fields_each(const struct field *f, uint8_t n, void (*done)(uint8_t row))
{
    uint8_t i = 0, j, row;

    while (i < n) {
        row = f[i].row;
        for (j = i; j < n && f[j].row == row; ++j)
            ;
        fmt_fields(f + i, (uint8_t)(j - i));
        done(row);
        i = j;
    }
}
#endif
#endif
