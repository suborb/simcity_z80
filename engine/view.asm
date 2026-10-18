; ------------------------------------------------------------------------
; view_cell: what to draw for one cell of the map.
;
; This is the cell-selection logic of the Spectrum's draw_map, extracted so
; every platform draws the same picture.  The result is exactly what the
; Spectrum build writes to its screen for that cell (checked against it by
; test/golden/run.py).
;
;   Entry:  C = map column (0..95), B = map row (0..95)
;   Exit:   HL -> 8 bytes of 1bpp art (top row first, bit 7 = left pixel)
;           A  = attribute byte (Spectrum format: bit 7 flash, bit 6 bright,
;                bits 5-3 paper, bits 2-0 ink); other platforms may map it
;   BC is preserved.  DE is destroyed.
;
; Animation: V_view_tick is the platform's frame counter.
;   bit 5 : unpowered zones flash the "needs power" icon
;   bit 4 : busy roads alternate between two pictures
; ------------------------------------------------------------------------
        IN_DATA
V_view_tick:    defb    0
        IN_CODE

view_cell:
        push    bc
        call    view_cell_1
        pop     bc
        ret

view_cell_1:
        ; hl = levelmap + row*96 + column
        ld      h,0
        ld      l,b
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de                   ;3 * row
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ;96 * row
        ld      e,c
        ld      d,0
        add     hl,de
        ld      de,levelmap
        add     hl,de
        ld      a,(hl)
        cp      128
        jr      nc,view_zone_cell

        ; ---- ordinary tile ------------------------------------------------
        ld      e,a                     ;e = tile
        cp      84                      ;compact R, C, I zone tiles 84..86
        jr      c,view_not_zone
        cp      87
        jr      nc,view_not_zone
        ld      a,(V_view_tick)
        bit     5,a
        jr      z,view_not_zone
        ld      e,TILE_NEED_POWER
        jr      view_tile
view_not_zone:
        ld      a,e
        ld      d,52                    ;busy horizontal road picture
        cp      TILE_H_ROAD
        jr      z,view_road
        ld      d,54                    ;busy vertical road picture
        cp      TILE_V_ROAD
        jr      nz,view_tile
view_road:
        call    get_traffic_density_value       ;a = traffic at this cell (bc kept)
        cp      220
        jr      nc,view_road_busy
        cp      150
        jr      c,view_tile             ;quiet road: the plain picture
        ld      a,(V_view_tick)
        and     16
        jr      z,view_road_busy
        inc     d                       ;second frame
view_road_busy:
        ld      e,d
view_tile:
        ld      d,0
        ld      hl,view_udgs+ART_TILE_ATTRS
        add     hl,de
        ld      a,(hl)                  ;attribute
        ld      hl,view_udgs+ART_TILES
        ex      de,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,de                   ;hl = art
        ret

        ; ---- cell of a large zone -----------------------------------------
        ; Rows of a zone start with a marker cell (bit 7 set, bit 6 clear: low
        ; 3 bits = width) followed by cells with bits 7 and 6 both set.  The
        ; marker's neighbours hold the picture: byte 1 = piece group (6 bits),
        ; byte 2 = piece within the group (3 bits); the piece for the cell k
        ; places from the left is group*8 + piece + k.
view_zone_cell:
        ld      d,0                     ;d = k
        cp      192
        jr      c,view_zone_found
view_zone_left:
        ld      a,(hl)
        and     192
        cp      192
        jr      nz,view_zone_found
        inc     d
        dec     hl
        jr      view_zone_left
view_zone_found:                        ;hl -> marker cell of this row
        ld      a,d
        and     a
        jr      nz,view_zone_piece
        ld      a,(hl)                  ;only the leftmost cell of an unpowered
        and     240                     ;zone's top row flashes (marker $A?)
        cp      160
        jr      nz,view_zone_piece
        ld      a,(V_view_tick)
        bit     5,a
        jr      z,view_zone_piece
        ld      e,TILE_NEED_POWER
        jr      view_tile
view_zone_piece:
        inc     hl
        ld      a,(hl)                  ;byte 1: group
        inc     hl
        ld      c,(hl)                  ;byte 2: piece (bc is restored by view_cell)
        and     63
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl                   ;group * 8
        ld      a,c
        and     7
        add     a,d                     ;piece + k
        ld      e,a
        ld      d,0
        add     hl,de                   ;hl = zone piece number
        ex      de,hl                   ;de = piece number
        ld      hl,view_udgs+ART_ZONE_ATTRS
        add     hl,de
        ld      a,(hl)                  ;attribute
        ld      hl,view_udgs+ART_ZONES
        ex      de,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,de                   ;hl = art
        ret
