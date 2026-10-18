/* The Z88 application descriptor (DOR): what OZ shows in its application list, how it starts
   the program, and the menus.  <application.h> builds all of it from the macros below;
   anything not set takes z88dk's default.  Used by `make z88rom`.

   Menus: TOPICn is a menu (up to 7), TOPICn_m an item in it (up to 24 each).  When the user
   chooses an item OZ calls handlecmds() with its CODE, which plat_console.c turns into the
   CMD_* of ui/platform.h (the codes below are those values: keep them in step; test/z88
   checks).

   Shortcuts: the user presses OZ's command-prefix key (the square or the diamond key: I have
   not confirmed which, and nothing here depends on it) and then types the letters of the
   item's KEY.  The letters are up to the application: here the first is the menu's initial
   (Game, Tools, Speed, Options) and the rest name the item, with no sequence the start of
   another (test/z88 checks that too). */
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
#define TOPIC1_3             "Quit"
#define TOPIC1_3KEY          "GQ"
#define TOPIC1_3CODE         0x9B

/* ---- Tools: CMD_TOOL + the tool's number, in the order of the game's tool keys ---- */
#define TOPIC2               "Tools"
#define TOPIC2_1             "Bulldoze"
#define TOPIC2_1KEY          "TB"
#define TOPIC2_1CODE         0x81
#define TOPIC2_2             "Road"
#define TOPIC2_2KEY          "TR"
#define TOPIC2_2CODE         0x82
#define TOPIC2_3             "Power line"
#define TOPIC2_3KEY          "TW"
#define TOPIC2_3CODE         0x83
#define TOPIC2_4             "Rail"
#define TOPIC2_4KEY          "TL"
#define TOPIC2_4CODE         0x84
#define TOPIC2_5             "Park"
#define TOPIC2_5KEY          "TK"
#define TOPIC2_5CODE         0x85
#define TOPIC2_6             "Residential zone"
#define TOPIC2_6KEY          "TE"
#define TOPIC2_6CODE         0x86
#define TOPIC2_7             "Commercial zone"
#define TOPIC2_7KEY          "TC"
#define TOPIC2_7CODE         0x87
#define TOPIC2_8             "Industrial zone"
#define TOPIC2_8KEY          "TI"
#define TOPIC2_8CODE         0x88
#define TOPIC2_9             "Police station"
#define TOPIC2_9KEY          "TO"
#define TOPIC2_9CODE         0x89
#define TOPIC2_10            "Fire station"
#define TOPIC2_10KEY         "TF"
#define TOPIC2_10CODE        0x8A
#define TOPIC2_11            "Stadium"
#define TOPIC2_11KEY         "TS"
#define TOPIC2_11CODE        0x8B
#define TOPIC2_12            "Power plant"
#define TOPIC2_12KEY         "TG"
#define TOPIC2_12CODE        0x8C
#define TOPIC2_13            "Seaport"
#define TOPIC2_13KEY         "TP"
#define TOPIC2_13CODE        0x8D
#define TOPIC2_14            "Airport"
#define TOPIC2_14KEY         "TA"
#define TOPIC2_14CODE        0x8E

/* ---- Speed ---- */
#define TOPIC3               "Speed"
#define TOPIC3_1             "Fast"
#define TOPIC3_1KEY          "SF"
#define TOPIC3_1CODE         0x92
#define TOPIC3_2             "Normal"
#define TOPIC3_2KEY          "SN"
#define TOPIC3_2CODE         0x93
#define TOPIC3_3             "Slow"
#define TOPIC3_3KEY          "SL"
#define TOPIC3_3CODE         0x94

/* ---- Options ---- */
#define TOPIC4               "Options"
#define TOPIC4_1             "Coal power plant"
#define TOPIC4_1KEY          "OC"
#define TOPIC4_1CODE         0x95
#define TOPIC4_2             "Nuclear power plant"
#define TOPIC4_2KEY          "ON"
#define TOPIC4_2CODE         0x96
#define TOPIC4_3             "Disasters on"
#define TOPIC4_3KEY          "ODN"
#define TOPIC4_3CODE         0x97
#define TOPIC4_4             "Disasters off"
#define TOPIC4_4KEY          "ODF"
#define TOPIC4_4CODE         0x98
#define TOPIC4_5             "Auto-bulldoze on"
#define TOPIC4_5KEY          "OBN"
#define TOPIC4_5CODE         0x99
#define TOPIC4_6             "Auto-bulldoze off"
#define TOPIC4_6KEY          "OBF"
#define TOPIC4_6CODE         0x9A

#include <application.h>
