; The sound hooks of a platform with no sound: the engine calls them and nothing happens.  (A platform
; with sound links its own file instead, e.g. platform/console/plat_sound.asm for the Z88.)
        MODULE  nosound

        PUBLIC  play_place_sound, play_crash_sound, play_rising_tone, play_falling_tone, soundfx1

        SECTION code_user
play_place_sound:
play_crash_sound:
play_rising_tone:
play_falling_tone:
soundfx1:
        ret
