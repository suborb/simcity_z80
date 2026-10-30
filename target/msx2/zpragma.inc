// z88dk pragmas for the MSX2 build (make msx2): an MSX-DOS 2 .COM at $0100, the stack from the top of the TPA.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma output CRT_TRIM_BSS = 1
// the stack starts at the top of the TPA, the word at address 6 (the BDOS entry): DOS 2 starts a .COM with SP near the top of RAM, above its own area
#pragma output REGISTER_SP = -6
// (the stack is in page 3 now, and the uninitialised data below $8000: the startup code can clear it)
