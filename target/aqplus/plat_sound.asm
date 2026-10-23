; The sound hooks of the engine on the Aquarius+'s AY-3-8910: five effects of the Atari ST game (assets/st_sounds.bin, in this order: tools/
; extract_st_sounds.py --effects 33,4,29,40,8), played by target/common/ay_sfx.asm a 50 Hz tick at a time.  The ticks come from the display's
; frames (port $FD bit 0, the vertical sync): ay_poll looks for the start of one and is called whenever the game is idle and as cells are drawn;
; an effect started by the engine in the middle of a calculation (the earthquake's rumble) waits for its ticks itself.
;
; The engine's hooks (see engine/PLATFORM_INTERFACE.md): play_place_sound (a tool is applied), play_crash_sound (a disaster that crashes or
; melts down), play_rising_tone (a fire), play_falling_tone (a flood) and soundfx1 (the earthquake: 255 calls, one a tick here).
; _sound_enabled is the game's Sound option.
        MODULE  plat_sound

        PUBLIC  soundfx1, play_place_sound, play_crash_sound, play_rising_tone, play_falling_tone
        PUBLIC  _sound_enabled, _ay_poll, ay_poll
        EXTERN  ay_start, ay_busy, ay_tick

        defc    SFX_PLACE = 0           ; the effects, in the file's order
        defc    SFX_CRASH = 1
        defc    SFX_RISING = 2
        defc    SFX_FALLING = 3
        defc    SFX_RUMBLE = 4
        defc    PORT_VSYNC = $FD

        SECTION code_user
_sound_enabled: defb    1
ay_vs:  defb    0                       ; the sync bit as it was

play_place_sound:
        push    af
        ld      a,SFX_PLACE
        jr      sfx_start
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

; The earthquake: E is a pitch mask the Spectrum's noise used; here the rumble plays while this is called, a tick for each call
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

; Wait for the start of a frame (the sync bit's change to 0) and tick
ay_edge:
        call    ay_sync
        jr      nz,ay_edge
        jp      ay_tick

; void ay_poll(void): a tick if a frame has begun since it was last called (the game is idle, or has drawn a cell)
_ay_poll:
ay_poll:
        call    ay_sync
        ret     nz
        jp      ay_tick

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
