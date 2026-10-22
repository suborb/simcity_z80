/* Mitsubishi Multi 8 platform: pictures and text are drawn by the placer in plat_multi8.asm, which also sets up
   the screen; this has the keyboard, the tool icons and the frame counter. */
#include <stdint.h>
#include "platform.h"

static uint16_t clock_count;

extern const uint8_t mp_icons[];

/* the 1 bit pictures in the colours of an attribute: the mini maps and the icons (plat_put_tile draws the map's pictures) */
extern void mp_tile1(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse);

#ifdef HAVE_MINIMAP_COLOUR
/* The mini maps: the city is its picture in white on black.  The other views are an intensity ramp in solid cells (ink
   and paper the same colour: the original's eight steps are the Spectrum's bright colours): black, blue, red, magenta,
   green, cyan, yellow and white.  Level 0 is the picture, as there is nothing to show. */
static const uint8_t minimap_colours[8] = { 7, 0x09, 0x12, 0x1B, 0x24, 0x2D, 0x36, 0x3F };

void plat_put_minimap(uint8_t col, uint8_t row, const uint8_t *art, uint8_t view, uint8_t level)
{
    uint8_t attr = 7;

    /* Density and coverage levels are 0..16 and 0..15 respectively, so halve them to get the 0..7 ramp index. */
    if (view != 1) {
        level >>= 1;
        if (level > 7)
            level = 7;
        attr = minimap_colours[level];
    }
    mp_tile1(col, row, art, attr, 0);
}
#endif

/* The tool icons: 16x16 pictures, four cells each. */
#define NUM_ICONS 14

void plat_icons(uint8_t selected)
{
    uint8_t i, r, c, cell;

    for (i = 0; i < NUM_ICONS; ++i)
        for (r = 0; r < 2; ++r)
            for (c = 0; c < 2; ++c) {
                cell = (uint8_t)(i * 4 + r * 2 + c);
                mp_tile1((uint8_t)(i * 2 + c), (uint8_t)(1 + r), mp_icons + cell * 8,
                         mp_icons[NUM_ICONS * 32 + cell], i == selected);
            }
}

/* The key presses plat_key hands out are the ones plat_multi8.asm saw going down (it looks after every cell it draws as
   well as here, so a short press during a redraw is not lost).  Codes are those of the Multi 8's keyboard:
   the cursor keys send $1C right, $1D left, $1E up and $1F down (shift is bit 7 of the flags), and the letters
   are capitals without shift. */
extern uint16_t mp_key(void);
static const uint8_t cursor_keys[8] = {
    KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_FAR_RIGHT, KEY_FAR_LEFT, KEY_FAR_UP, KEY_FAR_DOWN
};

uint8_t plat_key(void)
{
    uint16_t e = mp_key();
    uint8_t k = (uint8_t)e;

    if (k >= 0x1C && k <= 0x1F)
        return cursor_keys[(k - 0x1C) + ((e & 0x8000) ? 4 : 0)];
    if (k >= 'A' && k <= 'Z')
        k += 32;
    /* Only keys the game means: the shared code takes 0x81 and up as menu commands (disasters, new city, pause, quit...),
       so a function key, or a modifier on its own, must not get through as one; and the other control codes mean nothing */
    if (k >= 0x80 || (k < ' ' && k != KEY_LEFT && k != KEY_RIGHT && k != KEY_DOWN && k != KEY_UP && k != KEY_ENTER && k != KEY_ESC))
        return KEY_NONE;
    return k;
}

#ifdef HAVE_FILES
/* A city is saved to the cassette as two files, one after the other (z88dk's tape_save: the machine's own format, so
   the ordinary loaders can read them), and loaded from the first two files that come: a tape holds one city, so the
   name that is asked for is not kept.  The recorder is the player's: start it before the save's key press, and
   ESC gives up a load. */
extern int tape_save(const void *addr, uint16_t len) __smallc;
extern int tape_load_to(void *buf, uint16_t len) __smallc;

static uint8_t wait_key(void)
{
    uint8_t k;

    while (!(k = plat_key()))
        plat_idle();
    return k;
}

uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen)
{
    (void)name;
    plat_puts(0, 24, "RECORD, THEN PRESS A KEY");
    if (wait_key() == KEY_ESC)
        return 1;
    tape_save(a, alen);
    tape_save(b, blen);
    return 0;
}

uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen)
{
    (void)name;
    plat_puts(0, 24, "PLAY THE TAPE; ESC GIVES UP ");
    if ((uint16_t)tape_load_to(a, alen) != alen)
        return 1;
    return (uint16_t)tape_load_to(b, blen) == blen ? 0 : 2;
}

/* A tiny editor for file names, drawing with the placer. */
uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces)
{
    uint8_t n = 0, k;

    buf[0] = 0;
    for (;;) {
        k = wait_key();
        if (k == KEY_ENTER)
            return n != 0;
        if (k == KEY_ESC)
            return 0;
        if ((k == KEY_LEFT || k == 127) && n) {
            --n;
            plat_put((uint8_t)(col + n), row, ' ');
        } else if (k >= (spaces ? ' ' : '!') && k < 127 && n < max) {
            buf[n] = (char)k;
            plat_put((uint8_t)(col + n), row, k);
            ++n;
        }
        buf[n] = 0;
    }
}
#endif

uint16_t plat_clock(void) { return clock_count; }
void plat_idle(void) { ++clock_count; }
void plat_flush(void) {}
