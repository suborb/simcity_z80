// z88dk pragmas for the Sharp X1 disk build (make x1): the whole machine is RAM (+x1, startup 1: the program is at $0000).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
