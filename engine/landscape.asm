; landscape: lines 2137-2545 of disassembly/sim_game.asm (engine)
        IN_DATA
V_InitialSeed:   defw    3       ; VAR $6A8C / 27276 - initial random seed
        IN_CODE

; ============================================================
; LANDSCAPE GENERATION
; ============================================================
;
; The map is 96x96 cells.  Generation runs in three passes:
;
; PASS 1 - LAND BLOBS
;   The map is zeroed (all TILE_WATER).  paint_landscape_strokes is
;   called to lay down 128 filled elliptical blobs of TILE_DIRT.
;   No constraint is set, so blobs paint over water freely.
;   Together the overlapping blobs form the main landmasses and
;   coastlines.
;
; PASS 2 - SHORELINE SMOOTHING  (smooth_shoreline_tiles)
;   Every TILE_WATER cell that borders land is replaced with one of
;   five water-edge tiles (1-5) chosen by looking up the 8-neighbour
;   dirt pattern in the two-part table D_shoreline_lookup.  First half of that
;   table (66 entries) holds bitmasks; second half holds the matching
;   replacement tile.  This gives visually smooth coastlines.
;
; PASS 3 - TREE COVERAGE
;   paint_landscape_strokes is called again for 32 blobs, this time
;   painting tile 6 (trees) but ONLY over existing TILE_DIRT cells
;   (V_stroke_constraint = TILE_DIRT acts as the constraint).  This scatters
;   woodland across the interior of landmasses.
;
; STROKE ALGORITHM  (draw_filled_ellipse_stroke)
;   Each blob is a filled ellipse drawn without multiplication or
;   trigonometry, using a discretised rotation update:
;
;     dx_new = dx - (dy >> w) - 1
;     dy_new = dy + (dx_new >> h) + 1
;
;   (dx, dy) are 16-bit signed fixed-point (8.8) accumulators,
;   initialised to (0, s) where s = random step size 2-7.
;   w and h are the per-axis divisor exponents chosen from D_blob_shape_table:
;     (4,4) square-ish,  (5,3) wide,  (3,5) tall.
;   The high bytes of (dx, dy) give the integer map offset from the
;   blob centre.  Because the update equations approximate a rotation,
;   (dx_high, dy_high) traces an ellipse over 49 steps.
;   At each step a horizontal span of width = -2*dx_high cells is
;   painted at row (y_center + dy_high), giving the filled interior.
; ============================================================

create_landscape:
.L6a8e  call    initialise_simulation_variables
        ld      hl,levelmap         ; zero the whole map → all TILE_WATER
        ld      de,levelmap+1
        ld      bc,9215
        ld      (hl),0
        ldir
        ld      ix,text_generating_landscape
        call    cls_map
        call    cls_print_topbox
        call    render_status_bar
        ld      hl,(V_InitialSeed)
        ld      (V_random_seed),hl  ; seed RNG from saved initial seed
        ; --- Pass 1: land blobs (128 strokes, TILE_DIRT, no constraint)
        xor     a
        ld      (V_stroke_constraint),a         ; constraint=0: paint anywhere
        ld      bc,32770            ; b=128 strokes, c=TILE_DIRT
        ld      e,7                 ; step-size mask (produces 2-7)
        call    paint_landscape_strokes
        ; --- Pass 2: shoreline smoothing
        ld      a,2
        ld      (V_stroke_tile),a         ; tile=TILE_DIRT (used by smooth_shoreline_tiles)
        call    smooth_shoreline_tiles
        ; --- Pass 3: tree coverage (32 strokes, tile 6=trees, only over dirt)
        ld      a,2
        ld      (V_stroke_constraint),a         ; constraint=TILE_DIRT: only overwrite land
        ld      bc,$2006            ; b=32 strokes, c=6 (trees)
        ld      e,3                 ; step-size mask (produces 2-3, smaller blobs)
        call    paint_landscape_strokes
        ret     

; Ellipse shape table: pairs of (w exponent, h exponent) for draw_filled_ellipse_stroke.
; Larger exponent = more compression in that axis.
; Randomly indexed by (rand & 3)*2, giving one of: (4,4) square, (5,3) wide, (3,5) tall.
        IN_RODATA
D_blob_shape_table:                     ; $6AD3 / 27347 - ellipse (w-exp, h-exp) pairs for terrain paint blobs; indexed by (rand & 3)*2
        defb    $04, $04    ; square-ish
        defb    $05, $03    ; wide
        defb    $03, $05    ; tall
        defb    $04, $04    ; square-ish
        IN_CODE



