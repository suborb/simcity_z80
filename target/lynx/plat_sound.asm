; Sound on the Camputers Lynx 128K: the Atari ST game's effects (assets/st_sounds.bin, target/common/ay_sfx.asm assembled with -DAY_SHADOW, so
; that the player's AY register writes are only kept) rendered by the CPU into the 6-bit DAC at port $84.
;
; An effect is one voice (channel C): a tone and/or noise, its period swept and its volume following a curve, in ticks of 20 ms.  Each tick is
; rendered as SAMPLES samples, one every SAMPLE_T T-states, by a loop that takes the same time whichever way it branches:
;     tone     a 16 bit phase that steps by K / period a sample (the AY's square wave of 125000 / period Hz), the sign bit is the wave
;     noise    a 16 bit phase of its own that steps by K / (the noise period): each time it carries a 16 bit LFSR is clocked, and its top bit is the noise
;     mixer    the AY's: a tone and a noise that are both enabled are ANDed; one disabled is 1
;     volume   0 and 2 * the AY's volume as a level of the DAC: 0 is where the DAC rests, so an effect starts and ends without a click
; The CPU is busy for the whole of an effect: the game waits (there is no timer interrupt to make the sound while it runs, only the frame's).  So the
; effects block for the time they have: 0.2 to 2 s; a tool's chirp is not repeated within 15 frames; the earthquake (soundfx1 is called 255 times)
; plays a tick a call.  Interrupts are off while a tick is rendered (the game keeps them off outside plat_idle's wait: the frame interrupt is held for a
; few lines, and is counted late).
;
; The loop's length is SAMPLE_T (measured by test/lynx/sound_t.py); CPU_MHZ is the CPU's clock (MAME's Lynx 128K: 6): K is 65536 * 125000 / the sample rate.

        MODULE  plat_sound

        PUBLIC  _sound_enabled
        PUBLIC  play_place_sound, play_built_sound, play_crash_sound, play_rising_tone, play_falling_tone, soundfx1
        EXTERN  ay_start, ay_tick, ay_busy, ay_regs, mp_vbl

        IFNDEF  CPU_MHZ
        defc    CPU_MHZ = 6
        ENDIF
        defc    PORT_DAC = $84
        defc    SAMPLE_T = 180                          ; the loop's T-states a sample
        defc    SETUP_T = 9600                          ; what a tick takes besides its samples (the two divisions are most of it: measured)
        defc    SAMPLES = (CPU_MHZ * 20000 - SETUP_T) / SAMPLE_T        ; so that a tick is 20 ms
        defc    PASSES = 3                              ; (the inner loop counts in B: 8 bits)
        defc    INNER = SAMPLES / PASSES
        defc    KSTEP = SAMPLE_T * 8192 / CPU_MHZ       ; 65536 * 125000 / (CPU_MHZ * 1000000 / SAMPLE_T)
        defc    BUILT_GAP = 15                          ; frames between a tool's chirps

        defc    SFX_REFUSED = 0                         ; the effects, in the file's order (target/common/ay_hooks.asm)
        defc    SFX_CRASH = 1
        defc    SFX_RISING = 2
        defc    SFX_FALLING = 3
        defc    SFX_RUMBLE = 4
        defc    SFX_BUILT = 5

        SECTION code_user

_sound_enabled: defb    1

; The hooks: all keep af, bc, de, hl
play_place_sound:
        push    af
        ld      a,SFX_REFUSED
        jr      sfx_start
play_crash_sound:
        push    af
        ld      a,SFX_CRASH
        jr      sfx_start
play_rising_tone:
        push    af
        ld      a,SFX_RISING
        jr      sfx_start
play_falling_tone:
        push    af
        ld      a,SFX_FALLING
sfx_start:
        push    bc
        push    de
        push    hl
        ld      c,a
        ld      a,(_sound_enabled)
        or      a
        jr      z,sfx_done
        ld      a,c
        call    sfx_play
sfx_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

play_built_sound:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,(_sound_enabled)
        or      a
        jr      z,sfx_done
        ld      a,(mp_vbl)
        ld      hl,sfx_last
        sub     (hl)
        cp      BUILT_GAP
        jr      c,sfx_done              ; (a road dragged out is a tile a call: one chirp in a while)
        ld      a,SFX_BUILT
        call    sfx_play
        ld      a,(mp_vbl)
        ld      (sfx_last),a
        jr      sfx_done

; The earthquake: a tick of the rumble a call (it is called 255 times); the rumble starts again when it ends
soundfx1:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,(_sound_enabled)
        or      a
        jr      z,sfx_done
        call    ay_busy
        jr      nz,fx1_tick
        ld      a,SFX_RUMBLE
        call    ay_start
fx1_tick:
        call    ay_tick
        call    ay_busy
        jr      z,fx1_end
        call    render
        jr      sfx_done
fx1_end:
        xor     a
        out     (PORT_DAC),a            ; (the DAC at rest)
        jr      sfx_done

; Play effect A to its end
sfx_play:
        call    ay_start
sfx_next:
        call    ay_tick
        call    ay_busy                 ; Z if the effect ended with this tick
        jr      z,sfx_end
        call    render
        jr      sfx_next
sfx_end:
        xor     a
        out     (PORT_DAC),a            ; (the DAC at rest)
        ret

; Render the tick the player has set up (ay_regs: 4, 5 the tone period, 6 the noise period, 7 the mixer, 10 the volume).  Keeps everything.
render:
        ld      a,i
        push    af
        di
        push    bc
        push    de
        push    hl
        exx
        push    bc
        push    de
        push    hl
        exx
        ld      a,(ay_regs + 7)         ; the mixer: channel C's tone off is bit 2, its noise off bit 5
        ld      b,0
        bit     2,a
        jr      z,rd_t
        ld      b,$80
rd_t:   ld      c,0
        bit     5,a
        jr      z,rd_n
        ld      c,$80
rd_n:   ld      a,b
        ld      (tm),a
        ld      a,c
        ld      (nm),a
        ld      a,(ay_regs + 10)        ; the volume's level
        and     15
        ld      e,a
        ld      d,0
        ld      hl,levels
        add     hl,de
        ld      a,(hl)
        ld      (dd),a
        ld      hl,(ay_regs + 4)        ; the tone period (12 bits, not 0)
        ld      a,h
        and     15
        ld      h,a
        or      l
        jr      nz,rd_p
        inc     l
rd_p:   ex      de,hl
        call    step                    ; hl = K / de, at most $7FFF
        ld      (tstep),hl
        ld      a,(ay_regs + 6)         ; the noise period (5 bits, not 0)
        and     31
        jr      nz,rd_q
        inc     a
rd_q:   ld      e,a
        ld      d,0
        call    step
        ld      (nstep),hl
        ld      hl,(tph)                ; the loop's registers: tone phase, step; noise phase, step, LFSR
        ld      de,(tstep)
        exx
        ld      hl,(nph)
        ld      de,(nstep)
        ld      bc,(lfsr)
        exx
        ld      a,PASSES
        ld      (pass),a
pass_lp:
        ld      b,INNER
smp:                                    ; the samples: SAMPLE_T T-states each, the same on both paths
        add     hl,de                   ; 11   the tone's phase
        exx                             ;  4
        add     hl,de                   ; 11   the noise's phase: a carry clocks the LFSR
        jr      c,clk                   ; 12 / 7
        nop                             ; 28   (the path with no clock takes as long: 7 + 28 + 12 = 47 = 12 + 35)
        nop
        nop
        nop
        nop
        nop
        nop
        jr      join                    ; 12
clk:    srl     b                       ;  8   Galois LFSR, polynomial $B400
        rr      c                       ;  8
        sbc     a,a                     ;  4
        and     $B4                     ;  7
        xor     b                       ;  4
        ld      b,a                     ;  4
join:   ld      a,b                     ;  4   the noise bit is the LFSR's top bit
        exx                             ;  4
        ld      c,a                     ;  4
        ld      a,(nm)                  ; 13
        or      c                       ;  4   a disabled noise reads 1
        ld      c,a                     ;  4
        ld      a,(tm)                  ; 13
        or      h                       ;  4   the tone's sign bit, a disabled tone reads 1
        and     c                       ;  4
        add     a,a                     ;  4   bit 7 to the carry
        sbc     a,a                     ;  4   $FF or 0
        ld      c,a                     ;  4
        ld      a,(dd)                  ; 13
        and     c                       ;  4
        out     (PORT_DAC),a            ; 11
        djnz    smp                     ; 13 / 8
        ld      a,(pass)
        dec     a
        ld      (pass),a
        jr      nz,pass_lp
        ld      (tph),hl
        exx
        ld      (nph),hl
        ld      (lfsr),bc
        pop     hl
        pop     de
        pop     bc
        exx
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret     po
        ei
        ret

; hl := KSTEP / de, at most $7FFF (a 24 bit division, by shifting).  Uses af, bc, de.
step:
        ld      a,KSTEP & 255
        ld      (dv),a
        ld      a,(KSTEP / 256) & 255
        ld      (dv + 1),a
        ld      a,KSTEP / 65536
        ld      (dv + 2),a
        ld      hl,0                    ; the remainder
        ld      b,24
st_lp:  ld      a,(dv)
        add     a,a
        ld      (dv),a
        ld      a,(dv + 1)
        rla
        ld      (dv + 1),a
        ld      a,(dv + 2)
        rla
        ld      (dv + 2),a              ; the top bit to the carry
        adc     hl,hl
        or      a
        sbc     hl,de
        jr      nc,st_ok
        add     hl,de
        jr      st_nx
st_ok:  ld      a,(dv)
        or      1
        ld      (dv),a
st_nx:  djnz    st_lp
        ld      a,(dv + 2)
        or      a
        jr      nz,st_max
        ld      hl,(dv)
        ld      a,h
        cp      $80
        ret     c
st_max: ld      hl,$7FFF
        ret

; The DAC's high level for the AY's volumes 0 to 15 (3 dB a step, 62 at the top)
levels: defb    0,1,1,1,1,2,3,4,5,8,11,16,22,31,44,62

sfx_last:       defb    0               ; the frame count of the last chirp
tm:             defb    0
nm:             defb    0
dd:             defb    0
pass:           defb    0
tstep:          defw    0
nstep:          defw    0
tph:            defw    0
nph:            defw    0
lfsr:           defw    $ACE1
dv:             defs    3
