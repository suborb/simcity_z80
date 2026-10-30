; MZ-2500 implementation of the engine's optional bank interface (engine/sections.asm), as the MSX2's: the simulation's code is in a 16 KB bank linked at $4000 (RAM pages 20 and 21)
; that is mapped into windows 2 and 3 while it runs, and the UI's code (C, linked with zcc's --codeseg CODE_18) is in another (pages 18 and 19) that is mapped there the rest of the
; time.  Everything else (the glue, the drawing, the tables and all the data) is resident: the program at $0000 and the data at $8000.
        IFNDEF  MZ2500_ENGINE_BANK_INC
        defc    MZ2500_ENGINE_BANK_INC = 1
        EXTERN  mz_bank_in, mz_bank_out

        MACRO   ENGINE_BANK_CODE
        SECTION CODE_20
        ENDM

        MACRO   ENGINE_BANK_BSS
        SECTION bss_user                        ; (the engine's variables are resident)
        ENDM

        MACRO   ENGINE_COMMON_CODE
        SECTION code_user                       ; resident
        ENDM

        MACRO   ENGINE_BANK_IN
        call    mz_bank_in                      ; (keeps every register)
        ENDM

        MACRO   ENGINE_BANK_OUT
        call    mz_bank_out
        ENDM
        ENDIF
