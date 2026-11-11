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

        defc    TIMER_DIV = 31          ; ($F6) 487.5 * 4 / 32 = 60.9 Hz

; void pc_irq_init(void): the vector table (in the first page boundary inside irq_buf, as the table's address is $xx00: its high byte goes in I), the timer's rate, interrupts on
_pc_irq_init:
        di
        ld      hl,irq_buf
        ld      a,l
        or      a
        jr      z,aligned
        inc     h
aligned: ld     l,0
        push    hl
        ld      de,irq_default
        ld      b,20                    ; the vectors $00, $02 ... $26
ifill:  ld      (hl),e
        inc     hl
        ld      (hl),d
        inc     hl
        djnz    ifill
        pop     hl
        push    hl
        ld      de,$02                  ; the keyboard
        add     hl,de
        ld      de,key_isr
        ld      (hl),e
        inc     hl
        ld      (hl),d
        pop     hl
        push    hl
        ld      de,$06                  ; the timer
        add     hl,de
        ld      de,timer_isr
        ld      (hl),e
        inc     hl
        ld      (hl),d
        pop     hl
        ld      a,h
        ld      i,a
        im      2
        xor     a
        out     ($f3),a                 ; (the custom interrupt masks and vectors: the defaults)
        ld      a,6
        out     ($f7),a                 ; the timer's vector
        ld      a,TIMER_DIV
        out     ($f6),a
        xor     a
        ld      (key_last),a
        call    snd_init
        ei
        ret

key_isr:
        push    af
        in      a,($90)
        ld      (key_last),a
        pop     af
        ei
        reti

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

irq_default:
        ei
        reti

; uint8_t pc_key_take(void): the last key code sent (0 if none since the last call)
_pc_key_take:
        di
        ld      a,(key_last)
        ld      l,a
        ld      h,0
        xor     a
        ld      (key_last),a
        ei
        ret

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
irq_buf:    defs 512
key_last:   defb 0
ticks:      defw 0
