; mapaccess: lines 3870-4333 of disassembly/sim_game.asm (engine)
        IN_DATA
V_minimap_start:    defw        0   ; VAR $753C / 30012 - 753c/30012, address of mini map being handled
        IN_CODE


; Map is rendered at 48x48
minimap_xypos_50:
.L753e  push    bc
        push    de
        srl     b
        srl     c
        ld      l,b
        ld      h,0
        ld      b,h
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de
        add     hl,bc
        ld      bc,(V_minimap_start)
        add     hl,bc
        ld      a,(hl)
        pop     de
        pop     bc
        ret     


; The 96x96 map is rendered at 24x24 resolution
minimap_xypos_25:
.L755a  push    bc
        push    de
        srl     b           ;/4
        srl     b
        srl     c           ;/4
        srl     c
        ld      l,b
        ld      h,0
        ld      b,h
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de
        add     hl,bc
        ld      bc,(V_minimap_start)
        add     hl,bc
        ld      a,(hl)
        pop     de
        pop     bc
        ret     


get_land_value_minimap_value:                                    ; $7579 / 30073 - Point V_minimap_start at land-value minimap and read value at current map pos
.L7579  ld      hl,minimaps+1152
        ld      (V_minimap_start),hl
        jr      minimap_xypos_50                   ; (-67)


; Traffic density map
get_traffic_density_value:
.L7581  ld      hl,minimaps+3456
        ld      (V_minimap_start),hl
        jr      minimap_xypos_50                   ; (-75)

; Police minimap - get value
get_police_minimap_value:                                    ; $7589 / 30089 - Point V_minimap_start at police minimap (minimaps+576) and read value
.L7589  ld      hl,minimaps+576
        ld      (V_minimap_start),hl
        jr      minimap_xypos_25                   ; (-55)

; Fire minimap - get value
get_fire_minimap_value:                                    ; $7591 / 30097 - Point V_minimap_start at fire minimap (minimaps+0) and read value
.L7591  ld      hl,minimaps
        ld      (V_minimap_start),hl
        jr      minimap_xypos_25                   ; (-63)

; Entry:    a=tile data in levelmap
; Exit:     a=properties
;
; We only care about mapping the lower 127 characters (only 90 in the table anyway)
tile_to_flags:
.L7599  push    bc
        push    de
        push    hl
        bit     7,a
        jr      z,L75a4                 ; (4)
        ld      a,$99
        jr      tile_flags_return                   ; (8)
.L75a4  ld      c,a
        ld      b,0
        ld      hl,D_tile_flags              ;Tile flag table
        add     hl,bc
        ld      a,(hl)
tile_flags_return:                                    ; $75AC / 30124 - Restore BC/DE/HL and return; common exit path from tile_to_flags
.L75ac  pop     hl
        pop     de
        pop     bc
        ret     


; Write 3 zone tile + screen-address entries to the printer buffer (entry*9 offset into de table)
.write_zone_print_entries
.L75b0  ld      l,a
        add     a,a
        add     a,a
        add     a,a
        add     a,l
        ld      l,a
        ld      h,0
        add     hl,de
        ex      de,hl
        call    levelmap_xypos
        ld      a,179
        call    write_print_entry
        ld      a,131
        call    write_print_entry
        ld      a,131
        call    write_print_entry
        ret     


; Write one tile + packed screen-address pair to printer buffer, advance both pointers
; Entry: a = tile value, hl = dest in buffer, de = screen coords
.write_print_entry
.L75cd  ld      (hl),a
        inc     hl
        ld      b,d
        ld      a,e
        srl     b
        rra
        srl     b
        rra
        srl     b
        rra
        or      192
        ld      (hl),a
        inc     hl
        ld      a,e
        and     7
        or      192
        ld      (hl),a
        ld      bc,94
        add     hl,bc
        ex      de,hl
        ld      bc,3
        add     hl,bc
        ex      de,hl
        ret

        defb    $D1, $C9        ; padding ($D1=pop de, $C9=ret; unreachable after ret above)

