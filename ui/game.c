/* ------------------------------------------------------------------------
   SimCity game core: the user interface shared by every platform.

   It owns the cursor, the view and the keyboard, drives the portable engine
   (engine/), and draws through the small platform API in platform.h.  Nothing
   here depends on a particular machine; the Aquarius+, NC200 and Z88 builds
   differ only in the platform file they link.

   Layout: the top third of the screen is the status panel, the rest is the map.
   Platforms that can show the real tile graphics (HAVE_TILES) draw the
   map from view_fetch(), the engine's view_cell routine verified against the
   Spectrum's own rendering; the others draw a character per cell with glyph().
   ------------------------------------------------------------------------ */
#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"
#include "text.h"
#ifdef HAVE_POPUP_MENU
#include "menu.h"
#endif
#ifdef HAVE_MINIMAP
#ifndef MINIMAP_CHUNK_ROWS
#define MINIMAP_CHUNK_ROWS MM_CELLS_H
#endif
#include "minimap.h"
#endif
#if defined(HAVE_SPRITES) && defined(HAVE_TILES)
#include "sprites.h"
#define DRAW_SPRITES
#endif
#include "textfmt.h"
#ifdef HAVE_BUDGET
#include "budget.h"
#endif
#ifdef HAVE_EVALUATION
#include "evaluation.h"
#endif
#ifdef HAVE_FILES
#include "cityfile.h"
#endif
#if defined(HAVE_FILES) || defined(HAVE_APPNAME)
#include "prompt.h"
#endif
#include "game.h"

#define NUM_TOOLS   14

/* Frames between simulation ticks, indexed by V_simulation_speed. */
/* Rows of the simulation run per UI frame.  A slice is about 20ms on a 3.5MHz Z80, and
   the keyboard is read once per frame, so this sets how quickly the game answers a key:
   one slice per frame keeps a frame near 30ms. */
#define SLICES_PER_FRAME 1
static const uint8_t tick_frames[4] = { 2, 8, 24, 0 };

/* Footprint (cells) of each tool, as the Spectrum's D_zone_sizes. */
static const uint8_t tool_size[NUM_TOOLS] = { 1, 1, 1, 1, 1, 3, 3, 3, 3, 3, 4, 4, 4, 6 };

/* Tile flags: bit 1 rail, bit 2 road, bit 3 carries power (engine D_tile_flags). */
extern const uint8_t D_tile_flags[];

/* ---- state ------------------------------------------------------------- */
static uint8_t cur_x, cur_y;            /* cursor, map coordinates */
static uint8_t origin_x, origin_y;      /* map cell at the top left of the view */
static uint8_t tool;
static uint8_t frame;
static uint8_t quit;
static uint8_t restart;                 /* quit this city and start another */
static uint8_t redraw;                  /* parts of the display a modal screen overwrote */
#define REDRAW_ALL 1
#define REDRAW_MAP 4                    /* a popup sits entirely in the city map area: only the map is drawn again */
#ifdef HAVE_TEXT_WINDOW
#define REDRAW_TEXT 2                   /* the screens use the text window only: the map is as it was */
#else
#define REDRAW_TEXT REDRAW_ALL          /* they share the screen with the map */
#endif
static uint8_t power_nuclear;           /* what the power plant tool builds */
static uint8_t tick_reset;              /* a city was loaded: abandon the tick in progress */
static uint8_t map_view;                /* 0: the city; else the mini map shown (MM_CITY..) */
static uint8_t map_full;                /* the mini map needs drawing from scratch */
/* Everything the status panel shows, to tell when it needs redrawing. */
struct status {
    uint8_t money[3], pop[3];             /* 24 bit, as the engine keeps them */
    int16_t rv, cv, iv;
    uint16_t year;
    uint8_t month, tool, speed, alert, page, map_view;
};

/* Layout, decided from the screen size at start-up. */
static uint8_t cols, rows;
static uint8_t view_w, view_h;
static uint8_t map_row;                 /* screen row of the top of the map */
static uint8_t panel_col, panel_row;    /* where the status text starts */
static uint8_t panel_w, panel_h;

#ifndef MAX_VIEW_W
#define MAX_VIEW_W 80
#endif
#ifndef MAX_VIEW_H
#define MAX_VIEW_H 25
#endif
#ifdef HAVE_POPUP_MENU
/* The native Z88 menu already sends CMD_* values.  The other targets get this compact character-cell
   menu; the page values are deliberately below the printable and CMD_* ranges. */
#define MENU_GAME_OPTIONS  1
#define MENU_BUILD_OPTIONS 2
#define MENU_DISASTERS     3
#define MENU_MAIN          4
#define MENU_BUDGET          0xC0
#define MENU_EVALUATION      0xC1
#define MENU_MAP_NEXT        0xC2
#define MENU_NEW_CITY        0xC3
#define MENU_PAUSE           0xC4
#define MENU_SPEED_NEXT      0xC5
#define MENU_POWER_TOGGLE    0xC6
#define MENU_BULLDOZE_TOGGLE 0xC7
#define MENU_DISASTERS_TOGGLE 0xC8
#define MENU_AUTOBUDGET_TOGGLE 0xC9
#define MENU_DISASTER        0xCA    /* + 0..5 */
#define MENU_SOUND_TOGGLE    0xCB
#define MENU_SAVE            0xD1
#define MENU_LOAD            0xD2
#define MENU_TOGGLE          0x10    /* stay on this options page after the action */

static const struct menu_item main_menu[] = {
#ifdef HAVE_BUDGET
    { "BUDGET", MENU_BUDGET },
#endif /* HAVE_POPUP_MENU */
#ifdef HAVE_EVALUATION
    { "EVALUATION", MENU_EVALUATION },
#endif
#ifdef HAVE_FILES
    { "SAVE CITY", MENU_SAVE },
    { "LOAD CITY", MENU_LOAD },
#endif
#ifdef HAVE_MINIMAP
    { "MINI MAP", MENU_MAP_NEXT },
#endif
    { "GAME OPTIONS", MENU_GAME_OPTIONS },
    { "BUILDING OPTIONS", MENU_BUILD_OPTIONS },
    { "DISASTERS", MENU_DISASTERS },
    { "NEW CITY", MENU_NEW_CITY },
#ifndef TARGET_AQPLUS
    { "QUIT", CMD_QUIT }
#endif
};

/* Each setting has one action; its label is refreshed to show its current value. */
static struct menu_item game_options[] = {
    { "PAUSE: RUNNING", MENU_PAUSE | MENU_TOGGLE },
    { "SPEED: NORMAL", MENU_SPEED_NEXT | MENU_TOGGLE },
    { "AUTO BUDGET: ON", MENU_AUTOBUDGET_TOGGLE | MENU_TOGGLE },
#ifdef HAVE_SOUND
    { "SOUND: ON", MENU_SOUND_TOGGLE | MENU_TOGGLE },
#endif
    { "BACK", 0 }
};

static struct menu_item build_options[] = {
    { "POWER: COAL", MENU_POWER_TOGGLE | MENU_TOGGLE },
    { "AUTO BULLDOZE: ON", MENU_BULLDOZE_TOGGLE | MENU_TOGGLE },
    { "BACK", 0 }
};

static struct menu_item disaster_menu[] = {
    { "START FIRE", MENU_DISASTER },
    { "START FLOOD", MENU_DISASTER + 1 },
    { "EARTHQUAKE", MENU_DISASTER + 2 },
    { "AIR CRASH", MENU_DISASTER + 3 },
    { "TORNADO", MENU_DISASTER + 4 },
    { "MELTDOWN", MENU_DISASTER + 5 },
    { "RANDOM DISASTERS: ON", MENU_DISASTERS_TOGGLE | MENU_TOGGLE },
    { "BACK", 0 }
};

#define MENU_COUNT(a) (sizeof(a) / sizeof(struct menu_item))

static void handle_key(uint8_t k);

