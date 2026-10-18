; ------------------------------------------------------------------------
; Cooperative simulation task (PORTABLE builds only).
;
; The Spectrum runs the simulation as a second task under an IM2 task
; switcher.  Other machines have no such thing, and a whole tick takes about
; two seconds on a 3.5MHz Z80, so the UI would freeze.  This is the same idea
; with explicit switches: the simulation runs on its own stack and calls
; sim_yield at the end of each map row of process_ric_zones (and while it waits
; for the budget); the UI calls sim_step to run it up to the next yield.
;
;   sim_task_reset   abandon any tick in progress; the next sim_step starts one
;   sim_step         run the simulation to its next yield.
;                    Returns L = 1 if a whole tick has just completed, else 0.
;                    Registers are preserved except HL (result).
;   sim_yield        (engine internal) switch back to the UI.  Does nothing
;                    when not running under sim_step, so calling sim_tick
;                    directly still works.
;
; One tick = 96 yields (one per row), so sim_step slices a tick into pieces
; of roughly 1/96 of 2 seconds (about 20ms at 3.5MHz).
; If a budget needs the player (V_auto_budget = 0) the simulation parks in
; sim_budget_wait; sim_step then calls ui_budget_confirm on the UI's stack and
; resumes the simulation on the next call.
; ------------------------------------------------------------------------

SIM_STACK_SIZE  equ     256             ; the engine nests a few calls deep, plus interrupts

        MACRO   SIM_SAVE_REGS
        push    af
        push    bc
        push    de
        push    hl
        push    ix
        push    iy
        exx
        push    bc
        push    de
        push    hl
        exx
        ENDM

        MACRO   SIM_RESTORE_REGS
        exx
        pop     hl
        pop     de
        pop     bc
        exx
        pop     iy
        pop     ix
        pop     hl
        pop     de
        pop     bc
        pop     af
        ENDM

sim_task_reset:
        ; Build the first frame of the simulation stack: nine zeroed register
        ; pairs (what SIM_RESTORE_REGS pops), then the address sim_main.
        ld      hl,sim_stack_top-1
        ld      de,sim_main
        ld      (hl),d                  ; little endian: low byte at the lower address
        dec     hl
        ld      (hl),e
        ld      b,18
sim_task_reset_loop:
        dec     hl
        ld      (hl),0
        djnz    sim_task_reset_loop
        ld      (sim_sp),hl
        xor     a
        ld      (sim_coop_active),a
        ld      (sim_tick_complete),a
        ld      (V_wait_for_budget_confirm),a
        ret

sim_step:
        SIM_SAVE_REGS
        ld      (ui_sp),sp
        ld      sp,(sim_sp)
        ld      a,1
        ld      (sim_coop_active),a
        SIM_RESTORE_REGS
        ret                             ; into the simulation: sim_main or the instruction after its sim_yield

sim_yield:
        push    af
        ld      a,(sim_coop_active)
        and     a
        jr      nz,sim_yield_switch
        pop     af
        ret
sim_yield_switch:
        pop     af
        SIM_SAVE_REGS
        ld      (sim_sp),sp
        ld      sp,(ui_sp)
        xor     a
        ld      (sim_coop_active),a
        SIM_RESTORE_REGS                ; the UI's registers, saved by sim_step
        push    af
        ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      z,sim_step_return
        SIM_SAVE_REGS
        call    ui_budget_confirm       ; modal, on the UI's stack
        SIM_RESTORE_REGS
        xor     a
        ld      (V_wait_for_budget_confirm),a
sim_step_return:
        ld      a,(sim_tick_complete)
        ld      l,a
        ld      h,0
        xor     a
        ld      (sim_tick_complete),a
        pop     af
        ret

; The simulation task: tick forever, announcing each completed tick.
sim_main:
        call    sim_tick
        ld      a,1
        ld      (sim_tick_complete),a
        call    sim_yield
        jr      sim_main

; Replaces the Spectrum's busy loop: ask the UI to run the budget dialog and
; give the processor away until it has.
sim_budget_wait:
        ld      a,(sim_coop_active)
        and     a
        jp      z,ui_budget_confirm     ; sim_tick called directly: ask the UI right here
        ld      a,1
        ld      (V_wait_for_budget_confirm),a
sim_budget_wait_loop:
        call    sim_yield
        ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,sim_budget_wait_loop
        ret

sim_sp:              defw    0
ui_sp:               defw    0
sim_coop_active:     defb    0
sim_tick_complete:   defb    0

sim_stack:           defs    SIM_STACK_SIZE
sim_stack_top:
