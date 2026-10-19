/* What each build of the console platform (z88dk's conio: Aquarius+, NC200, Z88, Spectrum) can do and
   which of the game's optional features it has.  ui/platform.h includes it; the Makefile chooses the
   target with TARGET_AQPLUS, TARGET_Z88 and so on.  The capabilities are described in ui/platform.h. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

/* All four draw the game's real pictures, and can draw one of its own making (the mini maps). */
#define HAVE_TILES
#define HAVE_BITMAP

#ifndef TARGET_ZX
/* The Spectrum has none of the optional features: its memory has no room for them. */
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_MINIMAP
#define HAVE_SPRITES
#endif

#ifdef TARGET_Z88
#define HAVE_TEXT_WINDOW        /* OZ's text window beside the map */
#define HAVE_MENUS              /* OZ's menus: quit is in them, the keys need not show it */
#define HAVE_ICONS              /* the tools as user defined characters in the text window */
#define HAVE_FILES              /* OZ's files: save and load a city */
#define HAVE_SOUND              /* the beeper (platform/console/plat_sound.asm, linked by the Makefile) */
#endif

#endif
