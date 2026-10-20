/* What the headless test platform can do, by build: the default one is a plain 64x24 character screen;
   TEST_PANEL has the shape of the Z88's screen (a text window and a 32x8 map) and every feature;
   TEST_HIRES_MINIMAP is the Aquarius+'s 40x25 bitmap shape; TEST_SPRITES is the panel build with
   the map drawn from pictures, so the sprites can be checked. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#if defined(TEST_PANEL) || defined(TEST_MODAL) || defined(TEST_HIRES_MINIMAP)
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
#else
#define HAVE_TILES
#define HAVE_ICONS
#define HAVE_ICONS_TOP
#define MODAL_ROWS 24
#define MINIMAP_CELLS_H 19
#endif
#define HAVE_BITMAP
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_MINIMAP
#define HAVE_SPRITES
#endif

#ifdef TEST_SPRITES
#define HAVE_TILES
#endif

/* The plain and Aquarius-shaped harnesses exercise the shared pop-up menu.  TEST_PANEL has the Z88's native-menu
   behaviour, while TEST_MODAL keeps its deliberately tight full-screen fixture. */
#if !defined(TEST_PANEL) && !defined(TEST_MODAL)
#define HAVE_POPUP_MENU
#endif

#endif
