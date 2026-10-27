; zone_edge: lines 1358-1370 of disassembly/sim_game.asm (engine)

        IN_DATA
V_zone_x_offset:    defb    0       ; VAR $6592 / 26002 - how far the current x coordiante is in the zone
        IN_CODE

; Steps back in X to find the start of a special zone
; The 96x96 map's zones never reach an edge, so its code is the original's, byte for byte.  The bigger maps (scenarios: a zone that a map's edge cuts
; off, or damaged data) stop at the left edge (column 0) and the top row, instead of walking out of the map.
find_left_edge_of_zone:
        IF      MAP_W == 96
.L6593  ld      hl,V_zone_x_offset
.L6596  ld      a,(ix+0)
        and     192
        cp      192
        ret     nz
        inc     (hl)
        dec     ix
        jr      L6596                   ; (-13)
        ELSE
        ld      hl,V_zone_x_offset
        push    hl
        push    ix
        push    ix
        pop     hl
        call    map_addr_to_xy
        pop     ix
        pop     hl
find_left_edge_scan:
        ld      a,(ix+0)
        and     192
        cp      192
        ret     nz
        ld      a,c
        and     a
        ret     z                       ; malformed zone reaches left map edge
        inc     (hl)
        dec     ix
        dec     c
        jr      find_left_edge_scan
        ENDIF


        IF      MAP_W != 96
; Find a zone's top marker, stopping safely if malformed data reaches row zero.
; Entry: ix = a cell in the zone. Exit: ix = top marker, carry set; carry clear at map edge.
find_top_edge_of_zone:
        ld      de,-MAP_W
find_top_edge_scan:
        bit     5,(ix+0)
        jr      nz,find_top_edge_found
        push    ix
        pop     hl
        call    map_addr_to_xy
        ld      a,b
        and     a
        ret     z
        ld      de,-MAP_W
        add     ix,de
        jr      find_top_edge_scan
find_top_edge_found:
        scf
        ret
        ENDIF
