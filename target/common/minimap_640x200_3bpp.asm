; Row builder for the native pixel mini maps (HAVE_MINIMAP_NATIVE, see ui/minimap.h), in assembler because C is too slow
; for a full tile row.  For 640x200 screens of 3 bits a pixel, three planes (the Multi 8, the PC-8801).  Plain Z80 on the engine's tables; drawing is the platform's plat_put_minirow().  Row sy covers
; tile row 2 * sy.  Colours are 3 bits: bit 0 blue, 1 red, 2 green.  Both entry points keep IX.
;
; Flat colour mode:
;     void minimap_fast(uint8_t v, uint8_t sy, uint8_t *out) __smallc
; writes the row's 96 colours to out, for every view but crime, which is in ui/minimap.c.
;
; Art mode (HAVE_MINIMAP_ART, defined for the assembler as well as the C): a tile is its own picture at a quarter of the
; size, 4 columns by 3 lines of colour, 5 bytes a picture (tools/extract_cpc_tiles.py --mini).  A view gives some tiles a
; level (a colour, 1..7); the ground of such a tile's picture is drawn in that colour and its shape is left as it is.
; Tiles with no level are drawn as they are.
;     void minimap_fast(uint8_t v, uint8_t sy) __smallc     builds row sy in mm_row
;     void minimap_tiles(uint8_t sy) __smallc               the same from the levels already in mm_col (for crime)
; mm_row is the row as three planes (blue, red, green) of three lines of 48 bytes, 4 pixels a tile, the left tile in the
; high nibble: plane k, line j at 144 k + 48 j.  It is in low RAM so that a platform with paged video memory can copy
; from it.
        MODULE  minimap_640x200_3bpp
        INCLUDE "sections.asm"

        PUBLIC  _minimap_fast
        EXTERN  _levelmap, _minimaps, _D_tile_flags

        defc    C_DIRT = 0
        defc    C_WATER = 1
        defc    C_FIRE = 2              ; fire, and the services, power plants and the like
        defc    C_IND = 3
        defc    C_TREES = 4
        defc    C_RES = 5
        defc    C_COM = 6
        defc    C_ROAD = 7              ; roads, rails and wires: the network

        INCLUDE "mapsize.inc"
        defc    OFF_FIRE = MMO_FIRE      ; into minimaps (ui/minimap.c)
        defc    OFF_POLICE = MMO_POLICE
        defc    OFF_POLLUTION = MMO_POLLUTION
        defc    OFF_TRAFFIC = MMO_TRAFFIC
        defc    OFF_POWER = MMO_POWER

        IN_BSS
        IFDEF   HAVE_MINIMAP_SQUARE
        PUBLIC  _mm_odd
_mm_odd:
mm_odd: defb    0                       ; set for the odd tile row of the pair sy covers
        ENDIF
mm_sy:  defb    0
mm_out: defw    0
        IFDEF   HAVE_MINIMAP_ART
        PUBLIC  _mm_col
_mm_col:
mm_col: defs    96                      ; the level of each tile for the view (0: none), for the city's pictures to be drawn in
mm_base: defw   0                       ; a large zone's first piece (picture 94 + this + k for the cell k from its marker)
mm_k:   defb    0                       ; the cell's place from its zone's marker
mm_dp:  defw    0                       ; where the pair's first byte goes in mm_row
mm_cnt: defb    0
mm_lp:  defw    0                       ; the next tile of the row
mm_ip:  defw    0                       ; the next level
mm_nt:  defs    10                      ; a picture's nine nibbles and its ground colour
mm_g:   defs    3                       ; the ground, a nibble of ones in the planes that have it
mm_na:  defs    9                       ; the nibbles of a pair of tiles' left tile, shifted left
mm_nb:  defs    9                       ; ... and of the right
        ENDIF

        IN_CODE
