/* What the game core needs from a platform.  Implemented once per kind of
   display: platform/console (z88dk conio: NC200), target/aqplus, target/zx, target/z88, and
   target/test_ui (headless). */
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>
#include "plat_config.h"       /* the platform's own: what it can do, and which features it has */

/* Key codes returned by plat_key().  Printable keys return their ASCII code. */
#define KEY_NONE   0
#define KEY_LEFT   8
#define KEY_RIGHT  9
#define KEY_DOWN   10
#define KEY_UP     11
#define KEY_ENTER  13
#define KEY_FAR_LEFT  28            /* a platform with cursor keys sends these for shift + cursor: eight cells */
#define KEY_FAR_RIGHT 29
#define KEY_FAR_DOWN  30
#define KEY_FAR_UP    31
#define KEY_ESC    27

/* Commands.  A platform with menus (the Z88's OZ menus) returns these from plat_key() just as it
   returns keys; the game treats them like the keys that do the same thing.  The codes are the
   range OZ gives menu commands (0x81..0xB0), which the Z88's application descriptor uses. */
#define CMD_DISASTER        0x81    /* + 0..5 (0x81..0x86): start a fire, flood, earthquake, air crash, tornado or meltdown */
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
#define CMD_MAP             0x87    /* + view 0..7 (0x87..0x8E): show that mini map (see ui/minimap.h) */
#define CMD_MAP_OFF         0xA3    /* back to the city */
#define CMD_BUDGET          0xA4    /* the budget screen */
#define CMD_EVALUATION      0xA5    /* the evaluation screen: how the mayor is doing */
#define CMD_SAVE            0xA6    /* save the city to a file */
#define CMD_LOAD            0xA7    /* load a city from a file */
#define CMD_AUTOBUDGET_ON   0xA8    /* the engine runs the annual budget itself */
#define CMD_AUTOBUDGET_OFF  0xA9    /* the annual budget waits for the player */
#define CMD_SOUND_ON        0xAA
#define CMD_SOUND_OFF       0xAB

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

/* What a platform is and has is set by its plat_config.h, which defines these macros:
     HAVE_TEXT_WINDOW  a text window of its own beside the map (the Z88's OZ window): the map then gets the
                       whole console and everything textual is drawn with plat_text_puts() in the window's
                       coordinates.  Without it the text shares the screen, the top third.
     HAVE_TILES        it can draw the game's own 8x8 pictures (plat_put_tile())
     HAVE_BITMAP       it can draw pictures of the game's own making (plat_put_bitmap()); needed by HAVE_MINIMAP
     HAVE_ICONS        the tools as small pictures in rows 3 and 4 of the text area (plat_icons()); the status
                       panel then has the advisor message on row 6 and no key tips
     HAVE_ICONS_TOP    with HAVE_ICONS: the date, funds and population are on row 0, the icons in rows 1 and 2, then
                       the tool, the demand bars and the advisor: a six row panel (no text window; ui/game.c)
     HAVE_MENUS        menus of its own, which have quit: the X key does not quit there, ESC leaves a mini map,
                       and the cursor keys move (Q, A, O and P do not)
     HAVE_FILES        files, for saving and loading a city (plat_file_save()/plat_file_load())
     HAVE_APPNAME      the machine can show what the city is called (plat_set_name(); the Z88's Index)
     HAVE_SOUND        a beeper behind the engine's sound hooks (the Makefile links the platform's sound code, or
                       platform/common/nosound.asm if there is none); `sound_enabled` is the player's on/off
   and the optional features: HAVE_BUDGET, HAVE_EVALUATION, HAVE_MINIMAP, HAVE_SPRITES (see ui/*.c).  The
   screens and the status panel drawn from tables of fields (HAVE_FIELDS) come with any of the screens. */
#if defined(HAVE_BUDGET) || defined(HAVE_EVALUATION) || defined(HAVE_FILES) || defined(HAVE_ICONS) || defined(HAVE_APPNAME)
#ifndef HAVE_FIELDS
#define HAVE_FIELDS
#endif
#endif
#if defined(HAVE_MINIMAP) && !defined(HAVE_BITMAP)
#error "the mini maps need HAVE_BITMAP"
#endif
#if defined(HAVE_ICONS) && !defined(HAVE_TILES) && !defined(HAVE_TEXT_WINDOW)
#error "the icons need a text window, or pictures"
#endif

/* The text area.  Where there is a text window the status text, the title and the screens go in it; elsewhere
   plat_text_puts() is plat_puts() and plat_text_clear() is plat_clear(). */
extern uint8_t  plat_text_cols(void);
extern uint8_t  plat_text_rows(void);
extern void     plat_text_clear(void);
extern void     plat_text_puts(uint8_t col, uint8_t row, const char *s);

#ifdef HAVE_ICONS
/* plat_icons() draws the 14 tool icons in rows 3 and 4 of the text area (28 columns), tool `selected` highlighted. */
extern void     plat_icons(uint8_t selected);
#endif

#ifdef HAVE_TILES
/* Tile graphics: plat_put_tile() draws one of the engine's 8x8 pictures in a character cell.
     art      8 bytes of 1bpp art, as returned by view_fetch() (a pointer into the engine's tile table, which
              the platform may use to tell tiles apart)
     attr     the Spectrum-format attribute for the picture (colour platforms)
     inverse  1 for the blinking cursor: the picture with its pixels inverted */
extern void     plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);
#endif

#ifdef HAVE_BITMAP
/* plat_put_bitmap() draws 8 bytes of 1bpp art (a byte a pixel row, bit 7 on the left) in a character cell. */
extern void     plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art);
#endif

#if defined(HAVE_FILES) || defined(HAVE_APPNAME)
/* plat_text_input() lets the player edit a line of text at (col, row) of the text area, with the machine's own line
   editor (the Z88's OZ, or the console's fgets_cons): up to `max` characters into buf (max + 2 bytes), spaces allowed
   if `spaces` is set (a platform whose editor cannot tell may allow them anyway).  Returns 1 for a line, 0 if it is
   empty or was cancelled, and 2 if the platform wants the game to quit. */
extern uint8_t  plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces);
#endif

#ifdef HAVE_APPNAME
extern void     plat_set_name(const char *name);       /* the city's name: shown by the machine as it likes */
#endif

#ifdef HAVE_SOUND
extern uint8_t  sound_enabled;          /* the player's choice: 1 for sound, 0 for none */
#endif

#ifdef HAVE_FILES
/* plat_file_save() writes the two blocks one after the other to the named file; it returns 0 if all the
   bytes were written.  plat_file_load() reads them back: 0 if both were read in full, 1 if nothing was read
   (no such file, or too short for the first block), 2 if the second block was cut short (it has been
   partly overwritten). */
extern uint8_t  plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen);
extern uint8_t  plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen);
#endif

#endif
