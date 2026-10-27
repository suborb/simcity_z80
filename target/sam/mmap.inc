; SAM all-RAM custom map: simulation code follows ordinary user code in the
; high page, which is mapped while the simulation runs. Renderer and driver
; sections remain in the low resident area as defined by the SAM CRT.
    INCLUDE "target/sam/crt_section_code.inc"
    INCLUDE "crt/classic/crt_section_rodata.inc"
    SECTION ROMABLE_END
IF !__crt_model
    INCLUDE "crt/classic/crt_section_data.inc"
ENDIF
    INCLUDE "crt/classic/crt_section_bss.inc"

IF __crt_model > 0
    SECTION DATA
    org     -1
    defb    0
    INCLUDE "crt/classic/crt_section_data.inc"
ENDIF
    SECTION BSS_END

IF __crt_org_graphics > 0 || __crt_org_far > 0
    SECTION HIMEM
IF __crt_org_graphics > 0
    org     __crt_org_graphics
ELIF __crt_org_far > 0
    org     __crt_org_far
ENDIF
    SECTION code_himem
    SECTION rodata_himem
    SECTION data_himem
    SECTION bss_himem
IF __crt_org_graphics > 0
    SECTION smc_clib
    SECTION code_graphics
    SECTION rodata_graphics
    SECTION data_graphics
    SECTION bss_graphics
ENDIF
IF __crt_org_far > 0
    SECTION code_far
    SECTION code_l_sccz80_far
    SECTION data_far
    SECTION rodata_far
    SECTION bss_far
ENDIF
    SECTION HIMEM_END
ENDIF
