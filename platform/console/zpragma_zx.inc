// z88dk pragmas for the ZX Spectrum build, used with -pragma-include: by the Makefile and
// by test/tiles, so that they all build the same program.
// (The load address is -zorg=24000 on the command line: below about that, appmake embeds
// the program in a BASIC REM line at 23760 instead of using a separate loader, and the
// code would not be where it was linked.)

// Stack at the top of RAM, below the UDG area, not in the small gap under the code that
// the loader's CLEAR leaves.
#pragma output REGISTER_SP = 0xFF57

// The console's 32 column mode: UDGs and 8x8 cells need it (32x24: the original's 8 row
// panel above a 32x16 map).
#pragma output CLIB_ZX_CONIO32 = 1

// The 64 column font (768 bytes) is not used in 32 column mode.  Exporting the symbol as a
// public constant stops the library linking the font in; a plain "output"/-pragma-define
// would only make a local one, which does not.
#pragma export CRT_FONT_64 = 0

// Nothing here uses stdio or atexit (the game talks to conio directly), so leave out the
// FILE table for stdin/stdout/stderr and the atexit stack.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0

// The console only ever gets plain characters (positioning is done with gotoxy), so use the
// library's minimal fputc_cons, without the extra VT52 codes.
#pragma redirect fputc_cons_generic = fputc_cons_generic_minimal

// The crt carries a tape loader for extra 128K banks.  This is a 48K program loaded by the
// BASIC loader, so leave it out.
#pragma output CRT_DISABLELOADER = 1
