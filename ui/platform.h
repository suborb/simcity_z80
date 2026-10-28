/* What the game core needs from a platform.  Implemented once per kind of
   display: platform/console (z88dk conio: NC200), target/aqplus, target/multi8, target/zx, target/z88, and
   target/test_ui (headless). */
#ifndef PLATFORM_H
#define PLATFORM_H

#include <stdint.h>
#include "plat_config.h"       /* the platform's own: what it can do, and which features it has */

/* HAVE_DATA_PAGING (plat_config.h): the target banks the application's data, and plat_page_data() selects the data page (the UI calls it before it touches
   its variables again after the display code has run).  Flat-memory targets compile it away. */
#ifdef HAVE_DATA_PAGING
extern void plat_page_data(void);
#else
#define plat_page_data() ((void)0)
#endif

#ifndef HAVE_POINTER
#define plat_key_game() plat_key()              /* (a target with no pointer has one kind of key) */
#endif

/* Optional relative mouse device exposed to the UI as absolute screen pixels.
   Bit 0 of plat_mouse_input() means motion, bit 1 a new left press, and bit 2
   that the left button is held.  Targets own the device protocol and state. */
#ifdef HAVE_MOUSE
extern volatile int16_t plat_mouse_x, plat_mouse_y;
extern volatile uint8_t plat_mouse_buttons;
#ifdef HAVE_POINTER
/* The game's main loop reads its keys with plat_key_game(): the keyboard, and the mouse's right button as Esc (the menu).  Every other screen (the menus, the budget, the
   pickers) reads plat_key(), which also turns the mouse into keys: a step of 8 pixels is Up, Down, Left or Right, the left button Enter, the right Esc, and the arrow is hidden. */
extern uint8_t plat_key_game(void);
#define plat_mouse_present 1                    /* HAVE_POINTER (plat_config.h): the pointer is always there, and the keys move it if no mouse does */
#else
extern volatile uint8_t plat_mouse_present;
#endif
extern uint8_t plat_mouse_input(void);
extern void plat_mouse_init(void);
extern uint8_t plat_mouse_icon_hit(void);
/* Return nonzero when the pointer is at a viewport edge and the view moved. */
extern uint8_t plat_mouse_edge_scroll(void);
#endif
#ifdef HAVE_MOUSE_SPRITE
/* A pointer drawn by the hardware: positioned once a frame, and hidden while a menu is up (the keys use it). */
extern void plat_mouse_pointer_refresh(void);
extern void plat_mouse_pointer_hide(void);
#endif
#ifdef HAVE_MOUSE_POINTER
extern void plat_put_black_overlay(uint8_t col, uint8_t row, const uint8_t *art);
extern void plat_mouse_pointer_erase(void);
extern void plat_mouse_pointer_refresh(void);
#endif
/* Platforms with budget or evaluation screens state how many text rows their modal screens occupy.  The
   shared layouts are designed on an 8-row grid and spread over MODAL_ROWS, so the Z88 stays compact while
   full-screen targets can use their height. */
#if (defined(HAVE_BUDGET) || defined(HAVE_EVALUATION)) && !defined(MODAL_ROWS)
#error "a platform with modal screens must define MODAL_ROWS"
#endif
#if defined(MODAL_ROWS) && MODAL_ROWS < 8 && !defined(HAVE_TEXT_BANNER)
#error "MODAL_ROWS must be at least 8"
#endif
#if defined(HAVE_TEXT_BANNER) && !defined(HAVE_TEXT_WINDOW)
#error "a banner is the text window's"
#endif
/* The two screens have a layout for 40 or more columns (the default) and one for the 32 of many Z80 machines
   (a platform with a 32 column display sets MODAL_COLS to 32, and MODAL_ROWS to 24). */
/* The budget and evaluation screens have a 32 column arrangement (a row to each item, with room for bars), which a display of 32 columns uses.
   A platform with more can use it too by defining MODAL_NARROW, and MODAL_X to say the column the screens start at (4 to
   centre them in 40). */
#ifndef MODAL_NARROW
#if defined(MODAL_COLS) && MODAL_COLS < 40
#define MODAL_NARROW
#endif
#endif

