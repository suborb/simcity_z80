// z88dk pragmas for the SAM Coupe all RAM build (make sam).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// interrupts start on and plat_init turns them off while it sets up; the sound's frame interrupt (plat_sound.asm) turns them on again at its end
// (z88dk's handler pages the data in over the high window for the length of one, so one may come while the placer has the screen in)
#pragma output CRT_ENABLE_EIDI = 1
// the stack is in the low 32 KB, with the code (the startup code reserves it)
#pragma output CRT_STACK_SIZE = 768
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
// no far heap: the pages after the program are the pictures
#pragma output CLIB_FARHEAP_USE_INTERNAL = 0

// The uninitialised data starts at SAM_BSS (the Makefile gives the assembler __crt_org_bss) in the data's 32 KB; it is not on the disk.
