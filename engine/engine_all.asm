; All engine segments, in source order.  (With ENGINE_BANK the code of these files is in the engine's bank: sections.asm.)
        IFDEF   ENGINE_BANK
        defl    ENGINE_IN_BANK = 1
        ENDIF
        INCLUDE "rand.asm"
        INCLUDE "zone_edge.asm"
        INCLUDE "maths24.asm"
        INCLUDE "landscape.asm"
        INCLUDE "tools_a.asm"
        INCLUDE "tools_b.asm"
        INCLUDE "tools_c.asm"
        INCLUDE "tools_d.asm"
        INCLUDE "tools_e.asm"
        INCLUDE "mapaccess.asm"
        INCLUDE "transport.asm"
        INCLUDE "disasters.asm"
        INCLUDE "simulation.asm"
        IN_CODE                         ; simulation.asm may use a target-specific section
        INCLUDE "fire_flood.asm"
        IN_CODE
        INCLUDE "earthquake.asm"
        IN_CODE
        INCLUDE "budget.asm"
        IN_CODE
        INCLUDE "funding.asm"
        IN_CODE
        INCLUDE "alertmsg.asm"
        IN_CODE
        INCLUDE "messages.asm"
        IN_CODE
        INCLUDE "buffers.asm"
        IFDEF   ENGINE_BANK
        defl    ENGINE_IN_BANK = 0
        ENDIF