#ifndef MODAL_COLS
#define MODAL_COLS 40
#endif
#if MODAL_COLS < 40 && (!defined(MODAL_ROWS) || MODAL_ROWS < 24)
#error "the 32 column layouts need MODAL_ROWS 24"
#endif
/* How wide a row of the table screens (ui/textfmt.h) is: 40, or a narrower display's width, which the platform's
   plat_config.h says (FMT_WIDTH).  The Makefile gives the assembler the same number as -Ca-DFMT_WIDTH=n
   (ui/fmtfields.asm). */
#ifndef FMT_WIDTH
#define FMT_WIDTH 40
#endif

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
#ifdef PLAT_FIXED_COLS
#define plat_cols() ((uint8_t)PLAT_FIXED_COLS)
#define plat_rows() ((uint8_t)PLAT_FIXED_ROWS)
#define plat_text_cols() plat_cols()
#define plat_text_rows() plat_rows()
#else
extern uint8_t  plat_cols(void);                /* character columns */
extern uint8_t  plat_rows(void);                /* character rows */
#endif
extern void     plat_put(uint8_t col, uint8_t row, uint8_t ch);
extern void     plat_puts(uint8_t col, uint8_t row, const char *s);
extern void     plat_clear(void);
extern uint8_t  plat_key(void);                 /* KEY_NONE if no key is waiting */
extern uint16_t plat_clock(void);               /* free running counter, for seeding */
extern uint16_t plat_entropy(void);             /* inexpensive Z80 refresh-register sample */
extern void     plat_idle(void);                /* called once per frame: may wait */
extern void     plat_flush(void);               /* end of frame: show what was drawn */
#ifdef HAVE_SCENARIOS
/* HAVE_SCENARIOS: the title screen offers scenarios (ready-made cities in the platform's own storage).
     plat_scenario_choose()                  shows them (a picture of each, its title and text) and returns the number chosen, or 0xff for none
     plat_scenario_load(n)                   puts scenario n's map in levelmap and returns its year
     plat_scenario_restore_state(n)          after the engine has been reset for it (sim_loaded): puts back what it keeps in the minimaps (power, traffic) and returns the disaster to start (V_disaster_option: 0 none)
     plat_scenario_preview_row(y, x, pixels) draws a row of the picture of a scenario: one colour a tile */
extern uint8_t  plat_scenario_choose(void);
extern uint16_t plat_scenario_load(uint8_t index);
extern uint8_t  plat_scenario_restore_state(uint8_t index);
extern void     plat_scenario_preview_row(uint8_t y, uint8_t x, const uint8_t *pixels);
#endif

