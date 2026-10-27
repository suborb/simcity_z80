#ifndef SAM_MOUSE_H
#define SAM_MOUSE_H

#include <stdint.h>

#define SAM_MOUSE_LEFT   0x01
#define SAM_MOUSE_MIDDLE 0x02
#define SAM_MOUSE_RIGHT  0x04
#define SAM_MOUSE_RAW_COUNT 10

/* SAM diagnostic aliases for the generic platform mouse state/API. */
extern volatile int16_t plat_mouse_x;
extern volatile int16_t plat_mouse_y;
extern volatile uint8_t plat_mouse_buttons;
extern volatile uint8_t plat_mouse_present;
extern volatile uint16_t plat_mouse_polls;
extern volatile uint8_t plat_mouse_raw[SAM_MOUSE_RAW_COUNT];

void plat_mouse_init(void);
void plat_mouse_poll(void);
/* Poll; bit 0 is movement, bit 1 a new left press, bit 2 left held. */
uint8_t plat_mouse_input(void);
/* Return the clicked icon index, or 0xff when outside the icon strip. */
uint8_t plat_mouse_icon_hit(void);

#define sam_mouse_x       plat_mouse_x
#define sam_mouse_y       plat_mouse_y
#define sam_mouse_buttons plat_mouse_buttons
#define sam_mouse_present plat_mouse_present
#define sam_mouse_init    plat_mouse_init
#define sam_mouse_input   plat_mouse_input
#define sam_mouse_icon_hit plat_mouse_icon_hit
#define sam_mouse_poll     plat_mouse_poll
#define sam_mouse_polls     plat_mouse_polls
#define sam_mouse_raw       plat_mouse_raw
void plat_put_black_overlay(uint8_t col, uint8_t row, const uint8_t *art);

#endif
