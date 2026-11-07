; void plat_put_tile(uint8_t col, uint8_t row, const uint8_t *art, uint8_t attr, uint8_t inverse) __smallc: the fast part.  A map cell that already shows this picture is left alone: fp_cache has a word for
; each cell of the map (the picture number, with bit 15 set for the cursor's inverted one; $FFFF if it shows something else).  This looks it up; if the cell is not as wanted it records it and goes on to
; fp_tile_slow (plat_fp1100.c) with the same arguments, which queues the picture.  (The picture number is (art - view_tile_art) / 8.)
        IFNDEF  FP_FLAT
        SECTION code_user
        ENDIF
        PUBLIC  _plat_put_tile
        EXTERN  _fp_cache, _fp_rowcell, _fp_tile_slow, _view_tile_art
        EXTERN  _fp_pend_n, _fp_pend_bank, _fp_pend_cell, _fp_pend_idx, _fp_txt, _fp_blank
        defc    MAP_ROW = 6
        defc    MAP_ROWS = 19

_plat_put_tile:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; inverse
        inc     hl
        inc     hl
        inc     hl
        inc     hl                      ; (past the attribute)
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; art
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      b,(hl)                  ; col
        ex      de,hl
        ld      de,_view_tile_art
        or      a
        sbc     hl,de
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l                       ; the picture number
        ex      de,hl                   ; de
        bit     0,c
        jr      z,pt_up
        set     7,d                     ; (the cursor's)
pt_up:  sub     MAP_ROW
        jp      c,_fp_tile_slow         ; (not in the map: no cache entry)
        cp      MAP_ROWS
        jp      nc,_fp_tile_slow
        ld      l,a
        ld      h,0
        add     hl,hl
        push    de
        ld      de,_fp_rowcell
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the number of the row's first cell
        ld      l,b
        ld      h,0
        add     hl,de
        add     hl,hl
        ld      de,_fp_cache
        add     hl,de                   ; the entry
        pop     de                      ; the word wanted
        ld      a,(hl)
        cp      e
        jr      nz,pt_miss
        inc     hl
        ld      a,(hl)
        cp      d
        ret     z                       ; the cell shows it already
        ld      (hl),d
        jr      pt_fast
pt_miss:
        ld      (hl),e
        inc     hl
        ld      (hl),d
; The cell is to change (hl is at its entry's high byte, de the word).  A plain picture that goes on from the run waiting to be sent (the same bank, the next cell) is added to it here; anything else
; (the cursor's, the first of a run, a bank change) is for fp_tile_slow, which does the sending.
pt_fast:
        bit     7,d
        jp      nz,_fp_tile_slow
        ld      a,(_fp_pend_n)
        or      a
        jp      z,_fp_tile_slow
        cp      40
        jp      nc,_fp_tile_slow
        ld      c,a
        ld      a,d
        or      a
        jr      z,pf1
        ld      a,$40
pf1:    ld      b,a
        ld      a,(_fp_pend_bank)
        cp      b
        jp      nz,_fp_tile_slow
        dec     hl
        push    de                      ; the word
        ld      de,_fp_cache
        or      a
        sbc     hl,de
        srl     h
        rr      l
        ld      de,MAP_ROW * 40
        add     hl,de                   ; the screen cell
        push    hl
        ld      de,(_fp_pend_cell)
        ld      a,c
        add     a,e
        ld      e,a
        jr      nc,pf2
        inc     d
pf2:    or      a
        sbc     hl,de
        jr      nz,pf_no                ; (not the next cell)
        pop     hl                      ; the cell
        pop     de                      ; e = the picture's index
        ld      b,0
        push    hl
        ld      hl,_fp_pend_idx
        add     hl,bc
        ld      (hl),e
        ld      hl,_fp_pend_n
        inc     (hl)
        pop     hl
        ld      de,_fp_txt
        add     hl,de
        ld      (hl),0                  ; (not text any more)
        xor     a
        ld      (_fp_blank),a
        ret
pf_no:  pop     hl
        pop     de
        jp      _fp_tile_slow