/* What a platform is and has is set by its plat_config.h, which defines these macros:
     HAVE_TEXT_WINDOW  a text window of its own beside the map (the Z88's OZ window): the map then gets the
                       whole console and everything textual is drawn with plat_text_puts() in the window's
                       coordinates.  Without it the text shares the screen, the top third.
     HAVE_TEXT_BANNER  with HAVE_TEXT_WINDOW: the window is framed and its first row is a banner of the platform's own, so the
                       text area is a row shorter (MODAL_ROWS 7): the screens and the status panel are laid out in 7 rows
     HAVE_TILES        it can draw the game's own 8x8 pictures (plat_put_tile())
     HAVE_BITMAP       it can draw pictures of the game's own making (plat_put_bitmap()); needed by HAVE_MINIMAP (unless
                       it draws the mini maps itself: HAVE_MINIMAP_NATIVE)
     HAVE_SPRITE_OVERLAY  with HAVE_SPRITES and HAVE_TILES: the train, plane and tornado are drawn over the cell's tile
                       (plat_put_overlay()) instead of replacing it with the tile's picture ORed with theirs
                       (plat_put_bitmap()), which keeps the tile's colours where a screen has them
     HAVE_ICONS        the tools as small pictures in rows 3 and 4 of the text area (plat_icons()); the status
                       panel then has the advisor message on row 6 and no key tips
     HAVE_ICONS_TOP    with HAVE_ICONS: the date, funds and population are on row 0, the icons in rows 1 and 2, then
                       the tool, the demand bars and the advisor: a six row panel (no text window; ui/game.c)
     HAVE_SCROLL       the platform can move the map's pixels (plat_scroll()), so a scroll draws only the new cells (used when
                     the map is as wide as the screen)
   HAVE_MENUS        menus of its own, which have quit: the X key does not quit there, ESC leaves a mini map,
                       and the cursor keys move (Q, A, O and P do not, unless HAVE_KEYS_QAOP)
     HAVE_POPUP_MENU   use the shared console box + message selector (ui/menu.c): ESC opens it over the city, centred in the
                       map; the file dialogues (ui/prompt.c) are boxes too.  Do not set this on a platform with native
                       HAVE_MENUS
     HAVE_TEXT_COLOUR  the budget and evaluation screens in colour, with bar charts (plat_text_attr(), plat_bar())
     HAVE_DEMAND_BARS  the demand indicators as coloured bar charts (plat_demand())
     HAVE_ICONS_AFFORD the icons of the tools that cost more than the money dimmed (plat_afford())
     HAVE_POWER_ASK    placing a power station asks coal or nuclear when there is the money for both (needs HAVE_POPUP_MENU)
     HAVE_FILES        files, for saving and loading a city (plat_file_save()/plat_file_load()); FILE_NAME_MAX
                       (default 24) is the longest name the player may enter
     HAVE_APPNAME      the machine can show what the city is called (plat_set_name(); the Z88's Index)
     HAVE_SOUND        a beeper behind the engine's sound hooks (the Makefile links the platform's sound code, or
                       platform/common/nosound.asm if there is none); `sound_enabled` is the player's on/off
   and the optional features: HAVE_BUDGET, HAVE_EVALUATION, HAVE_MINIMAP, HAVE_SPRITES (see ui/*.c).  A mini-map
   target may set MINIMAP_CELLS_H (the default is the Z88's 8) to use more of its map window.  One with a colour screen of
   its own pixels can draw the mini maps itself instead, a row at a time (HAVE_MINIMAP_NATIVE: plat_put_minirow()): a
   colour a tile, or with HAVE_MINIMAP_ART the tiles' own pictures at a quarter of the size with the views laid over them
   (ui/minimap.h); there is no cursor on those maps and the cursor keys and the tools do nothing in them.  The screens
   and the status panel drawn from tables of fields (HAVE_FIELDS) come with any of the screens. */
#if defined(HAVE_BUDGET) || defined(HAVE_EVALUATION) || defined(HAVE_FILES) || defined(HAVE_ICONS) || defined(HAVE_APPNAME)
#ifndef HAVE_FIELDS
#define HAVE_FIELDS
#endif
#endif
#if defined(HAVE_MINIMAP) && !defined(HAVE_BITMAP) && !defined(HAVE_MINIMAP_NATIVE)
#error "the mini maps need HAVE_BITMAP"
#endif
#if defined(MINIMAP_CELLS_H) && (MINIMAP_CELLS_H < 1 || MINIMAP_CELLS_H > 24)
#error "MINIMAP_CELLS_H must be between 1 and 24"
#endif
#if defined(HAVE_ICONS) && !defined(HAVE_TILES) && !defined(HAVE_TEXT_WINDOW)
#error "the icons need a text window, or pictures"
#endif
#if defined(HAVE_MENUS) && defined(HAVE_POPUP_MENU)
#error "a platform uses either native menus or the shared popup menu"
#endif

/* The text area.  Where there is a text window the status text, the title and the screens go in it; elsewhere
   plat_text_puts() is plat_puts() and plat_text_clear() is plat_clear(). */
#ifndef PLAT_FIXED_COLS
extern uint8_t  plat_text_cols(void);
extern uint8_t  plat_text_rows(void);
#endif
extern void     plat_text_clear(void);
extern void     plat_text_puts(uint8_t col, uint8_t row, const char *s);
#ifdef HAVE_TEXT_BANNER
/* HAVE_TEXT_BANNER: the text window is framed, with a banner of its own (the Z88's OZ window): its rows (plat_text_rows(), and
   MODAL_ROWS: 7) are the ones inside, below the banner.  plat_text_bold() writes in bold, which the status panel does for the name of the
   mini map in view. */
extern void     plat_text_bold(uint8_t col, uint8_t row, const char *s);       /* write it in bold */
#else
#define plat_text_bold(c, r, s)
#endif