; Convert xy coordinates into 1152 byte minimap @+5760 = Power minimap
;
; 1152 = bit per levelmap tile
;
; What is it doing with data in the printer buffer?
;   - This is a mask byte for the X position
;
; 23296+17 = 80 40 20 10 08 04 02 01
;
; Entry:  bc = levelmap yx coordinates
; Exit:   hl = address in minimap
;          e = bit to set for this tile
;          d = mask to exclude this tile
get_power_map_addr:
.L75f1  push    bc
        ld      a,c
        and     7
        IFDEF PORTABLE
        ld      e,a
        ld      d,0
        ld      hl,D_bit_masks
        add     hl,de
        ELSE
        add     a,17
        ld      l,a
        ld      h,$5b            ;23296+17 -> 23296+17+8 FIXME RELOC
        ENDIF
        ld      a,(hl)          
        ld      l,b
        ld      h,0
        ld      b,h
        add     hl,hl
        add     hl,hl
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de           ;*12
        srl     c
        srl     c
        srl     c
        add     hl,bc
        ld      bc,minimaps+5760
        add     hl,bc
        ld      e,a            
        cpl     
        ld      d,a
        pop     bc
        ret     

; Convert map address to power minimap byte address + bit mask
; Entry: hl = map address
; Exit:  hl = address in power minimap, e = bit to set, d = exclusion mask
.map_addr_to_power_minimap
.L7615  ld      de,65536 - levelmap
        add     hl,de
        ld      a,l
        and     7
        IFDEF PORTABLE
        push    hl
        ld      e,a
        ld      d,0
        ld      hl,D_bit_masks
        add     hl,de
        ld      a,(hl)
        pop     hl
        ELSE
        add     a,17
        ld      e,a
        ld      d,$5b           ;Bit set 80 40 20 10 8 4 2 1
        ld      a,(de)
        ENDIF
        ld      e,a
        cpl     
        ld      d,a
        ld      a,l
        srl     h
        rra     
        srl     h
        rra     
        srl     h
        rra     
        ld      l,a
        ld      bc,minimaps+5760
        add     hl,bc
        ret     

; Convert map address into row/column coordinates
; Entry: hl = pointer into level map
; Exit:  b = row, c = column
.map_addr_to_xy
.L7635  ld      de,65536 - levelmap
        add     hl,de
        xor     a
        ld      de,-96
.L763d  inc     a
        add     hl,de
        jr      c,L763d                 ; (-4)
        sbc     hl,de
        dec     a
        ld      b,a
        ld      c,l
        ret     

; Divide hl / a
; Entry: hl =
;         a =
; Exit:  hl = quotient 
L_div_hl_a:
.L7647  ld      b,16
        ld      c,a
        xor     a
.L764b  add     hl,hl
        rla     
        jr      c,L7652                 ; (3)
        cp      c
        jr      c,L7654                 ; (2)
.L7652  sub     c
        inc     hl
.L7654  djnz    L764b                  ; (-11)
        ret     


; Unused???
l_mult_hlxde:                               ; $7657 / 30295
.L7657
        ld      c,h
        ld      a,l
        ld      hl,0
        ld      b,16
.L765e  add     hl,hl
        rla     
        rl      c
        jr      nc,L7665                ; (1)
        add     hl,de
.L7665  djnz    L765e                  ; (-9)
        ret     

; Return maximum value across a 2x2 minimap block (48-byte row stride)
; Exit: a = maximum value found
.minimap_max_2x2_block
.L7668  ld      d,0
        ld      b,2
.L766c  ld      c,2
        push    hl
.L766f  ld      a,(hl)
        cp      d
        jr      c,L7674                 ; (1)
        ld      d,a
.L7674  inc     hl
        dec     c
        jr      nz,L766f                ; (-9)
        pop     hl
        ld      a,d
        ld      de,48
        add     hl,de
        ld      d,a
        djnz    L766c                   ; (-21)
        ret     

        IN_RODATA
D_special_zone_types:                        ; $7682 / 30338
                        ; $7682 / 30338
        defb    $00         ;Police
        defb    $01         ;Fire
        defb    $02         ;Church
        defb    $03         ;Hospital
        defb    $09         ;Stadium
        defb    $0B         ;Coal
        defb    $0B         ;Nuclear
        defb    $0B         ;Port
        defb    $0A         ;Airport
        defb    $09         ;Residential
        defb    $0A         ;Commercial
        defb    $0B         ;Industrial
        IN_CODE
 
