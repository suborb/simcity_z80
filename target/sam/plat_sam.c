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
/* MagicFields pointer, extracted from magicfield.bin at $9000 with its mask
 * at $9020. The dump starts at $4000. */
static const uint16_t pointer_art[16] = {
    0x0000, 0x6000, 0x7000, 0x7800, 0x7C00, 0x7E00, 0x7800, 0x7800,
    0x4800, 0x0800, 0x0400, 0x0400, 0x0400, 0x0200, 0x0200, 0x0000
};
static const uint16_t pointer_outline[16] = {
    0xE000, 0x9000, 0x8800, 0x8400, 0x8200, 0x8100, 0x8600, 0x8400,
    0xB400, 0x5400, 0x0A00, 0x0A00, 0x0A00, 0x0500, 0x0500, 0x0200
};
static const uint16_t pointer_coverage[16] = {
    0xE000, 0xF000, 0xF800, 0xFC00, 0xFE00, 0xFF00, 0xFE00, 0xFC00,
    0xFC00, 0x5C00, 0x0E00, 0x0E00, 0x0E00, 0x0700, 0x0700, 0x0200
};

static void pointer_build_restore_mask(uint8_t cx, uint8_t row, uint16_t px, uint16_t py, uint8_t *mask)
{
    uint16_t left = (uint16_t)cx << 3, top = (uint16_t)row << 3;
    uint8_t dx0 = left > px ? (uint8_t)(left - px) : 0;
    uint8_t dy0 = top > py ? (uint8_t)(top - py) : 0;
    uint8_t dx1 = (uint8_t)((left + 8 - px) < 16 ? left + 8 - px : 16);
    uint8_t dy1 = (uint8_t)((top + 8 - py) < 16 ? top + 8 - py : 16);
    uint8_t dy, dx;

    memset(mask, 0, 32);
    for (dy = dy0; dy < dy1; ++dy) {
        uint16_t y = py + dy;
        for (dx = dx0; dx < dx1; ++dx) {
            uint16_t x = px + dx;
            uint8_t local_x;
            if (!(pointer_coverage[dy] & (0x8000u >> dx)))
                continue;
            local_x = (uint8_t)(x & 7);
            mask[((y & 7) << 2) + (local_x >> 1)] |= (local_x & 1) ? 0x0F : 0xF0;
        }
    }
}

static uint8_t pointer_cell_has_pixels(uint16_t px, uint16_t py, uint8_t cx, uint8_t row)
{
    uint16_t left = (uint16_t)cx << 3, top = (uint16_t)row << 3;
    uint8_t dx0 = left > px ? (uint8_t)(left - px) : 0;
    uint8_t dy0 = top > py ? (uint8_t)(top - py) : 0;
    uint8_t dx1 = (uint8_t)((left + 8 - px) < 16 ? left + 8 - px : 16);
    uint8_t dy1 = (uint8_t)((top + 8 - py) < 16 ? top + 8 - py : 16);
    uint16_t xmask = 0;
    uint8_t dx, dy;

    for (dx = dx0; dx < dx1; ++dx)
        xmask |= (uint16_t)(0x8000u >> dx);
    for (dy = dy0; dy < dy1; ++dy)
        if (pointer_coverage[dy] & xmask)
            return 1;
    return 0;
}

void plat_mouse_pointer_erase(void)
{
    plat_page_data();
    if (plat_mouse_pointer_cell_count) {
        plat_mouse_pointer_restore_screen();
        plat_mouse_pointer_cell_count = 0;
    }
}

static void pointer_overlay(uint8_t cx, uint8_t screen_row, uint16_t px, uint16_t py)
{
    uint8_t art[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    uint8_t outline[8] = { 0, 0, 0, 0, 0, 0, 0, 0 };
    uint16_t cell_left = (uint16_t)cx << 3, cell_top = (uint16_t)screen_row << 3;
    uint8_t dx0 = cell_left > px ? (uint8_t)(cell_left - px) : 0;
    uint8_t dy0 = cell_top > py ? (uint8_t)(cell_top - py) : 0;
    uint8_t dx1 = (uint8_t)((cell_left + 8 - px) < 16 ? cell_left + 8 - px : 16);
    uint8_t dy1 = (uint8_t)((cell_top + 8 - py) < 16 ? cell_top + 8 - py : 16);
    uint8_t dx, dy, visible = 0;

    for (dy = dy0; dy < dy1; ++dy) {
        uint16_t y = py + dy;
        for (dx = dx0; dx < dx1; ++dx) {
            uint16_t x = px + dx;
            if (pointer_art[dy] & (0x8000u >> dx)) {
                art[y & 7] |= (uint8_t)(0x80 >> (x & 7));
                visible = 1;
            } else if (pointer_outline[dy] & (0x8000u >> dx)) {
                outline[y & 7] |= (uint8_t)(0x80 >> (x & 7));
                visible = 1;
            }
        }
    }
    if (visible) {
        plat_put_overlay(cx, screen_row, art);
        plat_put_black_overlay(cx, screen_row, outline);
    }
}

void plat_mouse_pointer_refresh(void)
{
    uint16_t px, py;
    uint8_t x0, x1, y0, y1, x, y, i, cols, rows;

    plat_page_data();
    px = (uint16_t)plat_mouse_x;
    py = (uint16_t)plat_mouse_y;
    x0 = (uint8_t)(px >> 3);
    x1 = (uint8_t)((px + 15) >> 3);
    y0 = (uint8_t)(py >> 3);
    y1 = (uint8_t)((py + 15) >> 3);
    if (plat_mouse_pointer_cell_count &&
        (!plat_mouse_present || px != pointer_x || py != pointer_y))
        plat_mouse_pointer_erase();
    if (!plat_mouse_present || plat_mouse_pointer_cell_count)
        return;
    cols = plat_cols();
    rows = plat_rows();
    for (y = y0; y <= y1 && y < rows; ++y)
        for (x = x0; x <= x1 && x < cols; ++x)
            if (pointer_cell_has_pixels(px, py, x, y)) {
                i = plat_mouse_pointer_cell_count++;
                plat_mouse_pointer_cells[i * 2] = x;
                plat_mouse_pointer_cells[i * 2 + 1] = y;
            }
    if (!plat_mouse_pointer_cell_count)
        return;
    pointer_x = px;
    pointer_y = py;
    plat_mouse_pointer_save_screen();
    for (i = 0; i < plat_mouse_pointer_cell_count; ++i) {
        uint8_t cx = plat_mouse_pointer_cells[i * 2];
        uint8_t row = plat_mouse_pointer_cells[i * 2 + 1];
        pointer_build_restore_mask(cx, row, px, py, plat_mouse_pointer_mask + (uint16_t)i * 32);
        plat_page_data();
        pointer_overlay(cx, row, px, py);
    }
}
#endif
