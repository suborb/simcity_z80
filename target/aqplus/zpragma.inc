// z88dk pragmas for the Aquarius+ AQX build (make aqplus).
// The AQX loader loads the whole executable below $C000, so keep the CRT lean.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
// The game draws text and pictures itself (target/aqplus/plat_aqplus.asm) and sets the video mode and clears
// the screen itself, so none of z88dk's console is wanted: nothing prints through fputc_cons.
#pragma redirect fputc_cons = l_ret
#pragma redirect fputc_cons_generic = l_ret
#pragma output CRT_DISABLELOADER = 1
#pragma output CRT_COMPRESS_AQX = 1


#pragma output REGISTER_SP = 0x3d00
#pragma output CRT_ORG_CODE = 0x3d00

#pragma output CRT_TRIM_BSS = 1
#pragma output CRT_AQPLUS_BANK3_RAM = 1