#ifdef HAVE_ICONS
/* plat_icons() draws the 14 tool icons in rows 3 and 4 of the text area (28 columns), tool `selected` highlighted. */
extern void     plat_icons(uint8_t selected);
#endif

#ifdef HAVE_ICONS_AFFORD
/* plat_afford() says which tools there is the money for (bit i of mask is set for tool i), before the game calls plat_icons(): the
   platform draws the icons of the others dimmed: greyed out, or (the ZX icon set's way) thinned to a checkerboard: each byte of the
   1 bit picture AND %01010101 on the even rows and %10101010 on the odd ones. */
extern void     plat_afford(uint16_t mask);
#endif

#ifdef HAVE_TILES
/* Tile graphics: plat_put_tile() draws one of the engine's 8x8 pictures in a character cell.
     art      8 bytes of 1bpp art, as returned by view_fetch() (a pointer into the engine's tile table, which
              the platform may use to tell tiles apart)
     attr     the attribute byte for the picture: Spectrum format (colour platforms), or the Aquarius+'s own colour
              byte, where its engine art (assets/map_art_aq.bin, tools/make_aq_assets.py) comes converted
     inverse  1 for the blinking cursor: the picture with its pixels inverted */
extern void     plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);
#endif

#ifdef HAVE_TEXT_COLOUR
/* The screens of tables (the budget, the evaluation) are drawn as text and then coloured.  An attribute is the Spectrum's: the ink
   in bits 0-2, the paper in bits 3-5, a colour being 1 blue, 2 red and 4 green added up (so 0 black, 3 magenta, 5 cyan, 6 yellow,
   7 white); PLAT_ATTR(ink, paper) makes one.
     plat_text_attr(col, row, n, attr)       recolours n cells of the text already drawn: its pixels take the ink and the
                                             background the paper
     plat_bar(col, row, cells, fill, attr)   a horizontal bar chart `cells` wide (up to 31): the first `fill` pixels (0 to
                                             8 * cells, up to 255) in the ink, the rest in the paper */
#define COL_BLACK   0
#define COL_BLUE    1
#define COL_RED     2
#define COL_MAGENTA 3
#define COL_GREEN   4
#define COL_CYAN    5
#define COL_YELLOW  6
#define COL_WHITE   7
#define PLAT_ATTR(ink, paper) ((uint8_t)((ink) | ((paper) << 3)))
extern void     plat_text_attr(uint8_t col, uint8_t row, uint8_t n, uint8_t attr);
extern void     plat_bar(uint8_t col, uint8_t row, uint8_t cells, uint8_t fill, uint8_t attr);
#endif

/* HAVE_POPUP_MENU: the frame of the boxes is +, - and | unless plat_config.h defines BOX_TOP, BOX_BOTTOM and BOX_SIDE, three strings of
   MENU_WIDTH (30) characters, the corners and lines being character codes the platform's plat_put() draws as it likes (the SAM's are 1 to 6). */

#ifdef HAVE_DEMAND_BARS
/* plat_demand() draws a demand indicator as a bar chart (a colour display): the letter `name` in the cell at (col, row) and a bar
   after it with a zero mark in the middle, `level` (-27..27) steps of fill from it: to the right (green: more is wanted) if it is
   positive and to the left (red: too much) if it is negative.  A step is a zone of imbalance, so a platform with a coarser display
   scales it (3 cells of 9 steps, say).  Without HAVE_DEMAND_BARS the game prints the text bars of demand_bars[] in ui/game.c. */
extern void     plat_demand(uint8_t col, uint8_t row, char name, int8_t level);
#endif

#ifdef HAVE_CLEAR_MAP
/* plat_clear_map() clears what is below the status panel (as much of the screen as a native mini map's 144 pixel rows need)
   and the platform's idea of what is in the map's cells, but not the panel: opening a mini map does not redraw it. */
extern void     plat_clear_map(void);
#endif

#ifdef HAVE_SCROLL
/* plat_scroll() scrolls the map (cell rows row to row + rows - 1, the whole width): the view's origin moved by (dx, dy), so
   what was in cell (x, y) is now in (x - dx, y - dy).  The cells that come into view are left undefined; the game draws them.
   The platform keeps what it knows of the cells in step.  |dx| < width, |dy| < rows. */
extern void     plat_scroll(uint8_t row, uint8_t rows, int8_t dx, int8_t dy);
#endif

