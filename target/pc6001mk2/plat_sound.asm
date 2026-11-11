; PC-6001mkII sound: the AY-3-8910 at $A0 (register) and $A1 (data), clock 1.9968 MHz (tone = 1.9968 MHz / (16 * period), the noise the same with a 5 bit period).  Channel A only.
; The effects are written from scratch after the shapes of the CPC game's (its PSG writes and loops, disassembly/cpc_game.asm: a 312 Hz beep, noise with its volume falling, noise
; sweeps, a rumble that swells and fades), as short tables played by timer_isr's tick (target/pc6001mk2/plat_irq.asm, 61 Hz).
; An effect is segments of six bytes, ended by a 0:
;     ticks        how long
;     noise        the noise period (0-31) at the start, or $FF for none
;     slide        added to it every tick (signed; it wraps at 32)
;     tone lo, hi  the tone period, or $FF in the high byte for none
;     volume       bits 0-3 the volume at the start, bits 4-6 n: it changes by 1 every n ticks (0: it does not), bit 7: rises (else falls)
; The hooks are the engine's (engine/PLATFORM_INTERFACE.md): refused, built (not if one is sounding), crash (an aircrash, a meltdown), rising (a fire), falling (a flood), and
; soundfx1, the earthquake: called 255 times, it starts the rumble if there is none, and waits a tick.
        SECTION code_user
        PUBLIC  _sound_enabled
        PUBLIC  play_place_sound, play_built_sound, play_crash_sound, play_rising_tone, play_falling_tone, soundfx1
        PUBLIC  snd_tick, snd_init
        EXTERN  _pc_wait_frame

        defc    SFX_REFUSED = 0
        defc    SFX_CRASH = 1
        defc    SFX_RISING = 2
        defc    SFX_FALLING = 3
        defc    SFX_RUMBLE = 4
        defc    SFX_BUILT = 5

_sound_enabled: defb 1

; ay_w: a = register, e = value
ay_w:   out     ($a0),a
        ld      a,e
        out     ($a1),a
        ret

; snd_init: silence (mixer: all off, the I/O ports as the BASIC has them: A in, B out)
snd_init:
        ld      e,$bf
        ld      a,7
        call    ay_w
        ld      e,0
        ld      a,8
        jp      ay_w

play_place_sound:
        push    af
        ld      a,SFX_REFUSED
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
        jr      sfx_start
play_built_sound:
        push    af
        ld      a,(snd_ptr + 1)
        or      a
        jr      nz,sfx_off              ; (a road dragged out is a tile a call: the chirp does not restart)
        ld      a,SFX_BUILT
sfx_start:
        push    bc
        push    de
        push    hl
        call    sfx_go
        pop     hl
        pop     de
        pop     bc
sfx_off:
        pop     af
        ret

; sfx_go: effect a, unless the sound is off (clobbers a c d e hl)
sfx_go: ld      c,a
        ld      a,(_sound_enabled)
        or      a
        ret     z
        ld      a,c
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,sfx_table
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        di
        xor     a
        ld      (snd_cnt),a
        ld      (snd_ptr),de
        ei
        ret

soundfx1:
        push    af
        push    bc
        push    de
        push    hl
        ld      a,(_sound_enabled)
        or      a
        jr      z,fx_done
        ld      a,(snd_ptr + 1)
        or      a
        jr      nz,fx_wait
        ld      a,SFX_RUMBLE
        call    sfx_go                  ; (and again when it ends, until the earthquake does)
fx_wait:
        call    _pc_wait_frame
fx_done:
        pop     hl
        pop     de
        pop     bc
        pop     af
        ret