; Paint b filled ellipse blobs of tile c onto the map.
; Entry: b = number of strokes, c = tile to paint, e = step-size mask (ANDed with random, min 2)
.paint_landscape_strokes
.L6adb  ld      a,c
        ld      (V_stroke_tile),a         ; set tile type for draw_filled_ellipse_stroke
        ld      a,e
        IFDEF PORTABLE
        ld      (V_stroke_step_mask),a     ; AND mask used for step size
        ELSE
        ld      (SMC_27367+1),a     ; patch the AND mask used for step size
        ENDIF

.L6ae3  push    bc                  ; save stroke counter and tile
        ; randomise step size (2-7)
        call    get_random_number
SMC_27367:
        IFDEF PORTABLE
        push    hl
        ld      hl,V_stroke_step_mask
        and     (hl)                ; mask = e parameter (7 or 3)
        pop     hl
        ELSE
        and     7                   ; SMC: mask = e parameter (7 or 3)
        ENDIF
        cp      2
        jr      nc,L6aef
        ld      a,2                 ; clamp minimum step size to 2
.L6aef  ld      (V_stroke_step),a
        ; randomise centre x (16-79)
        call    get_random_number
        and     63
        add     a,16
        ld      (V_stroke_center),a         ; x centre
        ; randomise centre y (16-79)
        call    get_random_number
        and     63
        add     a,16
        ld      (V_stroke_center+1),a       ; y centre
        ; pick random shape from D_blob_shape_table: (4,4), (5,3) or (3,5)
        call    get_random_number
        and     3
        add     a,a                 ; index = (rand & 3) * 2
        ld      c,a
        ld      b,0
        ld      hl,D_blob_shape_table
        add     hl,bc
        ld      de,V_stroke_dims
        ldi                         ; copy w exponent to V_stroke_dims
        ldi                         ; copy h exponent to V_stroke_dims+1
        call    draw_filled_ellipse_stroke
        pop     bc
        djnz    L6ae3               ; repeat for all b strokes
        ret     


; Two-part shoreline lookup table used by smooth_shoreline_tiles.
; First 66 bytes: 8-neighbour dirt bitmasks (bits 0-7 = NW,N,NE,W,E,SW,S,SE are dirt).
; Second 66 bytes: replacement water-edge tile for the matching pattern.
; Tiles 1,3,4,5 are the diagonal/curved water-edge graphics; 2=TILE_DIRT.
        IN_RODATA
D_shoreline_lookup:                        ; $6B21 / 27425
                        ; $6B21 / 27425
        defb    $FE, $EB, $F5, $CB, $76, $6E, $DB
        defb    $7E, $E9, $7C, $3E, $D1, $8B, $F4, $8F 
        defb    $CF, $D3, $BE, $7D, $EF, $6C, $36, $EC
        defb    $B7, $FC, $37, $2F, $1F, $BF, $FB, $7F
        defb    $EE, $77, $9B, $F9, $F7, $D6, $D7, $9F
        defb    $F6, $EB, $FD, $6F, $BB, $DD, $E8, $E9
        defb    $0F, $0B, $2B, $17, $16, $96, $97, $3F
        defb    $69, $68, $6B, $6D, $F8, $F0, $D4, $D0
        defb    $F4, $DF, $FF
        
        defb    $02, $01, $04, $05, $03
        defb    $05, $02, $02, $05, $05, $02, $04, $01
        defb    $04, $01, $05, $03, $01, $04, $01, $05
        defb    $03, $05, $03, $02, $03, $01, $03, $01
        defb    $02, $02, $01, $04, $03, $05, $03, $04
        defb    $03, $01, $03, $01, $05, $05, $01, $05
        defb    $05, $05, $01, $01, $01, $03, $03, $03
        defb    $03, $03, $05, $05, $05, $05, $05, $04
        defb    $04, $04, $04, $02, $02
        IN_CODE


; Scan the entire 96x96 map and replace water cells that border land with
; appropriate shoreline tile graphics, using the D_shoreline_lookup lookup table.
; For each TILE_WATER cell: get the 8-neighbour dirt bitmask, search D_shoreline_lookup
; first half for a matching pattern, then write the corresponding edge tile.
smooth_shoreline_tiles:
.L6ba5  ld      b,96
.L6ba7  ld      c,96
.L6ba9  push    bc
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ld      a,(hl)
        and     a
        jr      nz,L6bd3                ; skip non-water cells
        call    get_dirt_neighbour_mask ; d = 8-neighbour dirt bitmask
        ld      a,d
        and     a
        jr      z,L6bd3                 ; no dirt neighbours: leave as water
        push    bc
        ld      hl,D_shoreline_lookup
        ld      bc,66
        cpir                            ; search first half of D_shoreline_lookup for bitmask d
        pop     bc
        jr      nz,L6bd3                ; pattern not in table: leave as water
        ld      de,65
        add     hl,de                   ; step into second half: replacement tile
        ld      e,(hl)
        call    levelmap_xypos_with_check
        ld      a,(hl)
        and     a
        jr      nz,L6bd3                ; only overwrite if cell still empty
        ld      (hl),e                  ; place shoreline tile
