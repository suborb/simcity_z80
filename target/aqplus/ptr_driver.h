/* What target/common/pointer.c needs of the Aquarius+: z88dk's mouse (in_MouseAQPlus, from the ESP32), the arrow (two hardware sprites), the keys. */
#include <arch/aqplus.h>

#define PTR_READ(b, x, y)   in_MouseAQPlus(b, x, y)
#define PTR_SETPOS(x, y)    in_MouseAQPlusSetPos(x, y)
#define PTR_HIDE()          plat_mouse_pointer_hide()

#define PTR_MAX_X   319                         /* the bitmap is 320x200 */
#define PTR_MAX_Y   199
#define PTR_START_X 160
#define PTR_START_Y 100

/* The game's loop does not wait for the frame, so the keys move the arrow by the frames that have gone by (counted as the sound polls the display's sync). */
#define PTR_FRAMES()        plat_frames()
extern uint8_t plat_frames(void);
extern void plat_mouse_pointer_hide(void);
extern uint8_t plat_pointer_keys(void);         /* what is down: 1 left, 2 right, 4 up, 8 down, 16 fire, 32 fast (plat_aqplus.asm) */
extern uint8_t plat_keyboard_key(void);         /* the keyboard's key, once when it goes down (plat_key's, before the mouse is keys too) */
