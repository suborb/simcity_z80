// z88dk pragmas for the Casio FP-1100 boot disc build: the whole machine is RAM, the program at $0000 with the standard RST vectors, and the game draws
// everything itself (through the sub-CPU), so none of z88dk's console is wanted.  The loader (z88dk's BOOTSTRAP2) runs at $F800 and is gone once the program starts; the stack is at the top of RAM (the takeover's interrupt table is at $FFF0).
#pragma output CRT_ORG_CODE = 0x0000
#pragma output REGISTER_SP = 0xFFF0
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
// The uninitialised data runs on from the program and is not on the disc.
#pragma output CRT_TRIM_BSS = 1
