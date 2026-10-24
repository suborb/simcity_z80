; The engine's sound hooks, for a platform whose sound is target/common/ay_sfx.asm: six effects of the Atari ST game, packed in
; assets/st_sounds.bin (made by tools/extract_st_sounds.py --effects 33,4,29,40,8,36, in the order of the SFX_ numbers below).
;
; The hooks (engine/PLATFORM_INTERFACE.md):
;     play_place_sound     a tool is refused: the place is taken, or it is not dirt
;     play_built_sound     money was spent: a tool placed something.  Does not cut off an effect that is sounding
;     play_crash_sound     an aircrash or a meltdown
;     play_rising_tone     a fire starts
;     play_falling_tone    a flood starts
;     soundfx1             the earthquake: called 255 times, so it waits one tick for each call and restarts the rumble when it ends
; _sound_enabled is the game's Sound option.
;
; Timing: the player wants a tick 50 times a second.  They come from the display's frames, which the platform's ay_sync finds (NZ unless
; one has just begun): ay_poll looks for the start of one and is called whenever the game is idle and as cells are drawn.  (A 60 Hz
; display skips frames: AY_SKIP, see ay_sfx.asm.)
        MODULE  ay_hooks

        PUBLIC  soundfx1, play_place_sound, play_built_sound, play_crash_sound, play_rising_tone, play_falling_tone
        PUBLIC  _sound_enabled, _ay_poll, ay_poll
        EXTERN  ay_start, ay_busy, ay_tick
        EXTERN  ay_sync                 ; (the platform's: NZ unless a frame has just begun)

        defc    SFX_REFUSED = 0         ; the effects, in the file's order
        defc    SFX_CRASH = 1
        defc    SFX_RISING = 2
        defc    SFX_FALLING = 3
        defc    SFX_RUMBLE = 4
        defc    SFX_BUILT = 5

        SECTION code_user
_sound_enabled: defb    1

play_place_sound:
        push    af
        ld      a,SFX_REFUSED
        jr      sfx_start
play_built_sound:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,(_sound_enabled)
        or      a
        jr      z,sfx_done
        call    ay_busy
        jr      nz,sfx_done             ; (a road dragged out is a tile a call: the chirp does not restart)
        ld      a,SFX_BUILT
        call    ay_start
        jr      sfx_done
play_crash_sound:
        push    af
        ld      a,SFX_CRASH
        jr      sfx_start
play_rising_tone:
        push    af
        ld      a,SFX_RISING
        jr      sfx_start
play_falling_tone:
        push    af
        ld      a,SFX_FALLING
sfx_start:
        push    bc
        push    de
        push    hl
        ld      c,a
        ld      a,(_sound_enabled)
        or      a
        jr      z,sfx_done
        ld      a,c
        call    ay_start
sfx_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; The earthquake: E is the pitch mask of the Spectrum's noise, not used here; the rumble plays while this is called, a tick for each call
soundfx1:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,(_sound_enabled)
        or      a
        jr      z,sfx_done
        call    ay_busy
        jr      nz,fx1_wait
        ld      a,SFX_RUMBLE
        call    ay_start                ; (and again when it ends, until the earthquake does)
fx1_wait:
        call    ay_edge                 ; the next frame, and its tick
        jr      sfx_done

; Wait for the start of a frame (the sync bit's change to 0) and tick (with AY_ISR an interrupt ticks, and this only waits: for as long as
; a frame is expected to take, in case the interrupts are off)
ay_edge:
        ld      bc,0                    ; (a bound, in case the frame clock does not run)
ay_edge_wait:
        push    bc
        call    ay_sync
        pop     bc
        jr      z,ay_edge_tick
        dec     bc
        ld      a,b
        or      c
        jr      nz,ay_edge_wait
ay_edge_tick:
        IFDEF   AY_ISR
        ret
        ELSE
        jp      ay_tick
        ENDIF

; void ay_poll(void): a tick if a frame has begun since it was last called (the game is idle, or has drawn a cell)
_ay_poll:
ay_poll:
        IFDEF   AY_ISR
        ret
        ELSE
        call    ay_sync                 ; (a tick for each frame it says has gone by)
        ret     nz
        call    ay_tick
        jr      ay_poll
        ENDIF
