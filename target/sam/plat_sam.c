/* SAM Coupe platform: the drawing (the tool icons too), the screen set-up and the keyboard are in plat_sam.asm; this has the
   frame counter. */
#include <stdint.h>
#include <string.h>
#include "platform.h"

static uint16_t clock_count;

uint16_t plat_clock(void) { return clock_count; }
#ifdef SOUND_TEST
extern void snd_test(void);
void plat_idle(void) { ++clock_count; snd_test(); }      /* (the build for test/sam/sound_check.py) */
#else
void plat_idle(void) { ++clock_count; }
#endif
void plat_flush(void) {}

#ifdef HAVE_MOUSE_POINTER
extern void plat_page_data(void);
extern void plat_mouse_pointer_save_screen(void);
extern void plat_mouse_pointer_restore_screen(void);
extern uint8_t plat_mouse_pointer_cell_count;
extern uint8_t plat_mouse_pointer_cells[18];
extern uint8_t plat_mouse_pointer_background[288];
extern uint8_t plat_mouse_pointer_mask[288];
extern uint8_t draw_refresh_row, map_row;
void plat_mouse_pointer_refresh(void);

static uint8_t pointer_row_overlaps(uint8_t row)
{
    uint8_t first = (uint8_t)((uint16_t)plat_mouse_y >> 3);
    uint8_t last = (uint8_t)(((uint16_t)plat_mouse_y + 15) >> 3);

    return row >= first && row <= last;
}

#pragma codeseg code_driver
void plat_mouse_pointer_before_map_row(void)
{
    uint8_t row = (uint8_t)(map_row + draw_refresh_row);

    if (plat_mouse_pointer_cell_count && pointer_row_overlaps(row)) {
        plat_page_data();
        plat_mouse_pointer_restore_screen();
        plat_mouse_pointer_cell_count = 0;
    }
}

#pragma codeseg code_compiler

static uint16_t pointer_x, pointer_y;
extern void plat_mouse_pointer_draw(void);     /* (plat_sam.asm: the arrow, composed from its bit planes) */

void plat_mouse_pointer_erase(void)
{
    plat_page_data();
    if (plat_mouse_pointer_cell_count) {
        plat_mouse_pointer_restore_screen();
        plat_mouse_pointer_cell_count = 0;
    }
}

void plat_mouse_pointer_refresh(void)
{
    uint16_t px, py;

    plat_page_data();
    px = (uint16_t)plat_mouse_x;
    py = (uint16_t)plat_mouse_y;
    if (plat_mouse_pointer_cell_count &&
        (!plat_mouse_present || px != pointer_x || py != pointer_y))
        plat_mouse_pointer_erase();
    if (!plat_mouse_present || plat_mouse_pointer_cell_count)
        return;
    pointer_x = px;
    pointer_y = py;
    plat_mouse_pointer_draw();
}
#endif