_minimap_fast:
        push    ix
        ld      hl,4                    ; the return address and IX are on the stack
        add     hl,sp
        IFDEF   HAVE_MINIMAP_ART
        ld      de,mm_col
        ELSE
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; out
        inc     hl
        ENDIF
        ld      (mm_out),de
        ld      a,(hl)                  ; sy
        ld      (mm_sy),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; the view
        push    de
        pop     ix
        cp      2                       ; MM_POLLUTION
        jp      z,mm_pollution
        cp      5                       ; MM_TRAFFIC
        jp      z,mm_traffic
        cp      3                       ; MM_POLICE
        jp      z,mm_police
        cp      4                       ; MM_FIRE
        jp      z,mm_fire
        cp      6                       ; MM_POWER
        jp      z,mm_power
        cp      7                       ; MM_TRANSPORT
        jp      z,mm_transport
        IFDEF   HAVE_MINIMAP_ART
        ld      hl,mm_col               ; the city: no levels
        ld      de,mm_col + 1
        ld      bc,95
        ld      (hl),0
        ldir
        jp      mm_done
        ELSE
        call    mm_city
        ENDIF
mm_done:
        IFDEF   HAVE_MINIMAP_ART
        call    mm_tiles
        ENDIF
mm_ret: pop     ix
        ret

; hl = levelmap + MAP_W * 2 * sy, the start of tile row 2 * sy (HAVE_MINIMAP_SQUARE: the next row if mm_odd is set)
mm_levelrow:
        ld      a,(mm_sy)
        IF      MAP_W == 96
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 64 sy
        ld      d,h
        ld      e,l
        add     hl,hl                   ; 128 sy
        add     hl,de
        ELIF    MAP_W == 120
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 16 sy
        ld      b,h
        ld      c,l
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 256 sy
        and     a
        sbc     hl,bc                   ; 240 sy
        ELSE
        call    UNSUPPORTED_MAP_SIZE
        ENDIF
        ld      de,_levelmap
        add     hl,de
        IFDEF   HAVE_MINIMAP_SQUARE
        ld      a,(mm_odd)
        or      a
        ret     z
        ld      de,MAP_W
        add     hl,de
        ENDIF
        ret

; City colours for the row, at ix.  A large zone's row starts with a marker cell (bit 7 set, bit 6 clear) followed by a cell
; with the group; the rest of its cells (bits 7 and 6 set) take the colour the marker's group gives.
mm_city:
        call    mm_levelrow
        ld      b,MAP_W
        ld      c,C_FIRE                ; the zone colour so far
mm_c1:  ld      a,(hl)
        inc     hl
        cp      94
        jr      nc,mm_big
        ld      e,a
        ld      d,0
        push    hl
        ld      hl,mm_tilecol
        add     hl,de
        ld      a,(hl)
        pop     hl
mm_c2:  ld      (ix+0),a
        inc     ix
        djnz    mm_c1
        ret
mm_big: cp      128
        jr      nc,mm_zone
        xor     a                       ; ordinary tiles above the table: dirt
        jr      mm_c2
mm_zone:
        cp      192
        jr      nc,mm_zc                ; the rest of a zone's row
        ld      a,(hl)                  ; a marker: the group is next
        and     63
        ld      c,C_FIRE                ; the services
        cp      $11
        jr      c,mm_zc
        ld      c,C_RES                 ; $11..$14
        cp      $15
        jr      c,mm_zc
        ld      c,C_COM                 ; $15..$18
        cp      $19
        jr      c,mm_zc
        ld      c,C_FIRE
        cp      $1A
        jr      c,mm_zc
        ld      c,C_IND                 ; $1A..$1D
        cp      $1E
        jr      c,mm_zc
        ld      c,C_FIRE
mm_zc:  ld      a,c
        jr      mm_c2

; Pollution and traffic: a 48x48 map of 0..255.  An eighth of the value is the colour, two tiles to an entry; row sy.
mm_pollution:
        ld      de,_minimaps + OFF_POLLUTION
        jr      mm_density
