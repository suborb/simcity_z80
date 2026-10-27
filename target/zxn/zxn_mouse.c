/* ZX Spectrum Next: the pointer.  The arrow is always there (HAVE_POINTER): the keys move it (plat_pointer_keys: Q A O P, the cursor keys; Space or Enter is its
   button), and so does a Kempston mouse, whose steps are added.  A Kempston mouse cannot be detected (its ports read as anything without one), so it is always read: with
   none the position does not change.  The mouse is read by z88dk's in_MouseKemp, which keeps the position as 0..255 by 0..191 in the four variables below.  The pointer
   takes the city's cursor over the map, a click on an icon picks the tool, and the view scrolls when the pointer rests on its edge, as on the SAM Coupe
   (target/sam/sam_mouse.asm); the pointer is hardware sprite 0, so nothing has to be drawn under it or put back. */
#include <stdint.h>
#include <arch/zxn.h>
#include <arch/zx/zx_input.h>
#include "platform.h"
#include "engine.h"

#ifdef HAVE_MOUSE                               /* (plat_config.h: a build without the mouse has nothing here) */

extern void zxn_out(uint16_t port, uint8_t value);
extern uint8_t plat_pointer_keys(void);         /* what is down: 1 left, 2 right, 4 up, 8 down, 16 fire, 32 fast (plat_zxn.asm) */

#define REG_PERIPHERAL_5 0x0A                   /* (z88dk has no name for it) bits 1 and 0: the mouse's DPI, 0 low, 1 the default, 2 medium, 3 high */
#define STEP        2                           /* pixels a frame (the map's cells and the mini map's tiles are 8 and 2) */
#define STEP_FAST   4

extern uint8_t cur_x, cur_y, origin_x, origin_y, frame, view_w, view_h, map_row;

/* the variables in_MouseKemp needs (arch/zx/zx_input.h) */
uint8_t in_KempcoordX, in_KempcoordY, in_KemprawX, in_KemprawY;

volatile int16_t plat_mouse_x, plat_mouse_y;
volatile uint8_t plat_mouse_buttons;

static int16_t sent_x, sent_y;                  /* the position as the driver has it: the keys move the pointer too, and it is told before the next read */
static uint8_t last_buttons, seen;
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
    plat_mouse_x = 128;
    plat_mouse_y = 128;
    in_MouseKempSetPos(128, 128);
    sent_x = sent_y = 128;
    shown_x = -1;
}

/* Read the mouse and the keys, then return bit 0 for movement, bit 1 for a new press of the left button (or fire) and bit 2 while it is held. */
uint8_t plat_mouse_input(void)
{
    uint8_t buttons, keys, step, events = 0;
    uint16_t x, y;
    int16_t nx, ny;

    if (plat_mouse_x != sent_x || plat_mouse_y != sent_y)
        in_MouseKempSetPos(plat_mouse_x, plat_mouse_y);    /* the keys moved it */
    in_MouseKemp(&buttons, &x, &y);
    sent_x = nx = (int16_t)x;
    sent_y = ny = (int16_t)y;
    keys = plat_pointer_keys();
    step = (keys & 32) ? STEP_FAST : STEP;
    if (keys & 1)
        nx -= step;
    if (keys & 2)
        nx += step;
    if (keys & 4)
        ny -= step;
    if (keys & 8)
        ny += step;
    if (nx < 0)
        nx = 0;
    if (nx > 255)
        nx = 255;
    if (ny < 0)
        ny = 0;
    if (ny > 191)
        ny = 191;
    if (!seen || nx != plat_mouse_x || ny != plat_mouse_y)
        events |= 1;
    seen = 1;
    plat_mouse_x = nx;
    plat_mouse_y = ny;
    if (keys & 16)
        buttons |= 1;
    plat_mouse_buttons = buttons;
    if (buttons & 1) {
        events |= 4;
        if (!(last_buttons & 1))
            events |= 2;
    }
    last_buttons = buttons;
    return events;
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

/* Move the view by one cell while the pointer rests on its edge (the game asks only when the pointer is over the map).  Returns 1 if it moved.
   It looks every fourth frame: the city would otherwise fly past. */
uint8_t plat_mouse_edge_scroll(void)
{
    uint8_t col, row;

    if (frame & 3)
        return 0;
    col = (uint8_t)plat_mouse_x >> 3;
    row = (uint8_t)plat_mouse_y >> 3;
    if (col == 0) {
        if (cur_x) {
            --cur_x;
            --origin_x;
            return 1;
        }
    } else if (col == view_w - 1) {
        if (cur_x != MAP_W - 1) {
            ++cur_x;
            ++origin_x;
            return 1;
        }
    }
    if (row == map_row) {
        if (cur_y) {
            --cur_y;
            --origin_y;
            return 1;
        }
    } else if (row == map_row + view_h - 1) {
        if (cur_y != MAP_H - 1) {
            ++cur_y;
            ++origin_y;
            return 1;
        }
    }
    return 0;
}

#endif /* HAVE_MOUSE */
