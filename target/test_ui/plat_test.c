/* ------------------------------------------------------------------------
   Headless platform for the game core: a character screen in RAM and a
   scripted keyboard.  Built for z88dk's +test target and run under
   z88dk-ticks by test/ui/run.py, which reads test_screen back from memory.
   ------------------------------------------------------------------------ */
#include <stdint.h>
#include "platform.h"

/* Three shapes.  The default is one 64x24 screen with the status in its top third.  With
   TEST_PANEL the console is a 32x8 map, like the Z88's, and the text has a window of its own
   (51x8) that the game draws the title and the status panel in.  TEST_HIRES_MINIMAP is the
   Aquarius+'s 40x25 bitmap display, used to check its taller map-window mini map. */
#ifdef TEST_PANEL
#define COLS 32
#define ROWS 8
#define TEXT_COLS 51
#define TEXT_ROWS 8
#elif defined(TEST_HIRES_MINIMAP)
#define COLS 40
#define ROWS 25
#else
#define COLS 64
#define ROWS 24
#endif

/* read by the test harness */
uint8_t test_screen[ROWS][COLS];
uint8_t test_frames;                    /* frames drawn so far */
uint8_t test_done;
#ifdef TEST_PANEL
uint8_t test_text[TEXT_ROWS][TEXT_COLS];    /* the separate text window */
#endif
uint16_t test_put_count;                /* plat_put calls: cells and characters drawn */

/* Keys fed to the game, one per frame; 0 = no key.  The harness patches this. */
uint8_t test_script[2048] = { '2', 0 };
uint16_t test_script_pos;

void plat_init(void) { }
void plat_exit(void) { test_done = 1; }
uint8_t plat_cols(void) { return COLS; }
uint8_t plat_rows(void) { return ROWS; }

uint16_t test_clears;                   /* how often the map console was cleared */
uint8_t test_cleared;                   /* plat_clear was called: in the panel build the game has made its city by then */

void plat_clear(void)
{
    uint8_t r, c;
    test_cleared = 1;
    ++test_clears;
    for (r = 0; r < ROWS; ++r)
        for (c = 0; c < COLS; ++c)
            test_screen[r][c] = ' ';
}

void plat_put(uint8_t col, uint8_t row, uint8_t ch)
{
    ++test_put_count;
    if (col < COLS && row < ROWS)
        test_screen[row][col] = ch;
}

void plat_puts(uint8_t col, uint8_t row, const char *s)
{
    while (*s && col < COLS)
        plat_put(col++, row, (uint8_t)*s++);
}

uint8_t plat_key(void)
{
    uint8_t k;
    if (test_script_pos >= sizeof(test_script))
        return CMD_QUIT;                /* not 'x': that leaves a mini map instead of quitting */
    k = test_script[test_script_pos];
    if (k == 0xFF)                      /* end of script: quit */
        return CMD_QUIT;
    ++test_script_pos;
    return k;
}

#ifdef TEST_PANEL
uint8_t plat_text_cols(void) { return TEXT_COLS; }
uint8_t plat_text_rows(void) { return TEXT_ROWS; }

#if defined(HAVE_FILES) || defined(HAVE_APPNAME)
/* The line editor of the headless platform: the keys of the script, ENTER to finish, ESC to cancel, delete or cursor
   left to take a letter back; the line is echoed in the text window. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k, i;
    char one[2];

    one[1] = 0;
    buf[0] = 0;
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER || k == KEY_ESC || k == CMD_QUIT) {
            buf[n] = 0;
            return k == KEY_ENTER ? n != 0 : k == KEY_ESC ? 0 : 2;
        }
        if ((k == KEY_LEFT || k == 127) && n)
            buf[--n] = 0;
        else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n++] = (char)k;
            buf[n] = 0;
        }
        for (i = 0; i < max + 1; ++i) {
            one[0] = i < n ? buf[i] : ' ';
            plat_text_puts((uint8_t)(col + i), row, one);
        }
    }
}
#endif

uint16_t test_text_clears;               /* how often the whole text window was cleared */

void plat_text_clear(void)
{
    uint8_t r, c;
    ++test_text_clears;
    for (r = 0; r < TEXT_ROWS; ++r)
        for (c = 0; c < TEXT_COLS; ++c)
            test_text[r][c] = ' ';
}

void plat_text_puts(uint8_t col, uint8_t row, const char *s)
{
    while (*s && col < TEXT_COLS) {
        if (row < TEXT_ROWS)
            test_text[row][col] = (uint8_t)*s;
        ++col;
        ++s;
    }
}
#else
uint8_t plat_text_cols(void) { return COLS; }
uint8_t plat_text_rows(void) { return ROWS; }
void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }
#endif

#ifdef HAVE_APPNAME
char test_app_name[16];                  /* what the game last told the machine the city is called */
void plat_set_name(const char *name)
{
    uint8_t i;
    for (i = 0; i < 15 && name[i]; ++i)
        test_app_name[i] = name[i];
    test_app_name[i] = 0;
}
#endif

#ifdef HAVE_SOUND
uint8_t sound_enabled = 1;               /* the game's Sound option */
#endif

#ifdef HAVE_ICONS
uint8_t test_icons_selected = 255;      /* the tool plat_icons() was last asked to highlight */
uint16_t test_icons_calls;
void plat_icons(uint8_t selected) { test_icons_selected = selected; ++test_icons_calls; }
#endif