mm_traffic:
        ld      de,_minimaps + OFF_TRAFFIC
mm_density:
        ld      a,(mm_sy)
        ld      l,a
        ld      h,0
        IF      MM50_W == 48
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,bc                   ; 3 sy
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 48 sy
        ELIF    MM50_W == 60
        push    de                      ; preserve the minimap base address
        add     hl,hl
        add     hl,hl                   ; 4 sy
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 64 sy
        and     a
        sbc     hl,bc                   ; 60 sy
        pop     de
        ELSE
        call    UNSUPPORTED_MAP_SIZE
        ENDIF
        add     hl,de
        ld      b,MM50_W
mm_d1:  ld      a,(hl)
        inc     hl
        rrca
        rrca
        rrca
        rrca
        rrca
        and     7
        ld      (ix+0),a
        ld      (ix+1),a
        inc     ix
        inc     ix
        djnz    mm_d1
        jp      mm_done

; Police and fire cover: a 24x24 map of 0..15.  Half the value is the colour, four tiles to an entry; row sy / 2.
mm_police:
        ld      de,_minimaps + OFF_POLICE
        jr      mm_cover
mm_fire:
        ld      de,_minimaps + OFF_FIRE
mm_cover:
        ld      a,(mm_sy)
        srl     a
        ld      l,a
        ld      h,0
        IF      MM25_W == 24
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,bc                   ; 3 * (sy / 2)
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 24 * (sy / 2)
        ELIF    MM25_W == 30
        add     hl,hl                   ; 2 * (sy / 2)
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 32 * (sy / 2)
        and     a
        sbc     hl,bc                   ; 30 * (sy / 2)
        ELSE
        call    UNSUPPORTED_MAP_SIZE
        ENDIF
        add     hl,de
        ld      b,MM25_W
mm_v1:  ld      a,(hl)
        inc     hl
        srl     a
        ld      (ix+0),a
        ld      (ix+1),a
        ld      (ix+2),a
        ld      (ix+3),a
        inc     ix
        inc     ix
        inc     ix
        inc     ix
        djnz    mm_v1
        jp      mm_done

; Power: the city, yellow where there is power and red where something is built without it.  The map is a bit a tile.
mm_power:
        call    mm_city
        ld      ix,(mm_out)
        ld      a,(mm_sy)
        ld      l,a
        ld      h,0
        ld      d,h
        ld      e,l
        IF      MM_POWER_ROW == 12
        add     hl,hl
        add     hl,de                   ; 3 sy
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 24 sy: 12 bytes a row of tiles, two rows a map row
        ELIF    MM_POWER_ROW == 15
        add     hl,hl                   ; 2 sy
        ld      b,h
        ld      c,l
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ; 32 sy
        and     a
        sbc     hl,bc                   ; 30 sy
        ELSE
        call    UNSUPPORTED_MAP_SIZE
        ENDIF
        ld      de,_minimaps + OFF_POWER
        add     hl,de
        IFDEF   HAVE_MINIMAP_SQUARE
        ld      a,(mm_odd)
        or      a
        jr      z,mm_p0
        ld      de,MM_POWER_ROW
        add     hl,de
mm_p0:
        ENDIF
        ld      b,MM_POWER_ROW
mm_p1:  ld      c,(hl)
        inc     hl
        ld      d,8
mm_p2:  sla     c
        jr      nc,mm_p3
        ld      (ix+0),C_COM
        jr      mm_p4
mm_p3:  ld      a,(ix+0)                ; without power: a zone or a service is red, water is itself, the rest dirt
        push    hl
        ld      hl,mm_unpowered
        add     a,l
        ld      l,a
        jr      nc,mm_p5
        inc     h
mm_p5:  ld      a,(hl)
        pop     hl
        ld      (ix+0),a