; 
; Entry: bc = coordinates
; Exit:   a = zone type?
;         c = 
;        nc =
;
; Any non-zone tile that has bit 2 or 4 clear return a=9 (residential?)
get_zone_handler_type:                                    ; $768E / 30350 - Given map addr in HL, find zone handler-type byte from D_zone_handler_config; Z=not found
.L768e  push    bc
        ld      a,(hl)
        bit     7,a
        jr      z,L76c9                 ; (53)
        push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96

find_special_zone_top:                                    ; $769D / 30365 - Walk IX upward until bit 5 set; extract tile type from IX+1 to look up handler config
.L769d  bit     5,(ix+0)
        jr      nz,L76a7                ; (4)
        add     ix,de
        jr      find_special_zone_top                   ; (-10)

.L76a7  ld      a,(ix+1)
        and     63
        ld      e,a
        ld      hl,D_zone_handler_config
        ld      bc,4

scan_zone_handler_config:                                    ; $76B3 / 30387 - Linear scan through D_zone_handler_config until tile-type match or $FF sentinel
.L76b3  ld      a,(hl)
        cp      255
        ret     z
        cp      e
        jr      z,L76bd                 ; (3)
        add     hl,bc
        jr      scan_zone_handler_config                   ; (-10)

.L76bd  inc     hl
        ld      c,(hl)
        ld      b,0
        ld      hl,D_special_zone_types
        add     hl,bc
        ld      a,(hl)
        pop     bc
        or      a
        ret     


.L76c9  call    tile_to_flags
        bit     4,a
        jr      z,L76d9                 ; (9)
        bit     6,a
        jr      z,L76d9                 ; (5)
        ld      a,9
        pop     bc
        or      a
        ret     


.L76d9  pop     bc
        scf     
        ret     

        IN_RODATA
D_cardinal_offsets:                     ; $76DC / 30428 - (dx, dy) pairs for 4 cardinal directions: N, E, S, W
        defb    $00, $ff
        defb    $01, $00
        defb    $00,$01
        defb    $ff,$00
        IN_CODE

; Entry: bc = coordinates
;         a = direction
; Exit:  bc = original coordinates
;        hl = levelmap of coords + direction

levelmap_addr_in_direction:                                    ; $76E4 / 30436 - Entry: a=direction, bc=coords; return HL=levelmap address of neighbour cell in that direction
.L76e4  push    bc
        call    coords_add_direction_offset
        call    levelmap_xypos
        pop     bc
        ret     


; Add direction offset (from D_cardinal_offsets table) to bc coordinates
; Entry: a = direction index, bc = coordinates
; Exit:  bc = coordinates + offset for that direction
.coords_add_direction_offset
.L76ed  add     a,a
        ld      e,a
        ld      d,0
        ld      hl,D_cardinal_offsets
        add     hl,de
        ld      a,c
        add     a,(hl)
        ld      c,a
        inc     hl
        ld      a,b
        add     a,(hl)
        ld      b,a
        ret     

        IN_DATA
V_PowerStackNum:    defb        0       ; VAR $76FD / 30461 - power BFS queue tail index (2 bytes per entry, wraps within queue)
        IN_CODE

; Push bc coordinates onto the power BFS queue
.powerqueue_push
.L76fe  ld      hl,V_PowerStackNum
        inc     (hl)
        call    powerqueue_entry_addr
        ld      (hl),c
        inc     hl
        ld      (hl),b
        ret


; Pop bc coordinates from the power BFS queue
.powerqueue_pop
.L7709  call    powerqueue_entry_addr
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        ld      hl,V_PowerStackNum
        dec     (hl)
        ret


; Return hl = address of current power queue entry (V_PowerStackNum * 2 + queue base)
.powerqueue_entry_addr
.L7714  ld      a,(V_PowerStackNum)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,V_powerqueue
        add     hl,de
        ret     


.increment_month  
        ld      hl,V_month
        ld      a,(hl)
        inc     a
        cp      12
        jr      z,increment_year                 ; (2)
        ld      (hl),a
        ret     
.increment_year  
        xor     a
        ld      (hl),a
        ld      hl,(V_year)
        inc     hl
        ld      (V_year),hl
        ret     