static void update_option_labels(void)
{
    static const char * const speed[] = {
        "SPEED: FAST", "SPEED: NORMAL", "SPEED: SLOW", "SPEED: PAUSED"
    };

    game_options[0].text = V_simulation_speed == 3 ? "PAUSE: PAUSED" : "PAUSE: RUNNING";
    game_options[1].text = speed[V_simulation_speed];
    game_options[2].text = V_auto_budget ? "AUTO BUDGET: ON" : "AUTO BUDGET: OFF";
#ifdef HAVE_SOUND
    game_options[3].text = sound_enabled ? "SOUND: ON" : "SOUND: OFF";
#endif
    build_options[0].text = power_nuclear ? "POWER: NUCLEAR" : "POWER: COAL";
    build_options[1].text = V_auto_bulldoze ? "AUTO BULLDOZE: ON" : "AUTO BULLDOZE: OFF";
    disaster_menu[6].text = V_disaster_reset ? "RANDOM DISASTERS: OFF" : "RANDOM DISASTERS: ON";
}

static uint8_t popup_menu(void)
{
    uint8_t choice = MENU_MAIN, page;

    while (choice) {
        page = choice;
        if (choice == MENU_MAIN)
            choice = menu_choose("SIMCITY", main_menu, MENU_COUNT(main_menu));
        else if (choice == MENU_GAME_OPTIONS) {
            update_option_labels();
            choice = menu_choose("GAME", game_options, MENU_COUNT(game_options));
        } else if (choice == MENU_BUILD_OPTIONS) {
            update_option_labels();
            choice = menu_choose("BUILDING", build_options, MENU_COUNT(build_options));
        } else if (choice == MENU_DISASTERS) {
            update_option_labels();
            choice = menu_choose("DISASTERS", disaster_menu, MENU_COUNT(disaster_menu));
        }
        /* A setting changes in place.  Redraw its page so the value column
           immediately describes the new state, rather than dismissing it. */
        if (choice >= (MENU_PAUSE | MENU_TOGGLE) && choice <= (MENU_SOUND_TOGGLE | MENU_TOGGLE)) {
            handle_key((uint8_t)(choice & ~MENU_TOGGLE));
            choice = page;
        }
        if (choice != MENU_MAIN && choice != MENU_GAME_OPTIONS && choice != MENU_BUILD_OPTIONS && choice != MENU_DISASTERS)
            return choice;
    }
    return 0;
}
#endif

/* ---- small helpers ----------------------------------------------------- */
#ifndef HAVE_FIELDS                                 /* the status panel without tables prints the numbers itself */
static uint32_t money(void)
{
    return (uint32_t)V_money[0] | ((uint32_t)V_money[1] << 8) | ((uint32_t)V_money[2] << 16);
}

static uint32_t citypop(void)
{
    /* V_CityPop is the running total of the tick in progress, so it is partial (or 0) while the simulation is
       halfway; the engine copies the finished figure to V_display_population at the end of each tick. */
    return (uint32_t)V_display_population[0] | ((uint32_t)V_display_population[1] << 8) | ((uint32_t)V_display_population[2] << 16);
}
#endif

#ifndef HAVE_FIELDS
static uint8_t put_number(char *buf, uint32_t v)
{
    return fmt_dec(buf, v);
}

static void line(uint8_t row, const char *s, uint32_t number, uint8_t with_number)
{
    char buf[64];
    uint8_t n = 0;
    while (s[n] && n < sizeof(buf) - 12) {
        buf[n] = s[n];
        ++n;
    }
    if (with_number)
        n += put_number(buf + n, number);
    if (n > panel_w)
        n = panel_w;                    /* never run into the next line */
    while (n < panel_w && n < sizeof(buf) - 1)
        buf[n++] = ' ';
    buf[n] = 0;
    if (row < panel_h)
        plat_text_puts(panel_col, (uint8_t)(panel_row + row), buf);
}

#endif

#ifndef HAVE_TILES
/* ---- map glyphs --------------------------------------------------------- */
static uint8_t zone_glyph(uint8_t x, uint8_t y)
{
    uint16_t at = (uint16_t)y * MAP_W + x;
    uint8_t type;

    /* left to the marker cell of this row, then up to the zone's top row */
    while ((levelmap[at] & 0xC0) == 0xC0 && at)
        --at;
    while (!(levelmap[at] & 0x20) && at >= MAP_W)
        at -= MAP_W;
    type = levelmap[at + 1] & 63;
    switch (type) {
    case 0:  return 'P';                /* police */
    case 1:  return 'F';                /* fire */
    case 2:  return '+';                /* church */
    case 3:  return 'H';                /* hospital */
    case 4:  return 'S';                /* stadium */
    case 6:  return 'E';                /* coal power */
    case 8:  return 'N';                /* nuclear power */
    case 10: return 'W';                /* seaport */
    case 12: return 'A';                /* airport */
    default:
        if (type >= 0x11 && type <= 0x14) return 'R';
        if (type >= 0x15 && type <= 0x18) return 'C';
        if (type >= 0x1a && type <= 0x1d) return 'I';
        return '#';
    }
}

static uint8_t glyph(uint8_t x, uint8_t y)
{
    uint8_t t = levelmap[(uint16_t)y * MAP_W + x];
    uint8_t f;

    if (t & 0x80)
        return zone_glyph(x, y);
    if (t == 0 || t == 68)  return '~';             /* water, flood */
    if (t == 2)             return ' ';             /* dirt */
    if (t < 6)              return '.';             /* shoreline */
    if (t == 6)             return '^';             /* trees */
    if (t == 69)            return '&';             /* fire */
    if (t == 89)            return 'x';             /* radiation */
    if (t == 58 || (t >= 70 && t <= 72)) return '%';        /* rubble */
    if (t == 59)            return '!';             /* needs power */
    if (t == 56 || t == 57) return 'T';             /* park */
    if (t >= 60 && t <= 67) return 'h';             /* houses growing round a zone */
    if (t >= 73 && t <= 80) return '.';             /* empty zone border */
    if (t == 81) return 'R';
    if (t == 82) return 'C';
    if (t == 83) return 'I';
    if (t == 84) return 'r';
    if (t == 85) return 'c';
    if (t == 86) return 'i';
    f = D_tile_flags[t];
    if ((f & 4) && (f & 8)) return '#';             /* road under a power line */
    if (f & 4) return (t == 8) ? '|' : (t == 7) ? '-' : '+';
    if (f & 2) return ':';                          /* rail */
    if (f & 8) return '*';                          /* power line */
    return '?';
}
#endif

/* ---- drawing -------------------------------------------------------------- */
static uint8_t last_cx = 255, last_cy;  /* where the cursor was drawn, in view cells */
static uint8_t last_size, last_phase;   /* its size (the tool's footprint) and blink phase then */
#ifdef DRAW_SPRITES
static struct sprite sprites[MAX_SPRITES], last_sprites[MAX_SPRITES];   /* the train, plane and tornado, now and last frame */
#endif

/* The cursor is the size of what the tool would place: a square of tool_size[tool] cells whose top
   left is the cursor position. */
static uint8_t in_cursor(uint8_t mx, uint8_t my)
{
    uint8_t size = tool_size[tool];
    return (uint8_t)(mx - cur_x) < size && (uint8_t)(my - cur_y) < size;
}

/* Draw one scheduled cell of the view.  The scheduler below only asks for a
   full view after it has been overwritten or moved; otherwise it supplies the
   changed map rows, cursor and sprites.  Keeping a tile identity for every
   visible cell saves writes, but costs too much RAM on small targets. */
