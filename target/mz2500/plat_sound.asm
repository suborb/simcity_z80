; The MZ-2500's sound (target/common/ay_hooks.asm, target/common/ay_sfx.asm with -DAY_SCALE -DAY_DIV2 -DAY_OPN -DAY_ADDR_PORT=$C8 -DAY_DATA_PORT=$C9): the YM2203's SSG
; (a PSG that is an AY-3-8910 to the program) is at ports $C8 (register) and $C9 (data).  The machine runs with interrupts off, so the sound is ticked as the Aquarius+'s is: ay_poll
; is called when the game is idle and as tiles are drawn, and asks ay_sync whether a tick is due (the 8253's clock: see ay_sync).
        MODULE  plat_sound

        PUBLIC  ay_sync, _mz_snd_init

        SECTION code_user

; Z if a tick of the sound is due, NZ if not: the 8253's channel 0 (31250 Hz, counting down: plat_mz2500.asm's mz_pit_init) is the clock, 625 of its ticks a 50 Hz tick.  The time
; that has gone by since the last call is added to what was not used, so a pass of the game that takes several ticks is made up for by ticks, one a call, until it is caught up (ay_poll
; calls again for each); what is owed is at most three ticks, so that a long wait does not play an effect in a rush.
ay_sync:
        xor     a                       ; the count now
        out     ($e7),a
        in      a,($e4)
        ld      l,a
        in      a,($e4)
        ld      h,a
        ld      de,(ay_last)
        ld      (ay_last),hl
        ex      de,hl                   ; hl = the last count, de = this one
        or      a
        sbc     hl,de                   ; the ticks that have gone by
        ld      de,(ay_acc)
        add     hl,de
        ld      de,AY_TICK
        or      a
        sbc     hl,de
        jr      c,ay_not_yet
        push    hl                      ; a tick is due: what is left is owed, to at most three
        ld      de,AY_TICK * 2
        or      a
        sbc     hl,de
        pop     hl
        jr      c,ay_owed
        ld      hl,AY_TICK * 2
ay_owed:
        ld      (ay_acc),hl
        xor     a                       ; Z
        ret
ay_not_yet:
        add     hl,de                   ; (back to what there was)
        ld      (ay_acc),hl
        or      1                       ; NZ
        ret

        defc    AY_TICK = 625

ay_last:        defw    0
ay_acc:         defw    0

; void mz_snd_init(void): the three channels silent, every tone and noise off, ports A and B (the machine's own) outputs
_mz_snd_init:
        ld      b,3
        ld      c,8
snd_vol:
        ld      a,c
        out     ($c8),a
        xor     a
        out     ($c9),a
        inc     c
        djnz    snd_vol
        ld      a,7
        out     ($c8),a
        ld      a,$ff
        out     ($c9),a
        ret
