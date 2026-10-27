; The map arithmetic of the engine, for every cell of the map, under z88dk-ticks.  test/mapsize/check.py assembles this inside
; target/test/test_platform.asm (-DMAPSIZE_TEST, and the size to test) and runs it.  Every test works out what the engine's routine
; should answer the plain way (by adding, never by shifting) and counts the cells where it does not: mapsize_fail[n], with the
; first of them in mapsize_first[n] (x, then y + 1).
;   0 levelmap_xypos_with_check: inside the map the address, outside (any of the 256 x 256 coordinates) carry clear
;   1 get_power_map_addr: the power map's byte and bit of a tile
;   2 map_addr_to_power_minimap: the same from a map address
;   3 map_addr_to_xy: the tile of a map address
;   4 minimap_xypos_25: a tile's cell in the coverage maps (the index through its low, then its high byte)
;   5 minimap_xypos_50: the cell in the pollution and traffic maps
;   6 view_cell: the map cell it reads (the tile is a digit of the cell's index in base 64, in three passes)
        IN_BSS
mapsize_fail:   defs    2 * 8
mapsize_first:  defs    2 * 8
mapsize_x:      defb    0
mapsize_y:      defb    0
        IN_DATA
mapsize_no:     defb    0
        IN_CODE

; The current test failed at (mapsize_x, mapsize_y)
mapsize_bad:
        push    hl
        push    de
        ld      a,(mapsize_no)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,mapsize_fail
        add     hl,de
        inc     (hl)
        jr      nz,mb1
        inc     hl
        inc     (hl)
mb1:    ld      hl,mapsize_first
        add     hl,de
        inc     hl
        ld      a,(hl)
        and     a
        jr      nz,mb2                  ; (the first one stays)
        ld      a,(mapsize_y)
        inc     a
        ld      (hl),a
        dec     hl
        ld      a,(mapsize_x)
        ld      (hl),a
mb2:    pop     de
        pop     hl
        ret

; hl = a * de, by adding
mapsize_mul:
        ld      hl,0
        and     a
        ret     z
mm1:    add     hl,de
        dec     a
        jr      nz,mm1
        ret

; Run the routine in hl for every cell: b = y, c = x, de = y * MAP_W + x; it calls mapsize_bad when it finds the engine wrong
mapsize_each:
        ld      (mapsize_call+1),hl
        ld      hl,0                    ; the offset of the row
        ld      b,0
mrow:   ld      c,0
mcol:   ld      a,b
        ld      (mapsize_y),a
        ld      a,c
        ld      (mapsize_x),a
        push    hl
        push    bc
        ld      e,c
        ld      d,0
        add     hl,de
        ex      de,hl                   ; de = the offset
mapsize_call:
        call    0
        pop     bc
        pop     hl
        inc     c
        ld      a,c
        cp      MAP_W
        jr      nz,mcol
        ld      de,MAP_W
        add     hl,de
        inc     b
        ld      a,b
        cp      MAP_H
        jr      nz,mrow
        ret

; ---- 0: levelmap_xypos_with_check -------------------------------------------------
mapsize_t0:
        ld      hl,mt0_in
        call    mapsize_each
        ld      b,0                     ; and every coordinate, 0 to 255, inside or not
mt0y:   ld      c,0
mt0x:   ld      a,b
        ld      (mapsize_y),a
        ld      a,c
        ld      (mapsize_x),a
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        sbc     a,a
        ld      d,a                     ; $FF if the engine says inside
        ld      e,0
        ld      a,b
        cp      MAP_H
        jr      nc,mt0n
        ld      a,c
        cp      MAP_W
        jr      nc,mt0n
        ld      e,$ff                   ; it is
mt0n:   ld      a,d
        cp      e
        call    nz,mapsize_bad
        inc     c
        jr      nz,mt0x
        inc     b
        jr      nz,mt0y
        ret
mt0_in:                                 ; hl = the address, carry set
        push    de
        call    levelmap_xypos_with_check
        pop     de
        jr      nc,mt0_bad
        ld      bc,levelmap
        ex      de,hl
        add     hl,bc
        and     a
        sbc     hl,de
        ret     z
mt0_bad:
        jp      mapsize_bad

; hl = the power map's byte of the cell (mapsize_y, mapsize_x), e = its bit, d = its complement, as they should be
mapsize_power_want:
        ld      de,MM_POWER_ROW
        ld      a,(mapsize_y)
        call    mapsize_mul
        ld      a,(mapsize_x)
        rrca
        rrca
        rrca
        and     31
        ld      e,a
        ld      d,0
        add     hl,de
        ld      de,minimaps+MMO_POWER
        add     hl,de
        ld      a,(mapsize_x)
        and     7
        ld      b,a
        ld      a,$80
        inc     b
        jr      mpw2
mpw1:   srl     a
mpw2:   djnz    mpw1
        ld      e,a
        cpl
        ld      d,a
        ret

; compare the engine's answer in hl, e, d with the right one
mapsize_power_check:
        push    hl
        push    de
        call    mapsize_power_want      ; hl, e, d = right
        pop     bc                      ; b = engine's d, c = engine's e
        ld      a,e
        cp      c
        jr      nz,mpc_bad2
        ld      a,d
        cp      b
        jr      nz,mpc_bad2
        pop     de                      ; de = engine's address
        and     a
        sbc     hl,de
        ret     z
        jp      mapsize_bad
mpc_bad2:
        pop     hl
        jp      mapsize_bad

mapsize_t1:
        ld      hl,mt1
        jp      mapsize_each
mt1:    call    get_power_map_addr      ; bc = y, x
        jr      mapsize_power_check

mapsize_t2:
        ld      hl,mt2
        jp      mapsize_each
mt2:    ld      hl,levelmap
        add     hl,de
        call    map_addr_to_power_minimap
        jr      mapsize_power_check

mapsize_t3:
        ld      hl,mt3
        jp      mapsize_each
mt3:    ld      hl,levelmap
        add     hl,de
        call    map_addr_to_xy
        ld      a,(mapsize_y)
        cp      b
        jr      nz,mt3bad
        ld      a,(mapsize_x)
        cp      c
        ret     z
mt3bad: jp      mapsize_bad

; ---- 4, 5: the minimaps' cell of a tile.  The minimap is filled with the low byte of each cell's index, then the high byte
mapsize_fill:                           ; hl = the table, bc = its cells, a = 0 low byte or 1 high byte
        ld      de,0
mf1:    push    af
        and     a
        ld      a,e
        jr      z,mf2
        ld      a,d
mf2:    ld      (hl),a
        pop     af
        inc     hl
        inc     de
        dec     bc
        push    af
        ld      a,b
        or      c
        jr      z,mf3
        pop     af
        jr      mf1
mf3:    pop     af
        ret

mapsize_t4:
        ld      hl,minimaps
        ld      (V_minimap_start),hl
        xor     a
        ld      (mapsize_pass),a
mt4p:   ld      hl,minimaps
        ld      bc,MM25_SIZE
        ld      a,(mapsize_pass)
        call    mapsize_fill
        ld      hl,mt4
        call    mapsize_each
        ld      a,(mapsize_pass)
        inc     a
        ld      (mapsize_pass),a
        cp      2
        jr      nz,mt4p
        ret
mt4:    ; the cell: (y / 4) * MM25_W + x / 4
        push    bc
        call    minimap_xypos_25        ; bc = y, x
        pop     bc
        jr      mapsize_cell_check
        IN_DATA
mapsize_pass:   defb    0
        IN_CODE

; a = the engine's byte of the cell: right if it is the (pass) byte of the index (y >> shift) * width + (x >> shift)
mapsize_cell_check:
        push    af
        ld      a,(mapsize_cell_shift)
        ld      c,a
        ld      a,(mapsize_y)
        call    mapsize_shr             ; y >> shift
        ld      de,(mapsize_cell_w)
        call    mapsize_mul             ; hl = (y >> shift) * width
        ld      a,(mapsize_cell_shift)
        ld      c,a
        ld      a,(mapsize_x)
        call    mapsize_shr
        ld      e,a
        ld      d,0
        add     hl,de                   ; the index
        ld      a,(mapsize_pass)
        and     a
        ld      a,l
        jr      z,mcc1
        ld      a,h
mcc1:   pop     bc
        cp      b
        ret     z
        jp      mapsize_bad

; a = a >> c
mapsize_shr:
        inc     c
        jr      mshr2
mshr1:  srl     a
mshr2:  dec     c
        jr      nz,mshr1
        ret
        IN_DATA
mapsize_cell_shift:     defb    0
mapsize_cell_w:         defw    0
        IN_CODE

mapsize_t5:
        ld      hl,minimaps
        ld      (V_minimap_start),hl
        xor     a
        ld      (mapsize_pass),a
mt5p:   ld      hl,minimaps
        ld      bc,MM50_SIZE
        ld      a,(mapsize_pass)
        call    mapsize_fill
        ld      hl,mt5
        call    mapsize_each
        ld      a,(mapsize_pass)
        inc     a
        ld      (mapsize_pass),a
        cp      2
        jr      nz,mt5p
        ret
mt5:    push    bc
        call    minimap_xypos_50
        pop     bc
        jr      mapsize_cell_check

; ---- 6: view_cell reads the map cell (y, x): the tile's number says which one it was
mapsize_t6:
        xor     a
        ld      (mapsize_pass),a
mt6p:   ld      hl,mt6f
        call    mapsize_each            ; fill the map: the tile is 10 + a digit of the index in base 64
        ld      hl,mt6
        call    mapsize_each
        ld      a,(mapsize_pass)
        inc     a
        ld      (mapsize_pass),a
        cp      3
        jr      nz,mt6p
        ret
mapsize_digit:                          ; a = the digit (by the pass) of the index in de, in base 64
        ld      a,(mapsize_pass)
        and     a
        jr      z,md0
        dec     a
        jr      z,md1
        ld      a,d                     ; pass 2: bits 12 and up
        rrca
        rrca
        rrca
        rrca
        and     15
        ret
md1:    ld      a,d                     ; pass 1: bits 6 to 11
        and     15
        add     a,a
        add     a,a
        ld      l,a
        ld      a,e
        rlca
        rlca
        and     3
        or      l
        ret
md0:    ld      a,e                     ; pass 0: bits 0 to 5
        and     63
        ret
mt6f:   call    mapsize_digit
        add     a,10
        ld      hl,levelmap
        add     hl,de
        ld      (hl),a
        ret
mt6:    push    de
        call    view_cell               ; b = y, c = x -> hl = the tile's art
        ld      de,view_udgs+ART_TILES
        and     a
        sbc     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l                       ; the tile
        ld      a,l
        sub     10
        ld      c,a
        pop     de
        push    bc
        call    mapsize_digit
        pop     bc
        cp      c
        ret     z
        jp      mapsize_bad

; ---- the driver ------------------------------------------------------------------
mapsize_test:
        ld      sp,$fff0
        di
        xor     a
        ld      (mapsize_no),a
        ld      hl,mapsize_tests
mst:    ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,d
        or      e
        jr      z,mapsize_done
        push    hl
        ex      de,hl
        ; cell width and shift for the minimap tests
        ld      de,MM25_W
        ld      a,2
        ld      (mapsize_cell_shift),a
        ld      a,(mapsize_no)
        cp      5
        jr      nz,mst1
        ld      de,MM50_W
        ld      a,1
        ld      (mapsize_cell_shift),a
mst1:   ld      (mapsize_cell_w),de
        call    mst_call
        ld      hl,mapsize_no
        inc     (hl)
        pop     hl
        jr      mst
mst_call:
        jp      (hl)
mapsize_done:
mapsize_end:
        jr      mapsize_end             ; z88dk-ticks stops here (-end)
        IN_RODATA
mapsize_tests:
        defw    mapsize_t0, mapsize_t1, mapsize_t2, mapsize_t3, mapsize_t4, mapsize_t5, mapsize_t6, 0
        IN_CODE
