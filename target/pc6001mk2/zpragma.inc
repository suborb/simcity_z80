// z88dk pragmas for the PC-6001mkII boot-disc build (make pc6001mk2: zcc +pc6001 -subtype=mk2disc): a flat RAM image at $0000, loaded by the boot sector z88dk's crt carries.
// The program, its data and the BSS are below $C000, which the 16K bitmap VRAM will take; the stack grows down from there.
#pragma output CRT_MODEL = 0
#pragma output REGISTER_SP = 0xC000
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma output CRT_TRIM_BSS = 1
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma redirect fputc_cons_native = l_ret
#pragma output CRT_INITIALIZE_BSS = 1
// the game sets its own mode and draws its own console: z88dk's mode-3 console (which the crt would otherwise set up) is not wanted
#pragma output CRT_PC6001MK2_NO_MODE = 1
