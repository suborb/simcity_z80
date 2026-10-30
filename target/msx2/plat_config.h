/* MSX2 (MSX-DOS 2) capabilities for the shared game UI: screen 5, 256x192 pixels of 4 bits, used as 32 columns of 8x8 cells
   (target/msx2/plat_msx2.c, plat_msx2.asm): the Atari ST's art and 16 colours as the SAM Coupe's, in the picture atlas in the video RAM's second page,
   which the VDP copies a tile at a time (HMMM). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
/* the box's frame in the placer's line pieces (plat_msx2.c): 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#ifndef MSX2_NO_SOUND
#define HAVE_SOUND              /* the Atari ST game's effects on the PSG (target/common/ay_sfx.asm, target/msx2/plat_sound.asm) */
#endif
#define HAVE_FILES          /* saving and loading a city as a DOS file (z88dk's open, read and write: DOS 2's handles) */
#define FILE_NAME_MAX 12    /* a DOS 8.3 name */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_COLS 32          /* a 32 column display: the budget and evaluation screens use 32 columns of the 24 rows */
#define MODAL_ROWS 24
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* the whole city in colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE    /* ... every tile row, 2x2 pixels a tile, 192x192 with a sidebar */
#define HAVE_CLEAR_MAP          /* a mini map clears the screen below the panel only (plat_clear_map) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define HAVE_SCROLL             /* a scroll moves the map's pixels with a VDP copy (plat_scroll) and the game draws only the cells that come into view */
#define HAVE_MOUSE              /* a mouse in a joystick connector (z88dk's in_MouseMSX, target/msx2/msx_pointer.c), which cannot be detected for sure, so it is always read ... */
#define HAVE_POINTER            /* ... and the pointer is always there: the keys move it too (QAOP, Space or Enter its button), and the city has no other cursor */
#define HAVE_MOUSE_SPRITE       /* the pointer is two VDP sprites: nothing to draw under it or to put back */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the sprites go over the baked tiles, which have colours */
#define HAVE_ICONS              /* the tools as 24x14 pictures */
#define HAVE_ICONS_TOP          /* status panel across the top of the display */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are greyed out (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_2X7          /* ... with the icons in two rows of seven (ui/game.c) */
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 17

#endif
