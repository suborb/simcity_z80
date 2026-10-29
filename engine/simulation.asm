; simulation: lines 4985-8158 of disassembly/sim_game.asm (engine)

; Thing this gets the top left of the zone for a map position
fill_zone_with_tile:                                    ; $7B86 / 31622 - Find top-left of zone at HL, fill entire zone area with V_fill_tile tile
.L7b86  push    hl
        pop     ix
        call    find_left_edge_of_zone
        IF      MAP_W == 96
        ld      de,-MAP_W

.L7b8f  bit     5,(ix+0)
        jr      nz,L7b99                ; (4)
        add     ix,de
        jr      L7b8f                   ; (-10)
        ELSE
        call    find_top_edge_of_zone
        ret     nc
        ENDIF

.L7b99  ld      a,(ix+0)
        and     7
        IFDEF PORTABLE
        ld      (V_width_31652),a
        ld      b,a
.L7ba2  push    ix
        ld      a,(V_width_31652)
        ld      c,a
        ELSE
        ld      (SMC_31652+1),a
        ld      b,a
.L7ba2  push    ix
SMC_31652:
        ld      c,0
        ENDIF
.L7ba6  ld      a,(V_fill_tile)
        ld      (ix+0),a
        inc     ix
        dec     c
        jr      nz,L7ba6                ; (-11)
        pop     ix
        ld      de,MAP_W
        add     ix,de
        djnz    L7ba2                   ; (-24)
        ret     


.L7bbb  push    hl
        pop     ix
        call    find_left_edge_of_zone
        IF      MAP_W == 96
        ld      de,-MAP_W

tornado_find_zone_top:                                    ; $7BC4 / 31684 - Walk IX upward (-96) until bit 5 set; used by tornado zone-destruction path
.L7bc4  bit     5,(ix+0)
        jr      nz,L7bce                ; (4)
        add     ix,de
        jr      tornado_find_zone_top                   ; (-10)
        ELSE
        call    find_top_edge_of_zone
        ret     nc
        ENDIF

.L7bce  ld      a,(ix+0)
        and     7
        IFDEF PORTABLE
        ld      (V_width_31705),a
        ld      b,a
.L7bd7  push    ix
        ld      a,(V_width_31705)
        ld      c,a
        ELSE
        ld      (SMC_31705+1),a
        ld      b,a
.L7bd7  push    ix
SMC_31705:
        ld      c,0
        ENDIF
.L7bdb  ld      a,58
        ld      (ix+0),a
        inc     ix
        dec     c
        jr      nz,L7bdb                ; (-10)
        pop     ix
        ld      de,MAP_W
        add     ix,de
        djnz    L7bd7                   ; (-23)
        ret     


; 5x5 attenuation kernel for police and fire stations.  Each entry is a SHIFT
; COUNT: the station's effectiveness (V_PoliceEffect/V_FireEffect, 0-15) is
; shifted right by (value-1) before being added to the coverage minimap, so
; 1 = full strength at the centre, 2 = half, and 9 = shifted away to nothing.
; Cells are capped at 15.
        IN_RODATA
D_station_influence_kernel:                        ; $7BEF / 31727
                        ; $7BEF / 31727
        defb    $09, $09, $02, $09, $09 
        defb    $09, $02, $01, $02, $09
        defb    $02, $01, $01, $01, $02 
        defb    $09, $02, $01, $02, $09 
        defb    $09, $09, $02, $09, $09
        IN_SIM_CODE


        IN_DATA
V_FireEffect:    defb        0       ; VAR $7C08 / 31752 -
        IN_SIM_CODE

apply_fire_station_kernel:                                    ; $7C09 / 31753 - Apply D_station_influence_kernel 5x5 around current pos to fire coverage minimap
.L7c09  ld      bc,(V_map_iter_xy)
        ld      ix,D_station_influence_kernel
        call    get_fire_minimap_value           ;Fire map
        ld      de,2*MM25_W+2
        and     a
        sbc     hl,de
        ld      d,5
.L7c1c  push    hl
        ld      e,5
.L7c1f  call    add_fire_kernel_value
        inc     hl
        inc     ix
        dec     e
        jr      nz,L7c1f                ; (-9)
        pop     hl
        ld      bc,MM25_W
        add     hl,bc
        dec     d
        jr      nz,L7c1c                ; (-20)
        ret     

        IN_DATA
V_PoliceEffect:    defb    0       ; VAR $7C31 / 31793 -
        IN_SIM_CODE

apply_police_station_kernel:                                    ; $7C32 / 31794 - Apply D_station_influence_kernel 5x5 around current pos to police coverage minimap
.L7c32  ld      bc,(V_map_iter_xy)
        ld      ix,D_station_influence_kernel
        call    get_police_minimap_value           ;Get police minimap address
        ld      de,2*MM25_W+2   ;Go 8 tiles up and two left??
        and     a
        sbc     hl,de
        ld      d,5             ;5x5 zone around it?
.L7c45  push    hl
        ld      e,5
.L7c48  call    add_police_kernel_value           ;Add some intensity?
        inc     hl
        inc     ix
        dec     e
        jr      nz,L7c48                ; (-9)
        pop     hl
        ld      bc,MM25_W       ;4 rows down
        add     hl,bc
        dec     d
        jr      nz,L7c45                ; (-20)
        ret     


add_police_kernel_value:                                    ; $7C5A / 31834 - Add scaled police effectiveness (V_PoliceEffect >> kernel weight) to police minimap cell; cap at 15
.L7c5a  ld      a,(V_PoliceEffect)
        jr      L7c62                   ; (3)

add_fire_kernel_value:                                    ; $7C5F / 31839 - Add scaled fire effectiveness (V_FireEffect >> kernel weight) to fire minimap cell; cap at 15
.L7c5f  ld      a,(V_FireEffect)

.L7c62  ld      b,(ix+0)
        dec     b
        jr      z,L7c6c                 ; (4)

.L7c68  srl     a
        djnz    L7c68                   ; (-4)

.L7c6c  ld      b,a
        ld      a,(hl)
        add     a,b
        cp      16
        jr      c,L7c75                 ; (2)
        ld      a,15

.L7c75  ld      (hl),a
        ret     


; Two 6x6 attenuation kernels back to back, used by apply_stadium_kernel with
; the same shift-count encoding as D_station_influence_kernel.  The first (large)
; one is used by polluters - coal/nuclear/port/industrial and radioactive tiles;
; the second (tighter, only 1 and 5) is used for the light pollution of road traffic
; (IX=31899 in process_traffic_from_connections).  The amount spread is
; V_traffic_bfs_steps (despite the name, it is the source strength here).
        IN_RODATA
D_stadium_effect_kernel:                        ; $7C77 / 31863
                        ; $7C77 / 31863
        defb    $09, $04, $04, $04, $04, $09
        defb    $04, $03, $02, $02, $03, $04
        defb    $04, $02, $01, $01, $02, $04
        defb    $04, $02, $01, $01, $02, $04
        defb    $04, $03, $02, $02, $03, $04
        defb    $09, $04, $04, $04, $04, $09
        defb    $09, $09, $09, $09, $09, $09
        defb    $09, $09, $05, $05, $09, $09
        defb    $09, $05, $01, $01, $05, $09
        defb    $09, $05, $01, $01, $05, $09
        defb    $09, $09, $05, $05, $09, $09
        defb    $09, $09, $09, $09, $09, $09
        IN_SIM_CODE

        IN_DATA
V_traffic_bfs_steps:    defb    $ff       ; VAR $7CBF / 31935 - traffic BFS step limit (initialised to 5, decremented per step; $ff = inactive)
        IN_SIM_CODE


apply_stadium_kernel_from_iter:                                    ; $7CC0 / 31936 - Load BC from V_map_iter_xy and IX from D_stadium_effect_kernel, then call apply_stadium_kernel
.L7cc0  ld      bc,(V_map_iter_xy)
        ld      ix,D_stadium_effect_kernel 

; NB the target is returned by get_land_value_minimap_value; despite that name it is
; the POLLUTION minimap (minimaps+1152), the same one decay_pollution_minimap and
; do_minimap_pollution use.
apply_stadium_kernel:                                    ; $7CC8 / 31944
.L7cc8  call    get_land_value_minimap_value       ;minimaps+2304
        ld      de,2*MM50_W+2
        and     a
        sbc     hl,de
        ld      d,6
.L7cd3  push    hl
        ld      e,6
.L7cd6  call    add_traffic_kernel_value
        inc     hl
        inc     ix
        dec     e
        jr      nz,L7cd6                ; (-9)
        pop     hl
        ld      bc,MM50_W
        add     hl,bc
        dec     d
        jr      nz,L7cd3                ; (-20)
        ret     


add_traffic_kernel_value:                                    ; $7CE8 / 31976 - Add scaled traffic density to traffic minimap at current pos; cap at 255
.L7ce8  ld      a,(V_traffic_bfs_steps)
        ld      b,(ix+0)
        dec     b
        jr      z,L7cf5                 ; (4)
.L7cf1  srl     a
        djnz    L7cf1                   ; (-4)
.L7cf5  ld      b,a
        ld      a,(hl)
        add     a,b
        jr      nc,L7cfc                ; (2)
        ld      a,255
.L7cfc  ld      (hl),a
        ret     


accumulate_pollution:                                    ; $7CFE / 31998 - Read land-value minimap at current pos; add to city pollution running sum
.L7cfe  ld      bc,(V_map_iter_xy)
        call    get_land_value_minimap_value
        call    minimap_max_2x2_block
        ld      (V_zone_landval_local),a
        ld      e,a
        ld      d,0
        ld      hl,(V_pollution_sum)
        add     hl,de
        ld      (V_pollution_sum),hl
        IF      MAP_W != 96
        ld      a,(V_pollution_sum_high)
        adc     a,0
        ld      (V_pollution_sum_high),a
        ENDIF
        ld      hl,(V_pollution_count)
        inc     hl
        ld      (V_pollution_count),hl
        ret     


read_traffic_density:                                    ; $7D1D / 32029 - Read traffic minimap at current map pos into V_zone_traffic_density
.L7d1d  ld      bc,(V_map_iter_xy)
        call    get_traffic_density_value
        call    minimap_max_2x2_block
        ld      (V_zone_traffic_density),a
        ret     


        IN_DATA
V_zone_best_coords:    defw        0       ; VAR $7D2B / 32043 - map coords of highest-value zone tile (candidate for upgrade)


V_zone_size_to_scan:    defw    0       ; VAR $7D2D / 32045 - size of zone to scan
        IN_SIM_CODE

scan_zone_with_size:                                    ; $7D2F / 32047 - Store HL as zone scan size in V_zone_size_to_scan, then enter zone scan loop
.L7d2f  ld      (V_zone_size_to_scan),hl
        jr      L7d3a                   ; (6)

;
; Survey the surroundings of a zone.  Used by every R/C/I handler, and (through
; scan_zone_with_size) by the stadium, port and airport.
;
; Entry: bc = top-left cell of the zone body (b=y, c=x)
;        V_zone_size_to_scan = (rows, width) of the body - $0303 for scan_3x3_zone
;
; Two kinds of cell are visited:
;   * the one-cell border running round the outside of the body, corners
;     excluded (scan_zone_cell) - this is what the zone is "next to": roads and
;     rails, parks, sea and trees are counted and scored there;
;   * the body itself (accumulate_land_value_demand) - for a residential zone
;     this adds up the development stages of the houses (see zone_ring_grow).
;
; Results (all reset first):
;   V_zone_transport_count / V_zone_transport_score
;   V_zone_parks / V_zone_seas / V_zone_trees
;   V_zone_best_coords      a randomly chosen adjacent road/rail cell ($FFFF if
;                           none) - the starting point for the traffic walk
;   V_zone_handler_params   += house stages found in the body
.scan_3x3_zone
.L7d34  ld      hl,$0303
        ld      (V_zone_size_to_scan),hl

.L7d3a  xor     a
        ld      (V_zone_transport_count),a
        ld      (V_zone_parks),a
        ld      (V_zone_seas),a
        ld      (V_zone_trees),a
        ld      (V_zone_transport_score),a
        ld      hl,$ffff
        ld      (V_zone_best_coords),hl
        push    bc
        dec     b
        ld      a,(V_zone_size_to_scan)
        ld      e,a

.L7d56  call    scan_zone_cell
        inc     c
        dec     e
        jr      nz,L7d56                ; (-7)
        pop     bc
        dec     c
        ld      a,(V_zone_size_to_scan+1)
        ld      d,a

.L7d63  push    bc
        call    scan_zone_cell
        inc     c
        ld      a,(V_zone_size_to_scan)
        ld      e,a

.L7d6c  call    accumulate_land_value_demand
        inc     c
        dec     e
        jr      nz,L7d6c                ; (-7)
        call    scan_zone_cell
        pop     bc
        inc     b
        dec     d
        jr      nz,L7d63                ; (-24)
        inc     c
        ld      a,(V_zone_size_to_scan)
        ld      e,a

.L7d80  call    scan_zone_cell
        inc     c
        dec     e
        jr      nz,L7d80                ; (-7)
        ret     


; Categorise one border cell of a zone and update the stat counters.
; Cells off the map and cells that are part of a zone (bit 7) are ignored.
;   park ($38/$39)  : parks++,     score +14
;   trees (6)       : trees++,     score +16
;   sea (0)         : seas++,      score +16
;   road or rail    : transport++, score +12 (and maybe becomes V_zone_best_coords)
; The score is a "pleasant surroundings / accessibility" figure, capped at 127.
; Entry: bc = map coordinates
.scan_zone_cell
.L7d88  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ret     nc
        ld      a,(hl)
        bit     7,a
        ret     nz
        cp      $38
        jr      z,L7dc8                 ; (50)
        cp      $39
        jr      z,L7dc8                 ; (46)
        cp      6
        jr      z,L7dd0                 ; (50)
        cp      0                       ; Sea
        jr      z,L7dc0                 ; (30)
        ld      a,(hl)
        call    tile_to_flags
        and     6                       ;Check for transport
        ret     z
        ld      hl,V_zone_transport_count
        inc     (hl)
        call    maybe_update_best_transport_coords
        ld      l,12

accumulate_transport_score:                                    ; $7DB2 / 32178 - Add L to V_zone_transport_score (clamped to 127); common tail for road/rail/park/sea accounting
.L7db2  ld      a,(V_zone_transport_score)
        add     a,l
        cp      128
        jr      c,L7dbc                 ; (2)
        ld      a,127

.L7dbc  ld      (V_zone_transport_score),a
        ret     


.L7dc0  ld      hl,V_zone_seas
        inc     (hl)
        ld      l,16
        jr      accumulate_transport_score                   ; (-22)

.L7dc8  ld      hl,V_zone_parks
        inc     (hl)
        ld      l,14
        jr      accumulate_transport_score                   ; (-30)

.L7dd0  ld      hl,V_zone_trees
        inc     (hl)
        ld      l,16
        jr      accumulate_transport_score                   ; (-38)

; Reservoir-style pick: the first road/rail cell found is always remembered,
; later ones replace it with probability 1/2.  (Biased towards the last cells
; scanned, but cheap and good enough to give the walk varied starting points.)
maybe_update_best_transport_coords:                                    ; $7DD8 / 32216
.L7dd8  ld      a,(V_zone_best_coords)
        cp      255
        jr      z,L7de5                 ; (6)
        call    get_random_number
        and     1
        ret     z
.L7de5  ld      (V_zone_best_coords),bc
        ret     


