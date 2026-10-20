; One bit sound for the Z88: the Spectrum's effects with the speaker moved from bit 4 of port $FE to bit 6 of
; the COM register (port $B0, shadowed by OZ at $04B0).  The speaker follows that bit while SRUN, bit 7, is 0,
; which it is when OZ is not making a noise of its own; each effect puts COM back as OZ had it.
;
; The engine's hooks (see engine/PLATFORM_INTERFACE.md): soundfx1 (E = pitch mask; noise), play_place_sound,
; play_crash_sound, play_rising_tone, play_falling_tone.  _sound_enabled is the game's Sound option.
; Interrupts are off while a sound plays (OZ_DI and OZ_EI, which pair like the Spectrum's DI and EI), as the
; effects are timed by their loops.
        MODULE  plat_sound
        INCLUDE "sections.asm"

        PUBLIC  soundfx1, soundfx2, play_place_sound, play_crash_sound, play_rising_tone, play_falling_tone
        PUBLIC  _sound_enabled

        defc    COM         = $B0           ; the COM register
        defc    BL_COM      = $04B0         ; OZ's copy of it
        defc    SBIT        = $40           ; the speaker
        defc    OZ_DI       = $0051         ; disable interrupts, returning the old state in AF
        defc    OZ_EI       = $0054         ; and put that state back

        IN_DATA
_sound_enabled: defb    1
        IN_CODE

; Spectrum: noise, 200 steps; every step where (counter AND E) = 0 the speaker goes to a random level.
;   E = mask.  Preserves E; the rest is as the Spectrum's.
soundfx1:
        ld      a,(_sound_enabled)
        and     a
        ret     z
        push    hl
        push    bc
        call    OZ_DI
        push    af
        ld      a,(BL_COM)
        and     $3F                     ; COM as OZ has it, with the speaker bits clear
        ld      h,a
        ld      l,1                     ; the noise: an 8 bit shift register
        ld      bc,200
        ld      d,0
sfx1_step:
        inc     d
        ld      a,d
        and     e
        jr      nz,sfx1_skip
        ld      a,l                     ; next random bit
        add     a,a
        jr      nc,sfx1_nox
        xor     $1D
sfx1_nox:
        ld      l,a
        and     $80
        rrca                            ; bit 7 to bit 6
        or      h
        out     (COM),a
sfx1_skip:
        dec     bc
        ld      a,b
        or      c
        jr      nz,sfx1_step
        ld      a,(BL_COM)              ; OZ's own COM back
        out     (COM),a
        pop     af
        call    OZ_EI
        pop     bc
        pop     hl
        ret

; Spectrum: a tone of 500 cycles, high for 16 steps and low for 48 (HL = 4144).
soundfx2:
        ld      a,(_sound_enabled)
        and     a
        ret     z
        push    hl
        push    de
        push    bc
        call    OZ_DI
        push    af
        ld      a,(BL_COM)
        and     $3F
        ld      c,a
        ld      hl,4144
        ld      de,500
sfx2_cycle:
        ld      a,c
        or      SBIT
        out     (COM),a
        ld      b,l
sfx2_high:
        djnz    sfx2_high
        ld      a,c
        out     (COM),a
        ld      b,h
sfx2_low:
        djnz    sfx2_low
        dec     de
        ld      a,d
        or      e
        jr      nz,sfx2_cycle
        ld      a,(BL_COM)
        out     (COM),a
        pop     af
        call    OZ_EI
        pop     bc
        pop     de
        pop     hl
        ret

; Spectrum: soundfx2 when the keys that move the cursor are not held; here always.
play_place_sound:
        jr      soundfx2

; 255 bursts of noise with the mask E running up from 0.
play_crash_sound:
        ld      b,255
        ld      e,0
crash_step:
        push    bc
        call    soundfx1
        pop     bc
        inc     e
        djnz    crash_step
        ret

; 127 bursts, the mask running 63 down to 0 and again (E = B AND 63).
play_rising_tone:
        ld      b,127
rising_step:
        push    bc
        ld      a,b
        and     63
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    rising_step
        ret

; 127 bursts, the mask E = NOT B AND 127.
play_falling_tone:
        ld      b,127
falling_step:
        push    bc
        ld      a,b
        cpl
        and     127
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    falling_step
        ret
