// CP/M .COM at $0100, in the standard classic map (mmap.inc).  The game draws everything itself.
#pragma output CRT_ORG_CODE = 0x0100
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma output CRT_TRIM_BSS = 1
// the stack starts at the top of the TPA: the word at address 6 (the BDOS entry)
#pragma output REGISTER_SP = -6
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
