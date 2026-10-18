/* ------------------------------------------------------------------------
   SimCity game core: the user interface shared by every platform.

   It owns the cursor, the view and the keyboard, drives the portable engine
   (engine/), and draws through the small platform API in platform.h.  Nothing
   here depends on a particular machine; the Aquarius+, NC200 and Z88 builds
   differ only in the platform file they link.

   Layout: the top third of the screen is the status panel, the rest is the map.
   Platforms that can show the real tile graphics (plat_has_tiles) draw the
   map from view_fetch(), the engine's view_cell routine verified against the
   Spectrum's own rendering; the others draw a character per cell with glyph().
   ------------------------------------------------------------------------ */
#include <stdint.h>
#include <string.h>
#include "engine.h"
#include "platform.h"
#include "text.h"
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
static uint8_t redraw;                  /* the screen was overwritten: draw everything again */
static uint8_t power_nuclear;           /* what the power plant tool builds */
/* Everything the status panel shows, to tell when it needs redrawing. */
struct status {
    uint32_t money, pop;
    int16_t rv, cv, iv;
    uint16_t year;
    uint8_t month, tool, speed, alert, page;
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
static uint16_t shadow[MAX_VIEW_W * MAX_VIEW_H];    /* what is on the screen: 0 = unknown */

/* ---- small helpers ----------------------------------------------------- */
static uint32_t money(void)
{
    return (uint32_t)V_money[0] | ((uint32_t)V_money[1] << 8) | ((uint32_t)V_money[2] << 16);
}

static uint32_t citypop(void)
{
    return (uint32_t)V_CityPop[0] | ((uint32_t)V_CityPop[1] << 8) | ((uint32_t)V_CityPop[2] << 16);
}

static uint8_t put_number(char *buf, uint32_t v)
{
    char tmp[11];
    uint8_t n = 0, i;
    if (v == 0) {
        buf[0] = '0';
        return 1;
    }
    while (v) {
        tmp[n++] = (char)('0' + (uint8_t)(v % 10));
        v /= 10;
    }
    for (i = 0; i < n; ++i)
        buf[i] = tmp[n - 1 - i];
    return n;
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
        plat_puts(panel_col, (uint8_t)(panel_row + row), buf);
}

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

/* Draw one cell of the view, unless it already shows the right thing. */
static void draw_cell(uint8_t cx, uint8_t cy)
{
    uint8_t mx = (uint8_t)(origin_x + cx), my = (uint8_t)(origin_y + cy);
    uint8_t cursor = (mx == cur_x && my == cur_y && (frame & 4));
    uint16_t *s = &shadow[(uint16_t)cy * MAX_VIEW_W + cx];
    uint16_t g;

#ifdef HAVE_TILES
    view_x = mx;
    view_y = my;
    view_fetch();
    g = (uint16_t)(((uint16_t)(view_art - view_tile_art) >> 3) + 1) | (cursor ? 0x8000 : 0);
    if (*s != g) {
        *s = g;
        plat_put_tile(cx, (uint8_t)(map_row + cy), view_art, view_attr, cursor);
    }
#else
    g = glyph(mx, my);
    if (cursor)
        g = '@';                                /* blinking cursor */
    if (*s != g) {
        *s = g;
        plat_put(cx, (uint8_t)(map_row + cy), (uint8_t)g);
    }
#endif
}

/* Redraw the view.  Looking at every cell costs a lot (the engine works out each
   picture), so a full pass is made only when the view has moved.  Otherwise:
     dirty    the rows a tool has just changed (the engine set map_dirty)
     always   one row in turn, to pick up the simulation's work and the animation
     always   the cursor's cell, and the one it left */
static void draw_view(uint8_t full, uint8_t dirty)
{
    static uint8_t refresh_row;
    uint8_t cx, cy, rows_dirty;

    if (full) {
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
        if (last_cx < view_w && last_cy < view_h)
            draw_cell(last_cx, last_cy);
    }
    last_cx = (uint8_t)(cur_x - origin_x);
    last_cy = (uint8_t)(cur_y - origin_y);
    if (!full && last_cx < view_w && last_cy < view_h)
        draw_cell(last_cx, last_cy);
}

static void invalidate_view(void)
{
    uint16_t i;
    for (i = 0; i < MAX_VIEW_W * MAX_VIEW_H; ++i)
        shadow[i] = 0;
}

/* "R   |## " : a letter, three cells for shortfall, a bar, three cells for demand. */
static void demand_bar(char *b, char name, int16_t v)
{
    int16_t n = v / 32;
    uint8_t i;
    for (i = 0; i < 8; ++i)
        b[i] = ' ';
    b[0] = name;
    b[4] = '|';
    if (n > 3) n = 3;
    if (n < -3) n = -3;
    if (n > 0)
        for (i = 0; i < (uint8_t)n; ++i) b[5 + i] = '#';
    else
        for (i = 0; i < (uint8_t)(-n); ++i) b[3 - i] = '#';
}

static const char *const help_page[3] = {
    "O P Q A MOVE  SPACE BUILD",
    ", . TOOL  0-9 PICK  E POWER",
    "H PAUSE  + - SPEED  X QUIT",
};

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
    line(4, help_page[(frame >> 6) % 3], 0, 0);
}

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