static void draw_cell(uint8_t cx, uint8_t cy)
{
    uint8_t mx = (uint8_t)(origin_x + cx), my = (uint8_t)(origin_y + cy);
    uint8_t cursor = ((frame & 4) && in_cursor(mx, my));

#ifdef HAVE_TILES
    view_x = mx;
    view_y = my;
    view_fetch();
#ifdef DRAW_SPRITES
#ifdef HAVE_SPRITE_OVERLAY
    {
        /* a coloured screen keeps the tile's colours: the tile, then the sprite's own pixels over it */
        uint8_t art[8];

        plat_put_tile(cx, (uint8_t)(map_row + cy), view_art, view_attr, cursor);
        if (sprites_cell(sprites, mx, my, sprite_blank, art))
            plat_put_overlay(cx, (uint8_t)(map_row + cy), art);
        return;
    }
#else
    {
        uint8_t art[8], key = sprites_cell(sprites, mx, my, view_art, art), i;

        if (key) {                          /* a sprite is over this cell: its picture, not the tile's */
            if (cursor)
                for (i = 0; i < 8; ++i)
                    art[i] ^= 0xFF;
            plat_put_bitmap(cx, (uint8_t)(map_row + cy), art);
            return;
        }
    }
#endif
#endif
    plat_put_tile(cx, (uint8_t)(map_row + cy), view_art, view_attr, cursor);
#else
    plat_put(cx, (uint8_t)(map_row + cy), cursor ? '@' : glyph(mx, my));
#endif
}

/* Redraw the view.  Looking at every cell costs a lot (the engine works out each
   picture), so a full pass is made only when the view has moved.  Otherwise:
     dirty    the rows a tool has just changed (the engine set map_dirty)
     always   one row in turn, to pick up the simulation's work and the animation
     always   the cursor's cells, and the ones it left, when it has moved, changed size or blinked */
static void draw_footprint(int16_t cx, int16_t cy, uint8_t size)   /* view cells; part may be off the view */
{
    int16_t x, y;
    for (y = cy; y < cy + size; ++y)
        for (x = cx; x < cx + size; ++x)
            if (x >= 0 && y >= 0 && x < view_w && y < view_h)
                draw_cell((uint8_t)x, (uint8_t)y);
}

#ifdef HAVE_SCROLL
/* The view's origin has moved a few cells: the platform moves its pixels (plat_scroll) and only the cells that come into view
   are drawn.  The cursor and sprites move with the picture; the cursor's old cells are redrawn if it moved. */
static int8_t scroll_dx, scroll_dy;

static uint8_t scroll_or_full(uint8_t full, uint8_t last_ox, uint8_t last_oy)
{
    int16_t dx = (int16_t)origin_x - last_ox, dy = (int16_t)origin_y - last_oy;

    if (full && last_cx != 255 && view_w == plat_cols() && dx > -(int16_t)view_w && dx < view_w && dy > -(int16_t)view_h && dy < view_h) {
        scroll_dx = (int8_t)dx;
        scroll_dy = (int8_t)dy;
        return 2;
    }
    return full;
}

static void scroll_view(void)
{
    uint8_t x, y, y0, y1;

    plat_scroll(map_row, view_h, scroll_dx, scroll_dy);
    if (scroll_dy) {
        y0 = scroll_dy > 0 ? (uint8_t)(view_h - scroll_dy) : 0;
        y1 = scroll_dy > 0 ? view_h : (uint8_t)-scroll_dy;
        for (y = y0; y < y1; ++y)
            for (x = 0; x < view_w; ++x)
                draw_cell(x, y);
    }
    if (scroll_dx)
        for (y = 0; y < view_h; ++y) {
            if (scroll_dy && y >= y0 && y < y1)
                continue;
            if (scroll_dx > 0)
                for (x = (uint8_t)(view_w - scroll_dx); x < view_w; ++x)
                    draw_cell(x, y);
            else
                for (x = 0; x < (uint8_t)-scroll_dx; ++x)
                    draw_cell(x, y);
        }
    if (last_cx < view_w && last_cy < view_h)
        draw_footprint((int16_t)last_cx - scroll_dx, (int16_t)last_cy - scroll_dy, last_size);
    last_cx = 254;                          /* (255 means a full pass) */
}
#endif

static void draw_view(uint8_t full, uint8_t dirty)
{
    static uint8_t refresh_row;
    uint8_t cx, cy, rows_dirty, size = tool_size[tool], phase = (frame & 4) != 0;

#ifdef DRAW_SPRITES
    sprites_collect(sprites, frame);
#endif
#ifdef HAVE_SCROLL
    if (full == 2)
        scroll_view();
#endif
    if (full == 1) {
        for (cy = 0; cy < view_h; ++cy)
            for (cx = 0; cx < view_w; ++cx)
                draw_cell(cx, cy);
    } else {
        if (dirty) {                        /* the tool's footprint starts at the cursor */
            cy = (uint8_t)(cur_y - origin_y);
            rows_dirty = tool_size[tool];
            for (; rows_dirty && cy < view_h; --rows_dirty, ++cy)
                for (cx = 0; cx < view_w; ++cx)
                    draw_cell(cx, cy);
        }
        if (++refresh_row >= view_h)
            refresh_row = 0;
        for (cx = 0; cx < view_w; ++cx)
            draw_cell(cx, refresh_row);
        cx = (uint8_t)(cur_x - origin_x);
        cy = (uint8_t)(cur_y - origin_y);
        if (cx != last_cx || cy != last_cy || size != last_size || phase != last_phase) {
            if (last_cx < view_w && last_cy < view_h)
                draw_footprint(last_cx, last_cy, last_size);
            draw_footprint(cx, cy, size);
        }
    }
#ifdef DRAW_SPRITES
    if (full != 1)                          /* a sprite that moved, changed or went: its old cells and its new */
        for (cx = 0; cx < MAX_SPRITES; ++cx)
            if (memcmp(&sprites[cx], &last_sprites[cx], sizeof(struct sprite))) {
                if (last_sprites[cx].on)
                    draw_footprint((int16_t)last_sprites[cx].x - origin_x, (int16_t)last_sprites[cx].y - origin_y, 2);
                if (sprites[cx].on)
                    draw_footprint((int16_t)sprites[cx].x - origin_x, (int16_t)sprites[cx].y - origin_y, 2);
            }
    memcpy(last_sprites, sprites, sizeof(sprites));
#endif
    last_cx = (uint8_t)(cur_x - origin_x);
    last_cy = (uint8_t)(cur_y - origin_y);
    last_size = size;
    last_phase = phase;
}

#ifdef HAVE_MINIMAP
/* ---- the mini maps ---------------------------------------------------------------
   The city is 24 cells square at two pixels a tile (see ui/minimap.h).  The compact default is the
   Z88's 24x8 window, with pages.  A platform can make it taller, but it remains in the normal map window
   beneath the status panel.  A cell row is redrawn every few frames to follow the simulation (a row of
   24 cells is a lot of work), and the cursor's cell every frame (it blinks, as in the city view). */

#ifdef HAVE_MINIMAP_NATIVE
/* Native pixel mini maps (see ui/minimap.h): the whole city, a row at a time.  A full pass draws a chunk of rows a frame
   so that the keyboard is read in between; afterwards a few rows in turn each frame follow the simulation.  The map has
   no cursor, and the cursor keys and the tools do nothing while it is shown. */
#define MM_CHUNK_ROWS   12
#define MM_REFRESH_ROWS 4
static uint8_t mm_full_row;                  /* progress through a full redraw */

static void draw_minirow(uint8_t sy)
{
#ifdef HAVE_MINIMAP_ART
    minimap_row(map_view, sy);
    plat_put_minirow(sy);
#else
    static uint8_t colours[MM_NATIVE_COLS];

    minimap_row(map_view, sy, colours);
    plat_put_minirow(sy, colours);
#endif
}

static uint8_t draw_minimap(uint8_t full)
{
    static uint8_t refresh_row;
    uint8_t n;

    if (full) {
        for (n = 0; n < MM_CHUNK_ROWS && mm_full_row < MM_NATIVE_ROWS; ++n)
            draw_minirow(mm_full_row++);
        if (mm_full_row < MM_NATIVE_ROWS)
            return 1;
        mm_full_row = 0;
    } else {
        for (n = 0; n < MM_REFRESH_ROWS; ++n) {
            if (++refresh_row >= MM_NATIVE_ROWS)
                refresh_row = 0;
            draw_minirow(refresh_row);
        }
    }
    return 0;
}

