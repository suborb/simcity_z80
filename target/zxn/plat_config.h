/* ZX Spectrum Next capabilities for the shared game UI: Layer 2, 256x192 pixels of 8 bits, used as 32 columns of 8x8 cells
   (target/zxn/plat_zxn.c, plat_zxn.asm), the same layout as the SAM Coupe's, with the Amiga SimCity 1 Meg's map art in its 64 colours (and the Atari ST's interface colours). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap */
/* the box's frame in the placer's line pieces (plat_zxn.c): 1 and 2 the top corners, 3 and 4 the bottom ones, 5 across, 6 down */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_SOUND              /* the Atari ST game's effects on the AY (target/common/ay_sfx.asm, target/zxn/plat_sound.asm) */
#define HAVE_FILES          /* saving and loading a city as a file (esxDOS, through z88dk's open, read and write) */
#define FILE_NAME_MAX 24
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_COLS 32          /* a 32 column display: the budget and evaluation screens use 32 columns of the 24 rows */
#define MODAL_ROWS 24
#define FMT_WIDTH 32            /* a row of a table screen: the display's width (and -Ca-DFMT_WIDTH=32: the Makefile) */
#if !defined(MAP_H) || MAP_H <= 96
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE    /* the whole city in colour (plat_put_minirow) */
#define HAVE_MINIMAP_SQUARE    /* ... every tile row, 2x2 pixels a tile, 192x192 with a sidebar */
#else
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE
#define HAVE_MINIMAP_SQUARE
#define HAVE_MINIMAP_SCROLL    /* show a 96x96 tile window of the larger city */
#endif
#define HAVE_CLEAR_MAP          /* a mini map clears the screen below the panel only (plat_clear_map) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the sprites go over the baked tiles, which have colours */
#define HAVE_ICONS              /* the tools as 24x14 pictures */
#define HAVE_ICONS_TOP          /* status panel across the top of the display */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are greyed out (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_2X7          /* ... with the icons in two rows of seven (ui/game.c) */
#define ICON_ROWS 5             /* ... the Amiga's 22x20 pixel icons: two rows of them are five cell rows, and the map starts a row lower */
#ifndef ZXN_NO_SCROLL
#define HAVE_SCROLL             /* a scroll moves the map's pixels by the DMA (plat_scroll) and draws only the cells that come into view */
#endif
#define HAVE_MOUSE              /* a Kempston mouse (target/zxn/zxn_mouse.c), which cannot be detected: the game options switch it on and off */
#define HAVE_MOUSE_TOGGLE
#define HAVE_MOUSE_SPRITE       /* the pointer is a hardware sprite: nothing to draw under it or to put back */
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 17

#endif
