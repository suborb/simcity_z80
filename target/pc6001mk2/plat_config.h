/* NEC PC-6001mkII on a boot disc (PC-6031 drive): all 64K is RAM once the ROM is mapped out.  The 320x200 mode of two bit planes (4 colours) as 40 x 25 cells (target/pc6001mk2/plat_pc6001mk2.asm); the map is drawn with the engine's pictures. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define PLAT_FIXED_COLS 40
#define PLAT_FIXED_ROWS 25
#define MAX_VIEW_W 40
#define MAX_VIEW_H 25
#define MODAL_ROWS 24
#define HAVE_TILES
/* HAVE_SCROLL (a pixel mover over both planes) was tried and is OFF, and its code is not kept: with it on, a host run of ~60 cursor moves ended with the simulation task returning to
   garbage ($6A20), although plat_scroll was never called; not understood (the sim stack in BSS? layout?) */
#define HAVE_POPUP_MENU
#define HAVE_BUDGET
#define HAVE_BUDGET_CAPS                /* the budget screen takes O P Q A in either case */
#define HAVE_EVALUATION
#define MODAL_NARROW                    /* the budget and evaluation screens in their 32 column arrangement, */
#define MODAL_X 4                       /* ... centred in the 40 columns */
#define NO_QUIT

#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE     /* the mini maps a row of tiles at a time (plat_put_minirow) ... */
#define HAVE_MINIMAP_SQUARE     /* ... every tile row, a tile 2x2 pixels: 192x192 (24 cells) and a sidebar of the other 16 columns */
#define MM_PIC_COL 0
#define MM_SIDE_COL 24
#define HAVE_TEXT_COLOUR        /* the budget and evaluation screens coloured, with bars (plat_text_attr, plat_bar: plat_text.c, in the modal overlay) */
#define HAVE_DEMAND_BARS        /* the R, C and I demand as bar charts (plat_demand) */
#define HAVE_SPRITES
#define HAVE_SPRITE_OVERLAY     /* the train, plane and tornado are drawn over the cell's tile, in red (plat_put_overlay) */
#define HAVE_FILES              /* city files on the disc (target/pc6001mk2/plat_files.c) */
#define HAVE_FILE_LIST          /* ... six slots to choose from */
#define FILE_NAME_MAX 12
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_SOUND              /* the PSG: effects written for it (target/pc6001mk2/plat_sound.asm) */
#define HAVE_ICONS              /* the tools as 16x16 pictures */
#define HAVE_ICONS_AFFORD       /* the icons of what there is no money for are dimmed (plat_afford) */
#define HAVE_POWER_ASK          /* a power station asks coal or nuclear when there is the money for both */
#define HAVE_ICONS_TOP          /* status panel across the top of the 40-column display */
#define plat_overlay_load pc6001mk2_overlay_load   /* (z88dk's: the overlays are the sections OVERLAY_0 to OVERLAY_4, on the disc after the program) */
#define HAVE_OVERLAY_UI                 /* the budget and evaluation screens (modal) and the prompt, menu and file code (game) are overlays read from the disc into one window */
#ifdef MK2_EVAL_UNIT                    /* (eval_ui.c: the evaluation screen is in an overlay of its own) */
#define PLAT_CODE_MODAL_OVERLAY _Pragma("codeseg OVERLAY_4")
#define PLAT_CONST_MODAL_OVERLAY _Pragma("constseg OVERLAY_4")
#else
#define PLAT_CODE_MODAL_OVERLAY _Pragma("codeseg OVERLAY_1")
#define PLAT_CONST_MODAL_OVERLAY _Pragma("constseg OVERLAY_1")
#endif
#ifdef MK2_FILE_UNIT                    /* (file_ui.c: the dialogues are in the file overlay) */
#define PLAT_CODE_GAME_OVERLAY  _Pragma("codeseg OVERLAY_2")
#define PLAT_CONST_GAME_OVERLAY _Pragma("constseg OVERLAY_2")
#else
#define PLAT_CODE_GAME_OVERLAY  _Pragma("codeseg OVERLAY_0")
#define PLAT_CONST_GAME_OVERLAY _Pragma("constseg OVERLAY_0")
#endif
#define HAVE_EVAL_OVERLAY
#define HAVE_START_OVERLAY
#define PLAT_CODE_START_OVERLAY _Pragma("codeseg OVERLAY_3")
#define PLAT_CODE_FILE_OVERLAY  _Pragma("codeseg OVERLAY_0")
#define PLAT_CODE_HOME          _Pragma("codeseg code_compiler")   /* (back to the resident code after an overlay's part of a file) */

#endif
