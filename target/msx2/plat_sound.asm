; The MSX2's sound clock (target/common/ay_hooks.asm, target/common/ay_sfx.asm with -DAY_ISR -DAY_SCALE -DAY_DOWN -DAY_ADDR_PORT=$A0 -DAY_DATA_PORT=$A1): the PSG (an AY-3-8910
; clone at 1.79 MHz) is at ports $A0 (register) and $A1 (data).  The VDP's frame interrupt goes through the BIOS, which calls the hook H.TIMI ($FD9F, 5 bytes) once a frame
; (50 or 60 a second) with the registers saved: snd_init points it at ay_isr, which ticks the sound and then runs what was there (the disk system's, say); snd_exit puts
; it back and silences the chip.  plat_idle waits for the next frame (plat_frames).
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init, _snd_init, snd_exit, _snd_exit, _plat_frames
        EXTERN  ay_tick

        defc    H_TIMI = $FD9F

        SECTION CODE_HI                 ; page 3: the BIOS interrupt runs with its ROM in pages 0 and 1, so the hook and all it calls must be above $C000
ay_frames:      defb    0               ; frames, counted by the interrupt
ay_seen:        defb    0               ; the count ay_sync last saw
ay_isr_in:      defb    0               ; the hook is ours
ay_old:         defs    5               ; the hook that was there, and runs after ours (a `ret` or a call through rst $30)

; The hook: a tick of the sound (it may use af, bc, de, hl: the BIOS saved them)
ay_isr:
        ld      hl,ay_frames
        inc     (hl)
        call    ay_tick
        jp      ay_old

; uint8_t plat_frames(void): the frames counted so far (it wraps)
_plat_frames:
        ld      a,(ay_frames)
        ld      l,a
        ld      h,0
        ret

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

; Put the hook in (once), and enable interrupts
snd_init:
_snd_init:
        ld      a,(ay_isr_in)
        or      a
        jr      nz,snd_on
        inc     a
        ld      (ay_isr_in),a
        di
        ld      hl,H_TIMI
        ld      de,ay_old
        ld      bc,5
        ldir
        ld      a,$C3                   ; jp ay_isr
        ld      (H_TIMI),a
        ld      hl,ay_isr
        ld      (H_TIMI + 1),hl
snd_on:
        ei
        ret

; Take the hook out and silence the chip (R#7 = $B8: tones on, noise off, port A input, port B output as the BIOS leaves it; the volumes 0)
snd_exit:
_snd_exit:
        ld      a,(ay_isr_in)
        or      a
        ret     z
        xor     a
        ld      (ay_isr_in),a
        di
        ld      hl,ay_old
        ld      de,H_TIMI
        ld      bc,5
        ldir
        ld      a,7
        out     ($A0),a
        ld      a,$B8
        out     ($A1),a
        ld      b,3
        ld      a,8
snd_vol:
        out     ($A0),a
        ld      c,a
        xor     a
        out     ($A1),a
        ld      a,c
        inc     a
        djnz    snd_vol
        ei
        ret
