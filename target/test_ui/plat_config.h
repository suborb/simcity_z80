/* What the headless test platform can do, by build: the default one is a plain 64x24 character screen;
   TEST_PANEL has the shape of the Z88's screen (a text window and a 32x8 map) and every feature;
   TEST_HIRES_MINIMAP is the Aquarius+'s 40x25 bitmap shape; TEST_SPRITES is the panel build with
   the map drawn from pictures, so the sprites can be checked.  TEST_NARROW is a 32x24 screen like the
   Spectrum's (the 32 column budget and evaluation layouts). */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#ifdef TEST_SCROLL                      /* the Aquarius+-shaped screen, whose platform can scroll the map by moving its pixels */
#define TEST_HIRES_MINIMAP
#define HAVE_SCROLL
#endif
#ifdef TEST_NATIVE_ART                  /* ... with the tiles' own pictures at a quarter of the size */
#define TEST_NATIVE_MINIMAP
#define HAVE_MINIMAP_ART
#endif
#ifdef TEST_NATIVE_MINIMAP              /* the Aquarius+-shaped screen with the Multi 8's colour a tile mini map */
#define TEST_HIRES_MINIMAP
#endif

#if defined(TEST_PANEL)
#define MAX_VIEW_W 32
#define MAX_VIEW_H 8
#elif defined(TEST_NARROW)
#define MAX_VIEW_W 32
#define MAX_VIEW_H 16
#elif defined(TEST_HIRES_MINIMAP)
#define MAX_VIEW_W 40
#define MAX_VIEW_H 19
#else
#define MAX_VIEW_W 80
#define MAX_VIEW_H 25
#endif

#if defined(TEST_PANEL) || defined(TEST_MODAL) || defined(TEST_HIRES_MINIMAP) || defined(TEST_NARROW)
#ifdef TEST_PANEL
#define HAVE_TEXT_WINDOW
#define HAVE_MENUS
#define HAVE_ICONS
#define HAVE_FILES
#define HAVE_APPNAME
#define HAVE_SOUND
#define MODAL_ROWS 8           /* matches the Z88-shaped text-window test */
#elif defined(TEST_MODAL)
#define MODAL_ROWS 24          /* the full 64x24 test screen, like a full-screen target */
#elif defined(TEST_NARROW)
#define FMT_WIDTH 32            /* (and -Ca-DFMT_WIDTH=32 for the assembler: the Makefile) */
#define MODAL_ROWS 24
#define MODAL_COLS 32
#define MINIMAP_CELLS_H 16
#else
#define HAVE_TILES
#define HAVE_ICONS
#define HAVE_ICONS_TOP
#ifndef TEST_NATIVE_MINIMAP
#define HAVE_FILES              /* the dialogues of a pop-up menu platform (ui/prompt.c) */
#endif
#define MODAL_ROWS 24
#define MINIMAP_CELLS_H 19
#endif
#ifndef TEST_NATIVE_MINIMAP
#define HAVE_BITMAP
#endif
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_MINIMAP
#ifdef TEST_NATIVE_MINIMAP
#define HAVE_MINIMAP_NATIVE
#endif
#define HAVE_MINIMAP_CURSOR
#ifndef TEST_NATIVE_MINIMAP
#define HAVE_SPRITES
#endif
#endif

#ifdef TEST_SPRITES
#define HAVE_TILES
#ifdef TEST_OVERLAY
#define HAVE_SPRITE_OVERLAY     /* the sprites over the tiles, as a coloured screen draws them */
#endif
#endif

/* The plain and Aquarius-shaped harnesses exercise the shared pop-up menu.  TEST_PANEL has the Z88's native-menu
   behaviour, while TEST_MODAL keeps its deliberately tight full-screen fixture. */
#if !defined(TEST_PANEL) && !defined(TEST_MODAL) && !defined(TEST_NARROW)
#define HAVE_POPUP_MENU
#endif

#endif
