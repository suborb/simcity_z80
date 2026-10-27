; The Next's sound clock (target/common/ay_hooks.asm, target/common/ay_sfx.asm with -DAY_ISR -DAY_PORT16 -DAY_SCALE -DAY_DOWN and the
; ports $FFFD and $BFFD): the 50 Hz frame interrupt updates ay_frames and calls ay_tick.  The program is at $0000, so the crt's vector at $0038 (interrupt mode
; 1) jumps to _z80_rst_38h, below.  The placer has slots 6 and 7 mapped to other pages while it draws, and the interrupt uses only what is
; below $C000 (the program, its stack).  snd_init (called by plat_init) sets the mode and turns interrupts on.
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init, _snd_init, _snd_wait, _z80_rst_38h
        EXTERN  ay_tick

        IFDEF   ENGINE_BANK
        SECTION code_home               ; the Next's engine bank (engine/sections.asm): this is called while the bank is mapped, so it is in the lowest 16 KB
        ELSE
        SECTION code_user
        ENDIF
ay_frames:      defb    0               ; frames, counted by the interrupt
ay_seen:        defb    0               ; the count ay_sync last saw

; The interrupt: a tick of the sound
_z80_rst_38h:
        push    af
        push    bc
        push    de
        push    hl
        ld      hl,ay_frames
        inc     (hl)
        call    ay_tick
        pop     hl
        pop     de
        pop     bc
        pop     af
        ei
        reti

; Z if a frame has gone by since the last call (the soundfx1's wait)
ay_sync:
        ld      a,(ay_frames)
        ld      hl,ay_seen
        ld      c,(hl)
        ld      (hl),a
        cp      c
        jr      nz,ay_frame
        or      1                       ; NZ
        ret
ay_frame:
        xor     a
        ret

; void snd_wait(void): halts until the next frame interrupt (interrupts must be on)
_snd_wait:
        ld      a,(ay_frames)
        ld      b,a
sw_lp:  halt
        ld      a,(ay_frames)
        cp      b
        jr      z,sw_lp
        ret

; Interrupt mode 1, and interrupts on
snd_init:
_snd_init:
        im      1
        ei
        ret
