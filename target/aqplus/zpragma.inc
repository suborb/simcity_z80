// z88dk pragmas for the Aquarius+ AQX build (make aqplus).
// The AQX loader loads the whole executable below $C000, so keep the CRT lean.
#pragma output CRT_ENABLE_STDIO = 0
#pragma output CLIB_EXIT_STACK_SIZE = 0
#pragma redirect fputc_cons_generic = fputc_cons_generic_minimal
#pragma redirect scrollup_BITMAP = l_ret
#pragma redirect scrollup_TEXT = l_ret
#pragma redirect cls_TEXT = l_ret
#pragma redirect conio_map_colour = l_ret
#pragma output CRT_DISABLELOADER = 1
#pragma output CRT_COMPRESS_AQX = 1


#pragma output REGISTER_SP = 0x3d00
#pragma output CRT_ORG_CODE = 0x3d00

#pragma output CRT_TRIM_BSS = 1
#pragma output CRT_AQPLUS_BANK3_RAM = 1

#pragma redirect CRT_FONT = _font_8x8_bbc_system