/* Show mini map v (1..MM_VIEWS), or 0 for the city again. */
static void set_map_view(uint8_t v)
{
#ifdef HAVE_ICONS_2X7
    if (v && view_h + 1 < MM_NATIVE_ROWS * 3 / 8)       /* (the 7 row panel's last row is not used in a mini map) */
#else
    if (v && view_h < MM_NATIVE_ROWS * 3 / 8)
#endif
        return;                             /* nowhere to draw it: 144 pixel rows, 18 cells */
    if (v == map_view)
        return;
    if (!map_view && v)
#ifdef HAVE_CLEAR_MAP
        plat_clear_map();                   /* entering the mini map replaces the city (the panel stays as it is) */
#else
        plat_clear();                       /* entering the mini map replaces the city layout */
#endif
    map_view = v;
    if (v) {
        mm_full_row = 0;
        map_full = 1;
    } else {
        last_cx = 255;                      /* a full pass over the city */
    }
}
#else
static uint8_t mm_top;                      /* the pixel row shown at the top */
static uint8_t mm_col, mm_row;               /* upper-left cell on the physical display */
static uint8_t mm_full_row;                  /* progress through a full minimap redraw */

static void draw_minimap_cell(uint8_t cx, uint8_t cy)
{
    uint8_t art[8];

    if (cy >= MM_CELLS_H)
        return;
#ifdef HAVE_MINIMAP_COLOUR
    minimap_cell(MM_CITY, cx, cy, mm_top, cur_x, cur_y, 0, art);
    plat_put_minimap((uint8_t)(mm_col + cx), (uint8_t)(mm_row + cy), art, map_view,
                     minimap_level(map_view, (uint8_t)(cx * 4),
                                   (uint8_t)((mm_top >> 1) + cy * 4))
#ifdef HAVE_MINIMAP_CURSOR
                     , 0
#endif
                     );
#else
    minimap_cell(map_view, cx, cy, mm_top, cur_x, cur_y,
#ifdef HAVE_MINIMAP_CURSOR
                 (frame & 4) != 0,
#else
                 0,
#endif
                 art);
    plat_put_bitmap((uint8_t)(mm_col + cx), (uint8_t)(mm_row + cy), art);
#endif
}

static uint8_t draw_minimap(uint8_t full)
{
    static uint8_t refresh_row, last_cx_, last_cy_;
    uint8_t cx, cy;

    if (full) {
        /* A complete AQ+ minimap is large; draw a small row chunk per frame so
           the keyboard is serviced between chunks instead of after the map. */
        cy = mm_full_row;
        for (;;) {
            for (cx = 0; cx < MM_CELLS_W; ++cx)
                draw_minimap_cell(cx, cy);
            ++cy;
            if (cy >= MM_CELLS_H || (uint8_t)(cy - mm_full_row) == MINIMAP_CHUNK_ROWS)
                break;
        }
        mm_full_row = cy;
        if (mm_full_row < MM_CELLS_H)
            return 1;
        mm_full_row = 0;
    } else {
        if (!(frame & 3)) {
            if (++refresh_row >= MM_CELLS_H)
                refresh_row = 0;
            for (cx = 0; cx < MM_CELLS_W; ++cx)
                draw_minimap_cell(cx, refresh_row);
        }
        draw_minimap_cell(last_cx_, last_cy_);
    }
    last_cx_ = (uint8_t)(cur_x >> 2);
    last_cy_ = (uint8_t)((uint8_t)(cur_y * 2 - mm_top) >> 3);       /* (8 or more: off the page, nothing is drawn) */
    draw_minimap_cell(last_cx_, last_cy_);
    return 0;
}

/* Up and down flip the page of the city the picture shows (the cursor stays where it is).  The step leaves
   16 pixels of the last page in view: this is the old 48-pixel step on the Z88. */
static void flip_page(int8_t dy)
{
    uint8_t step, top;

    if (MM_PIXELS_H >= MM_PICTURE_H)
        return;                              /* the whole city is already on screen */
    step = (uint8_t)(MM_PIXELS_H - 16);
    if (dy < 0)
        top = mm_top > step ? (uint8_t)(mm_top - step) : 0;
    else {
        top = (uint8_t)(mm_top + step);
        if (top > MM_PICTURE_H - MM_PIXELS_H)
            top = MM_PICTURE_H - MM_PIXELS_H;
    }
    mm_top = top;
    map_full = 1;
}

/* Show mini map v (1..MM_VIEWS), or 0 for the city again. */
static void set_map_view(uint8_t v)
{
    if (v && (view_w < MM_CELLS_W || view_h < MM_CELLS_H))
        return;                             /* nowhere to draw it */
    if (v == map_view)
        return;
    if (!map_view && v)
        plat_clear();                           /* entering the minimap replaces the city layout */
    map_view = v;
    if (v) {
        mm_full_row = 0;
        map_full = 1;
        mm_top = (uint8_t)((cur_y >> 5) << 6);   /* the third of the city the cursor is in */
        if (mm_top > MM_PICTURE_H - MM_PIXELS_H)
            mm_top = MM_PICTURE_H - MM_PIXELS_H;
        mm_col = (uint8_t)((cols - MM_CELLS_W) >> 1);
        mm_row = map_row;
    } else {
        last_cx = 255;                      /* a full pass over the city */
    }
}

#endif /* HAVE_MINIMAP_NATIVE */
#else
#define MM_VIEWS 0
#define draw_minimap(full) 0
#define set_map_view(v)
#endif

/* "R   |## " : a letter, three cells for shortfall, a bar, three cells for demand: the seven bars for -3..3 */
static const char demand_bars[7][8] = {
    "###|   ", " ##|   ", "  #|   ", "   |   ", "   |#  ", "   |## ", "   |###"
};

#ifdef HAVE_DEMAND_BARS
/* The demand as a number of zones: the engine's valve is 8 to a zone of imbalance, less an offset it keeps (26 for R, 30 for C and I) so
   that a city with nothing built shows nothing; within -27..27. */
static int8_t demand_level(int16_t v, int16_t offset)
{
    int16_t n = v + offset;

    n = n < 0 ? -(-n >> 3) : n >> 3;
    return (int8_t)(n > 27 ? 27 : n < -27 ? -27 : n);
}
#else
static void demand_bar(char *b, char name, int16_t v)
{
    int16_t n = v < 0 ? -(-v >> 5) : v >> 5;            /* v / 32, rounded towards 0 */

    b[0] = name;
    memcpy(b + 1, demand_bars[n > 3 ? 6 : n < -3 ? 0 : n + 3], 7);
}
#endif

static const char *const help_page[3] = {
    "O P Q A MOVE  SPACE BUILD",
    ", . TOOL  0-9 PICK  E POWER",
#ifdef HAVE_POPUP_MENU
    "H PAUSE  + - SPEED  X MENU",
#else
    "H PAUSE  + - SPEED  X QUIT",
#endif
};

#ifdef HAVE_FIELDS
/* The status panel as tables of fields (ui/textfmt.h): the pointers are set from the game's state just
   before it is drawn. */
static const char *st_month, *st_tool, *st_speed, *st_alert, *st_line[3];
static const char *const st_speeds[4] = { "FAST", "NORMAL", "SLOW", "PAUSED" };

