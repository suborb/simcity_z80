/* Sharp MZ-800 platform: the 320x200 bitmap (plat_mz800.asm draws the cells and the text), the keys and the frame timer (plat_input.asm: polled, there are no interrupts). */
#include <stdint.h>
#include "platform.h"

extern void mz_mode_bitmap(void);
extern uint8_t mz_key_scan(void);
extern uint16_t mz_ticks(void);
extern void mz_wait_frame(void);
extern uint8_t mz_cache[];                      /* the placer's byte for each cell: the number of the picture it shows, or $FF (plat_mz800.asm) */

void plat_init(void)
{
    mz_mode_bitmap();
    plat_clear();
}

void plat_exit(void) { }
void plat_flush(void) { }


/* The tool icons: 16x16 pictures of four cells (the art, then each cell's colour byte); the one selected is inverted, a tool there is no money for is thinned to a checkerboard. */
#define NUM_ICONS 14
extern const uint8_t mz_icons[];
static uint16_t afford = 0xFFFF;

void plat_afford(uint16_t mask) { afford = mask; }

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, k, cell, state;
    const uint8_t *art;
    uint8_t thin[8];

    for (i = 0; i < NUM_ICONS; ++i) {
        state = (uint8_t)(0xF0 | (i == selected) | (((afford >> i) & 1) << 1));
        if (mz_cache[40 + i * 2] == state)              /* (the icon's first cell says how it was drawn: the cache's $F0 and up are not pictures) */
            continue;
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                art = mz_icons + cell * 8;
                if (!((afford >> i) & 1)) {
                    for (k = 0; k < 8; ++k)
                        thin[k] = art[k] & ((k & 1) ? 0xAA : 0x55);
                    art = thin;
                }
                plat_put_tile((uint8_t)(i * 2 + c), (uint8_t)(1 + r), art, mz_icons[NUM_ICONS * 32 + cell], i == selected);
            }
        mz_cache[40 + i * 2] = state;
    }
}

/* The demand: a letter and seven cells of bar, 56 pixels, the zero mark at pixel 27, `level` pixels to the right in yellow (demand) or to the left in red (a shortfall) over blue.
   A cell is drawn from a buffer that changes, so the placer's cache is told it holds nothing first. */
#define COL_BAR_UP   (1 | (2 << 2))     /* pen 1 (yellow) on pen 2 (blue) */
#define COL_BAR_DOWN (3 | (2 << 2))     /* pen 3 (red) on blue */

void plat_demand(uint8_t col, uint8_t row, char name, int8_t level)
{
    uint8_t k, b, x, fill;
    uint8_t art[8];

    plat_put(col, row, (uint8_t)name);
    for (k = 0; k < 7; ++k) {
        fill = 0;
        for (b = 0; b < 8; ++b) {
            x = (uint8_t)(8 * k + b);
            if (x == 27 || (level > 0 ? x > 27 && x <= 27 + level : level < 0 && x < 27 && x >= 27 + level))
                fill |= (uint8_t)(0x80 >> b);
        }
        art[0] = art[7] = 0;
        art[1] = art[2] = art[3] = art[4] = art[5] = art[6] = fill;
        mz_cache[(uint16_t)row * 40 + col + 1 + k] = 0xFF;
        plat_put_tile((uint8_t)(col + 1 + k), row, art, level < 0 ? COL_BAR_DOWN : COL_BAR_UP, 0);
    }
}

/* Keys: mz_key_scan() (plat_input.asm) scans the 8255's matrix and returns the code of the key that is newly down, or is repeating (the matrix has no ASCII: its table gives letters
   as upper case with shift and lower case without, the cursor keys and DEL/INS/BREAK as the codes below).  The cursor keys' codes are the game's. */
#ifdef MZ_TEST_KEYS
/* A host test: the keys are the character codes in MZ_TEST_KEYS (a list: -DMZ_TEST_KEYS=49,50), one every MZ_KEY_GAP calls of plat_key, then none. */
static const char test_keys[] = { MZ_TEST_KEYS, 0 };
static uint8_t test_pos;
static uint16_t test_calls;
#endif

uint8_t plat_key(void)
{
#ifdef MZ_TEST_KEYS
    if (++test_calls % MZ_KEY_GAP == 0 && test_keys[test_pos])
        return (uint8_t)test_keys[test_pos++];
    return 0;
#else
    return mz_key_scan();
#endif
}

#ifdef MZ_TEST_KEYS
static uint16_t test_clock;
uint16_t plat_clock(void) { return test_clock; }
void plat_idle(void) { ++test_clock; }
#else
uint16_t plat_clock(void) { return mz_ticks(); }

void plat_idle(void) { mz_wait_frame(); }
#endif

/* The line editor: ENTER ends, ESC cancels, backspace takes a letter back. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k;

    buf[0] = 0;
    for (;;) {
        k = plat_key();
        if (!k) {
            plat_idle();
            continue;
        }
        if (k == KEY_ENTER)
            return n != 0;
        if (k == KEY_ESC)
            return 0;
        if ((k == KEY_LEFT || k == 8) && n) {
            buf[--n] = 0;
            plat_put((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n++] = (char)k;
            buf[n] = 0;
            plat_put((uint8_t)(col + n - 1), row, k);
        }
    }
}