mm_p4:  inc     ix
        dec     d
        jr      nz,mm_p2
        djnz    mm_p1
        jp      mm_done

; Transport: roads and rails (tile flags 2 and 4) white, water blue, the rest black.
mm_transport:
        call    mm_city
        ld      ix,(mm_out)
        call    mm_levelrow
        ld      b,MAP_W
mm_t1:  ld      a,(hl)
        inc     hl
        cp      128
        jr      nc,mm_t3
        push    hl
        ld      e,a
        ld      d,0
        ld      hl,_D_tile_flags
        add     hl,de
        ld      a,(hl)
        pop     hl
        and     6
        jr      z,mm_t3
        ld      (ix+0),C_ROAD
        jr      mm_t4
mm_t3:  ld      a,(ix+0)
        cp      C_WATER
        jr      z,mm_t4
        ld      (ix+0),C_DIRT
mm_t4:  inc     ix
        djnz    mm_t1
        jp      mm_done

        IN_RODATA
mm_unpowered:                           ; by colour: a zone or a service is red, water stays, the rest dirt
        defb    C_DIRT, C_WATER, C_FIRE, C_FIRE, C_DIRT, C_FIRE, C_FIRE, C_DIRT
mm_tilecol:                             ; the engine's ordinary tiles 0..93: 0..5 water, 6 trees, 7..55 roads, rails and wires,
                                        ; 60..67 houses, 69..72 and 90, 91 fire, 84..86 the zones' own tiles, 92, 93 water
        defb    C_WATER, C_WATER, C_DIRT, C_WATER, C_WATER, C_WATER, C_TREES, C_ROAD      ; 0..7
        defb    C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD      ; 8..15
        defb    C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD      ; 16..23
        defb    C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD      ; 24..31
        defb    C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD      ; 32..39
        defb    C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD      ; 40..47
        defb    C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD, C_ROAD      ; 48..55
        defb    C_DIRT, C_DIRT, C_DIRT, C_DIRT, C_RES, C_RES, C_RES, C_RES      ; 56..63
        defb    C_RES, C_RES, C_RES, C_RES, C_WATER, C_FIRE, C_FIRE, C_FIRE      ; 64..71
        defb    C_FIRE, C_DIRT, C_DIRT, C_DIRT, C_DIRT, C_DIRT, C_DIRT, C_DIRT      ; 72..79
        defb    C_DIRT, C_DIRT, C_DIRT, C_DIRT, C_RES, C_COM, C_IND, C_DIRT      ; 80..87
        defb    C_DIRT, C_DIRT, C_FIRE, C_FIRE, C_WATER, C_WATER      ; 88..93


        IFDEF   HAVE_MINIMAP_ART
        PUBLIC  _minimap_tiles, _mm_row
        IN_CODE
_mm_row: defs   432                     ; (in the low RAM, where a platform with paged video memory can read it)

; void minimap_tiles(uint8_t sy) __smallc: build row sy from the levels already in mm_col
_minimap_tiles:
        push    ix
        ld      hl,4
        add     hl,sp
        ld      a,(hl)
        ld      (mm_sy),a
        call    mm_tiles
        pop     ix
        ret

; Build row mm_sy in mm_row from the tiles' pictures and the levels in mm_col, two tiles at a time: the nine nibble pairs go
; to nine places 48 bytes apart.
mm_tiles:
        call    mm_levelrow
        ld      (mm_lp),hl
        ld      hl,mm_col
        ld      (mm_ip),hl
        ld      hl,_mm_row
        ld      (mm_dp),hl
        xor     a
        ld      (mm_k),a
        ld      b,48
mm_tl:  push    bc
        ld      de,mm_na
        call    mm_one
        ld      de,mm_nb
        call    mm_one
        ld      hl,mm_na                ; the nine bytes: the left nibble shifted up, the right nibble below it
        ld      de,mm_nb
        ld      ix,(mm_dp)
        ld      a,9
        ld      (mm_cnt),a