static const struct field status_top[] = {
    { 0,  0, F_STR,  0, &st_month },
    { 0,  8, F_U16,  0, &V_year },
    { 0, 10, F_TEXT, 0, "FUNDS $" },
    { 0, 17, F_L24,  0, V_money },
    { 0, 27, F_TEXT, 0, "POP" },
    { 0, 31, F_L24,  0, V_display_population },       /* not V_CityPop: that is the tick in progress */
};
static const struct field status_tool[] = {
    { 2,  0, F_STR,  0, &st_tool },
    { 2, 21, F_STR,  0, &st_speed },
};
static const struct field status_alert[] = {
    { 3,  0, F_STR,  0, &st_alert },
};
static const struct field status_alert_low[] = {            /* with icons in rows 3 and 4 */
    { 5,  0, F_TEXT, 0, "" },                               /* (where the map's name goes) */
    { 6,  0, F_STR,  0, &st_alert },
};
static const struct field status_help[] = {
    { 4,  0, F_STR,  0, &st_line[0] },
    { 5,  0, F_STR,  0, &st_line[1] },
    { 6,  0, F_STR,  0, &st_line[2] },
};
static const struct field status_map[] = {
    { 4,  0, F_TEXT, 0, "MAP:" },
    { 4,  5, F_STR,  0, &st_line[1] },
    { 5,  0, F_TEXT, 0, "M NEXT MAP  X BACK TO CITY" },
    { 6,  0, F_TEXT, 0, "" },
};
static const struct field status_map_low[] = {              /* with icons: just the name, below them */
    { 5,  0, F_TEXT, 0, "MAP:" },
    { 5,  5, F_STR,  0, &st_line[1] },
};

#ifdef HAVE_ICONS_TOP
/* The Spectrum's arrangement across the whole 40 columns (or 32: see below): the date, funds and population on row 0, the tool icons in
   rows 1 and 2, then the tool and speed, the three demand bars, and the advisor (or the mini map's name). */
#ifdef HAVE_ICONS_2X7
#define TOP_PANEL_ROWS  7                   /* (the mini map's 144 lines start under row 5: see draw_status) */
#else
#define TOP_PANEL_ROWS  6
#endif

#if MODAL_COLS < 40
/* On a 32 column display: no word FUNDS, the population nearer, the demand bars 11 apart, the map's keys shorter. */
#define TOP_DEMAND_C    11
#define TOP_DEMAND_I    22
static const struct field top_status[] = {
    { 0,  0, F_STR,  0, &st_month },
    { 0,  8, F_U16,  0, &V_year },
    { 0,  9, F_TEXT, 0, "$" },
    { 0, 10, F_L24,  0, V_money },
    { 0, 19, F_TEXT, 0, "POP" },
    { 0, 23, F_L24,  0, V_display_population },
    { 3,  0, F_STR,  0, &st_tool },
    { 3, 24, F_STR,  0, &st_speed },
};
#define TOP_MAP_KEYS_COL 20
#define TOP_MAP_KEYS     "M NEXT X OFF"
#else
#define TOP_DEMAND_C    13
#define TOP_DEMAND_I    26
static const struct field top_status[] = {
    { 0,  0, F_STR,  0, &st_month },
    { 0,  8, F_U16,  0, &V_year },
    { 0, 10, F_TEXT, 0, "FUNDS $" },
    { 0, 17, F_L24,  0, V_money },
    { 0, 27, F_TEXT, 0, "POP" },
    { 0, 31, F_L24,  0, V_display_population },
    { 3,  0, F_STR,  0, &st_tool },
    { 3, 24, F_STR,  0, &st_speed },
};
#define TOP_MAP_KEYS_COL 22
#define TOP_MAP_KEYS     "M NEXT  X BACK"
#endif
static const struct field top_alert[] = {
    { 5,  0, F_STR,  0, &st_alert },
};
static const struct field top_map[] = {
    { 5,  0, F_TEXT, 0, "MAP:" },
    { 5,  5, F_STR,  0, &st_line[1] },
    { 5, TOP_MAP_KEYS_COL, F_TEXT, 0, TOP_MAP_KEYS },
};

#ifdef HAVE_ICONS_2X7
/* The icons in two rows of seven (rows 1 to 4, 21 columns), with the demand bars and the speed in the 11 columns beside them, the
   tool and its cost on row 5 and the advisor on row 6.  Nothing here may print a whole row 1 to 4 (a field table does): that is
   the icons' place, and they are only drawn when the tool changes.  The mini map's 144 lines start under row 5, so in a mini map row 6 is not
   drawn and row 5 has the map's name. */
static const struct field top_status27[] = {
    { 0,  0, F_STR,  0, &st_month },
    { 0,  8, F_U16,  0, &V_year },
    { 0,  9, F_TEXT, 0, "$" },
    { 0, 10, F_L24,  0, V_money },
    { 0, 19, F_TEXT, 0, "POP" },
    { 0, 23, F_L24,  0, V_display_population },
    { 5,  0, F_STR,  0, &st_tool },
};
static const struct field top_alert27[] = {
    { 6,  0, F_STR,  0, &st_alert },
};

static void draw_status(void)
{
    char buf[9];

    st_month = text_months[V_month];
    st_tool = text_tools[tool];
    st_speed = st_speeds[V_simulation_speed & 3];
    st_alert = V_alertmessage < sizeof(text_alerts) / sizeof(text_alerts[0]) ? text_alerts[V_alertmessage] : "";
    buf[8] = 0;
    {                                       /* the speed, padded: a field would print the whole row, icons and all */
        uint8_t i = 0;
        const char *t = st_speed;

        while (*t && i < 8)
            buf[i++] = *t++;
        while (i < 8)
            buf[i++] = ' ';
        plat_text_puts(22, 4, buf);
    }
#ifdef HAVE_DEMAND_BARS
    plat_demand(22, 1, 'R', demand_level(V_RValve, 26));
    plat_demand(22, 2, 'C', demand_level(V_CValve, 30));
    plat_demand(22, 3, 'I', demand_level(V_IValve, 30));
#else
    demand_bar(buf, 'R', V_RValve);
    plat_text_puts(22, 1, buf);
    demand_bar(buf, 'C', V_CValve);
    plat_text_puts(22, 2, buf);
    demand_bar(buf, 'I', V_IValve);
    plat_text_puts(22, 3, buf);
#endif
#ifdef HAVE_MINIMAP
    if (map_view) {
        fmt_fields(top_status27, sizeof(top_status27) / sizeof(struct field) - 1);
        st_line[1] = minimap_names[map_view];
        fmt_fields(top_map, sizeof(top_map) / sizeof(struct field));
    } else
#endif
    {
        fmt_fields(top_status27, sizeof(top_status27) / sizeof(struct field));
        fmt_fields(top_alert27, 1);
    }
    plat_icons(tool);
}
#else
static void draw_status(void)
{
    char buf[41];

    st_month = text_months[V_month];
    st_tool = text_tools[tool];
    st_speed = st_speeds[V_simulation_speed & 3];
    st_alert = V_alertmessage < sizeof(text_alerts) / sizeof(text_alerts[0]) ? text_alerts[V_alertmessage] : "";
    fmt_fields(top_status, sizeof(top_status) / sizeof(struct field));
    fmt_blank(buf);
    demand_bar(buf, 'R', V_RValve);
    demand_bar(buf + TOP_DEMAND_C, 'C', V_CValve);
    demand_bar(buf + TOP_DEMAND_I, 'I', V_IValve);
    plat_text_puts(0, 4, buf);
#ifdef HAVE_MINIMAP
    if (map_view) {
        st_line[1] = minimap_names[map_view];
        fmt_fields(top_map, sizeof(top_map) / sizeof(struct field));
    } else
#endif
        fmt_fields(top_alert, 1);
    plat_icons(tool);
}
#endif
#else
/* The status panel: five lines, so it fits the top third of even a 16 row screen. */
static void draw_status(void)
{
    char buf[41];
#ifdef HAVE_ICONS
    uint8_t icons = panel_h >= 8;                           /* the tools as pictures in rows 3 and 4 */
#endif

    if (!panel_w)
        return;
    st_month = text_months[V_month];
    st_tool = text_tools[tool];
    st_speed = st_speeds[V_simulation_speed & 3];
    st_alert = V_alertmessage < sizeof(text_alerts) / sizeof(text_alerts[0]) ? text_alerts[V_alertmessage] : "";
    fmt_fields(status_top, sizeof(status_top) / sizeof(struct field));
    if (panel_h > 1) {
        fmt_blank(buf);
        demand_bar(buf, 'R', V_RValve);
        demand_bar(buf + 10, 'C', V_CValve);
        demand_bar(buf + 20, 'I', V_IValve);
        plat_text_puts(0, 1, buf);
    }
    fmt_fields(status_tool, sizeof(status_tool) / sizeof(struct field));
#ifdef HAVE_ICONS
    if (icons) {                                            /* rows 3 and 4 the icons, 6 the advisor, no key tips */
        fmt_fields(status_alert_low, sizeof(status_alert_low) / sizeof(struct field));
#ifdef HAVE_MINIMAP
        if (map_view) {
            st_line[1] = minimap_names[map_view];
            fmt_fields(status_map_low, sizeof(status_map_low) / sizeof(struct field));
        }
#endif
        plat_icons(tool);
        return;
    }
#endif
    fmt_fields(status_alert, 1);
#ifdef HAVE_MINIMAP
    if (map_view) {
        st_line[1] = minimap_names[map_view];
        fmt_fields(status_map, sizeof(status_map) / sizeof(struct field));
    } else
#endif
    {
        st_line[0] = help_page[panel_h >= 7 ? 0 : (frame >> 6) % 3];
        st_line[1] = help_page[1];
        st_line[2] = help_page[2];
        fmt_fields(status_help, panel_h >= 7 ? 3 : 1);
    }
}
#endif
#else
static uint8_t append(char *buf, uint8_t n, const char *s)
{
    while (*s)
        buf[n++] = *s++;
    return n;
}

