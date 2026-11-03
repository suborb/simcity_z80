#ifndef EINSTEIN256_PLAT_CONFIG_H
#define EINSTEIN256_PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_POPUP_MENU
#define BOX_TOP    "\1\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\2"
#define BOX_BOTTOM "\3\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\5\4"
#define BOX_SIDE   "\6                            \6"
#define HAVE_FILES
#define HAVE_OVERLAY_UI
#define FILE_NAME_MAX 12
#define FILE_RECORD 128                 /* CP/M keeps a file in whole 128 byte records (plat_v9938.c: the padding after a city) */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_MINIMAP
#define HAVE_MINIMAP_NATIVE
#define HAVE_MINIMAP_SQUARE
#define HAVE_CLEAR_MAP
#define HAVE_DEMAND_BARS
#define HAVE_TEXT_COLOUR
#define HAVE_SCROLL
#define HAVE_ICONS
#define HAVE_ICONS_TOP
#define HAVE_ICONS_AFFORD
#define HAVE_POWER_ASK
#define HAVE_ICONS_2X7
#define PLAT_FIXED_COLS 32
#define PLAT_FIXED_ROWS 24
#define MAX_VIEW_W 32
#define MAX_VIEW_H 17
#define MODAL_COLS 32
#define MODAL_ROWS 24
#define FMT_WIDTH 32

/* C section-placement hooks: only the two overlays and the file code (which the
   game overlay carries) are placed apart; everything else is the COM image. */
#define PLAT_CODE_GAME_OVERLAY  _Pragma("codeseg EINSTEIN_GAME_OVL")
#define PLAT_CONST_GAME_OVERLAY _Pragma("constseg EINSTEIN_GAME_OVL")
#define PLAT_CODE_MODAL_OVERLAY _Pragma("codeseg EINSTEIN_MODAL_OVL")
#define PLAT_CONST_MODAL_OVERLAY _Pragma("constseg EINSTEIN_MODAL_OVL")
#define PLAT_CODE_FILE_OVERLAY  _Pragma("codeseg EINSTEIN_GAME_OVL")
#define PLAT_CODE_HOME          _Pragma("codeseg code_compiler")   /* (back to the resident code after an overlay's part of a file) */

#endif