mm_mg:  ld      a,(hl)
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        ld      b,a
        ld      a,(de)
        or      b
        ld      (ix+0),a
        inc     hl
        inc     de
        ld      bc,48
        add     ix,bc
        ld      a,(mm_cnt)
        dec     a
        ld      (mm_cnt),a
        jr      nz,mm_mg
        ld      hl,(mm_dp)
        inc     hl
        ld      (mm_dp),hl
        pop     bc
        dec     b
        jp      nz,mm_tl
        ret

; hl -> the cell after a zone marker.  Sets mm_base to group * 8 + piece.  Keeps hl, de and bc.
mm_mark:
        push    de
        push    hl
        ld      a,(hl)
        and     63
        ld      e,a
        ld      d,0
        inc     hl
        ld      a,(hl)
        and     7
        ld      h,d
        ld      l,e
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (mm_base),hl
        pop     hl
        pop     de
        ret

; The next tile's nine nibbles go to de: plane 0's three lines, then plane 1's, then plane 2's.  Without a level they are
; the tile's picture.  With one (mm_ip) the picture's ground is that colour and its shape, the pixels that differ from the
; ground colour in any plane, is left as it is.
; An ordinary tile's picture is its number.  A large zone's row has a marker cell (bit 7 set, bit 6 clear), then a cell with
; the group (6 bits) and one with the piece (3 bits); the cell k places after the marker is picture 94 + group * 8 + piece + k.
mm_one:
        push    de
        ld      hl,(mm_lp)
        ld      a,(hl)
        inc     hl
        ld      (mm_lp),hl
        cp      94
        jr      c,mm_o1                 ; an ordinary tile
        cp      128
        jr      c,mm_odirt
        cp      192
        jr      nc,mm_ocont
        call    mm_mark                 ; a marker: the zone's first piece
        xor     a
        jr      mm_oz
mm_ocont:
        ld      a,(mm_k)
        inc     a
mm_oz:  ld      (mm_k),a
        ld      e,a
        ld      d,0
        ld      hl,(mm_base)
        add     hl,de
        ld      de,94
        add     hl,de
        jr      mm_o2
mm_odirt:
        ld      a,2
mm_o1:  ld      h,0
        ld      l,a
mm_o2:  ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de                   ; 5 a picture
        ld      de,mm_mini
        add     hl,de
        ld      de,mm_nt                ; the nibbles, in order, and the ground
        ld      a,(hl)
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     $0F
        ld      (de),a
        inc     de
        ld      a,b
        and     $0F
        ld      (de),a
        inc     de
        inc     hl
        ld      a,(hl)
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     $0F
        ld      (de),a
        inc     de
        ld      a,b
        and     $0F
        ld      (de),a
        inc     de
        inc     hl
        ld      a,(hl)
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     $0F
        ld      (de),a
        inc     de
        ld      a,b
        and     $0F
        ld      (de),a
        inc     de
        inc     hl
        ld      a,(hl)
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     $0F
        ld      (de),a
        inc     de
        ld      a,b
        and     $0F
        ld      (de),a
        inc     de
        inc     hl
        ld      a,(hl)
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     $0F
        ld      (de),a
        inc     de
        ld      a,b
        and     $0F
        ld      (de),a                  ; the ground colour
        ld      hl,(mm_ip)
        ld      c,(hl)                  ; the level
        inc     hl
        ld      (mm_ip),hl
        pop     de
        ld      a,c
        or      a
        jr      nz,mm_ov
        ld      hl,mm_nt                ; no level: the picture as it is
        ld      bc,9
        ldir
        ret
mm_ov:  ld      a,(mm_nt + 9)           ; the ground colour: its bits say which planes have it, as a nibble of ones
        ld      b,a
        ld      hl,mm_g
        xor     a
        bit     0,b
        jr      z,mm_g0
        ld      a,15