; Called for each cell of the zone body.  If the cell is a house tile (flag bit 6,
; i.e. tiles 60..67 - see zone_ring_grow) add its stage, tile-59 = 1..8, to
; V_zone_handler_params.  An empty compact zone starts with params = 0, so on
; return params is the zone's population measure: the sum of its house stages.
accumulate_land_value_demand:                                    ; $7DEA / 32234
.L7dea  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ret     nc
        ld      a,(hl)
        bit     7,a
        ret     nz
        call    tile_to_flags
        bit     6,a
        ret     z
        ld      a,(hl)
        sub     $3b         ;Residential low density?
        ld      hl,V_zone_handler_params
        add     a,(hl)
        ld      (hl),a
        ret     


manhattan_dist_to_centroid:                                    ; $7E03 / 32259 - Return L1 distance from BC to V_CCxy (tornado/zone centroid)
.L7e03  ld      hl,(V_CCxy)
        ld      a,h
        sub     b
        jp      p,L7e0d
        neg     

.L7e0d  ld      e,a
        ld      a,l
        sub     c
        jp      p,L7e15
        neg     

.L7e15  add     a,e
        ret     

        IN_DATA
V_zone_parks:    defb        0       ; VAR $7E17 / 32279 - park tile count within 3x3 zone scan
V_zone_seas:    defb        0       ; VAR $7E18 / 32280 - sea/water tile count within 3x3 zone scan
V_zone_trees:    defb        0       ; VAR $7E19 / 32281 - tree tile count within 3x3 zone scan
V_zone_transport_count:    defb        0       ; VAR $7E1A / 32282 - transport tile count within 3x3 zone scan
V_zone_transport_score:    defb        0       ; VAR $7E1B / 32283 - accumulated transport score (capped at 127)
V_zone_land_value_base:    defb        0       ; VAR $7E1C / 32284 - combined land value base score (parks + transport - pollution)
        IN_SIM_CODE


;
; First stage of the land-value calculation: a zone only has any value if it is
; powered AND touches a road/rail that carries traffic.
;   base = (127 - manhattan distance from the zone to the city centre V_CCxy,
;           floored at 0)  +  V_zone_transport_score
; i.e. central, well-connected, pleasant (parks/water/trees) sites score high.
; Traffic counts as present when V_traffic_active is non-zero (the last random
; traffic walk succeeded) or the traffic minimap already reads >= 50 here.
; Otherwise base = 0.  Result in V_zone_land_value_base; every zone also adds
; to the V_landval_num/den running average that becomes the house-price concern.
calc_land_value_transport:                                    ; $7E1D / 32285
.L7e1d  ld      a,(V_ZonePwrFlg)
        and     a
        jr      z,L7e54                 ; (49)
        ld      a,(V_zone_transport_count)
        and     a
        jr      z,L7e54                 ; (43)
        ld      a,(V_traffic_active)
        and     a
        jr      nz,L7e36                ; (7)
        call    read_traffic_density
        cp      50
        jr      c,L7e54                 ; (30)

.L7e36  call    proximity_score_to_centroid
        ld      hl,V_zone_transport_score
        add     a,(hl)
        ld      hl,V_zone_land_value_base
        ld      (hl),a
        ld      e,a
        ld      d,0
        ld      hl,(V_landval_num)
        add     hl,de
        ret     c
        ld      (V_landval_num),hl
increment_landval_denominator:                                    ; $7E4C / 32332 - Increment V_landval_den; common tail for land-value accumulation paths
.L7e4c  ld      hl,(V_landval_den)
        inc     hl
        ld      (V_landval_den),hl
        ret     


.L7e54  xor     a
        ld      (V_zone_land_value_base),a
        jr      increment_landval_denominator                   ; (-14)

proximity_score_to_centroid:                                    ; $7E5A / 32346 - Compute 127 - manhattan_dist_to_centroid(BC), clamped to 0; Entry: BC=coords
.L7e5a  ld      bc,(V_map_iter_xy)
        call    manhattan_dist_to_centroid
        ld      b,a
        ld      a,127
        sub     b
        ret     nc

        xor     a
        ret

        defb    0               ; padding

        IN_DATA
V_zone_police_score:    defb    0       ; VAR $7E69 / 32361 - police coverage score for zone (proximity to police station)
        IN_SIM_CODE

; Despite the name this produces a CRIME figure for the zone, later subtracted
; from its land value:
;     crime = max(0, (255 - land_value_base) / 16  -  police coverage)
; Low-value areas breed crime (up to 15); police coverage (0..15, from the
; police minimap) cancels it point for point.  Averaged over all zones into
; V_police_cov_num/den, which compute_concern_scores doubles into V_concern_crime.
calc_police_coverage_score:                                    ; $7E6A / 32362
.L7e6a  ld      bc,(V_map_iter_xy)
        call    get_police_minimap_value
        ld      c,a
        ld      hl,V_zone_land_value_base
        ld      a,255
        sub     (hl)
        srl     a
        srl     a
        srl     a
        srl     a
        sub     c
        jr      nc,L7e84                ; (1)
        xor     a

.L7e84  ld      (V_zone_police_score),a
        ld      e,a
        ld      d,0
        ld      hl,(V_police_cov_num)
        add     hl,de
        ret     c

        ld      (V_police_cov_num),hl
        ld      hl,(V_police_cov_den)
        inc     hl
        ld      (V_police_cov_den),hl
        ret     

        IN_DATA
V_zone_tax_penalty:    defb        0       ; VAR $7E9A / 32410 - tax rate * 8 + difficulty bonus; subtracted from zone land value
        IN_SIM_CODE

; penalty = tax_rate * 8, plus one more tax_rate for difficulty 1 and 2, plus a
; second one for difficulty 1 only (so *8, *10, *9 for difficulty 0, 1, 2 - the
; ordering of 1 and 2 looks odd but is what the code does).
calc_tax_penalty:                                    ; $7E9B / 32411
.L7e9b  ld      a,(SMC_tax_rate)           ;Tax rate
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        ld      (V_zone_tax_penalty),a
        ld      a,(V_difficulty)
        and     a
        ret     z

        ld      a,(V_zone_tax_penalty)
        add     a,b
        ld      (V_zone_tax_penalty),a
        ld      a,(V_difficulty)
        cp      2
        ret     z

        ld      a,(V_zone_tax_penalty)
        add     a,b
        ld      (V_zone_tax_penalty),a
        ret     

        IN_DATA
V_zone_landval_local:    defb        0       ; VAR $7EBF / 32447 - zone's local land value from the land value minimap
V_zone_traffic_density:    defb        0       ; VAR $7EC0 / 32448 - zone's traffic density from traffic minimap
V_zone_landval_final:    defb        0       ; VAR $7EC1 / 32449 - final computed land value for this zone (0-255)
V_zone_landval_mult:    defw        0       ; VAR $7EC2 / 32450 - land value demand multiplier (scales growth/shrink probability)
        IN_SIM_CODE

; Compute the final land value of the zone being processed (0-255).
;
;   if pollution >= 28 or land_value_base == 0 :  value = 0
;   else value = base - pollution - crime - tax_penalty     (each step floored at 0)
;                      + V_zone_landval_mult                (the R/C/I demand valve)
;   clamped to 0..255.
;
; V_zone_landval_mult is set by the caller to the relevant demand index
; (V_RValve / V_CValve / V_IValve), so a zone type in high demand gets a boost
; and one in oversupply is pushed down - this is how demand drives growth.
; Exit: V_zone_landval_final = land value (0-255)
.calculate_zone_land_value
.L7ec4  call    calc_land_value_transport
        call    calc_police_coverage_score
        call    calc_tax_penalty
        ld      a,(V_zone_landval_local)
        cp      28
        jr      nc,L7eff                ; (43)
        ld      a,(V_zone_land_value_base)
        and     a
        jr      z,L7eff                 ; (37)
        ld      hl,V_zone_landval_local
        sub     (hl)
        jr      nc,L7ee1                ; (1)
        xor     a

.L7ee1  ld      hl,V_zone_police_score
        sub     (hl)
        jr      nc,L7ee8                ; (1)
        xor     a

.L7ee8  ld      hl,V_zone_tax_penalty
        sub     (hl)
        jr      nc,L7eef                ; (1)
        xor     a

.L7eef  ld      l,a
        ld      h,0
        ld      de,(V_zone_landval_mult)
        add     hl,de
        call    clamp_h_to_byte
        ld      a,l
        ld      (V_zone_landval_final),a
        ret     


.L7eff  xor     a
        ld      (V_zone_landval_final),a
        ret     


clamp_h_to_byte:                                    ; $7F04 / 32516 - If H=0 return; H<0 -> L=0; H>0 -> L=255; clamps signed HL to byte range
.L7f04  ld      a,h
        and     a
        ret     z
        jp      p,L7f0d
        ld      l,0
        ret     
.L7f0d  ld      l,255
        ret     

        IN_DATA
V_zone_growth_factor:    defb    0       ; VAR $7F10 / 32528 - zone growth probability factor (land value based)
V_zone_half_landval:    defb    0       ; VAR $7F11 / 32529 - half of zone land value (used in population growth threshold)
        IN_SIM_CODE

; Derive the residential growth thresholds from land value.
;   V_zone_half_landval = value / 2                     (value < 128)
;                       = 80 + 16 * ((value-128) / 16)  (value >= 128)
;   V_zone_growth_factor = (value - 128) / 16, or 15 if value < 128
;                          (the SUB wraps/flags NC; preserved quirk of the original)
; DoResidential compares the zone's population measure against half_landval to
; decide whether the zone's ring should grow or shrink.
; Exit: V_zone_growth_factor = growth factor, V_zone_half_landval = threshold
.update_zone_population
.L7f12  call    calculate_zone_land_value
        ld      a,(V_zone_landval_final)
        srl     a
        ld      (V_zone_half_landval),a
        ld      a,(V_zone_landval_final)
        sub     128
        jr      nc,L7f26                ; (2)
        ld      a,255

.L7f26  srl     a
        srl     a
        srl     a
        srl     a
        ld      b,a
        ld      (V_zone_growth_factor),a
        ld      a,(V_zone_landval_final)
        cp      128
        ret     c

        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,80
        ld      (V_zone_half_landval),a
        ret     

        IN_DATA
V_com_growth_index:    defb    0       ; VAR $7F43 / 32579 -
V_com_growth_scaled:    defb    0       ; VAR $7F44 / 32580 - unused?
        IN_SIM_CODE


calc_commercial_growth_index:                                    ; $7F45 / 32581 - Compute land value / 25 -> V_com_growth_index growth index; *4 -> V_com_growth_scaled; for commercial zone upgrade
.L7f45  call    calculate_zone_land_value
        ld      a,(V_zone_landval_final)
        ld      l,a
        ld      h,0
        ld      a,25
        call    L_div_hl_a
        ld      a,l
        ld      (V_com_growth_index),a
        add     a,a
        add     a,a
        ld      (V_com_growth_scaled),a
        ret     

        IN_DATA
V_ind_growth_index:    defb    0       ; VAR $7F5D / 32605 -
V_ind_growth_scaled:    defb    0       ; VAR $7F5E / 32606 - unused?
        IN_SIM_CODE


calc_industrial_growth_index:                                    ; $7F5F / 32607 - Compute land value / 31 -> V_ind_growth_index growth index; *8 -> V_ind_growth_scaled; for industrial zone upgrade
.L7f5f  call    calculate_zone_land_value
        ld      a,(V_zone_landval_final)
        ld      l,a
        ld      h,0
        ld      a,31
        call    L_div_hl_a
        ld      a,l
        ld      (V_ind_growth_index),a
        add     a,a
        add     a,a
        add     a,a
        ld      (V_ind_growth_scaled),a
        ret     