.L6bd3  pop     bc
        dec     c
        jr      nz,L6ba9
        djnz    L6ba7
        ret     

        IN_DATA
V_levelmap_bounds_flag:   defb        0   ; VAR $6BDA / 27610 - ?? unused?
        IN_CODE

;Range check
.levelmap_xypos_with_check
.L6bdb  ld      hl,96
        ld      a,b
        cp      l
        jr      nc,L6bfd                ; (27)
        ld      a,c
        cp      l
        jr      nc,L6bfd                ; (23)

; Calculate the position with the level map
;
; Entry: b = y, c =x
; Exit:  hl = address, carry set
levelmap_xypos:                             ; $6BE6 / 27622
.L6be6  
        ld      l,b
        ld      h,0
        ld      a,c
        ld      b,h
        ld      c,l
        add     hl,hl   ;*2
        add     hl,bc   ;*3
        add     hl,hl   ;*6
        add     hl,hl   ;*12
        add     hl,hl   ;*24
        add     hl,hl   ;*48
        add     hl,hl   ;*96
        ld      b,0
        ld      c,a     ;+x
        add     hl,bc
        ld      bc,levelmap
        add     hl,bc
        scf     
        ret     

.L6bfd  xor     a
        ld      (V_levelmap_bounds_flag),a
        ret


        IN_DATA
V_stroke_center:        defw    0           ; VAR $6C02 / 27650 - landscape stroke center (x,y), random 16-79
V_stroke_step:        defb    $05         ; VAR $6C04 / 27652 - landscape stroke step size (random 2-7, controls drawing density)
V_stroke_tile:        defb    $02         ; VAR $6C05 / 27653 - landscape stroke tile type to paint (TILE_DIRT=2 for land pass, TILE_WATER=0 for water pass)
V_stroke_constraint:        defb    $00         ; VAR $6C06 / 27654 - landscape stroke constraint tile (0=paint anywhere; else only overwrite cells containing this tile)
V_stroke_dims:        defw    $0404       ; VAR $6C07 / 27655 - landscape stroke half-dimensions (w,h) loaded via ldi from D_blob_shape_table
        IN_CODE



; Draw one filled ellipse blob centred at V_stroke_center, painting V_stroke_tile.
; Uses a trigonometry-free incremental rotation to trace the ellipse perimeter,
; then fills each row with a horizontal span.
;
; Algorithm:
;   Two 16-bit signed fixed-point (8.8) accumulators (dx, dy) are maintained.
;   Each of 49 steps applies a discretised rotation:
;     dx_new = dx - (dy >> w) - 1
;     dy_new = dy + (dx_new >> h) + 1
;   where w = V_stroke_dims low byte, h = V_stroke_dims high byte (shape exponents from D_blob_shape_table).
;   Initial state: dx=0, dy=s (step size from V_stroke_step, range 2-7).
;   The high bytes of (dx, dy) give the integer cell offset from the centre.
;   At each step, a horizontal span of (-2 * dx_high) cells is painted at
;   row (y_center + dy_high), producing the filled ellipse interior.
;
; V_stroke_constraint = 0: paint unconditionally.
; V_stroke_constraint != 0: only paint cells that currently contain that tile (e.g. TILE_DIRT).
.draw_filled_ellipse_stroke
.L6c09  ld      a,(V_stroke_step)     ; step size s (2-7): controls initial dy magnitude
        ld      h,a
        ld      l,0
        IFDEF PORTABLE
        ld      (V_ellipse_dy),hl ; initialise dy = s (high byte), dx low byte = 0
        ld      h,l
        ld      (V_ellipse_dx),hl ; initialise dx = 0
        ELSE
        ld      (SMC_27676+1),hl ; initialise dy = s (high byte), dx low byte = 0
        ld      h,l
        ld      (SMC_27673+1),hl ; initialise dx = 0
        ENDIF
        ld      b,49             ; 49 steps traces one full ellipse path

.L6c18  push    bc              ; save outer loop counter
SMC_27673:
        IFDEF PORTABLE
        ld      hl,(V_ellipse_dx) ; current dx (updated each iteration)
        ELSE
        ld      hl,0            ; SMC: current dx (updated each iteration)
        ENDIF