#ifdef HAVE_SPRITE_OVERLAY
/* plat_put_overlay() draws the pixels set in 8 bytes of 1bpp art (a byte a pixel row, bit 7 on the left) over what is in
   a character cell, in the platform's colour for sprites; the rest of the cell is left as it is. */
extern void     plat_put_overlay(uint8_t col, uint8_t row, const uint8_t *art);
#endif

#ifdef HAVE_BITMAP
/* plat_put_bitmap() draws 8 bytes of 1bpp art (a byte a pixel row, bit 7 on the left) in a character cell. */
extern void     plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art);
#endif

#if defined(HAVE_MINIMAP_NATIVE) && defined(HAVE_MINIMAP_ART)
/* With HAVE_MINIMAP_ART the platform draws row sy (0..47) of the mini map from mm_row (see ui/minimap.h): three planes
   (blue, red, green: bits 0, 1 and 2 of a colour) of three lines of 48 bytes, 4 pixels a tile.  Row sy is lines 3 sy to
   3 sy + 2 of a map 144 lines high, which the Multi 8 centres under the status panel. */
extern void     plat_put_minirow(uint8_t sy);
#elif defined(HAVE_MINIMAP_SQUARE)
/* HAVE_MINIMAP_SQUARE (with HAVE_MINIMAP_NATIVE, a colour display of at least 192x192 pixels): the mini map shows a tile window, every tile
   row, a tile 2x2 pixels, so a square 192x192 at the left of the screen, and the rest of the screen is a sidebar the game fills
   in (the date, the money, the view's name, the demand, the keys).
     plat_put_minirow(ty, colours, base, view)   draws tile row ty (0..95) from 96 colours (0..7, as the builder makes them) of view
                                           `view`: what a colour is depends on the view, so the platform has its own palette for each.
                                           For a density (pollution, cover, traffic, crime) base has the city's colours of the row, to
                                           show where the density is none (0 otherwise)
     plat_minimap_key(view)                draws the key to the colours of the view in the sidebar's rows 5 to 15 (columns MM_SIDE_COL up: 24, unless
                                           plat_config.h defines it, to centre the picture and the sidebar on a wider display)
   With HAVE_MINIMAP_SCROLL, plat_minimap_scroll(x) sets the tile column at the window's left edge.  plat_minimap_pan(dx, dy, x) moves the
   existing 192x192 picture by one tile with the platform's fast screen copy; the UI then redraws only the exposed edge.  Opening one clears the
   whole screen, and the status panel is not drawn while it is open. */
extern void plat_put_minirow(uint8_t ty, const uint8_t *colours, const uint8_t *base, uint8_t view);
extern void plat_minimap_key(uint8_t view);
#ifdef HAVE_MINIMAP_4BPP
/* HAVE_MINIMAP_4BPP: a mini map is a different video mode.  plat_minimap_mode(1) is called when one is opened (after plat_clear) and (0) when the
   city is back (plat_clear is called then too); a view to another view calls (1) again. */
extern void plat_minimap_mode(uint8_t on);
#endif
#ifdef HAVE_MINIMAP_SCROLL
extern void plat_minimap_scroll(uint8_t x);
#ifdef HAVE_SCROLL
extern void plat_minimap_pan(int8_t dx, int8_t dy, uint8_t x);
#endif
#endif
#elif defined(HAVE_MINIMAP_NATIVE)
/* plat_put_minirow() draws row sy (0..47) of the mini map from 96 colours, one a tile column, each a block of pixels (the
   Multi 8: 4x3 hardware pixels, so the map is 384x144).  Bit 0 of a colour is the blue plane, 1 the red, 2 the green.
   The map is the whole city, and the map area must be at least 18 cell rows high. */
extern void     plat_put_minirow(uint8_t sy, const uint8_t *colours);
#endif

#ifdef HAVE_MINIMAP_COLOUR
/* Colour minimaps draw base city art and let the platform overlay a view-specific intensity. */
extern void     plat_put_minimap(uint8_t col, uint8_t row, const uint8_t *art,
                                 uint8_t view, uint8_t level
#ifdef HAVE_MINIMAP_CURSOR
                                 , uint8_t selected
#endif
                                 );
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