; Holds result f searching the map - address within map?
        IF      MAP_W == 96
        IN_BSS
        ELSE
        IN_ENGINE_BSS                   ; (only the engine reads it: in the bank, it leaves the program's RAM for the second power map)
        ENDIF
V_powerstation_list:    defs        POWER_STATION_LIST_BYTES ; map addresses of power stations, then a zero terminator
        IN_SIM_CODE


build_powerstation_list:                                    ; $7F98 / 32664 - Scan levelmap for power station tiles (coal/nuclear); store addresses into V_powerstation_list
.L7f98  ld      ix,V_powerstation_list
        ld      hl,levelmap         ;Search for a power station
        ld      bc,MAP_CELLS        ;somehow we know it exists?
powerstation_list_scan_loop:                                    ; $7FA2 / 32674 - Inner loop of build_powerstation_list: cpir for $B4, check coal/nuclear type, record address
.L7fa2  ld      a,$b4
        cpir    
        ld      a,(hl)              ;(hl)=$c6 (coal), $c8 (nuclear)
        and     63
        cp      6
        jr      z,L7fbe                 ; (17)
        cp      8
        jr      z,L7fbe                 ; (13)
        ld      a,b                 ;This check is always true?
        or      c
        jr      nz,powerstation_list_scan_loop                ; (-19)
        ld      (ix+0),0            ;End markers
        ld      (ix+1),0
        ret     
.L7fbe  dec     hl
        IF      POWER_CITYWIDE
        ; Keep the list bounded even if a loaded or damaged map contains more station markers than fit its legal 4x4 placement capacity.
        push    hl
        push    ix
        pop     hl
        ld      de,V_powerstation_list+2*POWER_STATION_SLOTS
        and     a
        sbc     hl,de
        pop     hl
        jr      nc,powerstation_list_skip
        ENDIF
        ld      (ix+0),l
        inc     ix
        ld      (ix+0),h
        inc     ix
        IF      POWER_CITYWIDE
powerstation_list_skip:
        ENDIF
        inc     hl
        jr      powerstation_list_scan_loop                   ; (-42)


        IN_DATA
V_brownout_detected:    defb    0       ; VAR $7FCC / 32716 - (32716/7fcc) - brownouts detected
        IN_SIM_CODE

generate_power_map:
.L7fcd
        call    build_powerstation_list
        ld      hl,minimaps + MMO_POWER          ;Clear power map
        ld      de,minimaps + MMO_POWER + 1
        ld      bc,MMO_POWER_SIZE-1
        ld      (hl),0
        ldir    
        xor     a
        ld      (V_brownout_detected),a
        IF      POWER_CITYWIDE
        call    power_bfs_start              ;One scan from all stations; capacity is shared citywide
        IFDEF   POWER_SHOWN
        ld      hl,minimaps + MMO_POWER                 ;whole: the UI's copy
        ld      de,minimaps + MMO_POWER_SHOWN
        ld      bc,MMO_POWER_SIZE
        ldir
        ENDIF
        ret
        ELSE
        ld      ix,V_powerstation_list
power_bfs_per_station:
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      a,h
        or      l
        ret     z
        inc     hl
        ld      a,(hl)
        and     63
        dec     hl
        ld      de,1350
        cp      8
        jr      z,power_bfs_legacy_budget_set
        ld      de,450
power_bfs_legacy_budget_set:
        ld      (V_power_units_left),de
        call    map_addr_to_xy
        ld      (V_power_bfs_pos),bc
        push    ix
        call    power_bfs_start
        pop     ix
        inc     ix
        inc     ix
        jr      power_bfs_per_station
        ENDIF

;8015
        IN_DATA
V_power_bfs_down:        defb    0       ; VAR $8015 / 32789 - power BFS downward traversal flag (set if going south, prevents backtrack)
V_power_bfs_up:        defb    0       ; VAR $8016 / 32790 - power BFS upward traversal flag (set if going north, prevents backtrack)
V_power_bfs_pos:        defw    0       ; VAR $8017 / 32791 - power BFS current map coordinates (b=y, c=x)
V_power_units_left: defw    0          ; remaining power capacity (citywide portable scan, per station in legacy path)
V_powersp:  defw    0       ; VAR $801B / 32795 - saved stack when aborting power search 
        IN_SIM_CODE

        IF      MAP_W == 96
        IN_BSS
        ELSE
        IN_ENGINE_BSS
        ENDIF
V_powerqueue:   defs    POWER_QUEUE_BYTES ; coordinate-pair queue, also reused as a short traffic-path stack
        IN_SIM_CODE



;
; PORTABLE power distribution uses one citywide capacity, matching Micropolis. The
; power map is also the visited map: each reached conductor is marked once
; and consumes one unit from the combined plant budget.
;
;   1. sum plant capacities and seed the queue with all station coordinates
;   2. pop a seed; run LEFT until the next tile does not conduct
;   3. run RIGHT along the row: power each tile (set_tile_as_powered) and look at
;      the tiles directly above and below (power_bfs_expand_row).  A neighbour
;      that conducts is queued as a new seed - but only once per run, tracked
;      by V_power_bfs_up / V_power_bfs_down - so a long wire running alongside
;      is not queued for every cell.
;   4. stop when capacity is exhausted and another unpowered conductor is
;      reached; increment V_brownout_detected and leave the rest unpowered.
;
; PORTABLE capacity is 450/1,350 on 96x96 maps and 700/2,000 on 120x100 maps,
; summed across stations and capped at the number of map cells. The IFNDEF
; PORTABLE path retains the original independent per-station budgets.
; The portable path yields between seeds and during queue refills because this
; scan runs before the simulation's normal row-by-row yields.
power_bfs_start:
        IF      POWER_CITYWIDE
        ld      (V_powersp),sp
        ld      hl,0
        ld      (V_power_units_left),hl
        xor     a
        ld      (V_brownout_detected),a
        ld      ix,V_powerqueue
        ld      bc,$ffff
        call    powerqueue_push_bc          ;bottom-of-stack end marker
        ld      hl,V_powerstation_list
power_bfs_seed_stations:
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,d
        or      e
        jr      nz,power_bfs_have_station
        jr      power_bfs_next
power_bfs_have_station:
        push    hl                          ;save station-list pointer
        ex      de,hl                       ;station map address
        push    hl
        inc     hl
        ld      a,(hl)
        and     63
        cp      8
        jr      z,power_bfs_seed_nuclear
        IF      MAP_W == 120
        ld      de,700
        ELSE
        ld      de,450
        ENDIF
        jr      power_bfs_add_capacity
power_bfs_seed_nuclear:
        IF      MAP_W == 120
        ld      de,2000
        ELSE
        ld      de,1350
        ENDIF
power_bfs_add_capacity:
        ld      hl,(V_power_units_left)
        add     hl,de
        jr      c,power_bfs_capacity_full
        push    hl
        ld      de,MAP_CELLS
        and     a
        sbc     hl,de
        pop     hl
        jr      c,power_bfs_store_capacity
power_bfs_capacity_full:
        ld      hl,MAP_CELLS
power_bfs_store_capacity:
        ld      (V_power_units_left),hl
        pop     hl                          ;restore station map address
        call    map_addr_to_xy
        call    powerqueue_push_bc          ;seed this station
        pop     hl                          ;restore station-list pointer
        call    sim_yield                   ;keep the UI responsive while many plants are seeded
        jr      power_bfs_seed_stations
        ELSE
        call    check_tile_needs_power
        ret     nz
        ld      ix,V_powerqueue
        ld      (V_powersp),sp
        ld      bc,$ffff
        call    powerqueue_push_bc
        ld      bc,(V_power_bfs_pos)
        call    powerqueue_push_bc
        ENDIF
power_bfs_next:                                    ; $8136 / 33078 - Pop next coords from power queue; return if sentinel (BFS complete)
.L8136  call    powerqueue_pop_to_bc           ;Get next cell 
        ld      a,b             ;Check if we're at the end
        cp      255
        IF      POWER_CITYWIDE
        jr      nz,power_bfs_process_seed
        ld      a,(V_brownout_detected)
        or      a
        ret     z
        xor     a
        ld      (V_brownout_detected),a
        ld      ix,V_powerqueue
        ld      bc,$ffff
        call    powerqueue_push_bc
        call    power_bfs_refill_queue
        jr      power_bfs_next
power_bfs_process_seed:
        call    sim_yield                   ;power distribution runs before the tick's row-by-row yields
        call    check_tile_needs_power
        jr      nz,power_bfs_next
        ELSE
        ret     z
        ENDIF
power_bfs_scan_left:                                    ; $813D / 33085 - From current BC, scan left (dec C) until tile does not need power; column scan entry
.L813d  IF      POWER_CITYWIDE
        call    check_tile_conducts
        ELSE
        call    check_tile_needs_power
        ENDIF
        jr      nz,L8145                ; We don't need power
        dec     c
        jr      power_bfs_scan_left                   ; Go left and try again

.L8145  inc     c                       ;Check right
        IF      POWER_CITYWIDE
        call    check_tile_conducts
        ELSE
        call    check_tile_needs_power
        ENDIF
        jr      nz,power_bfs_next                ;No conductor at this seed
        xor     a
        ld      (V_power_bfs_down),a           ;Down power check indicator
        ld      (V_power_bfs_up),a           ;Up power check indicator
.L8152
        IF      POWER_CITYWIDE
        call    check_tile_needs_power
        jr      nz,power_bfs_already_powered
        ld      hl,(V_power_units_left)
        ld      a,h
        or      l
        jr      nz,power_bfs_capacity_available
        ld      sp,(V_powersp)
        ld      hl,V_brownout_detected
        ld      (hl),1
        ret
power_bfs_capacity_available:
        ENDIF
        call    set_tile_as_powered ;Turns power on and charges only new cells
        IF      POWER_CITYWIDE
power_bfs_already_powered:
        ENDIF
        dec     b                   ;Up a row
        ld      hl,V_power_bfs_down
        call    power_bfs_expand_row
        inc     b                   ;And then below
        inc     b
        ld      hl,V_power_bfs_up
        call    power_bfs_expand_row
        dec     b                   ;And then to the right
        inc     c
        IF      POWER_CITYWIDE
        call    check_tile_conducts
        ELSE
        call    check_tile_needs_power
        ENDIF
        jr      z,L8152                 ; (-25)
        jr      power_bfs_next                   ; (-55)

power_bfs_expand_row:                                    ; $816D / 33133 - From BC in power BFS, check tiles above/below for power need; push unvisited to queue
.L816d  IF      POWER_CITYWIDE
        call    check_tile_conducts
        jr      nz,L818c                ; Not a conductor: clear the direction flag.
        call    check_tile_needs_power
        jr      nz,power_bfs_expand_seen
        ELSE
        call    check_tile_needs_power
        jr      nz,L818c
        ENDIF
        ld      a,(hl)                  ;Flag that we've already checked in this direction
        and     a
        ret     nz
        ld      (hl),1
                                        ;Fall into adding another point for consideration
        IF      POWER_CITYWIDE
        jr      powerqueue_push_bc
power_bfs_expand_seen:
        ld      (hl),1
        ret
; A full queue can drop a vertical seed. Once the current batch drains, walk
; the powered cells and queue unvisited conductors immediately
; above or below them. Refill batches until the connected grid is exhausted.
power_bfs_refill_queue:
        ld      b,0
power_bfs_refill_row:
        ld      c,0
power_bfs_refill_col:
        call    get_power_map_addr
        ld      a,(hl)
        and     e
        jr      z,power_bfs_refill_next
        xor     a
        ld      (V_power_bfs_down),a
        ld      (V_power_bfs_up),a
        dec     b
        ld      hl,V_power_bfs_down
        call    power_bfs_expand_row
        inc     b
        inc     b
        ld      hl,V_power_bfs_up
        call    power_bfs_expand_row
        dec     b
power_bfs_refill_next:
        inc     c
        ld      a,c
        cp      MAP_W
        jr      nz,power_bfs_refill_col
        inc     b
        ld      a,b
        cp      MAP_H
        jr      z,power_bfs_refill_done
        call    sim_yield                   ;a refill can scan the whole map; yield once per row
        jr      power_bfs_refill_row
power_bfs_refill_done:
        ret
        ENDIF

powerqueue_push_bc:                                    ; $8177 / 33143 - Push BC coords onto V_powerqueue at IX; guard against overflow
.L8177  push    ix
        pop     hl
        ld      de,V_powerqueue+POWER_QUEUE_BYTES
        and     a
        sbc     hl,de
        IF      POWER_CITYWIDE
        jr      c,powerqueue_push_room
        ld      a,1
        ld      (V_brownout_detected),a ;temporary queue-overflow flag until a brownout is confirmed
        ret
powerqueue_push_room:
        ELSE
        ret     nc
        ENDIF
        ld      (ix+0),c
        inc     ix
        ld      (ix+0),b
        inc     ix
        ret     

.L818c  ld      (hl),0
        ret     

powerqueue_pop_to_bc:                                    ; $818F / 33167 - Pop next BC coords from V_powerqueue by decrementing IX twice
.L818f  dec     ix
        ld      b,(ix+0)
        dec     ix
        ld      c,(ix+0)
        ret     

; Check if we need to supply power to a tile?
;
; Entry:  bc = coordinates
; Exit:    a = 0 + z       we need to supply power
;          a = 1 + nz      we don't need to?
; Preserves: bc, hl
        IF      POWER_CITYWIDE
check_tile_needs_power:
.L819a  call    check_tile_conducts
        ret     nz
        push    hl
        call    get_power_map_addr
        ld      a,(hl)
        and     e
        pop     hl
        ret

; Is this an in-bounds conductor, whether already powered or not?
check_tile_conducts:
        push    bc
        push    hl
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        jr      nc,power_conducts_no
check_tile_conducts_at_hl:
        ld      a,(hl)
        cp      128
        jr      nc,L81b8                ; (7)
        call    tile_to_flags
        bit     3,a                     ;Needs power?
        jr      z,power_conducts_no
.L81b8  xor     a
        pop     hl
        pop     bc
        ret    
power_conducts_no:
        ld      a,1
        and     a
        pop     hl
        pop     bc
        ret     
        ELSE
check_tile_needs_power:
.L819a  push    bc
        push    hl
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        jr      nc,L81bc                ; (25)
        push    hl                      ;levelmap ptr
        call    get_power_map_addr
        ld      a,(hl)
        and     e
        pop     hl                      ;levelmap ptr
.L81aa  jr      nz,L81bc               ; (16)
        ld      a,(hl)
        cp      128
        jr      nc,L81b8                ; (7)
        call    tile_to_flags
        bit     3,a                     ;Needs power?
        jr      z,L81bc                 ; (4)
.L81b8  xor     a
        pop     hl
        pop     bc
        ret    
 
.L81bc  ld      a,1
        and     a
        pop     hl
        pop     bc
        ret     
        ENDIF

; Turn power for zone
set_tile_as_powered:
.L81c2  push    bc
        call    get_power_map_addr
        ld      a,(hl)
        or      e
        ld      (hl),a
        pop     bc
        ld      hl,(V_power_units_left)          ;We have one less tile we can give power to
        dec     hl
        ld      (V_power_units_left),hl
        IF      POWER_CITYWIDE == 0             ; (the citywide scan stops itself when the capacity is gone)
        ld      a,h
        or      l
        ret     nz
        ld      sp,(V_powersp)
        ld      hl,V_brownout_detected
        inc     (hl)
        ENDIF
        ret     

;33245
        IN_BSS
V_city_score:           defs    3   ; VAR $81DD / 33245 - calculated city score
V_previous_city_score:  defs    3   ; VAR $81E0 / 33248 - previous city score
        IN_SIM_CODE


; cf s_eval.c::GetAssValue()
calculate_city_score:
.L81e3  ld      hl,(V_city_score)
        ld      a,(V_city_score+2)
        ld      c,a
        ld      (V_previous_city_score),hl
        ld      a,c
        ld      (V_previous_city_score+2),a
        ld      hl,(V_RailTotal)      ;RoadTotal
        ld      de,5
        call    L_mult_24_16x16
        ld      (V_city_score),hl
        ld      a,c
        ld      (V_city_score+2),a
        ld      hl,(V_RoadTotal)      ;RailTotal
        ld      de,10
        call    score_add_weighted_population
        ld      hl,(V_PolicePop)     ;PolicePop
        ld      de,1000
        call    score_add_weighted_population
        ld      hl,(V_FirePop)     ;FireStPop
        ld      de,1000
        call    score_add_weighted_population
        ld      hl,(V_HospitalPop)     ;HospPop
        ld      de,400
        call    score_add_weighted_population
        ld      hl,(V_StadiumPop)      ;StadiumPop
        ld      de,3000
        call    score_add_weighted_population
        ld      hl,(V_PortPop)      ;PortPop
        ld      de,5000
        call    score_add_weighted_population
        ld      hl,(V_AirportPop)      ;APortPop
        ld      de,10000
        call    score_add_weighted_population
        ld      hl,(V_CoalPop)      ;CoalPop
        ld      de,3000     
        call    score_add_weighted_population
        ld      hl,(V_NuclearPop)     ;NuclearPop
        ld      de,6000               

; Multiply hl by de (weight) and add result to V_city_score
.score_add_weighted_population
.L824f  call    L_mult_24_16x16
        ld      de,(V_city_score)
        ld      a,(V_city_score+2)
        ld      b,a
        call    l_add24
        ld      (V_city_score),hl
        ld      a,c
        ld      (V_city_score+2),a
        ret     

        IN_DATA
V_unemployment:    defw    0       ; VAR $8265 / 33381 - unemployment level (derived from industrial demand; feeds concern score)
        IN_SIM_CODE


; (Res-(Com+Ind))*4
set_unemployment:
.L8267  ld      de,(V_ComZPop)
        ld      hl,(V_IndZPop)
        add     hl,de
        ex      de,hl
        ld      hl,(V_ResZPop)
        and     a
        sbc     hl,de
        add     hl,hl
        add     hl,hl
        ld      (V_unemployment),hl      ;unemployment
        ret     


        IN_DATA
V_RValve:    defw    0       ; VAR $827C / 33404 - residential demand index (positive = demand, negative = surplus)
V_CValve:    defw    0       ; VAR $827E / 33406 - commercial demand index
V_IValve:    defw    0       ; VAR $8280 / 33408 - industrial demand index
        IN_SIM_CODE


; Calculate economic balance indices (unemployment, commercial/industrial balance, etc.)
; Results stored in V_RValve, V_CValve, V_IValve
.calculate_economic_indices
.L8282  ld      de,(V_ComZPop)
        ld      hl,(V_IndZPop)
        add     hl,de
        ld      de,(V_ResZPop)
        and     a
        sbc     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ex      de,hl       ;de = (com + ind - res) * 8
        ld      hl,(V_StadiumPop)
        add     hl,hl
        add     hl,hl
        ex      de,hl
        add     hl,de
        ld      de,-26
        add     hl,de
        ld      (V_RValve),hl

        ld      de,(V_ResZPop)
        ld      hl,(V_IndZPop)
        add     hl,de
        srl     h
        rr      l
        ld      de,(V_ComZPop)
        and     a
        sbc     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ex      de,hl       ;de = (((res + ind) / 2) - com) * 8
        ld      hl,(V_AirportPop)
        add     hl,hl
        add     hl,hl
        ex      de,hl
        add     hl,de
        ld      de,-30
        add     hl,de
        ld      (V_CValve),hl  ;(airport *4) + ((((res + ind) / 2) - com) * 8) - 30

        ld      de,(V_ComZPop)
        ld      hl,(V_ResZPop)
        add     hl,de
        srl     h
        rr      l
        ld      de,(V_IndZPop)
        and     a
        sbc     hl,de
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ex      de,hl
        ld      hl,(V_PortPop)
        add     hl,hl
        add     hl,hl
        ex      de,hl
        add     hl,de
        ld      de,-30
        add     hl,de
        ld      (V_IValve),hl
        ret     


citypop_add_de_times16:                                    ; $82EE / 33518 - Add DE*16 to V_CityPop 24-bit; accumulate zone population into city total
.L82ee  push    hl
        push    bc
        ex      de,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl       ;*16
        ex      de,hl
        ld      b,0
        ld      hl,(V_CityPop)
        ld      a,(V_CityPop+2)
        ld      c,a
        call    l_add24
        ld      (V_CityPop),hl
        ld      a,c
        ld      (V_CityPop+2),a
        pop     bc
        pop     hl
        ret     

; Seems to be setting the initial conditions?
initialise_simulation_variables:
.L830c
        IFNDEF PORTABLE
        ; Spectrum only: prime the cooperative task switcher so the simulation
        ; task starts at start_simulation with its own stack.
        ld      a,1             ;Enable the simulation task
        ld      (V_simulation_disabled),a
        ld      hl,63214
        ld      (V_task1_stack),hl
        ld      hl,start_simulation
        ld      (63234),hl
        ENDIF
        ld      hl,1902
        ld      (V_year),hl
        xor     a
        ld      (V_month),a
        call    zero_simulation_state
        ld      c,0
        ld      h,78
        ld      l,32        ;20000
        ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        ld      a,(V_difficulty)
        and     a
        ret     z
        ld      c,0
        ld      h,39
        ld      l,16        ;10000
        ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        ld      a,(V_difficulty)
        cp      1
        ret     z
        ld      c,0
        ld      h,19
        ld      l,136        ;5000
        ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        ret     


; ============================================================
; SIMULATION ENGINE
; ============================================================
; Runs as a separate cooperative task (IM2 scheduler), interleaved
; with the UI process.  Each iteration of the main loop is one
; simulation tick.  The month advances only every N ticks, where N
; is controlled by V_sim_speed_block+4 according to the chosen speed:
;   FAST=8  NORMAL=4  SLOW=3  PAUSED=ff (never)
;
; PER-TICK PIPELINE (start_simulation loop):
;   1. reset_simulation_vars     - zero all per-tick population/fund counters
;   2. set_simulation_speed      - reload V_sim_speed_block table from V_simulation_speed
;   3. generate_power_map        - BFS from each power station; mark powered tiles
;   4. process_ric_zones (process_ric_zones) - scan 96x96 map; evaluate all zone tiles
;   5. create_police_fire_minimaps - (every 4 ticks) rebuild police/fire coverage
;   6. decay_pollution_minimap (decay_pollution)   - (every other tick) decay pollution minimap
;   7. DecTrafficMem             - decay traffic density minimap; compute avg
;   8. calculate_economic_indices- demand indices for R/C/I; drives zone growth
;   9. compute_concern_scores                     - compute crime/house-price concern scores
;  10. calculate_city_score      - weighted sum of all infrastructure populations
;  11. set_unemployment          - (Res-(Com+Ind))*4 -> V_unemployment
;  12. census_church_hosp        - compute hospital/church demand from ResZPop
;  13. SendMessages              - post advisor messages based on city state
;  14. update_stats (update_stats)      - save safe copies of NuclearPop/AirportPop,
;                                  compute tornado centroid, average land values
;  -- monthly (when sim_loop_counter & speed_mask == 0) --
;  15. DoBudget                  - collect tax, set money; wait for UI confirmation
;  16. increment_month           - advance V_month/V_year
;
; POWER PROPAGATION (generate_power_map / power_bfs_start):
;   For each entry in V_powerstation_list (power station map addresses):
;     - Coal gives 450 units, Nuclear gives 1350 units (120x100: 700/2000; V_power_units_left)
;     - BFS via V_powerqueue (coordinate-pair queue; capacity is target/map-size dependent)
;     - already-powered conductors are pass-through cells; only new cells are charged
;     - set_tile_as_powered marks the power minimap bit and decrements the unit counter
;     - If units reach 0 before BFS completes: abort via saved SP,
;       increment V_brownout_detected
;
; ZONE SCANNER (process_ric_zones / process_ric_zones):
;   Full 96x96 scan.  For each cell:
;   a) Tiles $a0-$bf (zone centre tiles): call set_zone_power_state
;      - clears/sets bit 4 of map tile to reflect power minimap
;      - V_ZonePwrFlg=1 if powered, 0 if not
;   b) Tiles $51-$56 (compact R/I/C variants): call check_ric_power
;      - updates tile to powered/unpowered variant (e.g. 81<->84)
;   c) Dispatch via D_zone_handler_config lookup (tile type -> handler index)
;      then D_zone_handler_table jump table -> zone handler
;
; ZONE HANDLERS:
;   DoResidential / DoCommercial / DoIndustrial:
;     - Increment *Pop counter (e.g. V_ResZPop)
;     - Add density * 16 to V_CityPop (cumulative population for budget)
;     - Check transport access; conditionally call sim_update_traffic
;     - Drive zone upgrade/downgrade via zone_ring_grow_ticks/zone_ring_shrink_ticks/sim_place_zone_3x3
;   DoPolice / DoFire:
;     - Add 100 to fund counter (V_PoliceFund / V_FireFund)
;     - Increment *Pop if powered
;   DoCoal / DoNuclear:
;     - Increment *Pop; call place_fallout on meltdown flag
;   DoStadium / DoPort / DoAirport:
;     - Require power; check 4x4/4x4/6x6 surrounding area for road access
;     - Random chance to trigger sim_start_aircrash (airport)
;   DoChurch / DoHospital:
;     - Increment *Pop; randomly downgrade to residential if overpopulated
;
; ECONOMIC INDICES (calculate_economic_indices):
;   V_RValve = (Com+Ind-Res)*8 + StadiumPop*4 - 26   (residential demand)
;   V_CValve = ((Res+Ind)/2 - Com)*8 + AirportPop*4 - 30 (commercial demand)
;   V_IValve = ((Com+Res)/2 - Ind)*8 + PortPop*4 - 30   (industrial demand)
;   These drive whether zones upgrade (+) or downgrade (-).
;
; DISASTERS:
;   sim_maybe_start_fire_or_flood  - 1-in-4 chance each airport tick
;   sim_start_aircrash             - sets flight counter (V_aircrash_countdown); move_aircrash_sprite
;                                    ignites 2x2 cell block after countdown
;   sim_start_meltdown             - sets V_meltdown_triggered; place_fallout
;                                    scatters TILE_RADIOACTIVE in 45x45 region
;   sim_start_tornado              - wanders map, bulldozes zone tiles
;
; TRAFFIC SIMULATION (sim_update_traffic):
;   Random walk from zone centre; finds road/rail network
;   Increments traffic density minimap cell by 20 (capped at 240)
;   DecTrafficMem decays every cell each tick:
;     value<24 -> 0;  24-199 -> -24;  200+ -> -34
;   Average traffic density stored in V_TrafficAverage
;
; BUDGET (DoBudget - runs in December, month==11):
;   Copies current population/fund figures to budget panel variables
;   If auto_budget off: sets V_wait_for_budget_confirm=1 and busy-loops
;   until UI thread clears the flag (user confirms budget in menu)
;   Then reads V_money_after_budget written by UI into V_money
;
; KEY POPULATION VARIABLES (zeroed each tick by reset_simulation_vars):
;   V_CityPop  - cumulative population (24-bit, for tax calc)
;   V_ResZPop, V_ComZPop, V_IndZPop  - zone populations
;   V_PolicePop, V_FirePop, V_HospitalPop, V_ChurchPop
;   V_NuclearPop, V_CoalPop, V_StadiumPop, V_AirportPop, V_PortPop
;   V_PoliceFund, V_FireFund  - funding requested this tick
;   V_RailTotal, V_RoadTotal  - road/rail tile counts
; ============================================================

        IN_DATA
