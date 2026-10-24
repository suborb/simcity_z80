; The Aquarius+'s frame clock for the sound (target/common/ay_hooks.asm, target/common/ay_sfx.asm): the display's sync bit, port $FD bit 0.
        MODULE  plat_sound

        PUBLIC  ay_sync
        defc    PORT_VSYNC = $FD

        SECTION code_user
ay_vs:  defb    0                       ; the sync bit as it was

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
        ret
ay_nosync:
        or      1                       ; NZ
        ret
