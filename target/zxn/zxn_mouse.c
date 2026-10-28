/* ZX Spectrum Next: the pointer's own parts (the rest is target/common/pointer.c, with ptr_driver.h).  A Kempston mouse cannot be detected (its ports read as anything
   without one), so it is always read: with none the position does not change.  It is read by z88dk's in_MouseKemp, which keeps the position as 0..255 by 0..191 in the four
   variables below.  The pointer is hardware sprite 0, so nothing has to be drawn under it or put back; here too are the tool icons' places. */
#include <stdint.h>
#include <arch/zxn.h>
#include <arch/zx/zx_input.h>
#include "platform.h"
#include "engine.h"

#ifdef HAVE_MOUSE                               /* (plat_config.h: a build without the mouse has nothing here) */

extern void zxn_out(uint16_t port, uint8_t value);
extern void pointer_start(void);                /* (target/common/pointer.c) */

#define REG_PERIPHERAL_5 0x0A                   /* (z88dk has no name for it) bits 1 and 0: the mouse's DPI, 0 low, 1 the default, 2 medium, 3 high */

/* the variables in_MouseKemp needs (arch/zx/zx_input.h) */
uint8_t in_KempcoordX, in_KempcoordY, in_KemprawX, in_KemprawY;

static int16_t shown_x, shown_y;                /* where the sprite is, or -1 if it is hidden */

/* The arrow, 16x16, its tip at the top left: the rows of its black outline and its white fill, the leftmost pixel the top bit. */
static const uint16_t arrow_outline[16] = {
    0x8000, 0xC000, 0xA000, 0x9000, 0x8800, 0x8400, 0x8200, 0x8100, 0x8080, 0x8040, 0x83E0, 0x9200, 0xA900, 0xC900, 0x8480, 0x0700
};
static const uint16_t arrow_fill[16] = {
    0x0000, 0x0000, 0x4000, 0x6000, 0x7000, 0x7800, 0x7C00, 0x7E00, 0x7F00, 0x7F80, 0x7C00, 0x6C00, 0x4600, 0x0600, 0x0300, 0x0000
};
#define PEN_BLACK   1                           /* (the sprite palette's entries it uses) */
#define PEN_WHITE   2
#define PEN_CLEAR   0xE3                        /* (the transparent index the Next starts with) */

/* The screen's pixel (0,0) is the sprites' (32,32). */
#define SPRITE_ORIGIN 32

static void sprite_define(void)
{
    uint8_t row, col, pen, saved;
    uint16_t bit;

    saved = ZXN_READ_REG(REG_PALETTE_CONTROL);  /* two pens in the first sprite palette (the Layer 2 palette is written the same way) */
    ZXN_NEXTREGA(REG_PALETTE_CONTROL, (uint8_t)((saved & 0x0F) | RPC_SELECT_SPRITES_PALETTE_0));
    ZXN_NEXTREG(REG_PALETTE_INDEX, PEN_BLACK);
    ZXN_NEXTREG(REG_PALETTE_VALUE_8, 0x00);
    ZXN_NEXTREG(REG_PALETTE_INDEX, PEN_WHITE);
    ZXN_NEXTREG(REG_PALETTE_VALUE_8, 0xFF);
    ZXN_NEXTREGA(REG_PALETTE_CONTROL, saved);

    zxn_out(0x303B, 0);                         /* pattern 0 (and sprite 0) */
    for (row = 0; row < 16; ++row)
        for (col = 0, bit = 0x8000; col < 16; ++col, bit >>= 1) {
            pen = (arrow_fill[row] & bit) ? PEN_WHITE : (arrow_outline[row] & bit) ? PEN_BLACK : PEN_CLEAR;
            zxn_out(0x5B, pen);
        }
    ZXN_NEXTREGA(REG_SPRITE_LAYER_SYSTEM, (uint8_t)(ZXN_READ_REG(REG_SPRITE_LAYER_SYSTEM) | RSLS_SPRITES_VISIBLE));
}

/* Put sprite 0 at screen pixel (x,y), or hide it with x < 0. */
static void sprite_at(int16_t x, int16_t y)
{
    uint16_t sx = (uint16_t)(x + SPRITE_ORIGIN);

    zxn_out(0x303B, 0);
    zxn_out(0x57, (uint8_t)sx);                 /* x, low 8 bits */
    zxn_out(0x57, (uint8_t)(y + SPRITE_ORIGIN));
    zxn_out(0x57, (uint8_t)(sx >> 8));          /* no palette offset or mirrors; the x's top bit */
    zxn_out(0x57, x < 0 ? 0x00 : 0x80);         /* visible, pattern 0 */
}

/* The pointer starts in the middle of the map, with the mouse at its default DPI (left as it was, it can be far too quick). */
void plat_mouse_init(void)
{
    uint8_t p5 = ZXN_READ_REG(REG_PERIPHERAL_5);

    ZXN_NEXTREGA(REG_PERIPHERAL_5, (uint8_t)((p5 & ~3) | 1));
    sprite_define();
    in_MouseKempInit();                         /* (reads once, to drop what the mouse has counted) */
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
    if (shown_x >= 0) {
        sprite_at(-1, 0);
        shown_x = -1;
    }
}

/* The tool icon under the pointer (0 to 13), or $FF: they are 22x20 pixels, 23 apart across and 20 down, in two rows of seven from y=8 (plat_icons). */
uint8_t plat_mouse_icon_hit(void)
{
    uint8_t x = (uint8_t)plat_mouse_x, y = (uint8_t)plat_mouse_y;

    if (y < 8 || y >= 48 || x >= 161)
        return 0xFF;
    return (uint8_t)((y >= 28 ? 7 : 0) + x / 23);
}

#endif /* HAVE_MOUSE */
