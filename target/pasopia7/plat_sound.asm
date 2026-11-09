; Sound on the Toshiba Pasopia 7: the Atari ST's effects (assets/st_sounds.bin, target/common/ay_sfx.asm assembled with -DAY_SHADOW -DAY_SHADOW_TICK, and ay_hooks.asm) on the SN76489A
; at port $3A (the second chip, at $3B, is not used).  The player says what it wants as AY registers for channel C (a tone and/or noise, in 20 ms ticks); at the end of each tick
; ay_shadow_tick turns them into the SN76489's:
;     tone     the AY's period P (125000 / P Hz: the ST's 2 MHz clock) is the SN76489's divider P / 2 (it runs at 1.9968 MHz: 62400 / n Hz), at most 1023; channel 0
;     noise    white noise at the fastest rate (3.9 kHz: the AY's rates, 4 kHz and up, are not far off); the noise channel
;     volume   the AY's steps are 3 dB, the SN76489's 2: attenuation (15 - v) * 3 / 2, and off for 0; a tone or noise the mixer has off is attenuated to nothing
; The ticks come from the time plat_time.asm keeps (the Z80 CTC, 50 a second): ay_sync, and ay_poll, which the game calls whenever it idles or draws.

        MODULE  plat_sound

        PUBLIC  ay_sync, ay_shadow_tick
        EXTERN  ay_regs, p7_tick, p7_acc_s

        defc    PORT_PSG = $3A

        SECTION code_user

; Z if a tick (20 ms: 312 counts of the clock plat_time.asm keeps) has gone by since the last call, else NZ: the accumulator gives them one at a time.  Keeps all but af, hl, de.
ay_sync:
        call    p7_tick
        ld      hl,(p7_acc_s)
        ld      de,312
        or      a
        sbc     hl,de
        jr      c,ay_nosync
        ld      (p7_acc_s),hl
        xor     a                       ; Z: a tick
        ret
ay_nosync:
        or      1                       ; NZ
        ret

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
ay_n1:  ld      hl,(ay_regs + 4)        ; the tone period (12 bits): the divider is half of it
        ld      a,h
        and     15
        ld      h,a
        srl     h
        rr      l
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