mm_g0:  ld      (hl),a
        inc     hl
        xor     a
        bit     1,b
        jr      z,mm_g1
        ld      a,15
mm_g1:  ld      (hl),a
        inc     hl
        xor     a
        bit     2,b
        jr      z,mm_g2
        ld      a,15
mm_g2:  ld      (hl),a
        ; line 0: b = the picture's shape (what is not its ground, in any plane): that stays as it is, the rest is the level's colour
        ld      a,(mm_nt + 0)
        ld      hl,mm_g
        xor     (hl)
        ld      b,a
        ld      a,(mm_nt + 3)
        inc     hl
        xor     (hl)
        or      b
        ld      b,a
        ld      a,(mm_nt + 6)
        inc     hl
        xor     (hl)
        or      b
        ld      b,a
        ld      a,(mm_nt + 0)
        and     b
        bit     0,c
        jr      z,mm_p0_0
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p0_0:
        ld      (de),a
        inc     de
        inc     de
        inc     de
        ld      a,(mm_nt + 3)
        and     b
        bit     1,c
        jr      z,mm_p1_0
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p1_0:
        ld      (de),a
        inc     de
        inc     de
        inc     de
        ld      a,(mm_nt + 6)
        and     b
        bit     2,c
        jr      z,mm_p2_0
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p2_0:
        ld      (de),a
        dec     de
        dec     de
        dec     de
        dec     de
        dec     de
        ; line 1: b = the picture's shape (what is not its ground, in any plane): that stays as it is, the rest is the level's colour
        ld      a,(mm_nt + 1)
        ld      hl,mm_g
        xor     (hl)
        ld      b,a
        ld      a,(mm_nt + 4)
        inc     hl
        xor     (hl)
        or      b
        ld      b,a
        ld      a,(mm_nt + 7)
        inc     hl
        xor     (hl)
        or      b
        ld      b,a
        ld      a,(mm_nt + 1)
        and     b
        bit     0,c
        jr      z,mm_p0_1
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p0_1:
        ld      (de),a
        inc     de
        inc     de
        inc     de
        ld      a,(mm_nt + 4)
        and     b
        bit     1,c
        jr      z,mm_p1_1
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p1_1:
        ld      (de),a
        inc     de
        inc     de
        inc     de
        ld      a,(mm_nt + 7)
        and     b
        bit     2,c
        jr      z,mm_p2_1
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p2_1:
        ld      (de),a
        dec     de
        dec     de
        dec     de
        dec     de
        dec     de
        ; line 2: b = the picture's shape (what is not its ground, in any plane): that stays as it is, the rest is the level's colour
        ld      a,(mm_nt + 2)
        ld      hl,mm_g
        xor     (hl)
        ld      b,a
        ld      a,(mm_nt + 5)
        inc     hl
        xor     (hl)
        or      b
        ld      b,a
        ld      a,(mm_nt + 8)
        inc     hl
        xor     (hl)
        or      b
        ld      b,a
        ld      a,(mm_nt + 2)
        and     b
        bit     0,c
        jr      z,mm_p0_2
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p0_2:
        ld      (de),a
        inc     de
        inc     de
        inc     de
        ld      a,(mm_nt + 5)
        and     b
        bit     1,c
        jr      z,mm_p1_2
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p1_2:
        ld      (de),a
        inc     de
        inc     de
        inc     de
        ld      a,(mm_nt + 8)
        and     b
        bit     2,c
        jr      z,mm_p2_2
        ld      l,a
        ld      a,b
        cpl
        and     $0F
        or      l
mm_p2_2:
        ld      (de),a
        ret
        
        IN_RODATA
mm_mini:                                ; the pictures at a quarter of the size, 5 bytes each (tools/extract_cpc_tiles.py --mini)
        BINARY  "build/common/minitiles_640x200_3bpp.bin"
        ENDIF
