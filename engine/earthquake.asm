; earthquake: lines 8373-8437 of disassembly/sim_game.asm (engine)

.sim_start_earthquake
.L9125  ld      a,24
        call    set_alert_message
        ld      b,255
        ld      c,0

.L912e  push    bc
        ld      e,c
        srl     e
        srl     e
        srl     e
        srl     e
        call    soundfx1
        pop     bc
        inc     c
        djnz    L912e                   ; (-17)
        call    L90af
        jr      L90dd                   ; (-103)

; Entry used by the UI frame dispatcher: maybe pick a disaster for later
sim_random_disaster:
.L9144  ld      a,(V_disaster_reset)
        and     a
        ret     nz
        call    get_random_number
        ld      hl,(V_random_seed)
        ld      a,h
        and     7
        or      l
        ret     nz
        call    get_random_number
        and     7
        ret     z
        cp      7
        ret     z
        cp      6
        jr      nz,L9169                ; (8)
        call    get_random_number
        and     7
        ret     nz
        ld      a,6
.L9169  ld      (V_disaster_option),a
        ret     


        IN_DATA
V_disaster_option:  defb       $0   ; VAR $916D / 37229 - which disasters are enabled
        IN_CODE

sim_start_disaster:
.L916e  ld      hl,V_disaster_option
        ld      a,(hl)
        and     a
        ret     z
        ld      (hl),0
        cp      1           ;FIRE
        jp      z,sim_start_fire
        cp      2           ;FLOOD
        jp      z,sim_start_flood
        cp      3           ;EARTHQUAKE
        jr      z,sim_start_earthquake                 ; (-95)
        cp      4           ;AIR CRASH
        jp      z,sim_start_aircrash
        cp      5           ;TORNADO
        jp      z,sim_start_tornado
        cp      6           ;NUCLEAR MELTDOWN
        jp      z,sim_start_meltdown
        ret     
