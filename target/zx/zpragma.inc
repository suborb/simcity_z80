// z88dk pragmas for the ZX Spectrum build, used by the Makefile and tile test.
// (The load address is -zorg=24000 on the command line: below about that appmake embeds
// the program in a BASIC REM line at 23760 instead of using a separate loader.)

#pragma output REGISTER_SP = 0xFF57
#pragma output CLIB_ZX_CONIO32 = 1
#pragma export CRT_FONT_64 = 0
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma redirect fputc_cons_generic = fputc_cons_generic_minimal
#pragma output CRT_DISABLELOADER = 1
