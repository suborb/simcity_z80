// Application policy for the two-stage Aquarius+ AQX build.
// The generic aqxboot subtype deliberately leaves BSS trimming to callers.
#pragma output CRT_TRIM_BSS = 1
// Stage 1 uses bank 3 for its stack, so it cannot run the generic bank-file
// loader, which pages that same window while it is active.
#pragma output CRT_DISABLELOADER = 1
// The video RAM is paged over bank 3 while a cell is drawn (plat_aqplus.asm), so the stacks are in the low RAM: the program starts at
// $1000 (the bootstrap loads it from CRT_ORG_CODE), the program's stack is $0C00-$0FFF under it, and the simulation's $0B00-$0BFF
// (the Makefile gives SIM_STACK_TOP).
#pragma output CRT_ORG_CODE = 0x1000
#pragma output REGISTER_SP = 0x1000
