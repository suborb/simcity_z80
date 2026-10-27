; ------------------------------------------------------------------------
; Section selection for the engine's code, tables and variables, so that a
; platform can put each where it belongs: code and tables in ROM, variables
; in RAM.  (The engine has no self-modifying code in a PORTABLE build.)
;
;     IN_CODE    code_user    instructions
;     IN_RODATA  rodata_user  tables nothing writes
;     IN_DATA    data_user    variables (initialised: the value is kept in ROM)
;     IN_BSS     bss_user     buffers (zeroed at start-up)
;
; Only PORTABLE builds switch section.  The Spectrum build leaves everything in
; one flat block, exactly as the original, so it stays byte-identical.
; ------------------------------------------------------------------------
        IFNDEF  SECTIONS_ASM            ; may be included more than once
        defc    SECTIONS_ASM = 1
        IFDEF   PORTABLE
; A target can set ENGINE_BANK and provide engine_bank.inc.  It supplies the section choices and the map/unmap instructions; this file only decides
; whether an engine source is currently banked.  ENGINE_IN_BANK is set by engine_all.asm for the simulation files, then cleared for the UI-facing code.
        IFDEF   ENGINE_BANK
        defl    ENGINE_IN_BANK = 0
        INCLUDE "engine_bank.inc"
        MACRO   IN_CODE
        IF      ENGINE_IN_BANK
        ENGINE_BANK_CODE
        ELSE
        ENGINE_COMMON_CODE
        ENDIF
        ENDM
        MACRO   BANK_IN
        ENGINE_BANK_IN
        ENDM
        MACRO   BANK_OUT
        ENGINE_BANK_OUT
        ENDM
        ELSE
        MACRO   IN_CODE
        SECTION code_user
        ENDM
        MACRO   BANK_IN
        ENDM
        MACRO   BANK_OUT
        ENDM
        ENDIF
        IFDEF   ENGINE_SIM_SECTION              ; a target that links the simulation's code in a section of its own supplies it: engine_sim.inc defines ENGINE_SIM_CODE
        INCLUDE "engine_sim.inc"
        MACRO   IN_SIM_CODE
        ENGINE_SIM_CODE
        ENDM
        ELSE
        IFDEF   ENGINE_BANK
        MACRO   IN_SIM_CODE
        IF      ENGINE_IN_BANK
        ENGINE_BANK_CODE
        ELSE
        ENGINE_COMMON_CODE
        ENDIF
        ENDM
        ELSE
        MACRO   IN_SIM_CODE
        SECTION code_user
        ENDM
        ENDIF
        ENDIF
        IFDEF   RODATA_IN_RAM           ; the Z88 ROM: the tables go in the initial data, which the startup unpacks
        MACRO   IN_RODATA
        SECTION data_user
        ENDM
        ELSE
        MACRO   IN_RODATA
        SECTION rodata_user
        ENDM
        ENDIF
        MACRO   IN_DATA
        SECTION data_user
        ENDM
        MACRO   IN_BSS
        SECTION bss_user
        ENDM
        MACRO   IN_ENGINE_BSS
        IFDEF   ENGINE_BANK
        IF      ENGINE_IN_BANK
        ENGINE_BANK_BSS
        ELSE
        SECTION bss_user
        ENDIF
        ELSE
        SECTION bss_user
        ENDIF
        ENDM
        ELSE
        MACRO   IN_CODE
        ENDM
        MACRO   IN_SIM_CODE
        ENDM
        MACRO   BANK_IN
        ENDM
        MACRO   BANK_OUT
        ENDM
        MACRO   IN_RODATA
        ENDM
        MACRO   IN_DATA
        ENDM
        MACRO   IN_BSS
        ENDM
        MACRO   IN_ENGINE_BSS
        ENDM
        ENDIF
        ENDIF
