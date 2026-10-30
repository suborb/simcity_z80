// z88dk pragmas for the MZ-2500 build (make mz2500): the program is linked at $0000 (RAM pages 16 and 17: the crt's BOOTSTRAP stub, which appmake puts at $8000, maps them and jumps there),
// the UI and the simulation are 16 KB banks linked at $4000 (pages 18-19 and 20-21) that the bank switch maps into windows 2 and 3, and the data is at $8000 and up.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// the game draws everything itself, so none of z88dk's console is wanted
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma output CRT_ORG_CODE = 0
#pragma output CRT_ORG_BSS = 0xA000
// the stack is at the top of window 7 (never in a window that is remapped: windows 2 and 3 are borrowed for the video, 0 and 1 hold the program); the uninitialised data
// is above RAM page 12's code ($8000-$9FFF) and below it
#pragma output REGISTER_SP = 0xFFF0
#pragma output CRT_MZ2500_IPL_DISABLED = 1
