/* Small helpers for laying text out in fixed columns (the budget and evaluation screens). */
#ifndef TEXTFMT_H
#define TEXTFMT_H

#include <stdint.h>

extern uint32_t fmt_u24(const uint8_t *p);                  /* a 24 bit little endian value */
extern int32_t  fmt_s24(const uint8_t *p);                  /* the same, signed */
extern uint8_t  fmt_str(char *b, uint8_t n, const char *s); /* s at b[n..]; returns the column after it */
extern void     fmt_num(char *b, uint8_t end, int32_t v);   /* v right aligned, ending before column end */
extern void     fmt_blank(char *b);                         /* 40 spaces and a NUL */

#endif
