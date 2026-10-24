; A player for sound effects on an AY-3-8910 (or a YM2149, or the PC-8801's SSG): the Atari ST game's own effects, packed small by
; tools/extract_st_sounds.py into assets/st_sounds.bin, played a tick at a time, 50 ticks a second.
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
; is none; AY_ISR if ay_tick is called by an interrupt of the platform's; AY_SCALE for a chip clocked at 3.579545 MHz, not the ST's 2 MHz), are set at assembly time (-Ca-DAY_ADDR_PORT=n ...); the defaults are the Aquarius+'s.  The variables are in the code section, so
; they sit outside any RAM that video is paged over.
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

; Start the effect in A: A = n.  (Keeps nothing.)  With AY_ISR, interrupts (which call ay_tick) are off while it sets the effect up, and
; on again at the end: so the game must call it with them on.
ay_start:
        IFDEF   AY_ISR
        di
        ENDIF
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
        IFDEF   AY_ISR
        call    ay_write
        ei
        ret
        ELSE
        jp      ay_write
        ENDIF

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
        IFDEF   AY_SCALE
        call    ay_scale
        ENDIF
        ld      c,4
        ld      a,l
        call    ay_write
        ld      c,5
        ld      a,h
        call    ay_write
        IFDEF   AY_SCALE
        ld      a,(ay_period)
        and     31
        ld      l,a
        ld      h,0
        call    ay_scale
        ld      a,h
        or      a
        ld      a,l
        jr      nz,ay_nmax
        cp      32
        jr      c,ay_nset
ay_nmax:
        ld      a,31
ay_nset:
        ELSE
        ld      a,(ay_period)
        and     31
        ENDIF
        ld      c,6                     ; (the scaling uses bc)
        call    ay_write
        ld      c,10
        ld      a,(ay_vol)
        jp      ay_write

        IFDEF   AY_SCALE
; hl := hl * 1.78125 (1 + 1/2 + 1/4 + 1/32), at most 4095: the periods are the ST's, whose chip runs at 2 MHz, for a chip at 3.579545 MHz
; (a factor of 1.7898).  Uses bc, de.
ay_scale:
        ld      d,h
        ld      e,l
        ld      b,h
        ld      c,l
        srl     b
        rr      c
        add     hl,bc
        srl     b
        rr      c
        add     hl,bc
        ld      b,d
        ld      c,e
        ld      a,5
ay_scale_lp:
        srl     b
        rr      c
        dec     a
        jr      nz,ay_scale_lp
        add     hl,bc
        ld      a,h
        cp      16
        ret     c
        ld      hl,4095
        ret
        ENDIF

        IFNDEF  AY_SAA
; Register C of the chip := A.  Keeps hl, de, b.
ay_write:
        push    af
        ld      a,c
        out     (AY_ADDR_PORT),a
        pop     af
        out     (AY_DATA_PORT),a
        ret
        ELSE

; The SAM Coupe's SAA 1099 instead of an AY (assemble with -DAY_SAA).  The player above still says what it wants as AY registers; this
; is the chip behind them.  Writes to the registers of channel C's tone, noise and mixer are kept; the write of its volume, the last of a
; tick, sends the tick to the chip's channel 0:
;     tone     the AY's period P (a square wave of 125000 / P Hz: the ST's 2 MHz clock) is an octave and a tone N of the SAA, whose
;              frequency is 15625 * 2^octave / (511 - N) Hz: so 511 - N = P * 2^octave / 8, which is between 256 and 511 for the octave
;              that puts P * 2^octave in 2048 to 4095, and N is the low byte of its complement
;     noise    the SAA has three rates, 31.3, 15.6 and 7.8 kHz (the AY's 125000 / n Hz: n under 6, under 12, the rest), and a channel
;              that has noise has it instead of its tone (the AY mixes the two): so noise alone is noise, and tone with noise is the tone
;     volume   the AY's steps are logarithmic, the SAA's linear: a table
; Keeps hl, de, b.
SAA_ADDR_PORT   equ     $01FF
SAA_DATA_PORT   equ     $00FF

ay_write:
        push    hl
        push    de
        push    bc
        ld      e,a
        ld      a,c
        cp      10
        jr      z,saa_tick
        cp      8
        jr      nc,saa_done             ; (8 and 9: the silent channels)
        sub     4
        jr      c,saa_done
        ld      c,a
        ld      b,0
        ld      hl,saa_shadow
        add     hl,bc
        ld      (hl),e                  ; tone low, tone high, noise period, mixer
        cp      3
        jr      nz,saa_done
        ld      d,2                     ; the mixer, at the start of an effect: reset the chip, switch it on, and say what channel 0 plays
        ld      a,$1C
        call    saa_put
        ld      d,1
        ld      a,$1C
        call    saa_put
        ld      a,e
        and     4
        ld      d,1                     ; tone, unless its AY bit (2) is set
        jr      z,saa_tone_en
        ld      d,0
saa_tone_en:
        ld      a,$14
        call    saa_put
        ld      a,e                     ; noise, if it is on and the tone is not
        and     36                      ; (bits 5 and 2)
        cp      4
        ld      d,1
        jr      z,saa_noise_en
        ld      d,0
saa_noise_en:
        ld      a,$15
        call    saa_put
saa_done:
        pop     bc
        pop     de
        pop     hl
        ret

; A tick: E = the volume
saa_tick:
        ld      hl,(saa_shadow)         ; the period
        ld      a,h
        and     15
        ld      h,a
        or      l
        jr      nz,saa_period
        inc     l                       ; (0 is 1 on the AY)
saa_period:
        ld      b,0                     ; the octave
saa_oct:
        ld      a,h
        cp      8
        jr      nc,saa_octave
        ld      a,b
        cp      7
        jr      z,saa_high              ; (a pitch beyond the SAA's top: its highest tone)
        add     hl,hl
        inc     b
        jr      saa_oct
saa_high:
        ld      hl,0
saa_octave:                             ; N = low byte of the complement of (hl >> 3)
        ld      a,l
        rrca
        rrca
        rrca
        and     31
        ld      c,a
        ld      a,h
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      c
        cpl
        ld      d,a
        ld      h,b                     ; (the octave: saa_put uses bc)
        ld      a,8
        call    saa_put
        ld      d,h                     ; octave: channel 0 is the low three bits of register $10
        ld      a,$10
        call    saa_put
        ld      a,(saa_shadow + 2)      ; the noise rate
        and     31
        ld      d,0
        cp      6
        jr      c,saa_rate
        inc     d
        cp      12
        jr      c,saa_rate
        inc     d
saa_rate:
        ld      a,$16
        call    saa_put
        ld      a,e                     ; the volume, in both ears
        and     15
        ld      c,a
        ld      b,0
        ld      hl,saa_amp
        add     hl,bc
        ld      d,(hl)
        xor     a
        call    saa_put
        jr      saa_done

; SAA register A := D
saa_put:
        ld      bc,SAA_ADDR_PORT
        out     (c),a
        dec     b
        out     (c),d
        ret

saa_shadow:     defs    4
; the AY's volumes 0 to 15 (3 dB steps, 1 at the top) as the SAA's linear 0 to 15, in both ears
saa_amp:        defb    $00,$00,$00,$00,$00,$11,$11,$11,$11,$22,$33,$44,$55,$88,$BB,$FF

        ENDIF
