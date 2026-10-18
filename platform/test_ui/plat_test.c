/* ------------------------------------------------------------------------
   Headless platform for the game core: a character screen in RAM and a
   scripted keyboard.  Built for z88dk's +test target and run under
   z88dk-ticks by test/ui/run.py, which reads test_screen back from memory.
   ------------------------------------------------------------------------ */
#include <stdint.h>
#include "platform.h"

/* Two shapes.  The default is one 64x24 screen with the status in its top third.  With
   TEST_PANEL the console is a 32x8 map, like the Z88's, and the text has a window of its own
   (51x8) that the game draws the title and the status panel in. */
#ifdef TEST_PANEL
#define COLS 32
#define ROWS 8
#define TEXT_COLS 51
#define TEXT_ROWS 8
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

void plat_clear(void)
{
    uint8_t r, c;
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
uint8_t plat_has_text_window(void) { return 1; }
uint8_t plat_text_cols(void) { return TEXT_COLS; }
uint8_t plat_text_rows(void) { return TEXT_ROWS; }

void plat_text_clear(void)
{
    uint8_t r, c;
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
uint8_t plat_has_text_window(void) { return 0; }
uint8_t plat_text_cols(void) { return COLS; }
uint8_t plat_text_rows(void) { return ROWS; }
void plat_text_clear(void) { plat_clear(); }
void plat_text_puts(uint8_t col, uint8_t row, const char *s) { plat_puts(col, row, s); }
#endif

#ifdef TEST_SPRITES
/* With TEST_SPRITES the game draws the map from pictures, which the test reads back from test_bitmap. */
uint8_t plat_has_tiles(void) { return 1; }
extern uint8_t test_bitmap[ROWS][COLS][8];
void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    uint8_t i;
    (void)attr;
    if (col < COLS && row < ROWS)
        for (i = 0; i < 8; ++i)
            test_bitmap[row][col][i] = inverse ? (uint8_t)~art[i] : art[i];
}
#else
uint8_t plat_has_tiles(void) { return 0; }
void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    (void)col; (void)row; (void)art; (void)attr; (void)inverse;
}
#endif

#ifdef TEST_PANEL
uint8_t test_bitmap[ROWS][COLS][8];     /* what plat_put_bitmap drew in each cell */
uint8_t plat_has_bitmap(void) { return 1; }
void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art)
{
    uint8_t i;
    if (col < COLS && row < ROWS)
        for (i = 0; i < 8; ++i)
            test_bitmap[row][col][i] = art[i];
}
#else
uint8_t plat_has_bitmap(void) { return 0; }
void plat_put_bitmap(uint8_t col, uint8_t row, const uint8_t *art) { (void)col; (void)row; (void)art; }
#endif

uint16_t plat_clock(void) { return 0x1234; }
void plat_idle(void) { }
#ifdef TEST_PANEL
/* The mini map tests want something in the coverage maps, which a city has none of until it has run
   for a year.  After the new city is made (the first frames), fill them with a pattern. */
extern uint8_t minimaps[6912];
/* ...and the evaluation wants a city with people in it and some problems (unless a test turns it off). */
extern uint8_t V_display_population[3], V_population[3], V_prev_year_population[3], V_previous_city_score[3];
extern uint8_t V_TrafficAverage, V_PolluteAverage, V_concern_crime, V_concern_house_price;
extern uint16_t V_LVAverage, V_unemployment;
uint8_t test_poke_city = 1;
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
    if (++test_frames == 3) {
        for (i = 0; i < sizeof(minimaps); ++i)
            minimaps[i] = (uint8_t)(i * 37u + (i >> 8) * 11u) & (i < 1152 ? 15 : 255);   /* coverage is 0..15 */
        if (test_poke_city) {
            V_display_population[0] = V_population[0] = 0x88; V_display_population[1] = V_population[1] = 0x13;   /* 5000 */
            V_prev_year_population[0] = 0xA0; V_prev_year_population[1] = 0x0F;                                    /* 4000 */
            V_previous_city_score[0] = 0xA0; V_previous_city_score[1] = 0x0F;       /* assessed value 4000 thousand */
            V_TrafficAverage = 20; V_PolluteAverage = 20; V_concern_crime = 40;
            V_LVAverage = 2; V_concern_house_price = 4; V_unemployment = 0;
        }
    }
}
#else
void plat_flush(void) { ++test_frames; }
#endif
