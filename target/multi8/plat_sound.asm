; The Multi 8's frame clock for the sound (target/common/ay_hooks.asm, target/common/ay_sfx.asm, the PSG at ports $18 and $19, clocked
; at 3.579545 MHz: -DAY_SCALE).  The game runs with interrupts off, and the vertical sync is a short pulse, so the 8253 timer is the clock:
; counter 1 (clocked at 1.9968 MHz) divides by 39936 for 50 Hz, its output clocks counter 2, which counts those pulses down from 65536.
; ay_sync reads counter 2 (a latch command, then the low and high bytes) and says "a frame" once for each pulse since it last looked (up to
; AY_MAXCATCH), so the effects keep time however seldom the game polls.  (Counter 0 is the serial port's baud rate: left alone.)
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init, ay_clock_reset
        IFNDEF  CLOCK_STUB
        PUBLIC  ay_clock
        ENDIF
        IFDEF   CLOCK_STUB
        EXTERN  ay_clock
        ENDIF

        defc    PIT_C1 = $25
        defc    PIT_C2 = $26
        defc    PIT_CTRL = $27
        defc    FRAME_DIVISOR = 39936   ; 1996800 Hz / 50
        defc    AY_MAXCATCH = 8

        SECTION code_user
ay_last:        defw    0               ; counter 2 as it was
ay_pending:     defb    0               ; frames still to be said

; Counters 1 and 2 as above.  (Uses a.)
snd_init:
        ld      a,$74                   ; counter 1: low then high byte, mode 2 (rate generator), binary
        out     (PIT_CTRL),a
        ld      a,FRAME_DIVISOR & 255
        out     (PIT_C1),a
        ld      a,FRAME_DIVISOR / 256
        out     (PIT_C1),a
        ld      a,$B4                   ; counter 2: low then high byte, mode 2, binary
        out     (PIT_CTRL),a
        xor     a                       ; (65536)
        out     (PIT_C2),a
        out     (PIT_C2),a
        ; fall into ay_clock_reset

; The frames since now are the ones to come
ay_clock_reset:
        call    ay_clock
        ld      (ay_last),hl
        xor     a
        ld      (ay_pending),a
        ret

        IFNDEF  CLOCK_STUB
; hl = counter 2 now
ay_clock:
        ld      a,$80                   ; latch counter 2
        out     (PIT_CTRL),a
        in      a,(PIT_C2)
        ld      l,a
        in      a,(PIT_C2)
        ld      h,a
        ret
        ENDIF

; Z for a frame that has gone by (and again for the next, if there are more), NZ if none.  Uses a, de, hl.
ay_sync:
        ld      a,(ay_pending)
        or      a
        jr      z,as_read
        dec     a
        ld      (ay_pending),a
        xor     a
        ret
as_read:
        call    ay_clock
        ld      de,(ay_last)
        ld      (ay_last),hl
        ex      de,hl                   ; hl = the counter as it was, de = now
        or      a
        sbc     hl,de                   ; the pulses between (the counter counts down)
        ld      a,h
        or      a
        jr      nz,as_many
        ld      a,l
        or      a
        jr      z,as_none
        cp      AY_MAXCATCH + 1
        jr      c,as_some
as_many:
        ld      a,AY_MAXCATCH
as_some:
        dec     a                       ; (this one is said now)
        ld      (ay_pending),a
        xor     a
        ret
as_none:
        or      1                       ; NZ
        ret
