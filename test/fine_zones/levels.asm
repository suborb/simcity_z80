; Every level a zone handler can write, under z88dk-ticks (test/fine_zones/levels.py assembles this inside target/test/test_platform.asm with
; -DLEVELS_TEST and the engine's flags).  A zone of each kind (residential, commercial, industrial) is put at its level 0 in the map; for each land value
; from 0 to 255 (the routine that works it out is patched to return, so the test sets it: V_zone_landval_final) the real DoResidential, DoCommercial or
; DoIndustrial is called with the sim speed block at 0 (so that it always acts), for a few seeds of the random numbers.  What it wrote in the zone's three rows
; is saved, and then get_zone_handler_type is asked for the type of the zone's middle cell, with a check that the stack pointer is as it was.
; The harness patches in: lev_zone0 (the level 0 zone of each kind: three rows of marker, group, piece) and lev_xy (each kind's zone: x, y of its top left cell).
LEV_CASES       equ     3 * 256         ; (a run is one seed: lev_seed_base, patched)

        IN_DATA
lev_zone0:      defs    3 * 9
lev_xy:         defs    3 * 2
lev_seed_n:     defb    0               ; the seed number of this run (patched)
lev_kind:       defb    0
lev_value:      defb    0
lev_cell:       defw    0
lev_sp:         defw    0
lev_stack_bad:  defb    0
lev_out_ptr:    defw    lev_out
lev_unknown:    defb    0               ; what get_zone_handler_type said of a zone of an unknown group, and whether it kept the stack
lev_unknown_stack: defb 0
        IN_BSS
lev_out:        defs    LEV_CASES * 12  ; per case: 9 bytes of rows, the type, whether either call left the stack different, a spare
        IN_CODE

levels_test:
        ld      sp,$fff0
        di
        xor     a
        ld      (V_sim_speed_block),a
        ld      (V_sim_speed_block+1),a
        ld      (V_sim_speed_block+2),a
        ld      (V_sim_speed_block+3),a
        inc     a
        ld      (V_ZonePwrFlg),a
        xor     a
        ld      (lev_kind),a
lev_kind_loop:
        xor     a
        ld      (lev_value),a
lev_value_loop:
        call    lev_one
        ld      hl,lev_value
        inc     (hl)
        jr      nz,lev_value_loop
        ld      hl,lev_kind
        inc     (hl)
        ld      a,(hl)
        cp      3
        jr      nz,lev_kind_loop
        ; a zone whose group is not in the table (group 16: what a neighbour's ring routine used to make of group 17): the lookup must say so and keep the stack
        ld      bc,$0a28                ; x 40, y 10
        call    levelmap_xypos
        ld      (lev_cell),hl
        ld      (hl),$b3
        inc     hl
        ld      (hl),$d0                ; group 16
        inc     hl
        ld      (hl),$c0
        ld      de,MAP_W - 2
        add     hl,de
        ld      (hl),$93
        inc     hl
        ld      (hl),$d0
        inc     hl
        ld      (hl),$c3
        ld      de,MAP_W - 2
        add     hl,de
        ld      (hl),$93
        inc     hl
        ld      (hl),$d0
        inc     hl
        ld      (hl),$c6
        ld      hl,(lev_cell)
        ld      de,MAP_W + 1
        add     hl,de
        xor     a
        ld      (lev_stack_bad),a
        ld      (lev_sp),sp
        call    get_zone_handler_type
        ld      (lev_unknown),a
        call    lev_check_sp
        ld      a,(lev_stack_bad)
        ld      (lev_unknown_stack),a
levels_end:
        jr      levels_end              ; z88dk-ticks stops here (-end)

; one case: the zone back at level 0, a seed and a land value, the handler, the result
lev_one:
        ld      a,(lev_kind)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,lev_xy
        add     hl,de
        ld      c,(hl)                  ; x
        inc     hl
        ld      b,(hl)                  ; y
        ld      (V_map_iter_xy),bc
        call    levelmap_xypos          ; hl = the zone's top left cell
        ld      (lev_cell),hl
        ld      (V_map_iter_addr),hl
        ; the template: 9 bytes a kind
        ld      a,(lev_kind)
        ld      e,a
        add     a,a
        add     a,a
        add     a,a
        add     a,e
        ld      e,a
        ld      d,0
        ld      hl,lev_zone0
        add     hl,de                   ; hl = the template
        ld      de,(lev_cell)           ; de = the map
        ld      b,3
lev_rows:
        push    bc
        push    de
        ld      bc,3
        ldir                            ; (hl and de move on by 3)
        pop     de
        ex      de,hl                   ; hl = this row's start, de = the template on
        push    de
        ld      de,MAP_W
        add     hl,de                   ; the next row
        pop     de
        ex      de,hl                   ; hl = the template, de = the next row
        pop     bc
        djnz    lev_rows
        ; the seed and the land value
        ld      a,(lev_seed_n)
        ld      c,a
        add     a,a
        add     a,a
        add     a,a
        add     a,c
        inc     a
        ld      (V_random_seed),a
        ld      a,c
        xor     $5a
        ld      (V_random_seed+1),a
        ld      a,(lev_value)
        ld      (V_zone_landval_final),a
        xor     a
        ld      (lev_stack_bad),a
        ld      (lev_sp),sp
        ld      a,(lev_kind)
        or      a
        jr      nz,lev_not_res
        call    DoResidential
        jr      lev_called
lev_not_res:
        dec     a
        jr      nz,lev_not_com
        call    DoCommercial
        jr      lev_called
lev_not_com:
        call    DoIndustrial
lev_called:
        call    lev_check_sp
        ; the zone's rows out
        ld      hl,(lev_cell)
        ld      iy,(lev_out_ptr)
        ld      b,3
lev_copy:
        ld      a,(hl)
        ld      (iy+0),a
        inc     hl
        ld      a,(hl)
        ld      (iy+1),a
        inc     hl
        ld      a,(hl)
        ld      (iy+2),a
        ld      de,MAP_W - 2
        add     hl,de
        inc     iy
        inc     iy
        inc     iy
        djnz    lev_copy
        ; the type of the middle cell
        ld      hl,(lev_cell)
        ld      de,MAP_W + 1
        add     hl,de
        ld      (lev_sp),sp
        call    get_zone_handler_type
        ld      (iy+0),a
        call    lev_check_sp
        ld      a,(lev_stack_bad)
        ld      (iy+1),a
        ld      de,12
        ld      hl,(lev_out_ptr)
        add     hl,de
        ld      (lev_out_ptr),hl
        ret

; the stack pointer is what lev_sp says (it was saved just before the call, with the call's return address pushed: so one word less than now)
lev_check_sp:
        ld      hl,0
        add     hl,sp
        inc     hl
        inc     hl                      ; (without this routine's own return address)
        ld      de,(lev_sp)
        or      a
        sbc     hl,de
        ld      a,h
        or      l
        ret     z
        ld      a,1
        ld      (lev_stack_bad),a
        ret
