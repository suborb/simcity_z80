/* NEC PC-6001mkII platform: the 320x200 bitmap (plat_pc6001mk2.asm draws the cells and the text), the keys and the frame timer, which are interrupts (plat_irq.asm). */
#include <stdint.h>
#include "platform.h"

extern void pc_mode_bitmap(void);
extern void pc_irq_init(void);
extern uint8_t pc_key_take(void);
extern uint16_t pc_ticks(void);
extern void pc_wait_frame(void);
extern uint8_t mk_cache[];                      /* the placer's byte for each cell: the number of the picture it shows, or $FF (plat_pc6001mk2.asm) */

void plat_init(void)
{
    pc_mode_bitmap();
    plat_clear();
    plat_overlay_load(0);                       /* the game overlay, from the disc (before interrupts are on) */
    pc_irq_init();
}

void plat_exit(void) { }
void plat_flush(void) { }


/* The tool icons: 16x16 pictures of four cells (the art, then each cell's colour byte); the one selected is inverted, a tool there is no money for is thinned to a checkerboard. */
#define NUM_ICONS 14
extern const uint8_t mk_icons[];
static uint16_t afford = 0xFFFF;

void plat_afford(uint16_t mask) { afford = mask; }

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, k, cell, state;
    const uint8_t *art;
    uint8_t thin[8];

    for (i = 0; i < NUM_ICONS; ++i) {
        state = (uint8_t)(0xF0 | (i == selected) | (((afford >> i) & 1) << 1));
        if (mk_cache[40 + i * 2] == state)              /* (the icon's first cell says how it was drawn: the cache's $F0 and up are not pictures) */
            continue;
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                art = mk_icons + cell * 8;
                if (!((afford >> i) & 1)) {
                    for (k = 0; k < 8; ++k)
                        thin[k] = art[k] & ((k & 1) ? 0xAA : 0x55);
                    art = thin;
                }
                plat_put_tile((uint8_t)(i * 2 + c), (uint8_t)(1 + r), art, mk_icons[NUM_ICONS * 32 + cell], i == selected);
            }
        mk_cache[40 + i * 2] = state;
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
        mk_cache[(uint16_t)row * 40 + col + 1 + k] = 0xFF;
        plat_put_tile((uint8_t)(col + 1 + k), row, art, level < 0 ? COL_BAR_DOWN : COL_BAR_UP, 0);
    }
}

/* Keys: the sub-CPU's codes are ASCII, lower case for a letter and upper case with shift, and the cursor keys $1C-$1F (right, left, down, up as the ROM's table has them). */
#ifdef MK2_TEST_KEYS
/* A host test (z88dk-ticks has no interrupts): the keys are the character codes in MK2_TEST_KEYS (a list: -DMK2_TEST_KEYS=49,50), one every MK2_KEY_GAP calls of plat_key, then none. */
static const char test_keys[] = { MK2_TEST_KEYS, 0 };
static uint8_t test_pos;
static uint16_t test_calls;
#endif

uint8_t plat_key(void)
{
#ifdef MK2_TEST_KEYS
    if (++test_calls % MK2_KEY_GAP == 0 && test_keys[test_pos])
        return (uint8_t)test_keys[test_pos++];
    return 0;
#else
    uint8_t k = pc_key_take();

    switch (k) {
    case 0x1D: return KEY_LEFT;
    case 0x1C: return KEY_RIGHT;
    case 0x1F: return KEY_DOWN;
    case 0x1E: return KEY_UP;
    case 0x7F: return KEY_LEFT;                 /* (backspace) */
    }
    return k < 0x80 ? k : 0;                    /* (the function keys and the kana are not used) */
#endif
}

#ifdef MK2_TEST_KEYS
static uint16_t test_clock;
uint16_t plat_clock(void) { return test_clock; }
void plat_idle(void) { ++test_clock; }         /* (no timer interrupts under ticks) */
#else
uint16_t plat_clock(void) { return pc_ticks(); }

void plat_idle(void) { pc_wait_frame(); }
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
