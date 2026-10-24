/* Cambridge Z88 capabilities for the shared game UI. */
#ifndef PLAT_CONFIG_H
#define PLAT_CONFIG_H

#define HAVE_TILES
#define HAVE_BITMAP
#define HAVE_BUDGET
#define HAVE_EVALUATION
#define HAVE_TEXT_BANNER       /* the OZ window is framed, with a banner, which takes a row of its 8 */
#define MODAL_ROWS 7           /* the rows inside it */
#define HAVE_MINIMAP
#define HAVE_MINIMAP_CURSOR
#define HAVE_SPRITES
#define HAVE_TEXT_WINDOW
#define HAVE_MENUS
#define HAVE_KEYS_QAOP         /* Q A O P (and shifted, 8 cells) move the cursor as well as the cursor keys */
#define HAVE_ICONS
#define HAVE_DEMAND_BARS       /* the demand indicators as bars of user defined characters (plat_demand()) */
#define HAVE_FILES
#define HAVE_APPNAME
#define HAVE_SOUND
#define MAX_VIEW_W 32
#define MAX_VIEW_H 8

#endif
