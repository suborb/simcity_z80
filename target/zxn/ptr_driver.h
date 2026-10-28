/* What target/common/pointer.c needs of the Next: z88dk's Kempston mouse, the arrow (hardware sprite 0), the keys. */
#include <arch/zx/zx_input.h>

#define PTR_READ(b, x, y)   in_MouseKemp(b, x, y)
#define PTR_SETPOS(x, y)    in_MouseKempSetPos(x, y)
#define PTR_HIDE()          plat_mouse_pointer_hide()

extern void plat_mouse_pointer_hide(void);
extern uint8_t plat_pointer_keys(void);         /* what is down: 1 left, 2 right, 4 up, 8 down, 16 fire, 32 fast (plat_zxn.asm) */
extern uint8_t plat_keyboard_key(void);         /* the keyboard's key, once when it goes down (plat_key's, before the mouse is keys too) */
