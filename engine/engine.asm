; The portable engine as one unit.  Assemble with PORTABLE defined (-DPORTABLE).
; The platform must provide the symbols listed in engine/PLATFORM_INTERFACE.md.
        INCLUDE "engine_defs.asm"
        INCLUDE "engine_all.asm"
        IFDEF   ENGINE_BANK
        defl    ENGINE_IN_BANK = 1             ; (the entry points the glue in engine_c.asm calls with the bank mapped)
        ENDIF
        INCLUDE "engine_api.asm"
        IFDEF   ENGINE_BANK
        defl    ENGINE_IN_BANK = 0
        ENDIF
        INCLUDE "view.asm"
        INCLUDE "art.asm"
        INCLUDE "coop.asm"
