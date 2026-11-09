// z88dk pragmas for the Camputers Lynx 128K build (make lynx): the program is in the user RAM from $0100 and the BASIC and the DOS are not used.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma output CRT_TRIM_BSS = 1
