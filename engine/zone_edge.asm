; zone_edge: lines 1358-1370 of disassembly/sim_game.asm (engine)

        IN_DATA
V_zone_x_offset:    defb    0       ; VAR $6592 / 26002 - how far the current x coordiante is in the zone
        IN_CODE

; Steps back in X to find the start of a special zone
find_left_edge_of_zone:
.L6593  ld      hl,V_zone_x_offset
.L6596  ld      a,(ix+0)
        and     192
        cp      192
        ret     nz
        inc     (hl)
        dec     ix
        jr      L6596                   ; (-13)
