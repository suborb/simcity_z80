; PC-6001mkII interrupts (IM 2): the keyboard and the timer.
; The sub-CPU (the 8049) sends a key as a code on the 8255's port A ($90) with an interrupt whose vector is $02; the timer's vector is $F7 ($06 by default) and its rate is
; 487.5 Hz * 4 / ($F6 + 1), running when $B0 bit 0 is 0 (target/pc6001mk2/plat_pc6001mk2.asm).  Takeda's timer.cpp and MAME's pc6001.cpp agree on these; unverified on hardware.
; The handlers end in EI and RETI (the emulators watch for the RETI).
        SECTION code_user
        PUBLIC  _pc_irq_init
        PUBLIC  _pc_key_take
        PUBLIC  _pc_ticks
        PUBLIC  _pc_wait_frame
        EXTERN  snd_tick
        EXTERN  snd_init
        EXTERN  __pc6001mk2_irq_table

        defc    TIMER_DIV = 31          ; ($F6) 487.5 * 4 / 32 = 60.9 Hz

; void pc_irq_init(void): the timer's vector in the crt's table (z88dk's allrammk2.asm: at a page boundary, every other vector "ei, reti"; the keyboard's
; is z88dk's too, see pc_key_take: it has set I and IM 2 before main), the timer's rate, interrupts on.  ($F3, the custom interrupt masks and vectors, and the timer's vector $F7 = $06 are left as the ROM has them.)
_pc_irq_init:
        di
        ld      hl,timer_isr
        ld      (__pc6001mk2_irq_table+$06),hl  ; the timer
        ld      a,TIMER_DIV
        out     ($f6),a
        call    snd_init
        ei
        ret

timer_isr:
        push    af
        push    hl
        ld      hl,(ticks)
        inc     hl
        ld      (ticks),hl
        call    snd_tick
        pop     hl
        pop     af
        ei
        reti

; uint8_t pc_key_take(void): the last key code sent (0 if none since the last call): z88dk's, which also has the keyboard's interrupt (pc6001mk2_key.asm: it
; sets the vector $02 and IM 2 at start-up, before main)
        EXTERN  _pc6001mk2_key_take
        defc    _pc_key_take = _pc6001mk2_key_take

; uint16_t pc_ticks(void): the timer's count
_pc_ticks:
        di
        ld      hl,(ticks)
        ei
        ret

; void pc_wait_frame(void): until the timer's next tick
_pc_wait_frame:
        di
        ld      bc,(ticks)
        ei
wf:     halt
        di
        ld      hl,(ticks)
        ei
        or      a
        sbc     hl,bc
        jr      z,wf
        ret

        SECTION bss_user
ticks:      defw 0
