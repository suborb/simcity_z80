/* What the headless test platform can do, by build: the default one is a plain 64x24 character screen;
   TEST_PANEL has the shape of the Z88's screen (a text window and a 32x8 map) and every feature;
   TEST_SPRITES is that with the map drawn from pictures, so the sprites can be checked. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#ifdef TEST_PANEL
#define HAVE_TEXT_WINDOW
#define HAVE_MENUS
#define HAVE_ICONS
#define HAVE_FILES
#define HAVE_SOUND
#define HAVE_BITMAP
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_MINIMAP
#define HAVE_SPRITES
#endif

#ifdef TEST_SPRITES
#define HAVE_TILES
#endif

#endif
