// z88dk pragmas for the Multi 8 tape build (make multi8): the whole machine is RAM (-subtype=64k).
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// The game draws text and pictures itself (target/multi8/plat_multi8.asm), so none of z88dk's console is wanted.
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret

// The three video planes are paged in over $8000-$BFFF while a cell is drawn, and the rest of the time that is
// ordinary RAM: the uninitialised data lives there, in a file of its own that is not on the tape.
// The uninitialised data runs on from the image and is not saved with it.
#pragma output CRT_TRIM_BSS = 1
