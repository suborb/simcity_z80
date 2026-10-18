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

/* Commands.  A platform with menus (the Z88's OZ menus) returns these from plat_key() just as it
   returns keys; the game treats them like the keys that do the same thing.  The codes are the
   range OZ gives menu commands (0x81..0xB0), which the Z88's application descriptor uses. */
#define CMD_TOOL            0x81    /* + tool number 0..13 (0x81..0x8E): choose that tool */
#define CMD_NEW_CITY        0x90    /* back to the title screen, then a new city */
#define CMD_PAUSE           0x91    /* pause or resume */
#define CMD_SPEED_FAST      0x92
#define CMD_SPEED_NORMAL    0x93
#define CMD_SPEED_SLOW      0x94
#define CMD_POWER_COAL      0x95    /* what the power plant tool builds */
#define CMD_POWER_NUCLEAR   0x96
#define CMD_DISASTERS_ON    0x97
#define CMD_DISASTERS_OFF   0x98
#define CMD_AUTOBULLDOZE_ON 0x99    /* tools clear what is in the way */
#define CMD_AUTOBULLDOZE_OFF 0x9A
#define CMD_QUIT            0x9B
#define CMD_REDRAW          0x9C    /* the screen was overwritten (OZ asks for a redraw) */

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

/* The text area.  On most platforms the status text shares the screen with the map, in the top
   third (the game's layout decides).  A platform with a text window of its own - the Z88's OZ
   text window beside its map - says so with plat_has_text_window(): the map then gets the whole
   console, and everything textual (the title, "generating landscape", the status panel) is drawn
   with plat_text_puts() in the text window's own coordinates.  Elsewhere plat_text_puts() is
   plat_puts() and plat_text_clear() is plat_clear(). */
extern uint8_t  plat_has_text_window(void);
extern uint8_t  plat_text_cols(void);
extern uint8_t  plat_text_rows(void);
extern void     plat_text_clear(void);
extern void     plat_text_puts(uint8_t col, uint8_t row, const char *s);

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
