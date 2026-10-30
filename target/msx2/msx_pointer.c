/* MSX2: the pointer's own parts (the rest is target/common/pointer.c, with ptr_driver.h).  The mouse is z88dk's in_MouseMSX, in a joystick connector (the library
   looks in both for one that answers); the keys that move the arrow are Q A O P and the cursor keys, Space or Enter its button, Shift for fast.  The arrow is two VDP
   sprites (16x16, one over the other: white, and its black outline under it), so nothing has to be drawn under it or put back; here too are the tool icons' places.
   This is resident code in page 3 (SIMCITY.HI). */
#include <stdint.h>
#include <string.h>
#include "platform.h"
#include "engine.h"
#include "ptr_driver.h"

#pragma codeseg CODE_HI

#ifdef HAVE_MOUSE                               /* (plat_config.h: a build without the mouse has nothing here) */

extern void pointer_start(void);                /* (target/common/pointer.c) */
extern void vram_write(uint16_t addr, const uint8_t *src, uint16_t len);
extern void msx_vreg(uint8_t reg, uint8_t value);
extern uint8_t msx_keyrow(uint8_t row);

#define RG1SAV      (*(volatile uint8_t *)0xF3E0)       /* the BIOS's copies of VDP registers 1 and 8 */
#define RG8SAV      (*(volatile uint8_t *)0xFFE7)
#define SAT         0x7600u                     /* the sprite tables of screen 5 (the BIOS's places, in the video RAM's unused lines): attributes (Y, X, pattern, 0), */
#define SCT         0x7400u                     /* colours (16 bytes a sprite: a line each), */
#define SPT         0x7800u                     /* and patterns */

static int16_t shown_x, shown_y;                /* where the sprite is, or -1 if it is hidden */

/* The arrow: 14 rows, a bit a column from the left (the tip is the top left) */
static const uint16_t arrow[14] = {
    0x8000, 0xC000, 0xE000, 0xF000, 0xF800, 0xFC00, 0xFE00, 0xFF00, 0xFF80, 0xF800, 0xDC00, 0x9C00, 0x1C00, 0x0C00
};

/* The patterns of a 16x16 sprite are four 8x8 ones: the left top, the left bottom, the right top, the right bottom */
static void pattern(uint8_t *dst, const uint16_t *rows)
{
    uint8_t r;

    for (r = 0; r < 8; ++r) {
        dst[r] = (uint8_t)(rows[r] >> 8);
        dst[8 + r] = (uint8_t)(rows[8 + r] >> 8);
        dst[16 + r] = (uint8_t)rows[r];
        dst[24 + r] = (uint8_t)rows[8 + r];
    }
}

/* The sprites: the arrow's fill is pattern 0 (white), its outline pattern 4 (colour 0, black, which sprites draw because TP is set); the fill is one row and one column
   into the 16x16 so that the outline has room, and the sprite is put one up and one left of the pointer's position. */
static void sprite_define(void)
{
    uint16_t fill[16], line[16];
    uint8_t pat[64], col[32], attr[12], r;

    memset(fill, 0, sizeof(fill));
    for (r = 0; r < 14; ++r)
        fill[r + 1] = arrow[r] >> 1;
    for (r = 0; r < 16; ++r) {                  /* the outline: the fill and the cells next to it */
        uint16_t o = fill[r] | (r ? fill[r - 1] : 0) | (r < 15 ? fill[r + 1] : 0);

        line[r] = o | (o << 1) | (o >> 1);
    }
    pattern(pat, fill);
    pattern(pat + 32, line);
    vram_write(SPT, pat, 64);
    memset(col, 15, 16);
    memset(col + 16, 0, 16);
    vram_write(SCT, col, 32);
    memset(attr, 0, sizeof(attr));
    attr[0] = attr[4] = attr[8] = 216;          /* (216 ends the list: none shown) */
    attr[6] = 4;
    vram_write(SAT, attr, 12);
    msx_vreg(5, 0xEF);                          /* where the tables are (the BIOS's values for screen 5) */
    msx_vreg(11, 0);
    msx_vreg(6, 0x0F);
    msx_vreg(1, (uint8_t)((RG1SAV & ~3) | 2));  /* 16x16 sprites, not magnified */
    msx_vreg(8, (uint8_t)((RG8SAV & ~2) | 0x20));       /* sprites on, and colour 0 drawn */
}

static void sprite_at(int16_t x, int16_t y)
{
    uint8_t a[8], sy = (uint8_t)(y - 2), sx = x ? (uint8_t)(x - 1) : 0;

    a[0] = a[4] = sy;
    a[1] = a[5] = sx;
    a[2] = 0;
    a[3] = 0;
    a[6] = 4;
    a[7] = 0;
    vram_write(SAT, a, 8);
}

/* Looks for the mouse (in both connectors), puts the pointer in the middle of the map and defines the arrow. */
void plat_mouse_init(void)
{
    in_MouseMSXInit(0);
    sprite_define();
    pointer_start();
    shown_x = -1;
}

/* The pointer, once a frame. */
void plat_mouse_pointer_refresh(void)
{
    if (plat_mouse_x != shown_x || plat_mouse_y != shown_y) {
        sprite_at(plat_mouse_x, plat_mouse_y);
        shown_x = plat_mouse_x;
        shown_y = plat_mouse_y;
    }
}

/* Hidden while a menu is up, which the keys use (the next refresh shows it again). */
void plat_mouse_pointer_hide(void)
{
    static const uint8_t end = 216;

    if (shown_x >= 0) {
        vram_write(SAT, &end, 1);
        shown_x = -1;
    }
}

/* The tool icon under the pointer (0 to 13), or $FF: they are 24 pixels wide and 16 high, in two rows of seven from y=8 (plat_icons). */
uint8_t plat_mouse_icon_hit(void)
{
    uint8_t x = (uint8_t)plat_mouse_x, y = (uint8_t)plat_mouse_y;

    if (y < 8 || y >= 40 || x >= 168)
        return 0xFF;
    return (uint8_t)((y >= 24 ? 7 : 0) + x / 24);
}

/* The keys that move the arrow, as target/common/pointer.c wants them: 1 left (O, or the cursor key), 2 right (P), 4 up (Q), 8 down (A), 16 fire (Space or Enter),
   32 fast (Shift). */
uint8_t plat_pointer_keys(void)
{
    uint8_t r2 = (uint8_t)~msx_keyrow(2), r4 = (uint8_t)~msx_keyrow(4), r6 = (uint8_t)~msx_keyrow(6), r7 = (uint8_t)~msx_keyrow(7), r8 = (uint8_t)~msx_keyrow(8);
    uint8_t k = 0;

    if ((r4 & 0x10) || (r8 & 0x10))
        k |= 1;
    if ((r4 & 0x20) || (r8 & 0x80))
        k |= 2;
    if ((r4 & 0x40) || (r8 & 0x20))
        k |= 4;
    if ((r2 & 0x40) || (r8 & 0x40))
        k |= 8;
    if ((r8 & 1) || (r7 & 0x80))
        k |= 16;
    if (r6 & 1)
        k |= 32;
    return k;
}

#endif /* HAVE_MOUSE */
