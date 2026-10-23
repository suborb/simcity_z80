; Sound effects for a machine with an AY-3-8910 (or a YM2149, or the PC-8801's SSG): the Atari ST game's own effects, packed small by
; tools/extract_st_sounds.py (assets/st_sounds.bin) and played a tick at a time, 50 ticks a second.
;
; An effect is one voice, on channel C: a tone and/or noise, the tone period swept in steps and the volume following a curve.  Packed:
;     mixer, the length of the volume stream, the first tone period (a word),
;     the volume as runs of equal ticks, a byte each (count << 4 | volume), 0 to end,
;     the tone period as segments of ticks that change it by the same amount each (a count with bit 7 set for a 16 bit delta, then the
;     delta, one byte or two), 0 to end.
; The noise period is the tone period's low byte (the chip uses five bits of it).  A file is a count, a word offset to each effect, the effects.
;
;     void ay_play(uint8_t n) __smallc    start effect n (0 up: the order the file was made in); one that is sounding stops
;     void ay_tick(void)                  one 50 Hz tick of the sounding effect: the platform calls it each frame it finds (see AY_SKIP)
;     void ay_stop(void)                  silence
;     ay_start                            the same as ay_play for assembler: A = n
;     ay_busy                             Z if no effect is sounding (A = 0)
;
; The chip's address and data ports, and how many of 256 frames to skip to make 50 Hz of a faster display (a 60 Hz one: 43; the default
; is none), are set at assembly time (-Ca-DAY_ADDR_PORT=n ...); the defaults are the Aquarius+'s.  The variables are in the code section: a
; platform whose video RAM is paged over some of its RAM needs them where it is not.
        MODULE  ay_sfx

        PUBLIC  _ay_play, _ay_tick, _ay_stop, ay_start, ay_busy, ay_tick, ay_stop
        PUBLIC  _ay_sfx_data

        IFNDEF  AY_ADDR_PORT
        defc    AY_ADDR_PORT = $F7
        ENDIF
        IFNDEF  AY_DATA_PORT
        defc    AY_DATA_PORT = $F6
        ENDIF
        IFNDEF  AY_SKIP
        defc    AY_SKIP = 0
        ENDIF

        SECTION code_user

; The data
_ay_sfx_data:
        BINARY  "assets/st_sounds.bin"

; The player's state
ay_active:  defb    0
ay_first:   defb    0                   ; the next tick is the effect's first (its period is the first one, not stepped)
ay_acc:     defb    0                   ; the frame skip's accumulator
ay_vleft:   defb    0                   ; ticks left of the volume run
ay_vol:     defb    0
ay_pleft:   defb    0                   ; ticks left of the period segment
ay_period:  defw    0
ay_delta:   defw    0
ay_vptr:    defw    0
ay_pptr:    defw    0

; void ay_play(uint8_t n) __smallc
_ay_play:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        call    ay_start
        ret

; Start the effect in A: A = n.  (Keeps nothing.)
ay_start:
        ld      hl,_ay_sfx_data + 1
        add     a,a
        ld      e,a
        ld      d,0
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the effect's offset
        ld      hl,_ay_sfx_data
        add     hl,de
        ld      a,(hl)                  ; the mixer
        inc     hl
        ld      c,(hl)                  ; the length of the volume stream
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the first period
        inc     hl
        ld      (ay_period),de
        ld      (ay_vptr),hl            ; the volume runs follow ...
        ld      b,0
        add     hl,bc
        ld      (ay_pptr),hl            ; ... and then the period segments
        ld      b,a                     ; (the mixer)
        xor     a
        ld      (ay_vleft),a
        ld      (ay_pleft),a
        ld      (ay_delta),a
        ld      (ay_delta + 1),a
        inc     a
        ld      (ay_first),a
        ld      (ay_active),a
        ld      c,8                     ; channels A and B silent, the mixer as the effect has it
        xor     a
        call    ay_write
        ld      c,9
        xor     a
        call    ay_write
        ld      c,7
        ld      a,b
        jp      ay_write

; void ay_stop(void)
_ay_stop:
ay_stop:
        xor     a
        ld      (ay_active),a
        ld      c,10                    ; channel C's volume
        jp      ay_write

; Z if nothing is sounding
ay_busy:
        ld      a,(ay_active)
        or      a
        ret

; void ay_tick(void)
_ay_tick:
ay_tick:
        ld      a,(ay_active)
        or      a
        ret     z
        IF      AY_SKIP
        ld      a,(ay_acc)
        add     a,AY_SKIP
        ld      (ay_acc),a
        ret     c                       ; a frame in a few is not a tick: the display is faster than 50 Hz
        ENDIF
        ld      a,(ay_vleft)            ; the volume
        or      a
        jr      nz,ay_vol_go
        ld      hl,(ay_vptr)
        ld      a,(hl)
        inc     hl
        or      a
        jr      z,ay_stop               ; the end of the effect: silence
        ld      (ay_vptr),hl
        ld      b,a
        and     15
        ld      (ay_vol),a
        ld      a,b
        rrca
        rrca
        rrca
        rrca
        and     15                      ; the run's length
ay_vol_go:
        dec     a
        ld      (ay_vleft),a
        ld      a,(ay_first)            ; the period: the first tick has the first period, the others step it
        or      a
        jr      z,ay_step
        xor     a
        ld      (ay_first),a
        jr      ay_out
ay_step:
        ld      a,(ay_pleft)
        or      a
        jr      nz,ay_have
        ld      hl,(ay_pptr)            ; the next segment
        ld      a,(hl)
        or      a
        jr      z,ay_hold               ; none left: the period stays
        inc     hl
        ld      b,a
        and     $7F
        ld      (ay_pleft),a
        ld      e,(hl)
        inc     hl
        bit     7,b
        jr      nz,ay_wide
        ld      a,e                     ; a byte, signed
        add     a,a
        sbc     a,a
        ld      d,a
        jr      ay_seg
ay_wide:
        ld      d,(hl)
        inc     hl
ay_seg:
        ld      (ay_pptr),hl
        ld      (ay_delta),de
        jr      ay_have
ay_hold:
        ld      hl,0                    ; none left: the period stays as it is
        ld      (ay_delta),hl
        ld      a,255
        ld      (ay_pleft),a
ay_have:
        ld      hl,(ay_period)
        ld      de,(ay_delta)
        add     hl,de
        ld      a,h
        and     15
        ld      h,a
        ld      (ay_period),hl
        ld      hl,ay_pleft
        dec     (hl)
ay_out:
        ld      hl,(ay_period)          ; channel C's tone, its noise (the same low byte) and its volume
        ld      c,4
        ld      a,l
        call    ay_write
        ld      c,5
        ld      a,h
        call    ay_write
        ld      c,6
        ld      a,(ay_period)
        and     31
        call    ay_write
        ld      c,10
        ld      a,(ay_vol)
        ; falls into ay_write

; Register C of the chip := A.  Keeps hl, de, b.
ay_write:
        push    af
        ld      a,c
        out     (AY_ADDR_PORT),a
        pop     af
        out     (AY_DATA_PORT),a
        ret
