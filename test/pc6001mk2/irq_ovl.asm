        SECTION code_user
        PUBLIC  _done
        PUBLIC  _stop
_done:  ld      a,2
        out     ($f8),a
_stop:  jr      _stop
; the engine's hooks have no underscore: C names for them
        EXTERN  play_place_sound
        EXTERN  play_built_sound
        PUBLIC  _play_place_sound
        PUBLIC  _play_built_sound
_play_place_sound:
        jp      play_place_sound
_play_built_sound:
        jp      play_built_sound
; the game's mode setup starts the timer ($B0 bit 0 clear: target/pc6001mk2/plat_pc6001mk2.asm); the test does only that
        PUBLIC  _timer_on
_timer_on:
        ld      a,2
        out     ($b0),a
        ret
