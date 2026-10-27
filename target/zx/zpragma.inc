// z88dk pragmas for the ZX Spectrum build, used by the Makefile and tile test.
// (The load address is -zorg=23900 on the command line: below about that appmake embeds
// the program in a BASIC REM line at 23760 instead of using a separate loader.)

#pragma output CRT_ORG_CODE = 24000
// The stack grows down from the start of the program, over the loader and BASIC workspace (the game never goes
// back to BASIC).  It needs about 200 bytes; this origin allows it to use part of the system-variable area.
#pragma output REGISTER_SP = 23900
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma output CRT_DISABLELOADER = 1
// The game draws text and pictures itself (target/zx/plat_zx.asm), so none of z88dk's console is wanted.
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