; snd_tick: one tick of the effect sounding (the timer interrupt: it keeps what it uses)
snd_tick:
        ld      hl,(snd_ptr)
        ld      a,h
        or      l
        ret     z
        push    bc
        push    de
        ld      a,(snd_cnt)
        or      a
        jr      nz,st_out
        ld      a,(hl)                  ; the next segment
        or      a
        jp      z,st_end
        ld      (snd_cnt),a
        inc     hl
        ld      de,snd_np
        ld      bc,5
        ldir                            ; noise, slide, tone lo, tone hi, volume byte
        ld      (snd_ptr),hl
        ld      a,(snd_vb)
        ld      c,a
        and     $0f
        ld      (snd_vol),a
        ld      a,c
        rrca
        rrca
        rrca
        rrca
        and     $0f
        ld      (snd_vr),a              ; bit 3 rises, bits 0-2 the ticks between steps
        and     7
        ld      (snd_vc),a
st_out: ld      e,$b6                   ; the mixer: tone and noise of channel A on or off
        ld      a,(snd_th)
        cp      $ff
        jr      nz,mx1
        inc     e
mx1:    ld      a,(snd_np)
        cp      $ff
        jr      nz,mx2
        ld      a,e
        or      8
        ld      e,a
mx2:    ld      a,7
        call    ay_w
        ld      a,(snd_vol)
        ld      e,a
        ld      a,8
        call    ay_w
        ld      a,(snd_th)
        cp      $ff
        jr      z,nt
        ld      e,a
        ld      a,1
        call    ay_w
        ld      a,(snd_tl)
        ld      e,a
        xor     a
        call    ay_w
nt:     ld      a,(snd_np)
        cp      $ff
        jr      z,adv
        ld      e,a
        ld      a,6
        call    ay_w
adv:    ld      hl,snd_cnt
        dec     (hl)
        ld      a,(snd_np)              ; the noise slides
        cp      $ff
        jr      z,vstep
        ld      hl,snd_nd
        add     a,(hl)
        and     $1f
        ld      (snd_np),a
vstep:  ld      a,(snd_vr)              ; the volume steps
        and     7
        jr      z,st_done
        ld      hl,snd_vc
        dec     (hl)
        jr      nz,st_done
        ld      (hl),a
        ld      a,(snd_vr)
        and     8
        ld      a,(snd_vol)
        jr      z,vdown
        cp      15
        jr      z,st_done
        inc     a
        jr      vset
vdown:  or      a
        jr      z,st_done
        dec     a
vset:   ld      (snd_vol),a
st_done:
        pop     de
        pop     bc
        ret
st_end: ld      hl,0
        ld      (snd_ptr),hl
        call    snd_init
        jr      st_done

        MACRO   SEG ticks, noise, slide, tone, vol
        defb    ticks, noise, slide
        IF      tone == -1
        defb    $00, $ff
        ELSE
        defb    tone & $ff, tone / 256
        ENDIF
        defb    vol
        ENDM

sfx_table:
        defw    fx_refused, fx_crash, fx_rising, fx_falling, fx_rumble, fx_built

fx_refused:                             ; a beep: 312 Hz as the CPC's, full volume, a fifth of a second
        SEG     12, $ff, 0, 400, $0f
        defb    0
fx_crash:                               ; noise, the volume falling from 15 to 0 over about two seconds
        SEG     105, 20, 0, -1, $7f
        defb    0
fx_rising:                              ; the noise's period falling 31 to 0, twice: it rises
        SEG     32, 31, $ff, -1, $0a
        SEG     32, 31, $ff, -1, $0a
        defb    0
fx_falling:                             ; the period rising 0 to 15, twice: it falls
        SEG     16, 0, 1, -1, $0a
        SEG     16, 0, 1, -1, $0a
        defb    0
fx_rumble:                              ; the noise swells for a second and a half, then fades for nearly two
        SEG     90, 20, 0, -1, $e0
        SEG     105, 20, 0, -1, $7f
        defb    0
fx_built:                               ; two short blips
        SEG     3, $ff, 0, 300, $0a
        SEG     3, $ff, 0, 220, $09
        defb    0

        SECTION bss_user
snd_ptr: defw   0
snd_cnt: defb   0
snd_np:  defb   0
snd_nd:  defb   0
snd_tl:  defb   0
snd_th:  defb   0
snd_vb:  defb   0
snd_vol: defb   0
snd_vr:  defb   0
snd_vc:  defb   0
