/* Aquarius+: the pointer's own parts (the rest is target/common/pointer.c, with ptr_driver.h).  The mouse is the ESP32's, read by z88dk's in_MouseAQPlus, which keeps the
   position as 0..319 by 0..199; the arrow is two hardware sprites (aq_mouse.asm), so nothing is drawn under it or put back; and here are the tool icons' places. */
#include <stdint.h>
#include <arch/aqplus.h>
#include "platform.h"
#include "engine.h"

#ifdef HAVE_MOUSE

extern void pointer_start(void);                /* (target/common/pointer.c) */
extern void aq_arrow_define(void);
extern void aq_arrow_at(int16_t x, int16_t y) __smallc;

static int16_t shown_x, shown_y;                /* where the arrow is, or -1 if it is hidden */

/* The pointer starts in the middle of the map. */
void plat_mouse_init(void)
{
    aq_arrow_define();
    in_MouseAQPlusInit();                       /* (the mouse may not be there: it adds nothing then) */
    pointer_start();
    shown_x = -1;
}

/* The pointer, once a frame. */
void plat_mouse_pointer_refresh(void)
{
    if (plat_mouse_x != shown_x || plat_mouse_y != shown_y) {
        aq_arrow_at(plat_mouse_x, plat_mouse_y);
        shown_x = plat_mouse_x;
        shown_y = plat_mouse_y;
    }
}

/* Hidden while a menu is up, which the keys use (the next refresh shows it again). */
void plat_mouse_pointer_hide(void)
{
    if (shown_x >= 0) {
        aq_arrow_at(-1, 0);
        shown_x = -1;
    }
}

/* The tool icon under the pointer (0 to 13), or $FF: they are 16x16 pixels in a row from x=0, y=8 (plat_icons). */
uint8_t plat_mouse_icon_hit(void)
{
    uint16_t x = (uint16_t)plat_mouse_x, y = (uint16_t)plat_mouse_y;

    if (y < 8 || y >= 24 || x >= 224)
        return 0xFF;
    return (uint8_t)(x >> 4);
}

#endif /* HAVE_MOUSE */
