// z88dk pragmas for the Z88 ROM application (make z88rom).
#pragma output CRT_ORG_CODE = 0x8000
#pragma output CRT_ORG_BSS = 0x2000
#pragma redirect handlecmds = _handlecmds
#pragma redirect redrawscreen = _redrawscreen
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma redirect fputc_cons_generic = fputc_cons_generic_minimal
