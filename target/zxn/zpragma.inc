// z88dk pragmas for the ZX Spectrum Next build (make zxn).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the program is at $0000, which z88dk's zxn crt starts with the restart vectors and no ROM variables or BASIC to return to;
// the stack is below the data; rst 8 (esxDOS) and rst $38 (the interrupt) are the program's: _z80_rst_08h and _z80_rst_38h
#pragma output CRT_ORG_CODE = 0
#pragma output REGISTER_SP = 0xAC00
#pragma output CRT_ENABLE_RST = 0x82
// interrupts are off until plat_init turns them on (the sound's frame interrupt, plat_sound.asm)
#pragma output CRT_ENABLE_EIDI = 1
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma output CLIB_FARHEAP_USE_INTERNAL = 0
