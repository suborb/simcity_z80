; The Sharp X1's sound clock (target/common/ay_hooks.asm, target/common/ay_sfx.asm with -DAY_PORT16 -DAY_ADDR_PORT=$1C00 -DAY_DATA_PORT=$1B00): the PSG is
; an AY-3-8910 at 2 MHz, as the Atari ST's.  There is no frame interrupt in use, so a frame is the display's vertical blank bit (port $1A01
; bit 7) changing: ay_sync says Z once for each time it is seen to fall, so the game looks at it as cells are drawn and when it is idle.
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init

        SECTION code_user
ay_vd:  defb    0                       ; the bit as it was

snd_init:
        ret

; Z for a frame (the bit has fallen since the last look), NZ if not.  Uses a, hl.
ay_sync:
        push    bc
        ld      bc,$1A01
        in      a,(c)
        pop     bc
        and     $80
        ld      hl,ay_vd
        cp      (hl)
        ld      (hl),a
        jr      z,as_none
        or      a                       ; it changed: Z if it fell
        ret
as_none:
        or      1                       ; NZ
        ret
