// z88dk pragmas for the SAM Coupe all RAM build (make sam).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// interrupts stay off: the screen is paged over the data while the placer draws
#pragma output CRT_ENABLE_EIDI = 1
// the stack is in the low 32 KB, with the code (the startup code reserves it)
#pragma output CRT_STACK_SIZE = 768
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
// no far heap: the pages after the program are the pictures
#pragma output CLIB_FARHEAP_USE_INTERNAL = 0

// The uninitialised data starts at SAM_BSS (the Makefile gives the assembler __crt_org_bss) in the data's 32 KB; it is not on the disk.
