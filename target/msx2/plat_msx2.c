/* The MSX2's parts of the V9938 platform (target/common/v9938/plat_v9938.c): the BIOS's screen modes, palette and key click, its frame counter, and the keyboard (the PPI's
   matrix: msx_keyrow, in msx_io.asm). */
#include <stdint.h>
#include <msx.h>
#include "platform.h"
#include "engine.h"

extern void v9938_vreg(uint8_t reg, uint8_t value);
extern void v9938_pal(const uint8_t *entries);
extern void msx_psg15(uint8_t value);
extern uint8_t msx_keyrow(uint8_t row);
extern void msx_print(const char *dollar_string);
extern void msx_bye(void);                      /* (msx_bank.asm) page 2 back as DOS had it, and out */

#define JIFFY       (*(volatile uint16_t *)0xFC9E)  /* the MSX BIOS's frame counter */
#define CLIKSW      (*(volatile uint8_t *)0xF3DB)   /* the BIOS's key click switch: its interrupt scans the keyboard and clicks for a key */
#define RG8SAV      (*(volatile uint8_t *)0xFFE7)   /* the BIOS's copies of VDP registers 8 and 9 */
#define RG9SAV      (*(volatile uint8_t *)0xFFE8)

static uint16_t clock_count;
static uint8_t saved_r9;
static uint8_t saved_click;
static uint8_t pace;                            /* the passes since the 60 Hz display's extra frame */

/* The MSX2 BIOS's palette, for the text screen DOS comes back to (red and blue, then green) */
static const uint8_t bios_palette[32] = {
    0x00, 0, 0x00, 0, 0x11, 6, 0x33, 7, 0x17, 1, 0x27, 3, 0x51, 1, 0x27, 6,
    0x71, 1, 0x73, 3, 0x61, 6, 0x64, 6, 0x11, 4, 0x65, 2, 0x55, 5, 0x77, 7
};

void v9938_fatal(const char *dollar_string)
{
    msx_print(dollar_string);                   /* DOS function 9 */
    msx_bye();
}

void v9938_screen5(void)
{
    saved_r9 = RG9SAV;
    saved_click = CLIKSW;
    CLIKSW = 0;                                 /* (the game reads the keys itself) */
    msx_screen(5);
    v9938_vreg(9, (uint8_t)(RG9SAV & 0x7F));    /* 192 lines (and PAL or NTSC as the machine has it) */
    v9938_vreg(8, (uint8_t)(RG8SAV | 2));       /* no sprites */
}

void v9938_leave(void)
{
#ifdef HAVE_MOUSE
    msx_psg15(0xCF);                            /* (the mouse's strobe low, port 1, as the BIOS has it) */
#endif
    CLIKSW = saved_click;
    v9938_vreg(14, 0);
    v9938_vreg(9, saved_r9);
    v9938_pal(bios_palette);
    msx_screen(0);
}

uint16_t plat_clock(void) { return clock_count; }
/* Once a pass of the game's loop, which waits for the next frame interrupt (the BIOS counts them in JIFFY).  The game is timed for 50 frames a second: on a 60 Hz
   display (R#9's NT bit clear) every fifth pass waits a second frame, which makes 5 passes in 6 frames, 50 a second. */
void plat_idle(void)
{
    uint16_t j = JIFFY;

    ++clock_count;
    while (JIFFY == j)
        ;
    if (!(saved_r9 & 2) && ++pace == 5) {
        pace = 0;
        j = JIFFY;
        while (JIFFY == j)
            ;
    }
}
void plat_flush(void) {}

/* The keyboard is resident in page 3 (SIMCITY.HI), with the rest of the code the UI's bank calls into */
PLAT_CODE_HIGH

/* ---- the keyboard ------------------------------------------------------------------------------------------------------------- */
/* The MSX matrix: PPI row 0 to 8, a key down is a 0 bit (bit 0 first).  Row 6 has SHIFT (bit 0), CTRL, GRAPH, CAPS, CODE and F1 to F3. */
static const uint8_t keys[9][8] = {
    { '0', '1', '2', '3', '4', '5', '6', '7' },
    { '8', '9', '-', '=', '\\', '[', ']', ';' },
    { '\'', '`', ',', '.', '/', 0, 'a', 'b' },
    { 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j' },
    { 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r' },
    { 's', 't', 'u', 'v', 'w', 'x', 'y', 'z' },
    { 0, 0, 0, 0, 0, 0, 0, 0 },
    { 0, 0, KEY_ESC, 0, KEY_ESC, 127, 0, KEY_ENTER },
    { ' ', 0, 0, 127, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_RIGHT }
};

static uint8_t held;                            /* the code of the key that is down, or 0 */
static uint8_t held_for;                        /* the looks it has been down for */

/* The key down now (the first in the matrix), as the game's code: letters lower case, a capital with SHIFT, SHIFT with a cursor key the eight cell move. */
static uint8_t scan(void)
{
    uint8_t row, bits, col, k = 0, shift;

    shift = !(msx_keyrow(6) & 1);
    for (row = 0; row < 9 && !k; ++row) {
        if (row == 6)
            continue;
        bits = (uint8_t)~msx_keyrow(row);
        for (col = 0; col < 8 && !k; ++col)
            if (bits & (1 << col))
                k = keys[row][col];
    }
    if (!k)
        return 0;
    if (shift) {
        switch (k) {
        case KEY_LEFT: return KEY_FAR_LEFT;
        case KEY_RIGHT: return KEY_FAR_RIGHT;
        case KEY_UP: return KEY_FAR_UP;
        case KEY_DOWN: return KEY_FAR_DOWN;
        case '=': return '+';
        }
        if (k >= 'a' && k <= 'z')
            k = (uint8_t)(k - 32);
    }
    return k;
}

/* A key registers when it goes down; a cursor key (or Q, A, O or P) repeats after 12 looks, then every 3 */
#ifdef HAVE_POINTER
uint8_t plat_keyboard_key(void)                 /* (target/common/pointer.c makes plat_key and plat_key_game of it) */
#else
uint8_t plat_key(void)
#endif
{
    uint8_t k = scan();

    if (k != held) {
        held = k;
        held_for = 0;
        return k;
    }
    if (!k || ++held_for < 12)
        return 0;
    if (k == KEY_LEFT || k == KEY_RIGHT || k == KEY_UP || k == KEY_DOWN || k == KEY_FAR_LEFT || k == KEY_FAR_RIGHT || k == KEY_FAR_UP || k == KEY_FAR_DOWN ||
        k == 'q' || k == 'a' || k == 'o' || k == 'p' || k == 'Q' || k == 'A' || k == 'O' || k == 'P') {
        held_for = 9;
        return k;
    }
    held_for = 12;
    return 0;
}