SMC_27676:
        IFDEF PORTABLE
        ld      de,(V_ellipse_dy) ; current dy (updated each iteration)
        ELSE
        ld      de,0            ; SMC: current dy (updated each iteration)
        ENDIF
        ; --- compute dx_new = dx - (dy >> w) - 1 ---
        ld      b,d
        ld      c,e             ; bc = dy
        ld      a,(V_stroke_dims)     ; w = x-axis shape exponent

.L6c24  sra     b
        rr      c
        dec     a
        jr      nz,L6c24        ; bc = dy >> w (arithmetic, preserves sign)
        inc     bc              ; bc = (dy >> w) + 1
        and     a
        sbc     hl,bc           ; hl (dx) = dx - (dy >> w) - 1

        ; --- compute dy_new = dy + (dx_new >> h) + 1 ---
        ex      de,hl           ; hl = old dy, de = new dx
        ld      b,d
        ld      c,e             ; bc = new dx
        ld      a,(V_stroke_dims+1)   ; h = y-axis shape exponent

.L6c35  sra     b
        rr      c
        dec     a
        jr      nz,L6c35        ; bc = dx_new >> h
        inc     bc              ; bc = (dx_new >> h) + 1
        add     hl,bc           ; hl (dy) = dy + (dx_new >> h) + 1

        ex      de,hl           ; de = new dy, hl = new dx
        IFDEF PORTABLE
        ld      (V_ellipse_dx),hl ; save updated dx for next iteration
        ld      (V_ellipse_dy),de ; save updated dy for next iteration
        ELSE
        ld      (SMC_27673+1),hl ; save updated dx for next iteration
        ld      (SMC_27676+1),de ; save updated dy for next iteration
        ENDIF

        ; --- compute map position and span width for this step ---
        ld      bc,(V_stroke_center)    ; bc = (y_center, x_center)
        ld      a,d             ; dy high byte = row offset
        add     a,b
        ld      b,a             ; b = y_center + dy_high
        ld      a,h             ; dx high byte = col offset (negative at equator)
        add     a,c
        ld      c,a             ; c = x_center + dx_high (left edge of span)
        IFDEF PORTABLE
        ld      a,(V_ellipse_dx+1) ; dx_high (high byte of stored dx)
        ELSE
        ld      a,(SMC_27673+2) ; dx_high (high byte of stored dx)
        ENDIF
        neg
        add     a,a
        ld      d,a             ; d = -2 * dx_high = span width (positive when dx_high < 0)

        ; --- paint horizontal span of d cells ---
.L6c57  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ld      a,(V_stroke_constraint)     ; constraint tile
        and     a
        jr      z,L6c69         ; constraint=0: always paint
        push    bc
        ld      b,a
        ld      a,(hl)
        cp      b               ; check if cell matches constraint tile
        pop     bc
        jr      nz,L6c6d        ; mismatch: skip this cell

.L6c69  ld      a,(V_stroke_tile)
        ld      (hl),a          ; paint tile

.L6c6d  inc     c               ; move one cell right
        dec     d
        jr      nz,L6c57        ; repeat for full span width
        pop     bc
        djnz    L6c18           ; next ellipse step
        ret     


; Checks if a coordinate is dirt
; Entry: bc = coordinates
; Exit:   c = dirt
;        nc = not dirt

map_check_dirt:
.L6c75  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ret     nc
        ld      a,(hl)
        cp      2           ;dirt
        jr      z,L6c82                 ; (2)
        or      a
        ret     

.L6c82  scf     
        ret     

; Build 8-neighbour dirt bitmask for the cell at bc.
; Checks all 8 surrounding cells and sets a bit for each one that is TILE_DIRT.
; Entry: bc = coordinates
; Exit:  d = bitmask (bit 0=NW, 1=N, 2=NE, 3=W, 4=E, 5=SW, 6=S, 7=SE)
;
;  012
;  3 4
;  567
.get_dirt_neighbour_mask
.L6c84  push    bc
        ld      d,0
        dec     b
        dec     c
        call    map_check_dirt
        rl      d
        inc     c
        call    map_check_dirt
        rl      d
        inc     c
        call    map_check_dirt
        rl      d
        dec     c
        dec     c
        inc     b
        call    map_check_dirt
        rl      d
        inc     c
        inc     c
        call    map_check_dirt
        rl      d
        dec     c
        dec     c
        inc     b
        call    map_check_dirt
        rl      d
        inc     c
        call    map_check_dirt
        rl      d
        inc     c
        call    map_check_dirt
        rl      d
        pop     bc
        ret     
