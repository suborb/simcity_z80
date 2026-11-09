; Time on the Toshiba Pasopia 7: the game has no interrupt, so the frames (60 Hz, for the key repeat and the pace) and the sound's ticks (50 Hz) are worked out from a clock that cannot
; miss time: the Z80 CTC.  Channel 0 is a timer (the CPU clock / 256, a time constant of 256) whose output counts channel 1 (a counter of 256), so that the two channels' counts make a
; 16 bit down counter that falls one every 256 clocks (64 us: 15600 a second), and wraps in 4.2 seconds.  Reading it as often as that, p7_tick adds the time since the last
; reading to two accumulators, in counts: one for frames (260 counts) and one for ticks (312), which their users take whole units from.  (The vertical sync bit, which has been
; counted before, is a pulse of a millisecond a frame: a long stretch of work without a look misses frames.)
; The CTC's channels are also the machine's beeper's, which the game does not use.

        MODULE  plat_time

        PUBLIC  p7_time_init, p7_tick, p7_acc_f, p7_acc_s
        defc    CTC0 = $28
        defc    CTC1 = $29

        SECTION code_user

; The channels programmed and the clock read, for p7_tick's first difference.  Uses af, hl.
p7_time_init:
        ld      a,$27                   ; channel 0: control word, a time constant follows, a software reset, the prescaler 256, a timer, no interrupt
        out     (CTC0),a
        xor     a
        out     (CTC0),a                ; the time constant 256
        ld      a,$47                   ; channel 1: the same, but a counter of the pulses of channel 0's output
        out     (CTC1),a
        xor     a
        out     (CTC1),a
        call    p7_read
        ld      (p7_last),hl
        ld      hl,0
        ld      (p7_acc_f),hl
        ld      (p7_acc_s),hl
        ret

; hl = the 16 bit down counter: channel 1's count and channel 0's (0 is 256), the first read again if the second moved in between.  Uses a.
p7_read:
        push    de
p7_r1:  in      a,(CTC1)
        ld      d,a
        in      a,(CTC0)
        ld      e,a
        in      a,(CTC1)
        cp      d
        jr      nz,p7_r1
        ld      h,d
        ld      l,e
        ld      a,e
        or      a
        jr      nz,p7_r2
        inc     h                       ; (a count of 0 is 256: the step from 1 to 256 is one, as the other counts)
p7_r2:  pop     de
        ret

; The time since the last call, in counts, added to both accumulators (they stop at 65535).  Keeps everything but af.
p7_tick:
        push    hl
        push    de
        call    p7_read
        ex      de,hl                   ; de = now
        ld      hl,(p7_last)
        ld      (p7_last),de
        or      a
        sbc     hl,de                   ; hl = the counts that have passed (it counts down)
        push    hl
        ld      de,(p7_acc_f)
        add     hl,de
        jr      nc,p7_t1
        ld      hl,$FFFF
p7_t1:  ld      (p7_acc_f),hl
        pop     hl
        ld      de,(p7_acc_s)
        add     hl,de
        jr      nc,p7_t2
        ld      hl,$FFFF
p7_t2:  ld      (p7_acc_s),hl
        pop     de
        pop     hl
        ret

p7_last:  defw  0                       ; the counter at the last reading
p7_acc_f: defw  0                       ; the counts not yet taken as frames
p7_acc_s: defw  0                       ; and as the sound's ticks
