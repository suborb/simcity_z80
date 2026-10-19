// z88dk pragmas for the Z88 ROM application (make z88rom), used with -pragma-include:.
//
// The program is 21 KB, more than the 16 KB the application startup assumes (it defaults to
// 0xC000, one bank at the top of the address space, and fails with "Binary file too large").
// Starting it at 0x8000 gives it the two banks of a 32 KB ROM image (simcity.epr).
#pragma output CRT_ORG_CODE = 0x8000

// The zeroed and initialised RAM is requested from OZ and sits above the stack, which lives
// below 8192.
#pragma output CRT_ORG_BSS = 0x2000

// OZ calls these two functions of plat_console.c: a chosen menu item (handlecmds) and a
// request to redraw the screen (redrawscreen).  Without the redirects the startup code does
// not call them.
#pragma redirect handlecmds = _handlecmds
#pragma redirect redrawscreen = _redrawscreen

// Nothing here uses stdio FILEs (the game talks to the console and, for saving, to OZ's own file calls) or atexit.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0

// The console only gets plain characters and pictures (positioning is done with gotoxy; the text window is
// written with OZ's own calls), so use the library's minimal fputc_cons.
#pragma redirect fputc_cons_generic = fputc_cons_generic_minimal
