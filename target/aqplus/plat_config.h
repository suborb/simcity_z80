/* Aquarius+ capabilities for the shared game UI. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU     /* shared box + message selector over the bitmap console */
#define HAVE_FILES          /* Aquarius+ ESP filesystem */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define MODAL_ROWS 24          /* budget and evaluation use the full 40x24 text area */
#define HAVE_MINIMAP
#define HAVE_SPRITES
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar) */
#define MODAL_NARROW            /* ... in their 32 column arrangement, */
#define MODAL_X 4               /* ... centred in the 40 columns */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as coloured bar charts (plat_demand) */
#define HAVE_SOUND              /* the Atari ST game's effects on the AY-3-8910 (target/aqplus/plat_sound.asm) */
#define HAVE_MINIMAP_NATIVE     /* the mini maps a row of tiles at a time (plat_put_minirow), as the SAM Coupe's: a square picture, a sidebar */
#define HAVE_MINIMAP_SQUARE
#define HAVE_TEXT_LAYER         /* the popups and the text pages (menus, dialogues, budget, evaluation, title) are on the text layer, over the picture: no redraw after them */
#define HAVE_MINIMAP_4BPP       /* ... in the 160x200 4bpp bitmap, a colour to each tile, the sidebar on the text layer (plat_minimap_mode) */
#define MM_SIDE_COL 28          /* the picture's 24 cells start at column 4, centred in the 40, and the sidebar is after them */
/* (The original cell mini maps, HAVE_MINIMAP_COLOUR with MINIMAP_CELLS_H 19 and MINIMAP_CHUNK_ROWS 4, are still in the shared code and plat_put_minimap()
   in plat_aqplus.c, but no build uses them now: the Aquarius+ build has the room for the square ones.) */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are dimmed (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define MM_PIC_COL 4
#define HAVE_MOUSE              /* the ESP32's mouse (target/aqplus/aq_mouse.c), which may not be there ... */
#define HAVE_POINTER            /* ... and the pointer is always there: the keys move it too (QAOP, Space or Enter its button), and the city has no other cursor */
#define HAVE_MOUSE_SPRITE       /* the pointer is two hardware sprites: nothing to draw under it or to put back */
#define HAVE_ICONS_TOP          /* status panel across the top of the 40-column display */
#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 19

#endif
