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
        MACRO   IN_CODE
        SECTION code_user
        ENDM
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
        ELSE
        MACRO   IN_CODE
        ENDM
        MACRO   IN_RODATA
        ENDM
        MACRO   IN_DATA
        ENDM
        MACRO   IN_BSS
        ENDM
        ENDIF
        ENDIF
