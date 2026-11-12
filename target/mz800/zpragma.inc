// z88dk pragmas for the MZ-800 boot disc (make mz800): the IPL reads the program to $1200 and moves it to $2000.  The video RAM ($8000-$9FFF) and the character generator
// ($1000-$1FFF) are paged in only while drawing: the drawing code is below $8000 (the Makefile checks), nothing is at $1000-$1FFF, the stack is the top of memory.
#pragma output CRT_ORG_CODE = 0x2000
#pragma output REGISTER_SP = 0
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma output CRT_TRIM_BSS = 1
#pragma output CRT_INITIALIZE_BSS = 1
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma redirect fputc_cons_native = l_ret
