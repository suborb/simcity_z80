; Sound on the MZ-800: the Atari ST's effects (target/common/ay_sfx.asm with -DAY_SHADOW -DAY_SHADOW_TICK, ay_hooks.asm) on the SN76489 at $F2.  The player gives AY registers for
; channel C every 20 ms tick; ay_shadow_tick turns them into SN76489 writes:
;     tone    AY period P (125000 / P Hz) -> divider n = P * 0.8867 (the chip is clocked at 3.5469 MHz), as P - P/8 + P/64 (7 cents sharp), at most 1023, channel 0
;     noise   white noise at the fastest rate
;     volume  attenuation (15 - v) * 3 / 2 (the AY's steps are 3 dB, the SN76489's 2), off for 0; a tone or noise the mixer has off is silenced
; Ticks come from the 8253's counter 1, which counts display lines (312 = 20 ms): a free running 16 bit down counter whose elapsed count goes into an accumulator that ay_sync
; takes 312 from at a time, so no tick is lost between polls.  ay_poll (ay_hooks.asm) runs when the game idles and as cells are drawn.
; Checked on the model (test/mz800/sound_test.py) and by ear in Takeda.

        MODULE  plat_sound

        PUBLIC  ay_sync, ay_shadow_tick, mz_time_init
        EXTERN  ay_regs

        defc    PORT_PSG = $F2
        defc    PIT1 = $D5
        defc    PIT_CTL = $D7
        defc    TICK_LINES = 312

        SECTION code_user

; counter 1 a free running down counter of the display's lines, and the clock read for the first difference.  Uses af, de.
mz_time_init:
        ld      a,$74                   ; counter 1, LSB then MSB, mode 2, binary
        out     (PIT_CTL),a
        xor     a
        out     (PIT1),a
        out     (PIT1),a                ; a count of 65536
        call    mz_read
        ld      (mz_last),de
        ld      hl,0
        ld      (mz_acc),hl
        ret

; de = the counter now (latched, so that the two bytes belong together).  Uses a.
mz_read:
        ld      a,$40                   ; latch counter 1
        out     (PIT_CTL),a
        in      a,(PIT1)
        ld      e,a
        in      a,(PIT1)
        ld      d,a
        ret

; Z if a tick (312 lines) has gone by since the last call, else NZ: the time since the last reading is added to the accumulator, which gives ticks one at a time.  Keeps all but af, hl.
ay_sync:
        push    de
        call    mz_read
        ld      hl,(mz_last)
        ld      (mz_last),de
        or      a
        sbc     hl,de                   ; the lines gone by (the counter counts down)
        ex      de,hl
        ld      hl,(mz_acc)
        add     hl,de
        jr      nc,ay_s1
        ld      hl,$FFFF                ; (stop at the top)
ay_s1:  ld      de,TICK_LINES
        or      a
        sbc     hl,de
        jr      c,ay_nosync_pop         ; not yet: put the accumulator back as it was
        ld      (mz_acc),hl
        pop     de
        xor     a                       ; Z: a tick
        ret
ay_nosync_pop:
        add     hl,de
        ld      (mz_acc),hl
        pop     de
        or      1                       ; NZ
        ret

mz_last: defw   0
mz_acc: defw    0

; The tick's AY registers (4, 5 the tone period, 6 the noise period, 7 the mixer, 10 the volume) to the chip.  Keeps everything.
ay_shadow_tick:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,(ay_regs + 10)
        and     15
        ld      b,15                    ; the attenuation: 15 (off) for a volume of 0
        jr      z,ay_att
        ld      c,a
        ld      a,15
        sub     c
        ld      b,a
        add     a,a
        add     a,b                     ; (15 - v) * 3
        srl     a                       ; / 2
        cp      15
        jr      c,ay_a2
        ld      a,14
ay_a2:  ld      b,a
ay_att: ld      a,(ay_regs + 7)         ; the mixer: channel C's tone is off with bit 2, its noise with bit 5
        ld      c,b                     ; c = the tone's attenuation
        bit     2,a
        jr      z,ay_t1
        ld      c,15
ay_t1:  ld      d,b                     ; d = the noise's
        bit     5,a
        jr      z,ay_n1
        ld      d,15
ay_n1:  push    de                      ; (d = the noise's attenuation: the divider uses de)
        ld      hl,(ay_regs + 4)        ; the tone period (12 bits): the divider is P - P / 8 + P / 64
        ld      a,h
        and     15
        ld      h,a
        ld      d,h
        ld      e,l                     ; de = P
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l                       ; hl = P / 8
        ex      de,hl
        or      a
        sbc     hl,de                   ; hl = P - P / 8
        push    hl
        ld      hl,(ay_regs + 4)
        ld      a,h
        and     15
        ld      h,a
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l                       ; hl = P / 64
        pop     de
        add     hl,de
        pop     de                      ; d = the noise's attenuation again
        ld      a,h
        cp      4
        jr      c,ay_d1
        ld      hl,1023
ay_d1:  ld      a,h
        or      l
        jr      nz,ay_d2
        inc     l
ay_d2:  ld      a,l                     ; the latch: channel 0, the divider's low 4 bits; then its high 6
        and     15
        or      $80
        out     (PORT_PSG),a
        ld      a,l
        rrca
        rrca
        rrca
        rrca
        and     15
        ld      e,a
        ld      a,h
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      e
        and     $3F
        out     (PORT_PSG),a
        ld      a,$90                   ; channel 0's attenuation
        or      c
        out     (PORT_PSG),a
        ld      a,$E4                   ; the noise: white, the fastest rate
        out     (PORT_PSG),a
        ld      a,$F0                   ; its attenuation
        or      d
        out     (PORT_PSG),a
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

