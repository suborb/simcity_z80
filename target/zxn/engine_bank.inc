; ZX Spectrum Next implementation of the engine's optional bank interface (engine/sections.asm).
; BANK_6 is the simulation's 16 KB NEX bank, linked at $4000.  Bank 5 is the normal program bank that occupies the same
; address window when the simulation is not running.  The engine's data remains in the permanently mapped upper RAM.
        IFNDEF  ZXN_ENGINE_BANK_INC
        defc    ZXN_ENGINE_BANK_INC = 1

        defc    ZXN_ENGINE_BANK_PAGE = 12       ; BANK_6: 8 KB pages for MMU slots 2 and 3
        defc    ZXN_PROGRAM_PAGE = 10           ; BANK_5: the normal pages for those slots

        MACRO   ENGINE_BANK_CODE
        SECTION BANK_6
        ENDM

        MACRO   ENGINE_BANK_BSS
        SECTION BANK_6
        ENDM

        MACRO   ENGINE_COMMON_CODE
        SECTION code_home                        ; low, always-visible program memory
        ENDM

        MACRO   ENGINE_BANK_IN
        nextreg $52,ZXN_ENGINE_BANK_PAGE
        nextreg $53,ZXN_ENGINE_BANK_PAGE+1
        ENDM

        MACRO   ENGINE_BANK_OUT
        nextreg $52,ZXN_PROGRAM_PAGE
        nextreg $53,ZXN_PROGRAM_PAGE+1
        ENDM
        ENDIF
