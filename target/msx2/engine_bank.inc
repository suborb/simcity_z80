; MSX2 (MSX-DOS 2) implementation of the engine's optional bank interface (engine/sections.asm), as the Next's: the simulation's code is in a 16 KB
; mapper segment that is mapped into page 2 ($8000-$BFFF) while it runs, and the UI's code (C, linked with zcc's --codeseg BANK_UI) is in another that
; is mapped there the rest of the time.  Everything else (the glue, the sound, the primitives, the tables and all the data) is resident below $8000.
; msx_bank.asm loads the two segments from SIMCITY.SIM and SIMCITY.UI and switches them.
        IFNDEF  MSX2_ENGINE_BANK_INC
        defc    MSX2_ENGINE_BANK_INC = 1
        EXTERN  msx_bank_in, msx_bank_out

        MACRO   ENGINE_BANK_CODE
        SECTION BANK_SIM
        ENDM

        MACRO   ENGINE_BANK_BSS
        SECTION bss_user                        ; (the engine's variables are resident)
        ENDM

        MACRO   ENGINE_COMMON_CODE
        SECTION code_user                       ; resident
        ENDM

        MACRO   ENGINE_BANK_IN
        call    msx_bank_in                     ; (keeps every register)
        ENDM

        MACRO   ENGINE_BANK_OUT
        call    msx_bank_out
        ENDM
        ENDIF
