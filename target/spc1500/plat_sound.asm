; The Samsung SPC-1500's sound clock (target/common/ay_hooks.asm,
; target/common/ay_sfx.asm with -DAY_PORT16 -DAY_ADDR_PORT=$1C00
; -DAY_DATA_PORT=$1B00): the PSG is
; an AY-3-8910 at 2 MHz (4 MHz / 2), as the Atari ST's and the X1's.  There is
; no frame interrupt in use, so a frame is the display's vertical blank bit
; (port $1A01
; bit 7) changing: ay_sync says Z once for each time it is seen to fall, so the
; game looks at it as cells are drawn and when it is idle.
;
; The display's rate is not certain: with the CRTC values of the IPL's 40 column
; mode (R0 56) MAME runs it at 120 Hz, twice the 60 Hz the game and its sound
; are timed
; for.  snd_init measures the time between two falls of the bit (in passes of a
; loop of known length) and, if the frames are that much shorter than 60 Hz's,
; ay_sync gives one
; frame for each two falls.
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init

        SECTION code_user
ay_vd:  defb    0                       ; the bit as it was
ay_div: defb    1                       ; the falls that make a frame: 1, or 2 if the display runs at twice the rate
ay_cnt: defb    1                       ; the falls still to see for the next frame

; Measure the display's rate: the passes (37 T-states each) of a loop from one
; fall of the bit to the next, 1800 at 60 Hz, 900 at 120.  Each wait is bounded:
; if there is no
; vertical blank to be seen the frame is every fall.
snd_init:
        ld      a,1
        ld      (ay_div),a
        ld      (ay_cnt),a
        ld      bc,$1A01
        ld      hl,0
sn_a:   in      a,(c)                   ; to the bit high,
        and     $80
        jr      nz,sn_b
        dec     hl
        ld      a,h
        or      l
        jr      nz,sn_a
        ret
sn_b:   ld      hl,0
sn_b1:  in      a,(c)                   ; and to it low: a fall,
        and     $80
        jr      z,sn_c
        dec     hl
        ld      a,h
        or      l
        jr      nz,sn_b1
        ret
sn_c:   ld      de,0                    ; then the passes to the next fall (low, high, low)
sn_c1:  inc     de
        ld      a,d
        or      e
        ret     z
        in      a,(c)
        and     $80
        jr      z,sn_c1
sn_c2:  inc     de
        ld      a,d
        or      e
        ret     z
        in      a,(c)
        and     $80
        jr      nz,sn_c2
        ld      hl,1350                 ; fewer passes than that: frames shorter than 50,000 T-states
        or      a
        sbc     hl,de
        ret     c
        ld      a,2
        ld      (ay_div),a
        ld      (ay_cnt),a
        ret

; Z for a frame (the bit has fallen, for the second time if the display runs at
; twice the rate, since the last one), NZ if not.  Uses a, hl.
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
        or      a                       ; it changed: a fall if it is 0
        ret     nz                      ; (it rose: NZ)
        ld      hl,ay_cnt
        dec     (hl)
        jr      nz,as_none
        ld      a,(ay_div)
        ld      (hl),a
        xor     a                       ; Z
        ret
as_none:
        or      1                       ; NZ
        ret
