/* ZX Spectrum Next: the pointer's own parts (the rest is target/common/pointer.c, with ptr_driver.h).  A Kempston mouse cannot be detected (its ports read as anything
   without one), so it is always read: with none the position does not change.  It is read by z88dk's in_MouseKemp, which keeps the position as 0..255 by 0..191 in the four
   variables below.  The pointer is hardware sprite 0, so nothing has to be drawn under it or put back; here too are the tool icons' places. */
#include <stdint.h>
#include <arch/zxn.h>
#include <arch/zx/zx_input.h>
#include "platform.h"
#include "engine.h"

#ifdef HAVE_MOUSE                               /* (plat_config.h: a build without the mouse has nothing here) */

extern void pointer_start(void);                /* (target/common/pointer.c) */

#define REG_PERIPHERAL_5 0x0A                   /* (z88dk has no name for it) bits 1 and 0: the mouse's DPI, 0 low, 1 the default, 2 medium, 3 high */

/* the variables in_MouseKemp needs (arch/zx/zx_input.h) */
uint8_t in_KempcoordX, in_KempcoordY, in_KemprawX, in_KemprawY;

static int16_t shown_x, shown_y;                /* where the sprite is, or -1 if it is hidden */

/* The arrow's sprite (plat_zxn.asm): its pixels and pens, and sprite 0 put at a screen pixel. */
extern void zxn_sprite_define(void);
extern void zxn_sprite_at(int16_t x, int16_t y) __smallc;
#define sprite_define() zxn_sprite_define()
#define sprite_at(x, y) zxn_sprite_at(x, y)

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
