; The Aquarius+'s frame clock for the sound (target/common/ay_hooks.asm, target/common/ay_sfx.asm): the display's sync bit, port $FD bit 0.
        MODULE  plat_sound

        PUBLIC  ay_sync, _plat_frames
        defc    PORT_VSYNC = $FD

        SECTION code_user
ay_vs:  defb    0                       ; the sync bit as it was
ay_frames: defb 0                       ; the frames seen so far (it wraps)

; uint8_t plat_frames(void): how long the game has taken, for the pointer's keys (target/common/pointer.c)
_plat_frames:
        ld      a,(ay_frames)
        ld      l,a
        ld      h,0
        ret

; NZ unless the sync bit has just gone to 0 (the start of a frame, whichever way up the bit is)
ay_sync:
        in      a,(PORT_VSYNC)
        and     1
        ld      hl,ay_vs
        ld      c,(hl)
        ld      (hl),a
        cp      c
        jr      z,ay_nosync
        or      a                       ; (changed: a falling edge when it is 0 now)
        ret     nz
        ld      hl,ay_frames
        inc     (hl)
        xor     a                       ; Z
        ret
ay_nosync:
        or      1                       ; NZ
        ret