.V_zone_dispatch_suppress            defb        0       ; VAR $835D / 33629 -
.V_sim_loop_counter defb       0       ; VAR $835E / 33630 - loop counter for simulation (increments each time through)
        IN_SIM_CODE

start_simulation:
        call    zero_simulation_state                           ;Initialise all simulation vars (minimaps, disaster flags, budgets)
.L8362  call    reset_simulation_vars           ;Zero all per-tick population/fund counters
        call    set_simulation_speed
        call    generate_power_map              ;BFS from each power station; populate power minimap
        call    process_ric_zones                           ;Scan 96x96 map: evaluate zones, dispatch zone handlers
        call    create_police_fire_minimaps     ;Every 4 ticks: rebuild police/fire coverage minimaps
        call    decay_pollution_minimap                           ;Every other tick: decay pollution minimap; avg -> V_PolluteAverage
        call    DecTrafficMem                   ;Decay traffic density; compute average -> V_TrafficAverage
        call    calculate_economic_indices      ;R/C/I demand indices -> V_RValve/6/8
        call    compute_concern_scores                           ;Crime/house-price concern scores -> V_concern_crime/10
        call    calculate_city_score            ;Weighted infrastructure sum -> V_city_score
        call    set_unemployment                ;(Res-(Com+Ind))*4 -> V_unemployment
        call    census_church_hosp              ;Hospital/church demand -> V_hospital_demand/church_demand
        call    SendMessages                    ;Post advisor alerts based on city state
        call    update_stats                           ;Save safe NuclearPop/AirportPop; compute land-value centroid
        ld      a,(V_sim_loop_counter)
        ld      hl,V_sim_speed_block+4                    ;Speed-dependent month-advance mask
        and     (hl)
        jr      nz,L839b                ; (6)
        call    DoBudget                        ;Collect tax, update money; wait for UI budget confirm
        call    increment_month
.L839b  ld      hl,V_sim_loop_counter
        inc     (hl)
        jr      L8362                   ; (-63)

; Initialises the simulation variables
zero_simulation_state:                                    ; $83A1 / 33697 - Zero minimaps, reset all simulation variables (CCxy, funding, populations, disaster flags)
.L83a1  ld      hl,8224
        ld      (V_CCxy),hl
        ld      hl,minimaps
        ld      de,minimaps+1
        ld      bc,MM_BYTES-1
        ld      (hl),0
        ldir    
        ld      a,255
        ld      (V_rail_upgrade_mask),a
        ld      (V_road_upgrade_mask),a
        ld      a,15
        ld      (V_PoliceEffect),a
        ld      (V_FireEffect),a
        xor     a
        ld      (V_concern_house_price),a
        ld      (V_concern_crime),a
        ld      (V_TrafficAverage),a
        ld      (V_sim_loop_counter),a
        ld      (V_wait_for_budget_confirm),a
        ld      (V_hospital_demand),a
        ld      (V_church_demand),a
        ld      (V_transport_active),a
        ld      (V_aircrash_active),a
        ld      (V_aircrash_countdown),a
        ld      (V_meltdown_triggered),a
        ld      (V_tornado_active),a
        ld      (V_zone_dispatch_suppress),a
        ld      hl,0
        ld      (V_Transport_Funding_Requested),hl
        ld      (V_Budget_Police_Funding_Requested),hl
        ld      (V_Budget_Fire_Funding_Requested),hl
        ld      (V_Transport_Funding_Allocated),hl
        ld      (V_Police_Funding_Allocated),hl
        ld      (V_Fire_Funding_Allocated),hl
        ld      (V_unemployment),hl
        ld      (V_transport_total),hl
        ld      (V_safe_AirportPop),hl
        ld      (V_safe_NuclearPop),hl
        ld      (V_LVAverage),hl
        ld      (V_RValve),hl
        ld      (V_CValve),hl
        ld      (V_IValve),hl
        ld      c,0
        ld      h,0
        ld      l,0
        ld      (V_population),hl
        ld      a,c                     ;OPT
        ld      (V_population+2),a
        ld      (V_prev_year_population),hl
        ld      a,c                     ;OPT
        ld      (V_prev_year_population+2),a
        ld      (V_city_score),hl
        ld      a,c                     ;OPT
        ld      (V_city_score+2),a
        ld      (V_previous_city_score),hl
        ld      a,c                     ;OPT
        ld      (V_previous_city_score+2),a
        ld      (V_display_population),hl
        ld      a,c                     ;OPT
        ld      (V_display_population+2),a
        ret     

;8443, 33859
        IN_DATA
V_CityPop: defb        0,0,0       ; VAR $8443 / 33859 - 24-bit cumulative population total (summed per tick for tax revenue calculation)

V_ResZPop: defw        0       ; VAR $8446 / 33862
V_ComZPop: defw        0       ; VAR $8448 / 33864

V_IndZPop:  defw        0       ; VAR $844A / 33866
V_PolicePop:  defw        0       ; VAR $844C / 33868 - Police Population
V_FirePop:  defw        0       ; VAR $844E / 33870 - Fire Station Population
V_ChurchPop:  defw        0       ; VAR $8450 / 33872 - church population?
V_HospitalPop:  defw        0       ; VAR $8452 / 33874 - Hospital population
V_NuclearPop:  defw        0       ; VAR $8454 / 33876 - Nuclear Population

V_CoalPop:   defw        0       ; VAR $8456 / 33878 - Coal population

V_StadiumPop:  defw        0       ; VAR $8458 / 33880 - Stadium population

V_AirportPop:  defw        0       ; VAR $845A / 33882 - Airport popluation

V_PortPop:  defw        0       ; VAR $845C / 33884 - Port population

V_unPwrdZCnt:    defw        0       ; VAR $845E / 33886 - count of unpowered zone tiles this tick
V_PwrdZCnt:    defw        0       ; VAR $8460 / 33888 - count of powered zone tiles this tick
V_transport_fund:    defw        0       ; VAR $8462 / 33890 - transport funding requested (road+rail+zone contributions)
V_transport_util:    defw        0       ; VAR $8464 / 33892 - transport utilisation score (road 4/rail 3/station 6 per tile)

V_PoliceFund:   defw        0   ; VAR $8466 / 33894 - police funding requested this tick (100 per station)
V_FireFund:     defw        0   ; VAR $8468 / 33896 - fire funding requested this tick (100 per station)
V_RoadTotal:    defw        0   ; VAR $846A / 33898 - count of road tiles (tile flag bit 2; 1 transport_util each)
V_RailTotal:    defw        0   ; VAR $846C / 33900 - count of rail tiles (tile flag bit 1; 4 transport_util each)


V_police_cov_num:        defw        0   ; VAR $846E / 33902 - police coverage numerator (for crime concern score)

V_police_cov_den:        defw        0   ; VAR $8470 / 33904 - police coverage denominator
V_landval_num:        defw        0   ; VAR $8472 / 33906 - land value numerator (for house-price concern score)
V_landval_den:        defw        0   ; VAR $8474 / 33908 - land value denominator
V_traffic_sum:        defw        0   ; VAR $8476 / 33910 - traffic density accumulator (sum, for average)
V_traffic_count:        defw        0   ; VAR $8478 / 33912 - traffic tile count (denominator for average)
V_pollution_sum:        defw        0   ; VAR $847A / 33914 - pollution accumulator (sum, for average)
        IF      MAP_W != 96
V_pollution_sum_high:   defb        0   ; high byte for the 120x100 pollution accumulator
        ENDIF
V_pollution_count:        defw        0   ; VAR $847C / 33916 - pollution tile count (denominator for average)
V_landval_accum:        defw        0   ; VAR $847E / 33918 - land value accumulator (used by update_stats for tornado centroid)
        IN_SIM_CODE

      
;33920
reset_simulation_vars:
.L8480  ld      hl,V_CityPop           ;wipe out all populations
        ld      de,V_CityPop+1
        IF      MAP_W == 96
        ld      bc,60
        ELSE
        ld      bc,61
        ENDIF
        ld      (hl),0
        ldir    
        xor     a
        ld      (V_zone_extent),a
        ld      (V_zone_extent+2),a
        cpl     
        ld      (V_zone_extent+1),a
        ld      (V_zone_extent+3),a
        ret     

        IN_DATA
V_LVAverage:     defw    0           ; VAR $849C / 33948 - land value total snapshot (copy of V_landval_accum; used for display)

V_safe_AirportPop:        defw    0           ; VAR $849E / 33950
V_safe_NuclearPop:        defw    0           ; VAR $84A0 / 33952