#ifdef HAVE_TILES
/* With TEST_SPRITES the game draws the map from pictures, which the test reads back from test_bitmap. */
extern uint8_t test_bitmap[ROWS][COLS][8];
void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint8_t i;
    (void)attr;
    if (col < COLS && row < ROWS)
        for (i = 0; i < 8; ++i)
            test_bitmap[row][col][i] = inverse ? (uint8_t)~art[i] : art[i];
}
#endif

#ifdef HAVE_FILES
/* One file in memory, for the save and load tests.  The headless image is already close to the 64 KB
   a Z80 can address, so of the map it keeps only the rows the tests change (3600..6000, the middle). */
#define KEEP_FROM 3600
#define KEEP_TO   6000
uint8_t test_file[31 + KEEP_TO - KEEP_FROM];
char test_file_name[32];
uint16_t test_file_len;

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    uint16_t i;
    for (i = 0; i < 31 && name[i]; ++i)
        test_file_name[i] = name[i];
    test_file_name[i] = 0;
    for (i = 0; i < alen; ++i)
        test_file[i] = a[i];
    for (i = KEEP_FROM; i < KEEP_TO && i < blen; ++i)
        test_file[alen + i - KEEP_FROM] = b[i];
    test_file_len = alen + blen;
    return 0;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    uint16_t i;
    for (i = 0; name[i] || test_file_name[i]; ++i)
        if (name[i] != test_file_name[i])
            return 1;                           /* no such file */
    if (test_file_len < alen)
        return 1;
    for (i = 0; i < alen; ++i)
        a[i] = test_file[i];
    for (i = KEEP_FROM; i < KEEP_TO && i < blen; ++i)
        b[i] = test_file[alen + i - KEEP_FROM];
    return test_file_len < alen + blen ? 2 : 0;
}
#endif

#ifdef HAVE_BITMAP
uint8_t test_bitmap[ROWS][COLS][8];     /* what plat_put_bitmap drew in each cell */
void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    uint8_t i;
    if (col < COLS && row < ROWS)
        for (i = 0; i < 8; ++i)
            test_bitmap[row][col][i] = art[i];
}
#endif

uint16_t plat_clock(void) { return 0x1234; }
void plat_idle(void) { }
#if defined(TEST_PANEL) || defined(TEST_HIRES_MINIMAP)
/* The mini map tests want something in the coverage maps, which a city has none of until it has run
   for a year.  After the new city is made (the first frames), fill them with a pattern. */
extern uint8_t minimaps[6912];
/* ...and the evaluation wants a city with people in it and some problems (unless a test turns it off). */
extern uint8_t V_display_population[3], V_population[3], V_prev_year_population[3], V_previous_city_score[3];
extern uint8_t V_TrafficAverage, V_PolluteAverage, V_concern_crime, V_concern_house_price;
extern uint16_t V_LVAverage, V_unemployment;
uint8_t test_poke_city = 1;
extern uint8_t levelmap[9216];
#ifdef TEST_SPRITES
extern uint8_t V_transport_active, V_transport_pos[2], V_transport_sprite;
extern uint8_t V_aircrash_active, V_CrashXY[2];
uint8_t test_poke_sprites = 1;
#endif
void plat_flush(void)
{
    uint16_t i;
#ifdef TEST_SPRITES
    if (test_poke_sprites && test_frames >= 3) {        /* the engine moves or removes them: put them back each frame */
        V_transport_active = 1; V_transport_pos[0] = 40; V_transport_pos[1] = 46; V_transport_sprite = 3;
        V_aircrash_active = 1; V_CrashXY[0] = 36; V_CrashXY[1] = 45;
    }
#endif
    ++test_frames;
    if (test_cleared == 1) {                    /* the first frame of the city is drawn: put the figures in */
        test_cleared = 2;
        for (i = 0; i < sizeof(minimaps); ++i)
            minimaps[i] = (uint8_t)(i * 37u + (i >> 8) * 11u) & (i < 1152 ? 15 : 255);   /* coverage is 0..15 */
        if (test_poke_city) {
            V_display_population[0] = V_population[0] = 0x88; V_display_population[1] = V_population[1] = 0x13;   /* 5000 */
            V_prev_year_population[0] = 0xA0; V_prev_year_population[1] = 0x0F;                                    /* 4000 */
            V_previous_city_score[0] = 0xA0; V_previous_city_score[1] = 0x0F;       /* assessed value 4000 thousand */
            V_TrafficAverage = 20; V_PolluteAverage = 20; V_concern_crime = 40;
            V_LVAverage = 2; V_concern_house_price = 4; V_unemployment = 0;
            for (i = 40; i < 60; ++i) {                 /* a road, houses and a large zone's pieces, for the maps of them */
                levelmap[42 * 96 + i] = 7;
                levelmap[44 * 96 + i] = 60;
                levelmap[46 * 96 + i] = 0x81;
            }
        }
    }
}
#else
/* The plain build: once the new city exists, the engine's finished population is 5000 (its running total stays 0
   without a tick), so that a test can see which of the two the status panel shows. */
extern uint8_t V_display_population[3];
void plat_flush(void)
{
    if (++test_frames == 3) {
        V_display_population[0] = 0x88;
        V_display_population[1] = 0x13;
    }
}
#endif
