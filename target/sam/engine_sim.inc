; The SAM Coupe's implementation of the engine's optional simulation section (engine/sections.asm, ENGINE_SIM_SECTION): the simulation's code is in its own
; section, which target/sam/mmap.inc links after the user code in the high page, mapped only while the simulation runs.
        IFNDEF  SAM_ENGINE_SIM_INC
        defc    SAM_ENGINE_SIM_INC = 1

        MACRO   ENGINE_SIM_CODE
        SECTION code_simulation
        ENDM
        ENDIF