;V_CCxy
V_CCxy:    defb $20, $20       ; VAR $84A2 / 33954 - midpoint of active zone extent (x,y); used as tornado spawn target
        IN_SIM_CODE


; Update safe copies of airport/nuclear pop, land value centroid, pollution average
update_stats:
.L84a4  ld      a,(V_zone_extent)             ;V_zone_extent tracks min/max X of active zones
        ld      hl,V_zone_extent+1
        add     a,(hl)
        srl     a
        ld      (V_CCxy),a             ;V_CCxy = midpoint X of zone extent (tornado target)
        ld      a,(V_zone_extent+2)
        ld      hl,V_zone_extent+3
        add     a,(hl)
        srl     a
        ld      (V_CCxy+1),a           ;V_CCxy+1 = midpoint Y of zone extent
        ld      hl,(V_landval_accum)
        ld      (V_LVAverage),hl            ;V_LVAverage = land value total (for display)
        ld      hl,(V_NuclearPop)
        ld      (V_safe_NuclearPop),hl  ;Snapshot for disaster probability check
        ld      hl,(V_AirportPop)
        ld      (V_safe_AirportPop),hl  ;Snapshot for aircrash probability check
        IF      MAP_W == 96
        ld      hl,(V_pollution_sum)
        ld      de,(V_pollution_count)
        call    L_div16x16
        ld      a,l
        ELSE
        ; 12,000 8-bit pollution samples need 22 accumulator bits.  The average
        ; is bounded by 255, so repeated subtraction is a compact exact divide.
        ld      de,(V_pollution_count)
        ld      a,d
        or      e
        jr      nz,pollution_average_has_samples
        xor     a                       ; an empty city has no samples: its average is zero
        ld      (V_PolluteAverage),a
        ret
pollution_average_has_samples:
        ; Divide a working copy: the running numerator keeps accumulating across
        ; ticks, so do not leave the remainder in the live accumulator.
        ld      a,(V_pollution_sum_high)
        push    af
        ld      hl,(V_pollution_sum)
        push    hl
        ld      b,0
pollution_average_divide:
        ld      a,(V_pollution_sum_high)
        or      a
        jr      nz,pollution_average_subtract_high
        ld      hl,(V_pollution_sum)
        ld      de,(V_pollution_count)
        and     a
        sbc     hl,de
        jr      c,pollution_average_done
        ld      (V_pollution_sum),hl
        jr      pollution_average_count
pollution_average_subtract_high:
        ld      hl,(V_pollution_sum)
        ld      de,(V_pollution_count)
        and     a
        sbc     hl,de
        ld      (V_pollution_sum),hl
        ld      a,(V_pollution_sum_high)
        sbc     a,0
        ld      (V_pollution_sum_high),a
pollution_average_count:
        inc     b
        jr      pollution_average_divide
pollution_average_done:
        ld      a,b
        ld      (V_PolluteAverage),a
        pop     hl
        ld      (V_pollution_sum),hl
        pop     af
        ld      (V_pollution_sum_high),a
        ret
        ENDIF
        ld      (V_PolluteAverage),a             ;V_PolluteAverage = average pollution level
        ret

        IN_DATA
V_PolluteAverage:    defb        0       ; VAR $84DD / 34013 - average pollution level city-wide (V_pollution_sum / V_pollution_count)
        IN_SIM_CODE


; Decay pollution minimap and compute average (runs every other tick)
decay_pollution_minimap:                                    ; $84DE / 34014 - On odd ticks: decay all 2304 pollution minimap cells and compute V_PolluteAverage
.L84de  ld      a,(V_sim_loop_counter)
        and     1
        ret     z
        ld      hl,minimaps+MMO_POLLUTION    ;pollution minimap
        ld      bc,MM50_SIZE
        ld      de,$4000
.L84ed  ld      a,(hl)
        sub     d
        jr      nc,L84f2                ; (1)
        ld      a,e
.L84f2  ld      (hl),a
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L84ed                ; (-12)

        ld      hl,(V_pollution_sum)
        ld      de,(V_pollution_count)
        call    L_div16x16
        ld      a,l
        srl     a
        srl     a
        ld      (V_PolluteAverage),a
        ret     


zero_police_fire_minimaps:                                    ; $850C / 34060 - Zero first 1152 bytes of minimaps (police + fire coverage maps)
.L850c  ld      hl,minimaps
        ld      de,minimaps+1
        ld      bc,2*MM25_SIZE-1
        ld      (hl),0
        ldir    
        ret     

        IN_DATA
V_TrafficAverage:    defb        0       ; VAR $851A / 34074 - average traffic density city-wide (rolling average from DecTrafficMem)
        IN_SIM_CODE

; Decay traffic density minimap every tick; compute rolling average -> V_TrafficAverage
; Decay tiers: value<24 -> 0, 24-199 -> sub 24, 200-255 -> sub 34
DecTrafficMem:
.L851b  ld      hl,minimaps+MMO_TRAFFIC
        ld      bc,MM50_SIZE

.L8521  ld      a,(hl)    
        exx     
        and     a
        jr      z,L8539                 ; (19)
        ld      e,a
        ld      d,0
        ld      hl,(V_traffic_sum)
        add     hl,de
        jr      c,L8539                 ; (10)
        ld      (V_traffic_sum),hl
        ld      hl,(V_traffic_count)
        inc     hl
        ld      (V_traffic_count),hl

.L8539  exx     
        ld      a,(hl)
        cp      24
        jr      c,L854d                 ; (14)
        cp      200
        jr      c,L8548                 ; (5)
        sub     34
        ld      (hl),a
        jr      traffic_decay_loop_next                   ; (7)

.L8548  sub     24
        ld      (hl),a
        jr      traffic_decay_loop_next                   ; (2)

.L854d  ld      (hl),0

traffic_decay_loop_next:                                    ; $854F / 34127 - Advance HL and loop back; common tail for traffic minimap decay iteration
.L854f  inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L8521                ; (-52)
        ld      hl,(V_traffic_sum)
        ld      de,(V_traffic_count)
        call    L_div16x16
        ld      a,l
        srl     a
        srl     a
        ld      (V_TrafficAverage),a
        ret     

        IN_DATA
V_traffic_active:    defb    0       ; VAR $8568 / 34152 - traffic BFS active (1=road traffic, 2=rail traffic)
V_Zsource:    defb    0       ; VAR $8569 / 34153 - tile-flag mask for the traffic walk: the transport bits (4=road, 2=rail) of the start tile; only neighbours sharing a bit are walkable
        IN_SIM_CODE

;
; TRAFFIC MODEL.  Not a true BFS: each call sends a single "commuter" on a
; random walk along the road (or rail) network to see whether the zone is
; actually connected to a suitable destination, and lays down traffic density
; along the way.
;
;   * start cell  : V_zone_best_coords (an adjacent road/rail cell chosen by
;                   scan_zone_cell); V_Zsource = that tile's road/rail bits
;   * destination : any zone whose get_zone_handler_type is one of the two bytes
;                   in V_zone_neighbour_filter (set by the caller: residential
;                   looks for commercial/industrial etc.)
;   * limit       : 30 steps (V_PosStackN)
;   * success     : V_traffic_active = 1, then every other cell visited has 20
;                   added to the traffic minimap (capped 240) and a little
;                   pollution is spread round it
;   * failure     : V_traffic_active = 0 - which calc_land_value_transport reads
;                   as "no traffic route", dragging the zone's land value to 0
;
; The path so far is kept on the (shared) V_powerqueue with V_PowerStackNum as its
; depth, so a dead end can back up one step instead of failing outright.
.sim_update_traffic
.L856a  xor     a
        ld      (V_traffic_active),a
        ld      a,(V_zone_transport_count)
        and     a
        ret     z

        ld      bc,(V_zone_best_coords)
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        call    tile_to_flags
        and     6
        ld      (V_Zsource),a
        xor     a
        ld      (V_PowerStackNum),a
        call    powerqueue_push
        call    traffic_bfs_init
        ret     c

        ld      a,1
        ld      (V_traffic_active),a
        call    process_traffic_from_connections
        ret     


; Replay the recorded path: pop each cell, add 20 to its traffic density and
; spread a pollution kernel (strength 5) round it.  Rail trips (V_Zsource bit 2
; clear) leave no density behind.
; NB the six instructions after the JR below are unreachable (the JR loops back
; until the stack empties and the RET Z above is the only way out).  They look
; like a vestige of a "transport funding" increment.
.process_traffic_from_connections
.L8599  ld      a,(V_Zsource)
        bit     2,a
        ret     z


.L859f  ld      a,(V_PowerStackNum)
        and     a
        ret     z

        call    powerqueue_pop
        call    get_traffic_density_value
        ld      a,(hl)
        add     a,20
        jr      c,L85b3                 ; (4)
        cp      240
        jr      c,L85b5                 ; (2)

.L85b3  ld      a,240

.L85b5  ld      (hl),a
        ld      a,5
        ld      (V_traffic_bfs_steps),a
        ld      ix,D_stadium_effect_kernel+36   ;second (tighter) kernel
        call    apply_stadium_kernel
        jr      L859f                   ; (-37)
        xor     a
        ld      (V_traffic_active),a
        ld      hl,(V_transport_fund)
        inc     hl
        ld      a,h
        or      l
        jr      z,L85d3                 ; (3)
        ld      (V_transport_fund),hl

.L85d3  ret     

        IN_DATA
V_LDir:    defb    0       ; VAR $85D4 / 34260 - traffic BFS previous direction (prevents immediate U-turns)
V_PosStackN:    defb    0       ; VAR $85D5 / 34261 - traffic BFS steps taken so far (trip ends at 30)
        IN_SIM_CODE


;
; The walk loop.  Each iteration:
;   traffic_bfs_try_step    - move one cell; carry set = blocked in all 4 directions
;   blocked  : back up one entry of the saved path (fail if the path is empty)
;   moved    : look for a destination zone next to the new cell (success: NC)
;   then     : ++steps, and give up (SCF) when steps reaches 30
; Exit: nc = destination found, c = failed
traffic_bfs_init:                                    ; $85D6 / 34262
.L85d6  ld      a,5
        ld      (V_LDir),a
        xor     a
        ld      (V_PosStackN),a

.L85df  call    traffic_bfs_try_step
        jr      c,L85ea                 ; (6)
        call    find_zone_neighbour_of_type
        ret     nc

        jr      traffic_bfs_step_count                   ; (12)

.L85ea  ld      a,(V_PowerStackNum)
        and     a
        jr      z,L8604                 ; (20)
        dec     a
        ld      (V_PowerStackNum),a
        jr      traffic_bfs_check_limit                   ; (7)

traffic_bfs_step_count:                                    ; $85F6 / 34294 - Increment V_PosStackN (steps taken) then fall into step-limit check
.L85f6  ld      hl,V_PosStackN
        ld      a,(hl)
        add     a,1
        ld      (hl),a

traffic_bfs_check_limit:                                    ; $85FD / 34301 - Check PosStackN >= 30 (trip complete, set SCF); else continue BFS loop
.L85fd  ld      a,(V_PosStackN)
        sub     30
        jr      c,L85df                 ; (-37)

.L8604  scf     
        ret     

        IN_DATA
V_traffic_rand_dir:    defb    0       ; VAR $8606 / 34310 - traffic BFS initial random direction (0-3) for this step
V_traffic_cur_dir:    defb    0       ; VAR $8607 / 34311 - traffic BFS current direction being tried
V_traffic_attempts:    defb    0       ; VAR $8608 / 34312 - traffic BFS attempts remaining before step fails (tries all 4 directions)
        IN_SIM_CODE


;
; One step of the random walk.  Start from a random direction and try all four in
; rotation.  A direction is rejected if it is the way we just came from (V_LDir),
; is a zone tile, or does not share a transport bit with V_Zsource.  The first
; acceptable direction is taken: BC moves, V_LDir becomes the reverse of the move,
; and on every second step the new cell is pushed onto the path stack.
; Exit: nc = moved, c = no way forward
traffic_bfs_try_step:                                    ; $8609 / 34313
.L8609  call    get_random_number
        and     3
        ld      (V_traffic_rand_dir),a
        ld      a,4
        ld      (V_traffic_attempts),a

.L8616  ld      a,(V_traffic_rand_dir)
        and     3
        ld      (V_traffic_cur_dir),a
        ld      hl,V_LDir
        cp      (hl)
        jr      z,L8638                 ; (20)
        ld      a,(V_traffic_cur_dir)
        call    levelmap_addr_in_direction                   ;Get cell in direction
        IF      MAP_W != 96
        jr      nc,L8638                ; off-map neighbour
        ENDIF
        ld      a,(hl)
        bit     7,a
        jr      nz,L8638                ; (9)
        call    tile_to_flags
        ld      hl,V_Zsource
        and     (hl)
        jr      nz,L8644                ; (12)

.L8638  ld      hl,V_traffic_rand_dir
        inc     (hl)
        ld      hl,V_traffic_attempts
        dec     (hl)
        jr      nz,L8616                ; (-44)
        scf     
        ret     


.L8644  ld      a,(V_traffic_cur_dir)
        call    coords_add_direction_offset               ;Move coords in direction
        ld      a,(V_traffic_cur_dir)
        add     a,2
        and     3
        ld      (V_LDir),a
        ld      a,(V_PosStackN)
        and     1
        call    z,powerqueue_push
        or      a
        ret     

        IN_DATA
V_zone_neighbour_filter:    defw    0           ; VAR $865E / 34398 -
        IN_SIM_CODE

; Look at the four cells orthogonally around BC; if any belongs to a zone whose
; handler type (get_zone_handler_type) matches either byte of
; V_zone_neighbour_filter, the walk has reached a destination.
; Entry: bc = coordinates
; Exit:  nc = destination found
;         c = none of the neighbours match
find_zone_neighbour_of_type:                                    ; $8660 / 34400 - Scan 4 cardinal directions; return first neighbour matching V_zone_neighbour_filter zone type, else SCF
.L8660  ld      e,4
.L8662  push    de
        ld      a,e
        dec     a
        call    levelmap_addr_in_direction                   ;Get cell in direction
        IF      MAP_W != 96
        jr      nc,L8677                ; off-map neighbour
        ENDIF
        call    get_zone_handler_type
        jr      c,L8677                 ; (10)
        ld      hl,V_zone_neighbour_filter
        cp      (hl)
        jr      z,L867d                 ; (10)
        inc     hl
        cp      (hl)
        jr      z,L867d                 ; (6)

.L8677  pop     de
        dec     e
        jr      nz,L8662                ; (-25)
        scf     
        ret     


.L867d  pop     de
        or      a
        ret     


create_police_fire_minimaps:
.L8680  ld      a,(V_sim_loop_counter)
        and     3
        ret     nz
        call    zero_police_fire_minimaps
        ld      hl,levelmap         ;
        ld      b,MAP_H
        ld      d,0
.L8690  ld      c,MAP_W
        ld      e,0
.L8694  ld      a,(hl)
        and     $f0
        cp      $b0                 ;Don't understand this, police/fire=$a3
        jr      nz,L86ae                ; (19)
        ld      (V_map_iter_xy),de
        inc     hl
        ld      a,(hl)
        and     63
        cp      0           ;police
        call    z,apply_police_kernel_save_regs
        cp      1           ;fire
        call    z,apply_fire_kernel_save_regs
        dec     hl
.L86ae  inc     hl
        inc     e
        dec     c
        jr      nz,L8694                ; (-31)
        inc     d
        djnz    L8690                   ; (-38)
        ret     


apply_police_kernel_save_regs:          ; $86B7 / 34487 - Save alternate regs, apply police station kernel, restore; trampoline for map scanner
.L86b7  exx
        ex      af,af'
        call    apply_police_station_kernel
        ex      af,af'
        exx
        ret

