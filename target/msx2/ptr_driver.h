/* What target/common/pointer.c needs of the MSX2: z88dk's mouse in a joystick connector (in_MouseMSX: msx.h), the arrow (two VDP sprites), the keys. */
#include <msx.h>

#define PTR_READ(b, x, y)   in_MouseMSX(b, x, y)
#define PTR_SETPOS(x, y)    in_MouseMSXSetPos(x, y)
#define PTR_HIDE()          plat_mouse_pointer_hide()

extern void plat_mouse_pointer_hide(void);
extern uint8_t plat_pointer_keys(void);         /* what is down: 1 left, 2 right, 4 up, 8 down, 16 fire, 32 fast (msx_pointer.c) */
extern uint8_t plat_keyboard_key(void);         /* the keyboard's key, once when it goes down (plat_key's, before the mouse is keys too) */
