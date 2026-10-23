// Application policy for the two-stage Aquarius+ AQX build.
// The generic aqxboot subtype deliberately leaves BSS trimming to callers.
#pragma output CRT_TRIM_BSS = 1
// Stage 1 uses bank 3 for its stack, so it cannot run the generic bank-file
// loader, which pages that same window while it is active.
#pragma output CRT_DISABLELOADER = 1
// The stack stays at the top of the RAM, in bank 3: the video is paged over bank 2 (plat_aqplus.asm, AQ_VIDEO_BANK2), not over it.
#pragma output REGISTER_SP = 0xff00