apply_fire_kernel_save_regs:            ; $86BF / 34495 - Save alternate regs, apply fire station kernel, restore; trampoline for map scanner
.L86bf  exx
        call    apply_fire_station_kernel
        exx
        ret

        IN_DATA
V_ZonePwrFlg: defb    0       ; VAR $86C5 / 34501 - zone is powered this cell (1=yes, 0=no)
V_zone_proc_type: defb    0       ; VAR $86C6 / 34502 - zone processing type (1=big zone centre, 2=compact RIC tile)
V_CChr: defb    0       ; VAR $86C7 / 34503 - raw tile type of the zone centre tile (used to index D_zone_handler_config)
V_zone_unpow_tile: defb    0       ; VAR $86C8 / 34504 - unpowered tile variant for check_ric_power
        IN_SIM_CODE

; Scan full 96x96 map; evaluate zone tiles and dispatch to zone handlers
; Called once per simulation tick
process_ric_zones:
.L86c9  ld      hl,levelmap
        ld      b,MAP_H
        ld      d,0
.L86d0  ld      c,MAP_W
        ld      e,0
.L86d4  xor     a
        ld      (V_ZonePwrFlg),a             ;Reset per-cell zone state
        ld      (V_zone_proc_type),a
        ld      (V_zone_unpow_tile),a
        ld      (V_CChr),a
        ld      a,(hl)
        and     $e0
        cp      $a0                     ;$a0-$bf = multi-tile zone centre (big zones)
        call    z,set_zone_power_state  ;Check power minimap, update bit 4 of tile, set V_ZonePwrFlg
        ld      a,(hl)
        cp      $51
        jr      c,L86f3                 ; <$51 = infrastructure tile, skip zone dispatch
        cp      $57
        call    c,check_ric_power       ;$51-$56 = compact R/I/C; update powered/unpowered variant
.L86f3  ld      a,(V_zone_dispatch_suppress)             ;V_zone_dispatch_suppress is set externally to suppress zone dispatch (unused in practice)
        and     a
        jr      nz,L8703                ; (10)
        ld      a,(V_zone_proc_type)
        and     a
        call    nz,L8789                ;Big zone: look up in D_zone_handler_config, dispatch via D_zone_handler_table
        call    process_infra_tile                   ;Handle road/rail/radioactive/flood tiles
.L8703  inc     hl
        inc     e
        dec     c
        jr      nz,L86d4                ; (-52)
        inc     d
        IFDEF PORTABLE
        call    sim_yield               ;end of a map row
        ENDIF
        djnz    L86d0                   ; (-59)
        ret     

; Enter: hl = map coordinate
;Check power for zone
set_zone_power_state:
.L870c  ld      a,1
        ld      (V_zone_proc_type),a
        push    hl
        push    hl
        exx     
        pop     hl
        pop     ix
        ld      a,(ix+1)
        and     63
        ld      (V_CChr),a
        cp      6
        jr      z,L8739                 ; (22)
        cp      8
        jr      z,L8739                 ; (18)
        res     4,(hl)
        call    map_addr_to_power_minimap                   ;Get minimap power map+mask
        ld      a,(hl)
        and     e
        jr      z,L8739                 ;Doesn't have power....
        set     4,(ix+0)                ;We've got power!
        ld      a,1
        ld      (V_ZonePwrFlg),a
.L8739  exx     
        ret     

        IN_DATA
V_ric_tile_current: defb    0   ; VAR $873B / 34619 - current RIC tile state byte (powered/unpowered variant)
        IN_SIM_CODE


; Process RIC characters
check_ric_power:
.L873c  ld      a,2
        ld      (V_zone_proc_type),a
        push    hl
        push    hl
        exx     
        pop     ix
        pop     hl
        ld      a,(hl)
        ld      d,84
        ld      e,81
        cp      d
        jr      z,L8760                 ; (17)
        cp      e
        jr      z,L8760                 ; (14)
        ld      d,85
        ld      e,82
        cp      d
        jr      z,L8760                 ; (7)
        cp      e
        jr      z,L8760                 ; (4)
        ld      d,86
        ld      e,83

.L8760  ld      a,d                     ;Unpowered version
        ld      (V_zone_unpow_tile),a
        ld      (V_ric_tile_current),a
        push    de
        call    map_addr_to_power_minimap                   ;Get minimap power map+mask
        ld      a,(hl)
        and     e
        pop     de
        jr      z,L8779                 ;No power
        ld      a,e                     ;Set powr flag
        ld      (V_ric_tile_current),a
        ld      a,1
        ld      (V_ZonePwrFlg),a
.L8779  exx     
        ld      a,(V_ric_tile_current)
        cp      (ix+0)
        ret     z                       ;Power state hasn't changed
        ld      (ix+0),a
.L8784  ret     


        IN_DATA
V_map_iter_xy: defw    0       ; VAR $8785 / 34693 - map coordinates whilst iterating
V_map_iter_addr: defw    0       ; VAR $8787 / 34695 - map address whilst iterating
        IN_SIM_CODE


.L8789  ld      (V_map_iter_addr),hl
        ld      (V_map_iter_xy),de
        exx     
        ld      hl,L8789_return
        push    hl
        call    update_powered_zone_count
        call    update_zone_extent_both_axes
        ld      a,(V_zone_proc_type)
        cp      2
        jr      z,L87e4                 ; Handling RIC
        cp      1
        jp      z,L886b                 ; Handling other zones
        pop     hl
L8789_return:
        exx     
        ret     


update_powered_zone_count:                                    ; $87AA / 34730 - If ZonePwrFlg set increment V_PwrdZCnt, else increment V_unPwrdZCnt
.L87aa  ld      a,(V_ZonePwrFlg)
        and     a
        jr      z,L87bc                 ; (12)
        ld      hl,(V_PwrdZCnt)
        inc     hl
        ld      a,h
        or      l
        jr      z,L87bb                 ; (3)
        ld      (V_PwrdZCnt),hl
.L87bb  ret     


.L87bc  ld      hl,(V_unPwrdZCnt)
        inc     hl
        ld      a,h
        or      l
        jr      z,L87c7                 ; (3)
        ld      (V_unPwrdZCnt),hl
.L87c7  ret     

        IN_DATA
V_zone_extent:    defb    0, 255, 0, 255      ; VAR $87C8 / 34760 - zone bounding box: minX, maxX, minY, maxY (reset to 0,255,0,255 each tick)
        IN_SIM_CODE



update_zone_extent_both_axes:                                    ; $87CC / 34764 - Update both axes of V_zone_extent bounding box from V_map_iter_xy X and Y
.L87cc  ld      a,(V_map_iter_xy)
        ld      hl,V_zone_extent
        call    update_zone_extent_axis
        ld      a,(V_map_iter_xy+1)
        ld      hl,V_zone_extent+2
update_zone_extent_axis:                                    ; $87DB / 34779 - Update one axis of V_zone_extent bounding box (min/max) with value in A
.L87db  cp      (hl)
        jr      c,L87df                 ; (1)
        ld      (hl),a
.L87df  inc     hl
        cp      (hl)
        ret     nc
        ld      (hl),a
        ret     


; Dispatch compact RIC tile (tiles $51-$56) to the appropriate powered zone handler
; V_zone_unpow_tile holds the unpowered tile variant determined by check_ric_power
dispatch_compact_ric:
.L87e4  xor     a
        ld      (V_zone_handler_params),a
        ld      a,(V_zone_unpow_tile)
        cp      84          ;84 = unpowered residential -> DoResidential (powered path)
        jp      z,L8aa3
        cp      85          ;85 = unpowered commercial -> DoCommercial (powered path)
        jp      z,L8bc4
        cp      86          ;86 = unpowered industrial -> DoIndustrial (powered path)
        jp      z,L8c5b
        ret

; Zone handler jump table, indexed by D_zone_handler_config byte 1
        IN_RODATA
D_zone_handler_table:                   ; $87FB / 34811 - dispatch table of function pointers for special zone processors
        defw    DoPolice        ;0
        defw    DoFire          ;1
        defw    DoChurch        ;2
        defw    DoHospital      ;3
        defw    DoStadium       ;4
        defw    DoCoal          ;5
        defw    DoNuclear       ;6
        defw    DoPort          ;7
        defw    DoAirport       ;8
        defw    DoResidential   ;9
        defw    DoCommercial    ;a
        defw    DoIndustrial    ;b


; Zone lookup table: 4 bytes per entry
;   byte 0 = tile type (V_CChr) to match
;   byte 1 = D_zone_handler_table handler index (*2 for word table offset)
;   byte 2 = V_zone_handler_params+1 (zone sub-type parameter)
;   byte 3 = V_zone_handler_params+0 (zone density/population scale factor)
D_zone_handler_config:                  ; $8813 / 34835 - per-zone config: (tile-type, handler-idx, ?, budget) 4 bytes each
        defb    0,0,0,10                ;police
        defb    1,1,0,10                ;fire
        defb    2,2,0,5                 ;church
        defb    3,3,0,10                ;hospital
        defb    4,4,0,$1e               ;stadium
        defb    6,5,0,10                ;coal
        defb    8,6,0,10                ;nuclear
        defb    10,7,0,$1e              ;port
        defb    $0c,$08,$00,$28         ;airport
        IFDEF   FINE_ZONE_LEVELS
        ; A zone's type is the group (piece / 8) of the first piece of its picture, and a picture is nine pieces: the
        ; residential pictures start at piece 136, the commercial at 208 and the industrial at 298.  (Group $22
        ; and $2b start no picture.)
        defb    $11,$09,$00,$50         ;residential level 1
        defb    $12,$09,$01,$60
        defb    $13,$09,$02,$70
        defb    $14,$09,$03,$80
        defb    $15,$09,$04,$90
        defb    $16,$09,$05,$a0
        defb    $17,$09,$06,$b0
        defb    $18,$09,$07,$c0
        defb    $1a,$0a,$00,$04         ;commercial level 1
        defb    $1b,$0a,$01,$08
        defb    $1c,$0a,$02,$0c
        defb    $1d,$0a,$03,$10
        defb    $1e,$0a,$04,$14
        defb    $1f,$0a,$05,$18
        defb    $20,$0a,$06,$1c
        defb    $21,$0a,$07,$20
        defb    $23,$0a,$08,$24
        defb    $24,$0a,$09,$28
        defb    $25,$0b,$00,$08         ;industrial level 1
        defb    $26,$0b,$01,$10
        defb    $27,$0b,$02,$18
        defb    $28,$0b,$03,$20
        defb    $29,$0b,$04,$28
        defb    $2a,$0b,$05,$30
        defb    $2c,$0b,$06,$38
        defb    $2d,$0b,$07,$40
        ELSE
        defb    $11,$09,$00,$60         ;residential density 1
        defb    $12,$09,$01,$80         ;residential density 2
        defb    $13,$09,$02,$a0         ;residential density 3
        defb    $14,$09,$03,$c0         ;residential density 4
        defb    $15,$0a,$00,$0a         ;commercial density 1
        defb    $16,$0a,$01,$14         ;commercial density 2
        defb    $17,$0a,$02,$1e         ;commercial density 3
        defb    $18,$0a,$03,$28         ;commercial density 4
        defb    $1a,$0b,$00,$10         ;industrial density 1
        defb    $1b,$0b,$01,$20         ;industrial density 2
        defb    $1c,$0b,$02,$30         ;industrial density 3
        defb    $1d,$0b,$03,$40         ;industrial density 4
        ENDIF
        defb    $ff,$ff                 ;sentinel
        IN_SIM_CODE

        IN_DATA
V_zone_handler_params:                                        ; VAR $8869 / 34921
        defb    $00, $00         ;VAR 8869/34921 - density/sub-type from D_zone_handler_config for current zone
        IN_SIM_CODE

; Dispatch zone handler: search D_zone_handler_config for V_CChr (tile type), load V_zone_handler_params
; parameters, then jump via D_zone_handler_table to the appropriate DoXxx handler
dispatch_zone_handler:
.L886b  ld      hl,D_zone_handler_config
        ld      bc,4
        ld      a,(V_CChr)
        ld      e,a
.L8875  ld      a,(hl)
        cp      255
        ret     z
        cp      e
        jr      z,L887f                 ; (3)
        add     hl,bc
        jr      L8875                   ; (-10)

.L887f  inc     hl
        ld      c,(hl)
.L8881  inc     hl
        ld      a,(hl)
        ld      (V_zone_handler_params+1),a
        inc     hl
        ld      a,(hl)
        ld      (V_zone_handler_params),a
        sla     c
        ld      b,0
        ld      hl,D_zone_handler_table
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)

; Per-tick processing of every non-zone tile (< 128).
;   89 TILE_RADIOACTIVE : may decay to rubble, otherwise pollutes its surroundings
;   69 TILE_FIRE        : burns out (more likely near a fire station) or spreads
;   68 TILE_FLOOD       : spreads; all flood tiles vanish when V_flood_timer expires
;   tile flag bit 2     : ROAD - counted in V_RoadTotal, costs 1 transport_util (+3 for
;                         bridge tiles 18/19), may spawn a traffic sprite
;   tile flag bit 1     : RAIL - counted in V_RailTotal, costs 4 transport_util (+6 for
;                         the 31/32 crossings)
; For road and rail, the funding-dependent upgrade mask (alloc_funding_levels)
; gives an underfunded tile a 1 in (mask+1) chance each tick of crumbling to
; rubble (crumble_to_rubble).
process_infra_tile:
.L8898  ld      a,(hl)
        cp      128
        ret     nc                      ;Zone tile (bit 7 set) - nothing to do here

        ld      (V_map_iter_addr),hl
        ld      (V_map_iter_xy),de
        exx
        ld      hl,L8898_return
        push    hl
        cp      TILE_RADIOACTIVE
        jp      z,L8942                 ; Radioactive: may decay to rubble, else pollutes
        cp      69
        jp      z,L8962                 ; Fire: counted, may burn out (fire cover) or spread
        cp      68
        jp      z,L8986                 ; Flood: spreads until V_flood_timer runs out
        call    tile_to_flags
        bit     2,a
        jr      nz,L88c6                ; Road tile (bit 2): count road, add upkeep
        bit     1,a
        jr      nz,L8903                ; Rail tile (bit 1): count rail, add upkeep, maybe spawn sprite
        pop     hl
L8898_return:
        exx     
        ret     

        IN_DATA
V_rail_upgrade_mask:    defb    $FF         ; VAR $88C5 / 35013 -
        IN_SIM_CODE

.L88c6  ld      hl,V_rail_upgrade_mask
        ld      a,(hl)
        inc     a
        jr      z,L88d4                 ; (7)
        call    get_random_number
        and     (hl)
        jp      z,L8956

.L88d4  ld      hl,(V_RoadTotal)
        inc     hl
        ld      a,h
        or      l
        jr      z,L88df                 ; (3)
        ld      (V_RoadTotal),hl

.L88df  ld      hl,(V_transport_util)
        inc     hl
        ld      a,h
        or      l
        jr      z,L88ea                 ; (3)
        ld      (V_transport_util),hl

.L88ea  ld      hl,(V_map_iter_addr)
        ld      a,(hl)
        cp      19
        jr      z,L88f5                 ; (3)
        cp      18
        ret     nz


.L88f5  ld      hl,(V_transport_util)
        ld      de,3
        add     hl,de
        jr      c,L8901                 ; (3)
        ld      (V_transport_util),hl

.L8901  ret     

        IN_DATA
V_road_upgrade_mask:    defb    0       ; VAR $8902 / 35074 -
        IN_SIM_CODE

.L8903  ld      hl,V_road_upgrade_mask
        ld      a,(hl)
        inc     a
        jr      z,L8910                 ; (6)
        call    get_random_number
        and     (hl)
        jr      z,L8956                 ; (70)

.L8910  ld      hl,(V_RailTotal)
        inc     hl
        ld      a,h
        or      l
        jr      z,L891b                 ; (3)
        ld      (V_RailTotal),hl