static void handle_key(uint8_t k)
{
    switch (k) {
    case 'o': case KEY_LEFT:   move_cursor(-1, 0); break;
    case 'p': case KEY_RIGHT:  move_cursor(1, 0);  break;
    case 'q': case KEY_UP:     move_cursor(0, -1); break;
    case 'a': case KEY_DOWN:   move_cursor(0, 1);  break;
    case 'O': move_cursor(-8, 0); break;
    case 'P': move_cursor(8, 0);  break;
    case 'Q': move_cursor(0, -8); break;
    case 'A': move_cursor(0, 8);  break;
    case ' ': case KEY_ENTER:  apply_tool(); break;
    case ',': set_tool((uint8_t)(tool ? tool - 1 : NUM_TOOLS - 1)); break;
    case '.': set_tool((uint8_t)(tool + 1 < NUM_TOOLS ? tool + 1 : 0)); break;
    case 'e': power_nuclear = !power_nuclear; break;
    case 'h':
        V_simulation_speed = (V_simulation_speed == 3) ? 1 : 3;
        break;
    case '+':
        if (V_simulation_speed > 0 && V_simulation_speed < 3) --V_simulation_speed;
        break;
    case '-':
        if (V_simulation_speed < 2) ++V_simulation_speed;
        break;
    case 'x': case KEY_ESC: case CMD_QUIT: quit = 1; break;
    case CMD_NEW_CITY:         restart = quit = 1; break;
    case CMD_PAUSE:            V_simulation_speed = (V_simulation_speed == 3) ? 1 : 3; break;
    case CMD_SPEED_FAST:       V_simulation_speed = 0; break;
    case CMD_SPEED_NORMAL:     V_simulation_speed = 1; break;
    case CMD_SPEED_SLOW:       V_simulation_speed = 2; break;
    case CMD_POWER_COAL:       power_nuclear = 0; break;
    case CMD_POWER_NUCLEAR:    power_nuclear = 1; break;
    case CMD_DISASTERS_ON:     V_disaster_reset = 0; break;
    case CMD_DISASTERS_OFF:    V_disaster_reset = 1; break;
    case CMD_AUTOBULLDOZE_ON:  V_auto_bulldoze = 1; break;
    case CMD_AUTOBULLDOZE_OFF: V_auto_bulldoze = 0; break;
    case CMD_REDRAW:           redraw = 1; break;
    default:
        if (k >= '0' && k <= '9')
            set_tool((uint8_t)(k - '0'));
        else if (k >= CMD_TOOL && k < CMD_TOOL + NUM_TOOLS)
            set_tool((uint8_t)(k - CMD_TOOL));
        break;
    }
}

