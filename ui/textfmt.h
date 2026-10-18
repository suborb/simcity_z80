/* Laying text out in fixed columns, for the screens that are tables of fields (budget, evaluation). */
#ifndef TEXTFMT_H
#define TEXTFMT_H

#include <stdint.h>

extern uint8_t  fmt_str(char *b, uint8_t n, const char *s); /* s at b[n..]; returns the column after it */
extern void     fmt_blank(char *b);                         /* 40 spaces and a NUL */

/* A screen as a table: what goes where.  fmt_fields() lays the fields out a row at a time (they must
   be in row order) and writes each row to the text area with plat_text_puts(). */
#define F_TEXT 0                /* p is the string; col is its first column */
#define F_STR  1                /* p points to a const char * that holds the string */
#define F_U8   2                /* p points to a number, right aligned: col is the column after its last digit */
#define F_U16  3
#define F_U24  4                /* three bytes, little endian */
#define F_S24  5                /* the same, signed */
#define F_L24  6                /* a 24 bit number, left aligned: col is its first digit */
#define F_K24  7                /* the same, a number of thousands: its digits then 000 (or just 0) */

struct field {
    uint8_t row, col, kind, unit;       /* unit: a character to put straight after a right aligned number, or 0 */
    const void *p;
};

extern void fmt_fields(const struct field *f, uint8_t n);

#endif
