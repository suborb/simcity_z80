; tools_a: lines 2698-2732 of disassembly/sim_game.asm (engine)

D_zone_sizes:                        ; $6DAF / 28079
                        ; $6DAF / 28079
        defb    $01, $01    ;Bulldozer
        defb    $01, $01    ;Road
        defb    $01, $01    ;Power lines
        defb    $01, $01    ;Rail road
        defb    $01, $01    ;Park
        defb    $03, $03    ;Residential
        defb    $03, $03    ;Commercial
        defb    $03, $03    ;Industrial
        defb    $03, $03    ;Police station
        defb    $03, $03    ;Fire station
        defb    $04, $04    ;Stadium
        defb    $04, $04    ;Power plant
        defb    $04, $04    ;Seaport
        defb    $06, $06    ;Airport

; Get the size of a zone
;
; Exit: e = zone size x
;       d = zone size y
.get_zone_size
.L6dcb  ld      a,(V_selected_tool)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,D_zone_sizes
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ret     


