/* Numbers as text, and (with HAVE_FIELDS, see ui/platform.h) the screens that are tables of fields. */
#ifndef TEXTFMT_H
#define TEXTFMT_H

#include <stdint.h>
#include "platform.h"

/* v in decimal at b, no leading zeros ("0" for 0); returns the number of characters, up to 8.  There is
   no 32 bit division in it: see numfmt.asm. */
extern uint8_t fmt_dec(char *b, uint32_t v);

/* The same for the 24 bit value in t[0..2] (little endian); t must have 7 bytes, which are overwritten. */
extern uint8_t fmt_dec3(char *b, uint8_t *t);

#ifdef HAVE_FIELDS
#ifdef MODAL_X
extern uint8_t  fmt_col0;                                   /* the column the rows of a table are written from (0, except for a screen that sets it) */
#endif
extern uint8_t  fmt_str(char *b, uint8_t n, const char *s); /* s at b[n..]; returns the column after it */
extern void     fmt_blank(char *b);                         /* FMT_WIDTH (40, or a narrower display's) spaces and a NUL */

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

/* The drawing is in assembler (fmtfields.asm): fmt_fields(f, n) draws n fields of the table f. */
extern uint8_t fmt_count, fmt_row;
extern void fmt_run(const struct field *f) __z88dk_fastcall;
#define fmt_fields(f, n)    do { fmt_count = (n); fmt_run(f); } while (0)

#ifdef HAVE_TEXT_COLOUR
/* The same a row at a time, calling done(row) after each: the screens that colour their text do it row by row, so that only one row at
   a time is ever drawn plain (a whole screen printed and then coloured shows its colours gone for the time that takes). */
extern void fmt_fields_each(const struct field *f, uint8_t n, void (*done)(uint8_t row));
#endif
#endif

#endif
