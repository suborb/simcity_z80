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
uint8_t test_script[512] = { '2', 0 };
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
        return 'x';
    k = test_script[test_script_pos];
    if (k == 0xFF)                      /* end of script: quit */
        return 'x';
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

uint8_t plat_has_tiles(void) { return 0; }
void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse)
{
    (void)col; (void)row; (void)art; (void)attr; (void)inverse;
}

uint16_t plat_clock(void) { return 0x1234; }
void plat_idle(void) { }
void plat_flush(void) { ++test_frames; }