.L891b  ld      hl,(V_transport_util)
        ld      de,4
        add     hl,de
        jr      c,L8927                 ; (3)
        ld      (V_transport_util),hl

.L8927  call    maybe_spawn_transport
        ld      hl,(V_map_iter_addr)
        ld      a,(hl)
        cp      32
        jr      z,L8935                 ; (3)
        cp      31
        ret     nz


.L8935  ld      hl,(V_transport_util)
        ld      de,6
        add     hl,de
        jr      c,L8941                 ; (3)
        ld      (V_transport_util),hl

.L8941  ret     


; Radioactive tile: a 1 in 4096 chance per tick of decaying to rubble (the
; test is on the low 12 bits of the freshly stepped random seed); otherwise it
; spreads strength-64 pollution round itself.
.process_radioactive_tile
.L8942  call    get_random_number
        ld      hl,(V_random_seed)
        ld      a,h
        and     15
        or      l
        jr      z,L8956                 ; (8)
        ld      a,64
        ld      (V_traffic_bfs_steps),a
        jp      apply_stadium_kernel_from_iter

.crumble_to_rubble
.L8956  ld      hl,(V_map_iter_addr)
        ld      (hl),58
        ret     

place_dirt:
.L895c  ld      hl,(V_map_iter_addr)
        ld      (hl),TILE_DIRT
        ret     


; Fire tile (69).  Counted in V_landval_accum (this is the fire count that feeds
; the "fire concern" in the evaluation).  Fire-station coverage c (0..15, from the
; fire minimap) gives a (c+1)/16 chance per tick of burning out to rubble.
; Otherwise it spreads: fill tile 69, fill mode 0 (see fire_spread_to_neighbours).
.process_fire_tile
.L8962  ld      hl,(V_landval_accum)
        inc     hl
        ld      a,h
        or      l
        jr      z,L896d                 ; (3)
        ld      (V_landval_accum),hl

.L896d  call    get_fire_minimap_value
        inc     a
        ld      b,a
        call    get_random_number
        and     15
        cp      b
        jr      c,L8956                 ; (-36)
        ld      a,69
        ld      (V_fill_tile),a
        xor     a

.L8980  ld      (V_fill_mode_flag),a
        jr      fire_spread_to_neighbours                   ; (22)

        IN_DATA
V_flood_timer:  defb    $32         ; VAR $8985 / 35205 -
        IN_SIM_CODE

.process_flood_tile                     ; $8986 / 35206
.L8986
        ld      hl,V_flood_timer
        ld      a,(hl)
        and     a
        jr      z,place_dirt                 ; (-49)
        dec     (hl)
        ld      a,68
        ld      (V_fill_tile),a
        ld      (V_fill_mode_flag),a
        jr      fire_spread_to_neighbours                   ; (3)

        IN_DATA
V_fill_tile:    defb    0       ; VAR $8998 / 35224 -
V_fill_mode_flag:    defb    0       ; VAR $8999 / 35225 -
V_fire_neighbour_count:    defb    0       ; VAR $899A / 35226 -
        IN_SIM_CODE

fire_spread_to_neighbours:                                    ; $899B / 35227 - Scan 4 neighbours of current zone; probabilistically bulldoze flammable tiles to spread fire
.L899b  xor     a
        ld      (V_fire_neighbour_count),a
        ld      e,4
.L89a1  push    de
        ld      bc,(V_map_iter_xy)
        ld      a,e
        dec     a
        call    coords_add_direction_offset               ;Move coords in direction
        IF      MAP_W == 96
        call    levelmap_xypos
        ELSE
        call    levelmap_xypos_with_check
        ENDIF
        jr      nc,L89d3                ; (35)
        ld      a,(V_fill_mode_flag)
        and     a
        jr      nz,L89c2                ; (12)
        ld      a,(hl)
        cp      128
        jr      nc,L89c2                ; (7)
        call    tile_to_flags
        bit     7,a
        jr      z,L89d3                 ; (17)
.L89c2  ld      a,(V_fire_neighbour_count)
        inc     a
        ld      (V_fire_neighbour_count),a
        call    get_random_number
        and     7
        jr      nz,L89d3                ; (3)
        call    bulldoze_or_fill_zone_tile
.L89d3  pop     de
        dec     e
        jr      nz,L89a1                ; (-54)
        ld      a,(V_fill_mode_flag)
        and     a
        ret     nz
        call    get_random_number
        and     3
        ret     nz
        ld      a,(V_fire_neighbour_count)
        and     a
        jp      z,L8956
        ret     


bulldoze_or_fill_zone_tile:                                    ; $89EA / 35306 - Overwrite tile at HL with V_fill_tile unless it is a joinable tile or large zone block
.L89ea  ld      a,(V_fill_mode_flag)
        and     a
        jr      z,L89f3                 ; (3)
        ld      a,(hl)
        and     a
        ret     z
.L89f3  bit     7,(hl)
        jp      nz,fill_zone_with_tile
        push    hl
        ld      hl,D_joinable_tile_list
        ld      bc,8
        cpir    
        pop     hl
        ret     z
        ld      a,(V_fill_tile)
        ld      (hl),a
        ret     


;
; The eight cells ringing the centre tile of a 3x3 zone.  Each entry is
;   (dy, dx, ring tile)
; where "ring tile" is the tile that sits in that position in a freshly placed,
; empty zone (see residential_zone_2: $49 $4A $4B / $50 [$51] $4C / $4F $4E $4D).
; Indexed by (random & 7) * 3 in zone_pick_ring_cell.
        IN_RODATA
D_zone_ring_offsets:                    ; $8A08 / 35336
;8a08
        defb    $FF, $FF, $49, $FF, $00, $4A, $FF, $01
        defb    $4B, $00, $FF, $50, $00, $01, $4C, $01
        defb    $FF, $4F, $01, $00, $4E, $01
        
        
        defb    $01, $4D
        IN_SIM_CODE


;
; Pick one of the eight cells around the zone centre at random.
; Entry: V_map_iter_xy = zone centre
; Exit:  bc = coordinates of the chosen cell (b=y, c=x)
;        ix -> its D_zone_ring_offsets entry, so (ix+2) is the ring tile that belongs there
zone_pick_ring_cell:                                    ; $8A20 / 35360
.L8a20  call    get_random_number
        and     7
        ld      c,a
        add     a,a
        add     a,c
        ld      c,a
        ld      b,0
        ld      ix,D_zone_ring_offsets
        add     ix,bc
        ld      a,(V_map_iter_xy)
        add     a,(ix+1)
        ld      c,a
        ld      a,(V_map_iter_xy+1)
        add     a,(ix+0)
        ld      b,a
        ret     


;
; Make up to V_sim_speed_block[0] attempts at growing a random ring cell by one
; stage (the count differs with sim speed).  Stops after the first attempt that
; actually changes a cell (zone_ring_grow returns nc).  Called from DoResidential
; when the zone's density is below half its land value; the shrink twin is
; zone_ring_shrink_ticks.  Nothing happens when paused ($FF).
zone_ring_grow_ticks:
.L8a40
        ld      a,(V_sim_speed_block)
        cp      255
        ret     z

        ld      b,a

.L8a47  push    bc
        call    zone_pick_ring_cell
        call    zone_ring_grow
        pop     bc
        ret     nc
        djnz    L8a47                   ; (-11)
        ret     


;
; Develop one cell of the ring around a zone by a single stage.
;
; Tiles 60..67 are the "built" states of a ring cell ($D9 in D_tile_flags: bit 4
; set = part of a developable ring, bit 6 = residential).  Growth walks the cell
; through them:
;     ring tile (empty)  ->  60  ->  61  -> ... ->  67
; A cell that is already at 67 is left alone.  Cells whose tile flags do not
; have bit 4 set (roads, water, other zones...) are ignored too.
;
; Entry: bc = cell, ix -> D_zone_ring_offsets entry (ix+2 = empty ring tile)
; Exit:  nc = the cell was advanced one stage - the caller is finished
;        c  = nothing changed (ignored cell or already fully built); the
;             caller picks another random cell and tries again
zone_ring_grow:                                    ; $8A53 / 35411
.L8a53
        IF      MAP_W == 96
        call    levelmap_xypos
        ELSE
        call    levelmap_xypos_with_check
        jr      c,zone_ring_grow_on_map
        scf
        ret
zone_ring_grow_on_map:
        ENDIF
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z

        ld      a,(hl)
        cp      (ix+2)
        jr      nz,L8a66                ; (3)
        ld      (hl),60
        ret     


.L8a66  ld      a,(hl)
        inc     a
        cp      68
        jp      z,L8604
        ld      (hl),a
        or      a
        ret     


;
; Mirror of zone_ring_grow_ticks: make up to V_sim_speed_block[0] attempts at
; shrinking a random ring cell by one stage.  Stops after the first attempt that
; actually changes a cell (zone_ring_shrink returns nc).  Does nothing when the
; simulation is paused (speed block value $FF).
zone_ring_shrink_ticks:                                    ; $8A70 / 35440
.L8a70  ld      a,(V_sim_speed_block)
        cp      255
        ret     z
        ld      b,a
.L8a77  push    bc
        call    zone_pick_ring_cell
        call    zone_ring_shrink
        pop     bc
        ret     nc
        djnz    L8a77                   ; (-11)
        ret     


;
; Reverse of zone_ring_grow: take one stage of development off a ring cell.
;     67 -> 66 -> ... -> 60 -> (59 = sentinel, replaced by) the empty ring tile
; If the cell already holds the empty ring tile there is nothing left to remove.
; Entry/Exit as zone_ring_grow: nc = a stage was removed, c = nothing changed.
zone_ring_shrink:                                    ; $8A83 / 35459
.L8a83
        IF      MAP_W == 96
        call    levelmap_xypos
        ELSE
        call    levelmap_xypos_with_check
        jr      c,zone_ring_shrink_on_map
        scf
        ret
zone_ring_shrink_on_map:
        ENDIF
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      a,(hl)
        cp      (ix+2)
        jp      z,L8604
        ld      a,(hl)
        dec     a
        cp      59
        jr      nz,L8aa0                ; (6)
        ld      a,(ix+2)
        ld      (hl),a
        or      a
        ret     


.L8aa0  ld      (hl),a
        or      a
        ret     

