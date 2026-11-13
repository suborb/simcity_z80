// z88dk pragmas for the Samsung SPC-1500 cassette build (make spc1500): the whole machine is RAM (+spc1500: the program is at $0000).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
