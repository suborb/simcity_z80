/* The Z88 application descriptor (DOR): what OZ shows in its application list, how it starts
   the program, and the menus.  <application.h> builds all of it from the macros below;
   anything not set takes z88dk's default.  Used by `make z88rom`.

   There is no Tools menu: the icons in the text window show the tools, and TAB and SHIFT-TAB (or
   the number keys) choose one.

   Menus: TOPICn is a menu (up to 7), TOPICn_m an item in it (up to 24 each).  When the user
   chooses an item OZ calls handlecmds() with its CODE, which plat_console.c turns into the
   CMD_* of ui/platform.h (the codes below are those values: keep them in step; test/z88
   checks).

   Shortcuts: the user presses the [] (square) key and then types the letters of the item's KEY.  The letters are up to the application: here the first is the menu's initial
   (Game, Speed, Options, Views) and the rest name the item, with no sequence the start of
   another (test/z88 checks that too).  Keep M, I and J off the front of them: the ENTER key is Ctrl-M
   (<>M), TAB is <>I and <>J is LF, and OZ takes those for a shortcut that starts with the letter. */
#include <dor.h>

#define APP_NAME "SimCity"
#define APP_KEY  'S'
#define APP_INFO "A city building game"

#define HELP1 "A port of SimCity for the Z88"
#define HELP2 "Built with z88dk"

/* ---- Game ---- */
#define TOPIC1               "Game"
#define TOPIC1_1             "New city"
#define TOPIC1_1KEY          "GN"
#define TOPIC1_1CODE         0x90
#define TOPIC1_2             "Pause"
#define TOPIC1_2KEY          "GP"
#define TOPIC1_2CODE         0x91
#define TOPIC1_3             "Budget"
#define TOPIC1_3KEY          "GB"
#define TOPIC1_3CODE         0xA4
#define TOPIC1_4             "Evaluation"
#define TOPIC1_4KEY          "GE"
#define TOPIC1_4CODE         0xA5
#define TOPIC1_5             "Save"
#define TOPIC1_5KEY          "GS"
#define TOPIC1_5CODE         0xA6
#define TOPIC1_6             "Load"
#define TOPIC1_6KEY          "GL"
#define TOPIC1_6CODE         0xA7
#define TOPIC1_7             "Quit"
#define TOPIC1_7KEY          "GQ"
#define TOPIC1_7CODE         0x9B

/* ---- Speed ---- */
#define TOPIC2               "Speed"
#define TOPIC2_1             "Fast"
#define TOPIC2_1KEY          "SF"
#define TOPIC2_1CODE         0x92
#define TOPIC2_2             "Normal"
#define TOPIC2_2KEY          "SN"
#define TOPIC2_2CODE         0x93
#define TOPIC2_3             "Slow"
#define TOPIC2_3KEY          "SL"
#define TOPIC2_3CODE         0x94

/* ---- Options ---- */
#define TOPIC3               "Options"
#define TOPIC3_1             "Coal power plant"
#define TOPIC3_1KEY          "OC"
#define TOPIC3_1CODE         0x95
#define TOPIC3_2             "Nuclear power plant"
#define TOPIC3_2KEY          "ON"
#define TOPIC3_2CODE         0x96
#define TOPIC3_3             "Disasters on"
#define TOPIC3_3KEY          "ODN"
#define TOPIC3_3CODE         0x97
#define TOPIC3_4             "Disasters off"
#define TOPIC3_4KEY          "ODF"
#define TOPIC3_4CODE         0x98
#define TOPIC3_5             "Auto-bulldoze on"
#define TOPIC3_5KEY          "OBN"
#define TOPIC3_5CODE         0x99
#define TOPIC3_6             "Auto-bulldoze off"
#define TOPIC3_6KEY          "OBF"
#define TOPIC3_6CODE         0x9A

/* ---- Views: the mini maps, CMD_MAP + the view (ui/minimap.h), then back to the city.  Not "Maps": its
   shortcuts would start with M, and the ENTER key is Ctrl-M (<>M), which OZ then takes for them ---- */
#define TOPIC4               "Views"
#define TOPIC4_1             "City"
#define TOPIC4_1KEY          "VC"
#define TOPIC4_1CODE         0x9D
#define TOPIC4_2             "Pollution"
#define TOPIC4_2KEY          "VU"
#define TOPIC4_2CODE         0x9E
#define TOPIC4_3             "Police coverage"
#define TOPIC4_3KEY          "VO"
#define TOPIC4_3CODE         0x9F
#define TOPIC4_4             "Fire coverage"
#define TOPIC4_4KEY          "VF"
#define TOPIC4_4CODE         0xA0
#define TOPIC4_5             "Traffic"
#define TOPIC4_5KEY          "VT"
#define TOPIC4_5CODE         0xA1
#define TOPIC4_6             "Power"
#define TOPIC4_6KEY          "VW"
#define TOPIC4_6CODE         0xA2
#define TOPIC4_7             "Back to the city"
#define TOPIC4_7KEY          "VX"
#define TOPIC4_7CODE         0xA3

#include <application.h>
