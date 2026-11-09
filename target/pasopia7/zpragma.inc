// z88dk pragmas for the Toshiba Pasopia 7 build (make pasopia7): all RAM from $0000 (the ROMs are not used after the boot disc has loaded the program).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma output CRT_TRIM_BSS = 1
