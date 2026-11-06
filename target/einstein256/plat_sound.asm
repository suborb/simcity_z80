; The Einstein 256's sound (target/common/ay_hooks.asm, target/common/ay_sfx.asm with -DAY_EINSTEIN -DAY_ADDR_PORT=2 -DAY_DATA_PORT=3): the AY-3-8910 is at ports 2 (register) and
; 3 (data), at the ST's 2 MHz.  The chip's I/O ports are the keyboard's (register 14, port A, is the row it selects, register 15, port B, the keys it reads), so the mixer register
; keeps the directions the system set (ay_ports, from snd_init) and a register write is not interrupted (ay_sfx.asm).
; Nothing interrupts for the frame (the vertical blank interrupt is off: einstein_io.asm), so the ticks are made as the Aquarius+'s are: ay_poll, which plat_einstein256.c's plat_idle
; calls once a pass, which is a frame (ay_frame says one has begun), and soundfx1 waits for.  Not in the COM, which is full: all of this is SIMCITY.SND (mmap.inc), which
; einstein_loader.c reads in at start-up.
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init, _snd_init, snd_exit, _snd_exit, _ay_frame, ay_ports
        EXTERN  ay_stop

        SECTION EINSTEIN_SND
ay_ports:   defb    $40             ; bits 6 and 7 of register 7, as the system had them (snd_init); until then port A out, port B in
ay_pending: defb    0               ; plat_idle's frame, not yet ticked
ay_vr:      defb    0               ; the retrace flag as ay_sync last saw it

; void ay_frame(void): a frame has begun (the game waited for one)
_ay_frame:
        ld      a,1
        ld      (ay_pending),a
        ret

; Z if a frame has begun since the last call: the one plat_idle reported, or the retrace flag (status register 2, bit 6) going up
ay_sync:
        ld      a,(ay_pending)
        or      a
        jr      z,ay_look
        xor     a
        ld      (ay_pending),a
        ret                             ; Z
ay_look:
        di
        ld      a,2
        out     (VDP_CMD),a
        ld      a,$8F
        out     (VDP_CMD),a
        in      a,(VDP_CMD)
        ld      c,a
        xor     a
        out     (VDP_CMD),a
        ld      a,$8F
        out     (VDP_CMD),a
        ei
        ld      a,c
        and     $40
        ld      hl,ay_vr
        ld      c,(hl)
        ld      (hl),a
        jr      z,ay_nosync             ; not in the retrace
        ld      a,c
        or      a                       ; it was not: Z, a frame has begun
        ret
ay_nosync:
        or      1                       ; NZ
        ret

; Keep the I/O directions of register 7 (read through port 2, as the system's keyboard code reads its register 15)
snd_init:
_snd_init:
        di
        ld      a,7
        out     (2),a
        in      a,(2)
        and     $C0
        ld      (ay_ports),a
        ei
        ret

; Silence the effect (the volume of channel C).  The registers are the system's again.
snd_exit:
_snd_exit:
        jp      ay_stop