; Process residential zone
.L8aa3  ld      bc,(V_map_iter_xy)
        dec     b                   ;Back to top left corner of zone
        dec     c
        call    scan_3x3_zone
        ld      hl,(V_ResZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8ab7                 ; (3)
        ld      (V_ResZPop),hl

.L8ab7  ld      a,(V_zone_handler_params)
        ld      e,a
        ld      d,0
        call    citypop_add_de_times16                   ;Adds de to (33859..61)
        ld      a,(V_zone_transport_count)
        ld      (V_traffic_active),a
        call    get_random_number
        and     63
        ld      hl,V_zone_handler_params
        sub     (hl)
        jr      nc,L8ada                ; (9)
        ld      hl,$0a0b
        ld      (V_zone_neighbour_filter),hl
        call    sim_update_traffic                   ;Some transport check?
.L8ada  call    accumulate_pollution
        ld      hl,(V_RValve)
        ld      (V_zone_landval_mult),hl
        call    update_zone_population
        ld      a,(V_zone_handler_params)
        cp      16
        jr      c,L8aed                 ; (0) BUG?? L8afe makes more sense?
.L8aed  ld      a,(V_zone_handler_params)
        cp      63
        jr      nc,L8afe                ; (10)
        ld      hl,V_zone_half_landval
        cp      (hl)
        jp      c,L8a40
        jp      zone_ring_shrink_ticks


.L8afe  ld      a,(V_hospital_demand)
        and     a
        jr      nz,L8b17                ; (19)
        ld      a,(V_church_demand)
        and     a
        jr      nz,L8b27                ; (29)
        xor     a
        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      de,136
        jp      write_zone_print_entries

.L8b17  xor     a
        ld      (V_hospital_demand),a
        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      de,27
        jp      write_zone_print_entries

.L8b27  xor     a
        ld      (V_church_demand),a
        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      de,18
        jp      write_zone_print_entries

DoResidential:
L8b37:
        ld      hl,(V_ResZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8b42                 ; (3)
        ld      (V_ResZPop),hl
.L8b42  ld      bc,(V_map_iter_xy)
        call    scan_3x3_zone
        ld      a,(V_zone_handler_params)
        ld      e,a
        ld      d,0
        call    citypop_add_de_times16
        ld      a,(V_zone_transport_count)
        ld      (V_traffic_active),a
        call    get_random_number
        and     127
        ld      hl,V_zone_handler_params
        sub     (hl)
        jr      nc,L8b6c                ; (9)
        ld      hl,$0a0b
        ld      (V_zone_neighbour_filter),hl
        call    sim_update_traffic
.L8b6c  call    accumulate_pollution
        ld      a,(V_RValve)
        ld      (V_zone_landval_mult),a
        call    update_zone_population
        call    get_random_number
        ld      hl,V_sim_speed_block+1
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_zone_growth_factor)
        cp      8
        jr      nc,L8ba9                ; (30)
        IFNDEF  FINE_ZONE_LEVELS
        srl     a                       ; two growth levels to a picture
        ENDIF
        ld      bc,(V_map_iter_xy)
        ld      de,136                  ; (FINE_ZONE_LEVELS: eight pictures, one for each level)
        jp      write_zone_print_entries

;35735
        IN_RODATA
residential_zone_1:
        defb    $42, $40, $42
        defb    $41, $51, $43
        defb    $43, $42, $43


;35744/8ba0
; This is just the default zone 
residential_zone_2:
        defb    $49, $4a, $4b
        defb    $50, $51, $4c
        defb    $4f, $4e, $4d
        IN_SIM_CODE


.L8ba9  ld      ix,residential_zone_1
; Called by the simulator to place a zone
; This is used to up/downgrade a zone
sim_place_zone_3x3:
.L8bad  ld      bc,(V_map_iter_xy)
        call    levelmap_xypos
        ld      bc,$0303
        jp      place_zone_direct

        IN_RODATA
D_density_class_table:                  ; $8BBA / 35770 - population count index -> density class 0-3
        defb    $00, $00, $01, $01, $01, $02
        defb    $02, $03, $03, $03
        IN_SIM_CODE
        

.L8bc4  ld      hl,(V_ComZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8bcf                 ; (3)
        ld      (V_ComZPop),hl

.L8bcf  ld      a,(V_ZonePwrFlg)
        and     a
        ret     z

        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      (V_map_iter_xy),bc
        jr      do_commercial_zone_scan                   ; (11)

DoCommercial:
L8be0:
        ld      hl,(V_ComZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,do_commercial_zone_scan                 ; (3)
        ld      (V_ComZPop),hl
do_commercial_zone_scan:                                    ; $8BEB / 35819 - Scan 3x3 commercial zone: count transport, compute traffic, accumulate pollution and land value
.L8beb  ld      bc,(V_map_iter_xy)
        call    scan_3x3_zone
        ld      a,(V_zone_transport_count)
        ld      (V_traffic_active),a
        call    get_random_number
        and     31
        ld      hl,V_zone_handler_params
        sub     (hl)
        jr      nc,L8c0c                ; (9)
        ld      hl,$090b
        ld      (V_zone_neighbour_filter),hl
        call    sim_update_traffic
.L8c0c  call    accumulate_pollution
        ld      hl,(V_CValve)
        ld      (V_zone_landval_mult),hl
        call    calc_commercial_growth_index
        call    get_random_number
        ld      hl,V_sim_speed_block+2
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_com_growth_index)
        call    check_industrial_pop_nonzero
        cp      0
        jr      z,L8c4a                 ; (28)
        dec     a
        IFDEF   FINE_ZONE_LEVELS
        ld      bc,(V_map_iter_xy)      ; ten pictures, one for each level
        ld      de,208
        ELSE
        ld      c,a
        ld      b,0
        ld      hl,D_density_class_table
        add     hl,bc
        ld      a,(hl)
        ld      bc,(V_map_iter_xy)
        ld      de,172
        ENDIF
        jp      write_zone_print_entries

;8c41, 35905 
        IN_RODATA
commercial_zone_1:
        defb    $49, $4a, $4b
        defb    $50, $52, $4c
        defb    $4f, $4e, $4d
        IN_SIM_CODE


.L8c4a  ld      bc,(V_map_iter_xy)
        call    levelmap_xypos
        ld      bc,$0303
        ld      ix,commercial_zone_1
        jp      place_zone_direct

.L8c5b  ld      hl,(V_IndZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8c66                 ; (3)
        ld      (V_IndZPop),hl

.L8c66  ld      a,(V_ZonePwrFlg)
        and     a
        ret     z

        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      (V_map_iter_xy),bc
        jr      do_industrial_zone_scan                   ; (11)


; Process an industrial zone
DoIndustrial:
L8c77:
        ld      hl,(V_IndZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,do_industrial_zone_scan                 ; (3)
        ld      (V_IndZPop),hl

do_industrial_zone_scan:                                    ; $8C82 / 35970 - Scan 3x3 industrial zone: count transport, compute land value/growth, determine upgrade/downgrade
.L8c82  ld      bc,(V_map_iter_xy)
        call    scan_3x3_zone
        ld      a,(V_zone_transport_count)
        ld      (V_traffic_active),a
        call    get_random_number
        and     63
        ld      hl,V_zone_handler_params
        sub     (hl)
        jr      nc,L8ca3                ; (9)
        ld      hl,$0909
        ld      (V_zone_neighbour_filter),hl
        call    sim_update_traffic

.L8ca3  ld      hl,(V_IValve)
        ld      (V_zone_landval_mult),hl
        xor     a
        ld      (V_zone_landval_local),a
        call    calc_industrial_growth_index
        call    get_random_number
        ld      hl,V_sim_speed_block+1
        and     (hl)
        jr      nz,L8cd5                ; (28)
        ld      a,(hl)
        cp      255
        jr      z,L8cd5                 ; (23)
        ld      a,(V_ind_growth_index)
        call    check_industrial_pop_nonzero
        cp      0
        jr      z,L8cfa                 ; (50)
        dec     a
        IFDEF   FINE_ZONE_LEVELS
        ld      bc,(V_map_iter_xy)      ; eight pictures, one for each level
        ld      de,298
        ELSE
        srl     a
        ld      bc,(V_map_iter_xy)
        ld      de,208
        ENDIF
        call    write_zone_print_entries

.L8cd5  ld      a,(V_ind_growth_index)
        add     a,a
        add     a,a
        ld      (V_traffic_bfs_steps),a
        jp      apply_stadium_kernel_from_iter

check_industrial_pop_nonzero:                                    ; $8CE0 / 36064 - Return Z if V_display_population (industrial population) is zero; gates industrial zone upgrades
.L8ce0  push    af
        ld      hl,V_display_population
        ld      a,(hl)
        inc     hl
        or      (hl)
        inc     hl
        or      (hl)
        jp      z,L8cee
        pop     af
        ret     


.L8cee  pop     af
        xor     a
        ret     

        IN_RODATA
industrial_zone_1:
        defb    $49, $4a, $4b
        defb    $50, $53, $4c
        defb    $4f, $4e, $4d
        IN_SIM_CODE


.L8cfa  ld      bc,(V_map_iter_xy)
        call    levelmap_xypos
        ld      bc,$0303
        ld      ix,industrial_zone_1
        jp      place_zone_direct

DoCoal:
L8d0b:
        ld      hl,(V_CoalPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8d16                 ; (3)
        ld      (V_CoalPop),hl

.L8d16  xor     a
        ld      (V_zone_landval_mult),a
        ld      (V_zone_landval_local),a
        ld      (V_zone_transport_score),a
        inc     a
        ld      (V_traffic_active),a
        call    calculate_zone_land_value
        ld      a,255
        ld      (V_traffic_bfs_steps),a
        jp      apply_stadium_kernel_from_iter

DoNuclear:
L8d2f:
        ld      hl,(V_NuclearPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8d3a                 ; (3)
        ld      (V_NuclearPop),hl

.L8d3a  xor     a
        ld      (V_zone_landval_mult),a
        ld      (V_zone_landval_local),a
        ld      (V_zone_transport_score),a
        inc     a
        ld      (V_traffic_active),a
        call    calculate_zone_land_value
        call    place_fallout
        ld      a,48
        ld      (V_traffic_bfs_steps),a
        jp      apply_stadium_kernel_from_iter

DoPolice:
L8d56:
        ld      hl,(V_PoliceFund)
        ld      de,100
        add     hl,de
        jr      c,L8d62                 ; (3)
        ld      (V_PoliceFund),hl
.L8d62  ld      a,(V_ZonePwrFlg)
        and     a
        ret     z
        ld      hl,(V_PolicePop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8d72                 ; (3)
        ld      (V_PolicePop),hl
.L8d72  ret     

DoFire:
L8d73:
        ld      hl,(V_FireFund)
        ld      de,100
        add     hl,de
        jr      c,L8d7f                 ; (3)
        ld      (V_FireFund),hl
.L8d7f  ld      a,(V_ZonePwrFlg)
        and     a
        ret     z
        ld      hl,(V_FirePop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8d8f                 ; (3)
        ld      (V_FirePop),hl
.L8d8f  ret     

DoChurch:
L8d90:
        ld      hl,(V_ChurchPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8d9b                 ; (3)
        ld      (V_ChurchPop),hl
        ; This code downgrades the hospital into residential randomly
.L8d9b  call    get_random_number
        ld      hl,V_sim_speed_block+1
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_ZonePwrFlg)
        and     a
        jr      nz,L8db4                ; (7) TODO: Oopt
        ld      ix,residential_zone_2
        jp      sim_place_zone_3x3
.L8db4  ret     

; cf s_zone.c:DoHospChur
DoHospital:
        ld      hl,(V_HospitalPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8dc0                 ; (3)
        ld      (V_HospitalPop),hl

        ; This code downgrades the hospital into residential randomly
.L8dc0  call    get_random_number
        ld      hl,V_sim_speed_block+1
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_ZonePwrFlg)
        and     a
        jr      nz,L8dd9                ; TODO: OPT
        ld      ix,residential_zone_2
        jp      sim_place_zone_3x3

.L8dd9  ret     

DoStadium:
L8dda:
        ld      a,(V_ZonePwrFlg)
        and     a
        ret     z
        ld      bc,(V_map_iter_xy)
        ld      hl,$0404
        call    scan_zone_with_size
        ld      a,(V_zone_transport_count)
        and     a
        ret     z
        ld      (V_traffic_active),a
        ld      hl,$0909
        ld      (V_zone_neighbour_filter),hl
        call    get_random_number
        and     31
        call    z,sim_update_traffic
        ld      a,(V_traffic_active)
        and     a
        ret     z
        ld      hl,(V_StadiumPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8e0f                 ; (3)
        ld      (V_StadiumPop),hl
.L8e0f  ret     

DoPort:
L8e10:
        ld      a,(V_ZonePwrFlg)
        and     a
        ret     z
        ld      bc,(V_map_iter_xy)
        ld      hl,$0404
        call    scan_zone_with_size
        ld      a,(V_zone_seas)
        and     a
        ret     z
        ld      a,(V_zone_transport_count)
        and     a
        ret     z
        ld      (V_traffic_active),a
        ld      hl,$0b0b
        ld      (V_zone_neighbour_filter),hl
        call    get_random_number
        and     31
        call    z,sim_update_traffic
        ld      a,(V_traffic_active)
        and     a
        ret     z
        ld      hl,(V_PortPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8e4a                 ; (3)
        ld      (V_PortPop),hl
.L8e4a  ld      a,96
        ld      (V_traffic_bfs_steps),a
        jp      apply_stadium_kernel_from_iter

DoAirport:
L8e52:
        ld      a,(V_ZonePwrFlg)
        and     a
        ret     z
        ld      bc,(V_map_iter_xy)
        ld      hl,$0606
        call    scan_zone_with_size
        ld      a,(V_zone_transport_count)
        and     a
        ret     z
        ld      (V_traffic_active),a
        ld      hl,$0a0a
        ld      (V_zone_neighbour_filter),hl
        call    get_random_number
        and     31
        call    z,sim_update_traffic
        ld      a,(V_traffic_active)
        and     a
        ret     z
        ld      hl,(V_AirportPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8e87                 ; (3)
        ld      (V_AirportPop),hl
.L8e87  jp      sim_maybe_start_fire_or_flood


        IN_DATA
V_display_population:        defb    0,0,0        ; VAR $8E8A / 36490 - current cumulative population (copy for budget display)
V_prev_year_population:        defb    0,0,0        ; VAR $8E8D / 36493 - previous year's population (for budget comparison)
V_population:   defb    0,0,0        ; VAR $8E90 / 36496 - running population snapshot (updated each December)



; Simulation stops whilst waiting for budget confirmation, this variable is checked
.V_wait_for_budget_confirm defb    0   ; VAR $8E93 / 36499 - set waiting for budget to complete
        IN_SIM_CODE


; Budget processing - runs every tick to update V_display_population (current pop for display);
; on month==11 triggers the annual budget: copies fund requests to budget panel,
; then either processes auto-budget or busy-waits for UI confirmation.
.DoBudget                                   ; $8E94 / 36500
.L8e94
        ld      hl,(V_CityPop)
        ld      a,(V_CityPop+2)
        ld      c,a
        ld      (V_display_population),hl                    ;Update current-population display copy every tick
        ld      a,c
        ld      (V_display_population+2),a
        ld      a,(V_month)
        cp      11
        ret     nz                              ;Only do full budget in December
        ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      (V_prev_year_population),hl
        ld      a,c
        ld      (V_prev_year_population+2),a
        ld      hl,(V_CityPop)
        ld      a,(V_CityPop+2)
        ld      c,a
        ld      (V_population),hl
        ld      a,c
        ld      (V_population+2),a
        ld      hl,(V_transport_util)
        ld      (V_Transport_Funding_Requested),hl
        ld      hl,(V_PoliceFund)
        ld      (V_Budget_Police_Funding_Requested),hl
        ld      hl,(V_FireFund)
        ld      (V_Budget_Fire_Funding_Requested),hl
        ld      a,(V_auto_budget)
        and     a
        jr      nz,L8ee9                ; (13)
        IFDEF PORTABLE
        ; Portable builds have no second task: ask the UI to run the budget
        ; dialog (cooperative task in coop.asm, or a direct call).  It must
        ; leave the final funds in V_money_after_budget.
        call    sim_budget_wait
        jr      apply_budget_to_money
        ELSE
        ld      a,1
        ld      (V_wait_for_budget_confirm),a

        ; Busy loop waiting for other process to complete budget
.L8ee1  ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L8ee1                ; (-6)
        jr      apply_budget_to_money                   ; (6)
        ENDIF

.L8ee9  call    calculate_tax
        call    run_budget

apply_budget_to_money:                                    ; $8EEF / 36591 - Copy V_money_after_budget -> V_money; then run funding allocation (alloc_funding_levels)
.L8eef  ld      hl,(V_money_after_budget)
        ld      a,(V_money_after_budget+2)
        ld      c,a
        ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        call    alloc_funding_levels
        ret     


        IN_DATA
V_concern_crime:    defb    0       ; VAR $8F01 / 36609 - crime concern
V_concern_house_price:    defb    0       ; VAR $8F02 / 36610 - house price concern

V_transport_total:    defw    0       ; VAR $8F03 / 36611 - road/transport total (for city score display)
        IN_SIM_CODE


; Compute city concern scores from per-tick accumulators
; V_concern_crime = crime concern = (police coverage sum / count) * 2
; V_concern_house_price = house price concern = (land value sum / count) / 8
; V_transport_total = transport score (copy of V_transport_fund)
compute_concern_scores:
.L8f05  ld      hl,(V_police_cov_num)
        ld      de,(V_police_cov_den)
        call    L_div16x16
        ld      a,l
        add     a,a
        ld      (V_concern_crime),a             ;Crime concern: police coverage ratio * 2
        ld      hl,(V_landval_num)
        ld      de,(V_landval_den)
        call    L_div16x16
        ld      a,l
        srl     a
        srl     a
        srl     a
        ld      (V_concern_house_price),a             ;House price concern: land value ratio / 8
        ld      hl,(V_transport_fund)
        ld      (V_transport_total),hl            ;Transport score for display
        ret


        IN_DATA
V_hospital_demand:    defb    0       ; VAR $8F2F / 36655 - hopsital demand
V_church_demand:    defb    0       ; VAR $8F30 / 36656 - church demand
        IN_SIM_CODE

; Determine if we need a hospital or church
census_church_hosp:
.L8f31  xor     a
        ld      (V_hospital_demand),a
        ld      hl,(V_ResZPop)
        ld      a,18
        call    L_div_hl_a
        ld      de,(V_HospitalPop)
        and     a
        sbc     hl,de
        bit     7,h
        jr      nz,L8f4c                ; (4)
        ld      a,l
        ld      (V_hospital_demand),a       ;hospital demand

.L8f4c  xor     a
        ld      (V_church_demand),a
        ld      hl,(V_ResZPop)
        ld      a,20
        call    L_div_hl_a
        ld      de,(V_ChurchPop)
        and     a
        sbc     hl,de
        bit     7,h
        ret     nz
        ld      a,l
        ld      (V_church_demand),a       ;church demand
        ret     

; V_sim_speed_block: 5-byte speed-control block, copied from D_sim_speed_params each tick
;   +0 = number of ring-cell attempts per call in zone_ring_grow_ticks/zone_ring_shrink_ticks;
;        $FF means the simulation is paused
;   +1 = random mask (and X) for DoResidential, DoIndustrial, DoChurch and DoHospital
;   +2 = random mask for DoCommercial
;   +3 = not referenced by this code (the CPC version uses it in DoIndustrial)
;   +4 = month-advance mask (budget fires when sim_loop_counter & this == 0)
        IN_DATA
V_sim_speed_block:  defb    $08, $07, $07, $07, $01     ; VAR $8F67 / 36711 - 5-byte simulation speed control block (default = NORMAL speed)
        IN_SIM_CODE

; Speed settings table: 5 bytes per row, indexed by V_simulation_speed (0=FAST..3=PAUSED)
        IN_RODATA
D_sim_speed_params:                        ; $8F6C / 36716
                        ; $8F6C / 36716
        defb    $08, $01, $0f, $01, $00     ;FAST   (month every tick)
        defb    $04, $03, $1f, $03, $01     ;NORMAL (month every 2 ticks)
        defb    $03, $07, $3f, $07, $03     ;SLOW   (month every 4 ticks)
        defb    $ff, $ff, $ff, $ff, $ff     ;PAUSED (never advance month)
        IN_SIM_CODE


; Copy D_sim_speed_params row for current speed into V_sim_speed_block
.set_simulation_speed
.L8f80  ld      a,(V_simulation_speed)
        ld      b,a
        add     a,a         ;speed * 5
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,D_sim_speed_params
        add     hl,bc
        ld      de,V_sim_speed_block
        ld      bc,5
        ldir
        ret

; We have a few variables here 7 I think

        IN_DATA
V_money:       defb  0,0,0   ; VAR $8F97 / 36759 - money!! - 8f99
            defb    0       ;UNUSED
V_month:     defb  0       ; VAR $8F9B / 36763 - (8f9b) - Month
V_year:      defw  1902    ; VAR $8F9C / 36764 - (8f9c) - Year
V_8f9e:      defb  0       ; VAR $8F9E / 36766 - unreferenced, likely struct padding
        IN_SIM_CODE
