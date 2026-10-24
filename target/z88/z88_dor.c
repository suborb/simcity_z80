/* The Z88 application descriptor (DOR): what OZ shows in its application list, how it starts
   the program, and the menus.  <application.h> builds all of it from the macros below;
   anything not set takes z88dk's default.  Used by `make z88rom`.

   There is no Tools menu: the icons in the text window show the tools, and TAB and SHIFT-TAB (or
   the number keys) choose one.

   Menus: TOPICn is a menu (up to 7), TOPICn_m an item in it (up to 24 each).  When the user
   chooses an item OZ calls handlecmds() with its CODE, which plat_console.c turns into the
   CMD_* of ui/platform.h (the codes below are those values: keep them in step; test/z88
   checks).

   Shortcuts: the user presses <> and then types the letters of the item's KEY.  The letters are up to the application: the
   four most used (Budget, Evaluation, Save, Load) are one letter; the rest start with the menu's letter (Game, Tempo for the
   speed, Options, Views, Disasters) and then name the item, with no sequence the start of another (test/z88 checks that
   too).  Keep M, I and J off the front of them: the ENTER key is Ctrl-M (<>M), TAB is <>I and <>J is LF, and OZ takes
   those for a shortcut that starts with the letter. */
#include <dor.h>

#define APP_NAME "SimCity"
#define APP_KEY  'S'
#define APP_INFO "A city building game"

/* The main help (the HELP key): up to six lines. */
#define HELP1 "SimCity - The City Simulator"
#define HELP2 "(C) 1989 Maxis Software"
#define HELP3 "Spectrum version: Probe Software, Infogrames"
#define HELP4 "The Z88 port, built with z88dk"
#define HELP5 "https://github.com/suborb/simcity_z80"
#ifndef APP_VERSION
#error "APP_VERSION is set by the Makefile (VERSION)"
#endif
/* (the help text is expanded inside assembler, which takes the two strings of this one as a list, not as adjacent
   literals; the version arrives as a bare number, which zcc cannot pass quoted) */
#define STRING_(x) #x
#define STRING(x) STRING_(x)
#define HELP6 "Version ", STRING(APP_VERSION)

/* ---- Game ---- */
#define TOPIC1               "Game"
#define TOPIC1_1             "New city"
#define TOPIC1_1KEY          "GN"
#define TOPIC1_1CODE         0x90
#define TOPIC1_2             "Pause"
#define TOPIC1_2KEY          "GP"
#define TOPIC1_2CODE         0x91
#define TOPIC1_3             "Budget"
#define TOPIC1_3KEY          "B"
#define TOPIC1_3CODE         0xA4
#define TOPIC1_4             "Evaluation"
#define TOPIC1_4KEY          "E"
#define TOPIC1_4CODE         0xA5
#define TOPIC1_5             "Save"
#define TOPIC1_5KEY          "S"
#define TOPIC1_5CODE         0xA6
#define TOPIC1_6             "Load"
#define TOPIC1_6KEY          "L"
#define TOPIC1_6CODE         0xA7
#define TOPIC1_7             "Quit"
#define TOPIC1_7KEY          "GQ"
#define TOPIC1_7CODE         0x9B

/* ---- Speed ---- */
#define TOPIC2               "Speed"
#define TOPIC2_1             "Fast"
#define TOPIC2_1KEY          "TF"
#define TOPIC2_1CODE         0x92
#define TOPIC2_2             "Normal"
#define TOPIC2_2KEY          "TN"
#define TOPIC2_2CODE         0x93
#define TOPIC2_3             "Slow"
#define TOPIC2_3KEY          "TL"
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
#define TOPIC3_7             "Auto-budget on"
#define TOPIC3_7KEY          "OAN"
#define TOPIC3_7CODE         0xA8
#define TOPIC3_8             "Auto-budget off"
#define TOPIC3_8KEY          "OAF"
#define TOPIC3_8CODE         0xA9
#define TOPIC3_9             "Sound on"
#define TOPIC3_9KEY          "OSN"
#define TOPIC3_9CODE         0xAA
#define TOPIC3_10            "Sound off"
#define TOPIC3_10KEY         "OSF"
#define TOPIC3_10CODE        0xAB

/* ---- Views: the mini maps, CMD_MAP + the view (ui/minimap.h), then back to the city.  Not "Maps": its shortcuts would start with M, and the ENTER key is Ctrl-M (<>M), which OZ then takes for them ---- */
#define TOPIC4               "Views"
#define TOPIC4_1             "City"
#define TOPIC4_1KEY          "VC"
#define TOPIC4_1CODE         0x87
#define TOPIC4_2             "Pollution"
#define TOPIC4_2KEY          "VP"
#define TOPIC4_2CODE         0x88
#define TOPIC4_3             "Police coverage"
#define TOPIC4_3KEY          "VO"
#define TOPIC4_3CODE         0x89
#define TOPIC4_4             "Fire coverage"
#define TOPIC4_4KEY          "VF"
#define TOPIC4_4CODE         0x8A
#define TOPIC4_5             "Traffic"
#define TOPIC4_5KEY          "VT"
#define TOPIC4_5CODE         0x8B
#define TOPIC4_6             "Power"
#define TOPIC4_6KEY          "VW"
#define TOPIC4_6CODE         0x8C
#define TOPIC4_7             "Transport"
#define TOPIC4_7KEY          "VR"
#define TOPIC4_7CODE         0x8D
#define TOPIC4_8             "Crime"
#define TOPIC4_8KEY          "VI"
#define TOPIC4_8CODE         0x8E
#define TOPIC4_9             "Back to the city"
#define TOPIC4_9KEY          "VX"
#define TOPIC4_9CODE         0xA3

/* ---- Disasters: CMD_DISASTER + 0..5, started a few frames after the choice ---- */
#define TOPIC5               "Disasters"
#define TOPIC5_1             "Fire"
#define TOPIC5_1KEY          "DF"
#define TOPIC5_1CODE         0x81
#define TOPIC5_2             "Flood"
#define TOPIC5_2KEY          "DL"
#define TOPIC5_2CODE         0x82
#define TOPIC5_3             "Earthquake"
#define TOPIC5_3KEY          "DE"
#define TOPIC5_3CODE         0x83
#define TOPIC5_4             "Air crash"
#define TOPIC5_4KEY          "DA"
#define TOPIC5_4CODE         0x84
#define TOPIC5_5             "Tornado"
#define TOPIC5_5KEY          "DT"
#define TOPIC5_5CODE         0x85
#define TOPIC5_6             "Nuclear meltdown"
#define TOPIC5_6KEY          "DM"
#define TOPIC5_6CODE         0x86

#include <application.h>
