/* Decimal printing of a number, with no 32 bit division (see numfmt.asm). */
#ifndef NUMFMT_H
#define NUMFMT_H

#include <stdint.h>

/* v in decimal at b, no leading zeros ("0" for 0); returns the number of characters, up to 8. */
extern uint8_t fmt_dec(char *b, uint32_t v);

#endif