/* ---- start-up ----------------------------------------------------------------- */
static void choose_layout(void)
{
    cols = plat_cols();
    rows = plat_rows();
    view_w = cols < MAX_VIEW_W ? cols : MAX_VIEW_W;
    view_h = (uint8_t)(rows - rows / 3);            /* the map takes the bottom two thirds */
    if (view_h > MAX_VIEW_H)
        view_h = MAX_VIEW_H;
    map_row = (uint8_t)(rows - view_h);
    panel_col = panel_row = 0;                      /* the status panel, the top third */
    panel_w = cols;
    panel_h = map_row;
}

static void title_screen(void)
{
    uint16_t seed = 0;
    uint8_t k;

    plat_clear();
    plat_puts(0, 0, "S I M C I T Y");
    plat_puts(0, 2, "CHOOSE A LEVEL:  1 EASY  2 MEDIUM  3 HARD");
    plat_flush();
    do {
        seed++;
        k = plat_key();
        if (!k)
            plat_idle();
    } while (k != '1' && k != '2' && k != '3');
    V_difficulty = (uint8_t)(k - '1');
    V_InitialSeed = (uint16_t)(seed ^ plat_clock()) | 1;
    plat_clear();
    plat_puts(0, 0, "GENERATING LANDSCAPE...");
    plat_flush();
}

/* One city, from the title screen until it is quit or replaced. */
static void play_city(void)
{
    uint8_t k, countdown, ticking = 0, full, last_ox = 0, last_oy = 0;
    struct status st, last_st;

    title_screen();

    V_auto_budget = 1;
    V_auto_bulldoze = 1;
    V_disaster_reset = 0;
    V_simulation_speed = 1;
    SMC_tax_rate = 7;
    SMC_transport_percent = SMC_police_percent = SMC_fire_percent = 100;
    sim_new_city();

    cur_x = cur_y = MAP_W / 2;
    origin_x = (uint8_t)(cur_x - view_w / 2);
    origin_y = (uint8_t)(cur_y - view_h / 2);
    tool = 1;
    clamp_view();
    plat_clear();
    invalidate_view();
    last_cx = 255;                          /* draw the whole view on the first frame */
    countdown = tick_frames[V_simulation_speed];
    memset(&st, 0, sizeof(st));
    memset(&last_st, 0xFF, sizeof(last_st));          /* nothing drawn yet */

    while (!quit) {
        k = plat_key();
        if (k)
            handle_key(k);

        /* The simulation runs in slices (one map row each) so that the UI stays
           responsive: a tick is started every tick_frames[] frames, then advanced
           SLICES_PER_FRAME rows per frame until it completes. */
        if (tick_frames[V_simulation_speed]) {
            if (ticking) {
                for (k = 0; k < SLICES_PER_FRAME; ++k)
                    if (sim_step()) {
                        ticking = 0;
                        countdown = tick_frames[V_simulation_speed];
                        break;
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
        if (redraw) {                       /* OZ drew over us: start the screen again */
            redraw = 0;
            plat_clear();
            invalidate_view();
            memset(&last_st, 0xFF, sizeof(last_st));
            last_cx = 255;
        }
        full = origin_x != last_ox || origin_y != last_oy || last_cx == 255;
        last_ox = origin_x;
        last_oy = origin_y;
        draw_view(full, map_dirty);

        /* the status panel only when something it shows has changed */
        st.money = money();
        st.pop = citypop();
        st.year = V_year;
        st.rv = V_RValve;
        st.cv = V_CValve;
        st.iv = V_IValve;
        st.month = V_month;
        st.tool = tool;
        st.speed = V_simulation_speed;
        st.alert = V_alertmessage;
        st.page = (uint8_t)((frame >> 6) % 3);
        if (memcmp(&st, &last_st, sizeof(st))) {
            last_st = st;
            draw_status();
        }
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
