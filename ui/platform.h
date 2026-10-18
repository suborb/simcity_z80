/* What the game core needs from a platform.  Implemented once per kind of
   display: platform/console (z88dk conio: Aquarius+, NC200, Z88) and
   platform/test_ui (headless). */
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>

/* Key codes returned by plat_key().  Printable keys return their ASCII code. */
#define KEY_NONE   0
#define KEY_LEFT   8
#define KEY_RIGHT  9
#define KEY_DOWN   10
#define KEY_UP     11
#define KEY_ENTER  13
#define KEY_ESC    27

extern void     plat_init(void);
extern void     plat_exit(void);
extern uint8_t  plat_cols(void);                /* character columns */
extern uint8_t  plat_rows(void);                /* character rows */
extern void     plat_put(uint8_t col, uint8_t row, uint8_t ch);
extern void     plat_puts(uint8_t col, uint8_t row, const char *s);
extern void     plat_clear(void);
extern uint8_t  plat_key(void);                 /* KEY_NONE if no key is waiting */
extern uint16_t plat_clock(void);               /* free running counter, for seeding */
extern void     plat_idle(void);                /* called once per frame: may wait */
extern void     plat_flush(void);               /* end of frame: show what was drawn */

/* Tile graphics.  A platform that can show the game's 8x8 pictures returns 1
   from plat_has_tiles() and draws one in a character cell with plat_put_tile();
   the rest get characters from plat_put().
     art      8 bytes of 1bpp art, as returned by view_fetch() (a pointer into the
              engine's tile table, which the platform may use to tell tiles apart)
     attr     the Spectrum-format attribute for the picture (colour platforms)
     inverse  1 for the blinking cursor: the picture with its pixels inverted */
extern uint8_t  plat_has_tiles(void);
extern void     plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);

#endif
