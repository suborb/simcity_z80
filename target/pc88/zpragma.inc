// z88dk pragmas for the PC-8801 disk build (make pc88): the whole machine is RAM (-subtype=disk).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// interrupts stay off: the screen is paged over $C000-$FFFF while the placer draws
#pragma output CRT_ENABLE_EIDI = 1
#pragma output REGISTER_SP = 0xB600
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret

// The uninitialised data starts at $B600 and runs over $C000, where the screen is paged in (the Makefile gives the assembler
// __crt_org_bss=0xB600); it is not on the disk.  The stack is just under it.
