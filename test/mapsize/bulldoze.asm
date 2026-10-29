; The bulldozer's rubble sequence (bulldoze_degrade_tile) with the cursor on one row of the map, under z88dk-ticks.  test/mapsize/bulldoze.py assembles this inside
; target/test/test_platform.asm (-DBULLDOZE_TEST) and runs it twice with the cursor row and a "do nothing" flag poked into the image: the map is all rubble ($46) and so
; are the 256 bytes of the stack that follows it, and what the routine changed is the difference between the two runs.
        IN_DATA
bd_y:           defb    0               ; the cursor's map row (poked)
bd_skip:        defb    0               ; non-zero: do not call the routine
        IN_CODE
bulldoze_test:
        ld      sp,$fff0
        di
        ld      hl,levelmap
        ld      de,levelmap+1
        ld      bc,MAP_CELLS+256-1      ; (the map and the stack after it)
        ld      (hl),$46
        ldir
        ld      hl,0
        ld      (V_view_topleft),hl
        ld      a,(bd_y)
        add     a,8
        ld      h,a                     ; row within the view + 8
        ld      l,5                     ; the column (any)
        ld      (V_pointer_charxy),hl
        ld      a,(bd_skip)
        or      a
        call    z,bulldoze_degrade_tile
bulldoze_end:
        jr      bulldoze_end            ; z88dk-ticks stops here (-end)