/* The status panel: five lines, so it fits the top third of even a 16 row screen. */
static void draw_status(void)
{
    char buf[40];
    uint8_t n;

    if (!panel_w)
        return;
    n = append(buf, 0, text_months[V_month]);
    buf[n++] = ' ';
    n += put_number(buf + n, V_year);
    n = append(buf, n, "  FUNDS $");
    n += put_number(buf + n, money());
    n = append(buf, n, "  POP ");
    n += put_number(buf + n, citypop());
    buf[n] = 0;
    line(0, buf, 0, 0);

    for (n = 0; n < 28; ++n)
        buf[n] = ' ';
    demand_bar(buf, 'R', V_RValve);
    demand_bar(buf + 10, 'C', V_CValve);
    demand_bar(buf + 20, 'I', V_IValve);
    buf[28] = 0;
    line(1, buf, 0, 0);

    n = append(buf, 0, text_tools[tool]);
    n = append(buf, n, "  ");
    n = append(buf, n, V_simulation_speed == 3 ? "PAUSED" : V_simulation_speed == 0 ? "FAST" :
            V_simulation_speed == 1 ? "NORMAL" : "SLOW");
    buf[n] = 0;
    line(2, buf, 0, 0);
    line(3, V_alertmessage < sizeof(text_alerts) / sizeof(text_alerts[0]) ?
            text_alerts[V_alertmessage] : "", 0, 0);
#ifdef HAVE_MINIMAP
    if (map_view) {
        line(4, "", 0, 0);
        n = append(buf, 0, "MAP: ");
        n = append(buf, n, minimap_names[map_view]);
        buf[n] = 0;
        line(5, buf, 0, 0);
        line(6, "M NEXT MAP  X BACK TO CITY", 0, 0);
    } else
#endif
    if (panel_h >= 7) {                     /* room for all the help at once */
        line(4, help_page[0], 0, 0);
        line(5, help_page[1], 0, 0);
        line(6, help_page[2], 0, 0);
    } else {                                /* one line that changes every so often */
        line(4, help_page[(frame >> 6) % 3], 0, 0);
    }
}

#endif

/* ---- the cursor and the view -------------------------------------------------- */
static void clamp_view(void)
{
    if (cur_x < origin_x) origin_x = cur_x;
    if (cur_y < origin_y) origin_y = cur_y;
    if (cur_x >= origin_x + view_w) origin_x = (uint8_t)(cur_x - view_w + 1);
    if (cur_y >= origin_y + view_h) origin_y = (uint8_t)(cur_y - view_h + 1);
    if (origin_x > MAP_W - view_w) origin_x = (uint8_t)(MAP_W - view_w);
    if (origin_y > MAP_H - view_h) origin_y = (uint8_t)(MAP_H - view_h);
}

static void move_cursor(int8_t dx, int8_t dy)
{
#ifdef HAVE_MINIMAP_NATIVE
    if (map_view)
        return;                             /* a map has no cursor */
#endif
#if defined(HAVE_MINIMAP) && !defined(HAVE_MINIMAP_NATIVE)
    if (map_view) {                         /* on a mini map up and down turn its pages */
        if (dy)
            flip_page(dy);
        dy = 0;
    }
#endif
    int16_t nx = (int16_t)cur_x + dx;
    int16_t ny = (int16_t)cur_y + dy;
    if (nx < 0 || nx >= MAP_W || ny < 0 || ny >= MAP_H)
        return;
    cur_x = (uint8_t)nx;
    cur_y = (uint8_t)ny;
    clamp_view();
}

static void apply_tool(void)
{
    uint8_t size = tool_size[tool];

#ifdef HAVE_MINIMAP_NATIVE
    if (map_view)
        return;                             /* nothing is built from a map */
#endif
    if (cur_x + size > MAP_W || cur_y + size > MAP_H)
        return;
    V_selected_tool = tool;
    V_power_type_chosen = power_nuclear ? 1 : 2;
    V_pointer_charxy[0] = (uint8_t)(cur_x - origin_x);
    V_pointer_charxy[1] = (uint8_t)(cur_y - origin_y + 8);
    V_view_topleft[0] = origin_x;
    V_view_topleft[1] = origin_y;
    tool_apply();
}

static void set_tool(uint8_t t)
{
    if (t < NUM_TOOLS)
        tool = t;
}

#ifdef HAVE_BUDGET
/* The budget screen, modal.  The engine asks for it once a year (sim_step returns 2 and the main loop calls
   this, the simulation parked); the player can also look at it, and change the rates, any time. */
void game_budget(void)
{
    if (budget_screen())
        quit = 1;
    else
        redraw |= REDRAW_TEXT;              /* it used the text area */
}

#else
#define game_budget()
#endif

#ifdef HAVE_EVALUATION
/* The evaluation screen, modal. */
static void game_evaluation(void)
{
    if (evaluation_screen())
        quit = 1;
    else
        redraw |= REDRAW_TEXT;
}
#else
#define game_evaluation()
#endif

#ifdef HAVE_FILES
#ifdef HAVE_POPUP_MENU
#define file_done() (redraw |= (map_view ? REDRAW_ALL : REDRAW_MAP))   /* the dialogue is a box over the map */
#else
#define file_done() (redraw |= REDRAW_TEXT)
#endif

/* Save the city to a file, or load one. */
static void game_save(void)
{
    if (city_save() == CITY_QUIT)
        quit = 1;
    else
        file_done();
}

static void game_load(void)
{
    uint8_t r;

    r = city_load();
    if (r == CITY_QUIT) {
        quit = 1;
    } else if (r == CITY_BROKEN) {
        restart = quit = 1;                 /* the map was half read: a new city */
    } else if (r == CITY_LOADED) {
        redraw = REDRAW_ALL;
        tick_reset = 1;
    } else {
        file_done();                        /* nothing was loaded: the city as it was */
    }
}
#else
#define game_save()
#define game_load()
#endif

