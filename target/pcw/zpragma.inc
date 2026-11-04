// CP/M Plus .COM at $0100.  The screen is paged in over $4000-$BFFF, so the code that draws on it, the buffer it draws from and the stack are in common
// memory: the HIMEM section (code_himem, bss_himem) at CRT_ORG_GRAPHICS, and the stack below it.
#pragma output CRT_ORG_CODE = 0x0100
#pragma output CRT_ORG_GRAPHICS = 61000
#pragma output REGISTER_SP = 61000
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
