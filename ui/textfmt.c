#include "textfmt.h"
#include "numfmt.h"

uint32_t fmt_u24(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16);
}

int32_t fmt_s24(const uint8_t *p)
{
    uint32_t v = fmt_u24(p);
    return (int32_t)((v & 0x800000UL) ? (v | 0xFF000000UL) : v);
}

uint8_t fmt_str(char *b, uint8_t n, const char *s)
{
    while (*s)
        b[n++] = *s++;
    return n;
}

void fmt_num(char *b, uint8_t end, int32_t v)
{
    char t[10];
    uint8_t neg = v < 0, n;

    n = fmt_dec(t, neg ? (uint32_t)-v : (uint32_t)v);
    while (n)
        b[--end] = t[--n];
    if (neg)
        b[--end] = '-';
}

void fmt_blank(char *b)
{
    uint8_t i;
    for (i = 0; i < 40; ++i)
        b[i] = ' ';
    b[40] = 0;
}