static void handle_key(uint8_t k)
{
    switch (k) {
    case KEY_LEFT:   move_cursor(-1, 0); break;
    case KEY_RIGHT:  move_cursor(1, 0);  break;
    case KEY_UP:     move_cursor(0, -1); break;
    case KEY_DOWN:   move_cursor(0, 1);  break;
    case KEY_FAR_LEFT:  move_cursor(-8, 0); break;
    case KEY_FAR_RIGHT: move_cursor(8, 0);  break;
    case KEY_FAR_UP:    move_cursor(0, -8); break;
    case KEY_FAR_DOWN:  move_cursor(0, 8);  break;
#ifndef HAVE_MENUS                                  /* the letters, for keyboards without cursor keys */
    case 'o': move_cursor(-1, 0); break;
    case 'p': move_cursor(1, 0);  break;
    case 'q': move_cursor(0, -1); break;
    case 'a': move_cursor(0, 1);  break;
    case 'O': move_cursor(-8, 0); break;
    case 'P': move_cursor(8, 0);  break;
    case 'Q': move_cursor(0, -8); break;
    case 'A': move_cursor(0, 8);  break;
#endif
    case ' ': case KEY_ENTER:  apply_tool(); break;
    case ',': set_tool((uint8_t)(tool ? tool - 1 : NUM_TOOLS - 1)); break;
    case '.': set_tool((uint8_t)(tool + 1 < NUM_TOOLS ? tool + 1 : 0)); break;
    case '+':
        if (V_simulation_speed > 0 && V_simulation_speed < 3) --V_simulation_speed;
        break;
    case '-':
        if (V_simulation_speed < 2) ++V_simulation_speed;
        break;
#ifdef HAVE_MENUS
    case 'x':
        break;                              /* quit is in the menu */
    case KEY_ESC:
        if (map_view) set_map_view(0);      /* (it does not quit either) */
        break;
#elif defined(HAVE_POPUP_MENU)
    case 'x': case KEY_ESC:
        if (map_view)
            set_map_view(0);             /* X is the documented mini-map back key */
        else {
            k = popup_menu();
#ifdef HAVE_FILES
            if (k == MENU_SAVE || k == MENU_LOAD) {
                last_cx = 255;              /* the dialogue is a box too: show the map, not the menu's box, around it */
                draw_view(1, 0);
            }
#endif
            if (k)
                handle_key(k);
            if (!quit && !redraw)
                redraw = REDRAW_MAP;
        }
        break;
#else
    case 'x': case KEY_ESC:
        if (map_view) set_map_view(0); else quit = 1;
        break;
#endif
    case 'b':
#ifdef HAVE_POPUP_MENU
    case MENU_BUDGET:
#endif
#ifndef TARGET_AQPLUS
    case CMD_BUDGET:
#endif
        game_budget(); break;
    case 'v':
#ifdef HAVE_POPUP_MENU
    case MENU_EVALUATION:
#endif
#ifndef TARGET_AQPLUS
    case CMD_EVALUATION:
#endif
        game_evaluation(); break;
    case 's':
#ifdef HAVE_POPUP_MENU
    case MENU_SAVE:
#endif
#ifndef TARGET_AQPLUS
    case CMD_SAVE:
#endif
        game_save(); break;
    case 'l':
#ifdef HAVE_POPUP_MENU
    case MENU_LOAD:
#endif
#ifndef TARGET_AQPLUS
    case CMD_LOAD:
#endif
        game_load(); break;
    case 'm':
#ifdef HAVE_POPUP_MENU
    case MENU_MAP_NEXT:
#endif
        set_map_view((uint8_t)(map_view < MM_VIEWS ? map_view + 1 : 0)); break;
#ifdef HAVE_POPUP_MENU
    case MENU_NEW_CITY:
#endif
#ifndef TARGET_AQPLUS
    case CMD_NEW_CITY:
#endif
        restart = quit = 1; break;
    case 'h':
#ifdef HAVE_POPUP_MENU
    case MENU_PAUSE:
#endif
#ifndef TARGET_AQPLUS
    case CMD_PAUSE:
#endif
        V_simulation_speed = (V_simulation_speed == 3) ? 1 : 3; break;
#ifndef TARGET_AQPLUS
    case CMD_QUIT: quit = 1; break;
    case CMD_MAP_OFF: set_map_view(0); break;
#endif
#ifdef HAVE_POPUP_MENU
    case MENU_SPEED_NEXT:
        if (V_simulation_speed == 3) V_simulation_speed = 1;
        else if (V_simulation_speed) --V_simulation_speed;
        else V_simulation_speed = 2;
        break;
#endif
#ifndef TARGET_AQPLUS
    case CMD_SPEED_FAST:       V_simulation_speed = 0; break;
    case CMD_SPEED_NORMAL:     V_simulation_speed = 1; break;
    case CMD_SPEED_SLOW:       V_simulation_speed = 2; break;
#endif
    case 'e':
#ifdef HAVE_POPUP_MENU
    case MENU_POWER_TOGGLE:
#endif
        power_nuclear = !power_nuclear; break;
#ifndef TARGET_AQPLUS
    case CMD_POWER_COAL:       power_nuclear = 0; break;
    case CMD_POWER_NUCLEAR:    power_nuclear = 1; break;
#endif
#ifdef HAVE_POPUP_MENU
    case MENU_DISASTERS_TOGGLE: V_disaster_reset = !V_disaster_reset; break;
#endif
#ifndef TARGET_AQPLUS
    case CMD_DISASTERS_ON:     V_disaster_reset = 0; break;
    case CMD_DISASTERS_OFF:    V_disaster_reset = 1; break;
#endif
#ifdef HAVE_POPUP_MENU
    case MENU_BULLDOZE_TOGGLE: V_auto_bulldoze = !V_auto_bulldoze; break;
#endif
#ifndef TARGET_AQPLUS
    case CMD_AUTOBULLDOZE_ON:  V_auto_bulldoze = 1; break;
    case CMD_AUTOBULLDOZE_OFF: V_auto_bulldoze = 0; break;
#endif
#ifdef HAVE_SOUND
#ifdef HAVE_POPUP_MENU
    case MENU_SOUND_TOGGLE:    sound_enabled = !sound_enabled; break;
#endif
#ifndef TARGET_AQPLUS
    case CMD_SOUND_ON:         sound_enabled = 1; break;
    case CMD_SOUND_OFF:        sound_enabled = 0; break;
#endif
#endif
#ifdef HAVE_POPUP_MENU
    case MENU_AUTOBUDGET_TOGGLE: V_auto_budget = !V_auto_budget; break;
#endif
#ifndef TARGET_AQPLUS
    case CMD_AUTOBUDGET_ON:    V_auto_budget = 1; break;
    case CMD_AUTOBUDGET_OFF:   V_auto_budget = 0; break;
    case CMD_REDRAW:           redraw = REDRAW_ALL; break;
#endif
    default:
#ifndef TARGET_AQPLUS
        if (k >= CMD_MAP && k < CMD_MAP + MM_VIEWS)
            set_map_view((uint8_t)(k - CMD_MAP + 1));
        else
#else
#endif
        if (k >= '0' && k <= '9')
            set_tool((uint8_t)(k - '0'));
#ifdef HAVE_POPUP_MENU
        else if (k >= MENU_DISASTER && k < MENU_DISASTER + 6)
            V_disaster_option = (uint8_t)(k - MENU_DISASTER + 1);
#endif
#ifndef TARGET_AQPLUS
        else if (k >= CMD_DISASTER && k < CMD_DISASTER + 6)
            V_disaster_option = (uint8_t)(k - CMD_DISASTER + 1);       /* the engine starts it a few frames on */
#endif
        break;
    }
}

/* ---- start-up ----------------------------------------------------------------- */
static void choose_layout(void)
{
    cols = plat_cols();
    rows = plat_rows();
    view_w = cols < MAX_VIEW_W ? cols : MAX_VIEW_W;
#ifdef HAVE_TEXT_WINDOW                             /* the text has a window of its own: the map is all of the console */
    view_h = rows < MAX_VIEW_H ? rows : MAX_VIEW_H;
    map_row = 0;
    panel_col = panel_row = 0;
    panel_w = plat_text_cols();
    panel_h = plat_text_rows();
#elif defined(HAVE_ICONS_TOP)
    panel_col = panel_row = 0;
    panel_w = cols;
    panel_h = TOP_PANEL_ROWS;                       /* a short panel across the top: the map gets the rest */
    map_row = TOP_PANEL_ROWS;
    view_h = (uint8_t)(rows - TOP_PANEL_ROWS);
    if (view_h > MAX_VIEW_H)
        view_h = MAX_VIEW_H;
#else
    view_h = (uint8_t)(rows - rows / 3);            /* the map takes the bottom two thirds */
    if (view_h > MAX_VIEW_H)
        view_h = MAX_VIEW_H;
    map_row = (uint8_t)(rows - view_h);
    panel_col = panel_row = 0;                      /* the status panel, the top third */
    panel_w = cols;
    panel_h = map_row;
#endif
#ifdef HAVE_POPUP_MENU
    menu_area(map_row, view_h);                     /* the menus and dialogues are centred in the map */
#endif
}

static void title_screen(void)
{
    uint16_t seed = 0, first;
    uint8_t k;

    plat_text_clear();
    plat_text_puts(0, 0, "S I M C I T Y");
#ifdef HAVE_NARROW_TITLE                           /* a 32 column display: one choice to a line */
    plat_text_puts(0, 2, "CHOOSE A LEVEL:");
    plat_text_puts(2, 4, "1 EASY");
    plat_text_puts(2, 6, "2 MEDIUM");
    plat_text_puts(2, 8, "3 HARD");
#else
    plat_text_puts(0, 2, "CHOOSE A LEVEL: 1 EASY 2 MEDIUM 3 HARD");
#endif
    plat_flush();
    do {
        seed++;
        k = plat_key();
        if (!k)
            plat_idle();
    } while (k != '1' && k != '2' && k != '3');
    V_difficulty = (uint8_t)(k - '1');
    first = plat_clock();                           /* how long the level took to choose... */
#ifdef HAVE_APPNAME
    {                                               /* the Spectrum asks for the city's name here */
        char name[CITY_NAME_LEN + 2];
        uint8_t k2;

        k = prompt_ask("NAME YOUR CITY", "CITY NAME:", name, CITY_NAME_LEN, 1);
        if (k == 2) {
            quit = 1;
            return;
        }
        for (k2 = 0; k2 < CITY_NAME_LEN + 1; ++k2)
            city_name[k2] = k == 1 ? name[k2] : "HERESVILLE"[k2];
        city_name[CITY_NAME_LEN] = 0;
        plat_set_name(city_name);
    }
#endif
    V_InitialSeed = (uint16_t)(seed ^ first ^ (plat_clock() - first) ^ plat_entropy()) | 1; /* ...and the name took to type */
    plat_text_clear();
    plat_text_puts(0, 0, "GENERATING LANDSCAPE...");
    plat_flush();
}

/* One city, from the title screen until it is quit or replaced. */
static void play_city(void)
{
    uint8_t k, countdown, ticking = 0, full, last_ox = 0, last_oy = 0;
    struct status st, last_st;

    title_screen();

#ifdef HAVE_BUDGET
    V_auto_budget = 0;                      /* the annual budget waits for the player (game_budget) */
#else
    V_auto_budget = 1;
#endif
    V_auto_bulldoze = 1;
    V_disaster_reset = 0;
    V_simulation_speed = 1;
    SMC_tax_rate = 7;
    SMC_transport_percent = SMC_police_percent = SMC_fire_percent = 100;
    sim_new_city();
    map_view = 0;

    cur_x = cur_y = MAP_W / 2;
    origin_x = (uint8_t)(cur_x - view_w / 2);
    origin_y = (uint8_t)(cur_y - view_h / 2);
    tool = 1;
    clamp_view();
    plat_clear();
    plat_text_clear();
    last_cx = 255;                          /* draw the whole view on the first frame */
    countdown = tick_frames[V_simulation_speed];
    memset(&st, 0, sizeof(st));
    memset(&last_st, 0xFF, sizeof(last_st));          /* nothing drawn yet */

    while (!quit) {
        if (tick_reset) {                   /* a city was loaded */
            tick_reset = 0;
            ticking = 0;
            countdown = tick_frames[V_simulation_speed];
        }
        k = plat_key();
        if (k)
            handle_key(k);
        if (quit)                           /* no last frame: it would draw over a screen the quit left up */
            break;

        /* The simulation runs in slices (one map row each) so that the UI stays
           responsive: a tick is started every tick_frames[] frames, then advanced
           SLICES_PER_FRAME rows per frame until it completes. */
        if (tick_frames[V_simulation_speed]) {
            if (ticking) {
                for (k = 0; k < SLICES_PER_FRAME; ++k) {
                    full = sim_step();
#ifdef HAVE_BUDGET
                    if (full == 2) {            /* the annual budget needs the player: show it here, not in the simulation */
                        game_budget();
                        V_wait_for_budget_confirm = 0;
                        break;
                    }
#endif
                    if (full) {
#ifdef HAVE_EVALUATION
                        eval_unpowered = V_unPwrdZCnt;      /* the tick's own count, whole at last */
#endif
                        ticking = 0;
                        countdown = tick_frames[V_simulation_speed];
                        break;
                    }
                }
            } else if (--countdown == 0) {
                ticking = 1;
            }
        } else {
            countdown = 1;
        }

        V_view_tick = frame;
        engine_a = frame;
        sim_periodic();

        /* a full pass over the map only when the view has moved */
        if (redraw) {                       /* OZ drew over us, or a screen did: start the affected area again */
            if (redraw & REDRAW_ALL) {
                plat_clear();
                last_cx = 255;
                map_full = 1;
            }
            else if (redraw & REDRAW_MAP) {
                /* A popup can only open from the city, not a mini map.  A full
                   city-view pass overwrites its box without touching status. */
                last_cx = 255;
            }
            if (!(redraw & REDRAW_MAP) || (redraw & REDRAW_ALL)) {
                plat_text_clear();
                memset(&last_st, 0xFF, sizeof(last_st));
            }
            redraw = 0;
        }
#ifndef HAVE_ICONS_TOP
        full = origin_x != last_ox || origin_y != last_oy || last_cx == 255;
#ifdef HAVE_SCROLL
        full = scroll_or_full(full, last_ox, last_oy);
#endif
        last_ox = origin_x;
        last_oy = origin_y;
        if (map_view) {
            map_full = draw_minimap(map_full);
        } else {
            draw_view(full, map_dirty);
        }
#endif

        /* the status panel only when something it shows has changed */
        memcpy(st.money, V_money, 3);
        memcpy(st.pop, V_display_population, 3);
        st.year = V_year;
        st.rv = V_RValve;
        st.cv = V_CValve;
        st.iv = V_IValve;
        st.month = V_month;
        st.tool = tool;
        st.speed = V_simulation_speed;
        st.alert = V_alertmessage;
        st.map_view = map_view;
        st.page = (panel_h >= 7) ? 0 : (uint8_t)((frame >> 6) % 3);
        if (memcmp(&st, &last_st, sizeof(st))) {
            last_st = st;
            draw_status();
        }
#ifdef HAVE_ICONS_TOP                  /* the panel is at the top: it is drawn first, so a new screen does not show the map before it */
        full = origin_x != last_ox || origin_y != last_oy || last_cx == 255;
#ifdef HAVE_SCROLL
        full = scroll_or_full(full, last_ox, last_oy);
#endif
        last_ox = origin_x;
        last_oy = origin_y;
        if (map_view) {
            map_full = draw_minimap(map_full);
        } else {
            draw_view(full, map_dirty);
        }
#endif
        plat_flush();
        map_dirty = 0;
        ++frame;
        plat_idle();
    }
}

void game_run(void)
{
    plat_init();
    choose_layout();
    do {
        quit = restart = 0;
        play_city();
    } while (restart);
    plat_exit();
}
