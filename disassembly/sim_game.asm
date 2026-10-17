;
; Disassembly by dz80 
;
; This is Sim City
;
; Disassembled and commented by djm 12/3/2000 - 

        defc        zx_rom_tape_load = $0562

        defc        keystore = 23296
        ; Keystore + 8 = bits 0x80 -> 0x01 (used for minimap)

        defc        udgs         = 59472

        org        23323


        defc        TILE_DIRT = 2
        defc        TILE_WATER = 0
        defc        TILE_H_ROAD = 7
        defc        TILE_V_ROAD = 8
        defc        TILE_H_RAIL = 20
        defc        TILE_H_POWER = 33
        defc        TILE_PARK = 56
        defc        TILE_PARK2 = 57
        defc        TILE_NEED_POWER = 59
        defc        TILE_RADIOACTIVE = 89
        defc        TILE_FLOOD = 68
        defc        TILE_FIRE = 69

;Entry! - 

.LB19
.start
        di      
        ld      sp,$f6c2
        xor     a
        out     (254),a
        ld      a,1
        ld      (V_simulation_disabled),a
        xor     a
        ld      (V_kempston),a
        ld      hl,32768    
        ; Test for kempston
.L5b2e  in      a,(31)
        cp      31
        jr      nc,L5b3e                ; (10)
        dec     hl
        ld      a,h
        or      l
        jr      nz,L5b2e                ; (-11)
        ld      a,1
        ld      (V_kempston),a                ; we have kempston
.L5b3e  ld      a,253                        ; Set up im2
        ld      i,a
        im      2
        ei      
        jp      gameentry

; Funky sound effect

.soundfx1  
        di      
        ld      a,(V_sound_enabled)
        and     a
        ret     z
        ld      bc,200
        ld      d,0
.L5b53  inc     d
        ld      a,d
        and     e
        jr      nz,L5b5f                ; (7)
        call    get_random_number
        and     16
        out     (254),a
.L5b5f  dec     bc
        ld      a,b
        or      c
        jr      nz,L5b53                ; (-17)
        ei      
        ret     

; Funky soundfx #2

.soundfx2  
        ld      hl,4144
        ld      de,500
.L5b6c  ld      a,16
        out     (254),a
        ld      b,l
.L5b71  djnz    L5b71                  ; (-2)
        xor     a
        out     (254),a
        ld      b,h
.L5b77  djnz    L5b77                  ; (-2)
        dec     de
        ld      a,d
        or      e
        jr      nz,L5b6c                ; (-18)
        ret     

; Kempston stuff

V_kempston:   defb    1       ; VAR $5B7F / 23423 - kempston enabled or not

read_kempston:                              ; $5B80 / 23424
.L5b80
        ld      a,(V_kempston)
        and     a
        jr      z,L5b88                 ; (2)
        in      a,(31)
L5b88:  cpl     
        ret     

; Key conversion table

.keytab
        defb        3
        defm        "ZXCVASDFGQWERT1234509876"
        defm        "POIUY"
        defb        8
        defm        "LKJH .MNB"

.V_key_pressed        defb        0        ; VAR $5BB2 / 23474 - holds key pressed value

; Munch up the previously read keys and make something
; meaningful out of them
; It seems that V_key_pressed will hold the key status...

.munchkeys  
        ld      hl,keystore
        ld      bc,2304
        ld      d,254
L5bbb:  ld      a,(hl)
        cpl     
        and     31
        and     d
        jr      nz,munchkeys_found_key                ; (16)
        ld      d,255
        ld      a,c
        add     a,5
        ld      c,a
        inc     hl
        djnz    L5bbb                   ; (-16)
        ld      a,255
        ld      (V_key_pressed),a
        scf     
        ret     
munchkeys_found_key:                                    ; $5BD2 / 23506 - Rotate key bits and store matched key code in V_key_pressed; part of munchkeys scan loop
.L5bd2  rrca    
        jr      nc,L5bdb                ; (6)
        ld      a,c
        ld      (V_key_pressed),a
.L5bd9  or      a
        ret     
.L5bdb  inc     c
        jr      munchkeys_found_key                   ; (-12)
        defb    0               ; padding

; Return the key just pressed
; Returns an ASCII code - I'm sure this code is just generic z80 with 
; Machine specific bits tagged on here and there!
; Entry: none
; Exit:  a = ASCII key just pressed
;         c set if no key/nc if key

.getkeyval  
        call    munchkeys
        ret     c
        ld      a,(V_key_pressed)
        ld      e,a
        ld      d,0
        ld      hl,keytab
        add     hl,de
        ld      a,(hl)
        ret     

; Flip the keytable into true on/off state

.twiddlekeys  
        ld      b,9
        ld      hl,keystore
.L5bf4  ld      a,(hl)
        cpl     
        and     31
        ret     nz
        inc     l
        djnz    L5bf4                   ; (-8)
        xor     a
        ret     

; Convert character xy posn in bc to df addr in hl

.xypos  ld      a,b
        and     24
        or      64
        ld      h,a
        ld      a,b
        and     7
        rrca    
        rrca    
        rrca    
        or      c
        ld      l,a
        ret     

; Convert df addr to attr addr
; Entry: hl = xyposition
; Exit:  hl = attr attr

.cxytoattr  
        ld      l,b
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      b,88
        add     hl,bc
        ret     

; Get next line in display file
; Entry: hl = current df address
; Exit:  hl = address of next line in df

.drow        inc     h
        ld      a,h
        and     7
        ret     nz
        ld      a,l
        add     a,32
        ld      l,a
        ret     c
        ld      a,h
        sub     8
        ld      h,a
        ret     

; Prints a udg - does it for menu I think

.prmenu_udg  
        push    af
        call    xypos
        ld      (textpos),hl
        pop     af
        ld      l,a
        ld      h,0
        ld      (V_current_tile),hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,udgs
        add     hl,bc
        ex      de,hl
        ld      hl,(textpos)
        ld      b,8
.L5c43  ld      a,(de)
        ld      (hl),a
        inc     de
        inc     h
        djnz    L5c43                   ; (-6)
        ex      de,hl
        ld      bc,(V_current_tile)
        ld      hl,udgs + 3240
        add     hl,bc
        ld      a,(hl)
        ex      de,hl
        jp      dotextcol_1

; Print UDG in a
; Do colour for it as well

.prudg  ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,udgs
        add     hl,bc
        ex      de,hl
        ld      hl,(textpos)
        ld      b,8
.L5c67  ld      a,(de)
        ld      (hl),a
        inc     de
        inc     h
        djnz    L5c67                   ; (-6)
        jp      dotextcol

.cls_white  
        ld      a,56
        jr      cls                   ; (2)

.cls_black  
        ld      a,7

; Clear screen
; Set attribute colour to a

.cls        
        ld      hl,16384
        ld      de,16385
        ld      bc,2047
        ld      (hl),0
        ldir    
        ld      hl,22528
        ld      de,22529
        ld      bc,255
        ld      (hl),a
        ldir    
; Clear the area of screen used for the map
.cls_map  
        ld      hl,18432
        ld      de,18433
        ld      bc,4095
        ld      (hl),0
        ldir    
        ld      hl,22784
        ld      de,22785
        ld      bc,511
        ld      (hl),71
        ldir    
        ret     

; Sets up the attributes for the minimap screen
.setminimap_col  
        call    cls_white
        ld      hl,22528
        ld      d,24
.L5cb2  ld      b,8
.L5cb4  ld      (hl),7
        inc     hl
        djnz    L5cb4                   ; (-5)
        ld      b,24
.L5cbb  ld      (hl),33
        inc     hl
        djnz    L5cbb                   ; (-5)
        dec     d
        jr      nz,L5cb2                ; (-17)
        ret     

V_random_seed: defw        $fc03        ; VAR $5CC4 / 23748 - random seed

; Random number generator?
get_random_number:                          ; $5CC6 / 23750
.L5cc6
        push    hl
        push    de
        push    bc
        ld      de,(V_random_seed)
        ld      h,e
        ld      l,253
.L5cd0  ld      a,d
        or      a
.L5cd2  ld      b,0
.L5cd4  sbc     hl,de
        sbc     a,b
        sbc     hl,de
        sbc     a,b
        ld      e,a
        ld      d,b
        sbc     hl,de
        jr      nc,L5ce1                ; (1)
        inc     hl
.L5ce1  ld      (V_random_seed),hl
        ld      a,h
        ld      a,(V_random_seed)
        pop     bc
        pop     de
        pop     hl
        ret     

; Pointer sprites and mask

.D_pointer_sprite       defb        0,120,112,120,92,8,0,0        ; $5CEC / 23788 - 8-byte UDG pixel data for cursor arrow
.D_pointer_mask         defb        7,3,7,3,1,35,247,255          ; $5CF4 / 23796 - 8-byte UDG mask for cursor arrow

.V_pointerxy        defw        $0135        ; VAR $5CFC / 23804 - pointer xypos

; Print the pointer

.prpointer
        ld        bc,(V_pointerxy)
        srl        b
        srl        b
        srl        b
        srl        c
        call    xypos
        ld      (V_pointer_xy_prev),hl
        ld      ix,V_pointer_underlay
        ld      iy,D_pointer_mask
        ld      de,D_pointer_sprite
        ld      b,8
.L5d1d  ld      a,(hl)
        ld      (ix+0),a
        ld      a,(hl)
        and     (iy+0)
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de
        inc     ix
        inc     iy
        call    drow
        djnz    L5d1d                   ; (-22)
        ret     

.V_pointer_underlay        defs        8        ; VAR $5D34 / 23860 - used to hold what was under pointer
.V_pointer_xy_prev        defw        0        ; VAR $5D3C / 23868 - old pointer posn

.blankpointer  
        ld      hl,(V_pointer_xy_prev)
        ld      de,V_pointer_underlay
        ld      b,8
.L5d46  ld      a,(de)
        ld      (hl),a
        inc     de
        call    drow
        djnz    L5d46                   ; (-8)
        ret     

.V_zone_cursor_size        defw        $0101        ; VAR $5D4F / 23887 - zone size related
.V_map_cursor_cell        defw        0        ; VAR $5D51 / 23889 - map character-cell coordinates of cursor (b=row, c=col, derived from pixel pointer)
.V_cursor_validity        defw        0        ; VAR $5D53 / 23891 - byte 0 = raw cursor Y pixel; byte 1 = cursor in-map validity flag (1=valid, 0=outside map)

validate_cursor_position:               ; $5D55 / 23381 - Check pointer is in map, convert pixel coords to map char-cell; sets V_cursor_validity (0=out, 1=valid)
.L5d55  xor     a
        ld      (V_cursor_validity),a
        ld      (V_cursor_validity+1),a
        ld      bc,(V_pointerxy)
        ld      a,b
        cp      64
        ret     c
        ld      (V_cursor_validity),a
        ld      a,b
        sub     64
        srl     a
        srl     a
        srl     a
        ld      b,a
        ld      a,c
        srl     a
        ld      c,a
        ld      (V_map_cursor_cell),bc
        ld      a,b
        add     a,8
        ld      b,a
        ld      hl,(V_zone_cursor_size)
        ld      a,b
        add     a,h
        cp      25
        ret     nc
        ld      a,c
        add     a,l
        cp      33
        ret     nc
        ld      a,1
        ld      (V_cursor_validity+1),a
draw_cursor_xor:                                    ; $5D8F / 23951 - XOR-invert pixels under cursor (zone-size rows at xypos); cursor-already-valid path
.L5d8f  call    xypos
        ld      bc,(V_zone_cursor_size)
        sla     b
        sla     b
        sla     b
        ld      a,c
        ld      (SMC_23970+1),a
.L5da0  push    bc
        push    hl
SMC_23970:
        ld      b,2
.L5da4  ld      a,(hl)
        xor     255
        ld      (hl),a
        inc     l
        djnz    L5da4                   ; (-7)
        pop     hl
        pop     bc
        call    drow
        djnz    L5da0                   ; (-18)
        ret     

; Prints the menu icons
; Calls the prmenu_udg to handle the gubbins

.pricon  
        push    bc
        push    af
        call    prmenu_udg
        pop     af
        pop     bc
        inc     a
        inc     c
        push    bc
        push    af
        call    prmenu_udg
        pop     af
        pop     bc
        dec     c
        inc     b
        inc     a
        push    bc
        push    af
        call    prmenu_udg
        pop     af
        pop     bc
        inc     a
        inc     c
        jp      prmenu_udg

; Does the menu udgs

.doicons  
        ld      bc,$0102
        ld      d,14
        ld      e,0
.L5dd9  push    bc
        push    de
        ld      a,e
        call    pricon
        pop     de
        pop     bc
        ld      a,e
        add     a,4
        ld      e,a
        inc     c
        inc     c
        dec     d
        jr      nz,L5dd9                ; (-17)
        ret     


; Part of the printroutine
; We enter with the text stored at the return address

        defc        T_SETCOL        = 251
        defc        T_NUM           = 252        ;print number following (8 bit)
        defc        T_BOX           = 253        ;draw line/box?
        defc        T_END           = 254
        defc        T_SETXY         = 255

replace_with_direct_prchar_call:
        call    prchar
        ret

        
.prt_ctrl  
        pop     hl
.L5df0  ld      a,(hl)
        cp      T_END
        jp      z,endctrl
        cp      T_SETCOL                        ;251
        jr      z,set_txtcol                 ; set textcol
        cp      T_SETXY
        jr      z,ctrl_setxy                 ; (124)
        cp      T_BOX
        jp      z,ctrl_line
        cp      252
        jr      z,ctrl_prnum                 ; (30)
        push    hl
        call    replace_with_direct_prchar_call       ; TODO: Optimise this away
        call    incprpos                        ;inc print posn
        pop     hl

.nxtctrl  inc     hl
        jr      L5df0                   ; (-34)

.incprpos  
        ld      hl,(textpos)
        inc     hl
        ld      (textpos),hl
        ld      hl,textxy
        inc     (hl)
        ret     


.set_txtcol
        inc     hl
        ld      a,(hl)
        ld      (textcol),a
        jr      nxtctrl                   ; (-22)

.ctrl_prnum  
        inc     hl
        ld      a,(hl)
        push    hl
        ld      l,a
        ld      h,0
        call    prhund
        pop     hl
        jr      nxtctrl                   ; (-34)
        ld      (textxy),bc

set_textpos_from_textxy:                                    ; $5E35 / 24117 - Move textpos to screen address for current textxy; preamble before number printing
.L5e35  push    hl
        ld      bc,(textxy)
        call    xypos
        ld      (textpos),hl
        pop     hl

; Print a number

.prtthou  
        ld      de,-10000
        call    prdigit
.prthou  
        ld      de,-1000
        call    prdigit
.prhund 
        ld      de,-100
        call    prdigit
        ld      de,-10
        call    prdigit
        ld      a,l
        call    print_digit_char        ;
        ret     

.prdigit 
        xor     a
.L5e5f  inc     a
        add     hl,de
        jr      c,L5e5f                 ; (-4)
        sbc     hl,de
        dec     a
print_digit_char:                                    ; $5E66 / 24166 - Convert digit in A to ASCII, store in V_digit_char_buf and print at current textpos
.L5e66  add     a,48
        ld      (V_digit_char_buf),a
        push    hl
        call    replace_with_direct_prchar_call
        ld      hl,(textpos)
        inc     hl
        ld      (textpos),hl
        pop     hl
        ret     


endctrl:                                    ; $5E78 / 24184
.L5e78
        inc     hl
        jp      (hl)

.ctrl_setxy  
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        jr      nxtctrl                   ; (-121)

; Draw a udg line..

.ctrl_line  
        inc     hl
        push    hl
        call    L5e97
        pop     hl
        ld      de,3
        add     hl,de
        jp      nxtctrl

.V_text_col_width        defw        $1020                ; VAR $5E95 / 24213 - holds textxy


.L5e97  ld      b,(hl)
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (textxy),bc
        ld      (V_text_col_width),de
        ld      a,(textxy)
        ld      (SMC_24334+1),a
        ld      a,56
        ld      b,57
        ld      c,58
        call    print_zone_tile_row
        ld      a,(V_text_col_width+1)
        sub     2
        ld      b,a

.L5ebb  push    bc
        ld      a,63
        ld      b,32
        ld      c,59
        call    print_zone_tile_row
        pop     bc
        djnz    L5ebb                   ; (-13)
        ld      a,62
        ld      b,61
        ld      c,60
        call    print_zone_tile_row
        ret     

.L24274
        defb        $01

; Print one horizontal row of zone UDGs
; Entry: a = left-edge UDG, b = middle UDG, c = right-edge UDG
.print_zone_tile_row                        ; $5ED3 / 24275
.L5ed3
        ld      (SMC_24296+1),a
        ld      a,b
        ld      (SMC_24312+1),a
        ld      a,c
        ld      (SMC_24326+1),a
        ld      bc,(textxy)
        call    xypos
        ld      (textpos),hl
SMC_24296:
        ld      a,64
        call    prudg
        ld      a,(V_text_col_width)
        sub     2
        ld      b,a

.L5ef3  push    bc
        ld      hl,textpos
        inc     (hl)
SMC_24312:
        ld      a,65
        cp      32
        call    nz,prudg
        pop     bc
        djnz    L5ef3                   ; (-15)
        ld      hl,textpos
        inc     (hl)
SMC_24326:
        ld      a,66
        call    prudg
        ld      hl,textxy
.SMC_24334                                ;FIXME
        ld      (hl),0
        inc     hl
        inc     (hl)
        ret     

; Print the main game text and box

.ingame_scrdraw  
        call    prt_ctrl
        defb        T_SETCOL,7
        defb        T_SETXY,0,0
        defm        "SYSTEM OPTIONS DISASTERS WINDOWS"
        defb        T_SETXY,2,0
        defb        '+'
        defb        T_END
        call        prt_ctrl
        defb        T_SETCOL,56
        defb        T_BOX,3,0,32,5
        defb        T_SETCOL,57
        defb        T_END
        call        ingame_txt
        call    doicons
        call    update_cursor_and_greyout
        call    L6305
        call    print_date
        call    print_money
        ret     

.ingame_txt  
        call    prt_ctrl
        defb        T_SETCOL,57
        defb        T_SETXY,5,1
SMC_cityname:
.D_24424                                                                                                    ; $5F68 / 24424 - VAR        (12) - townname
        defm        "HERESVILLE  "
        defb        T_SETXY,5,17
        defm        "FUNDS $"
        defb        T_END
        ret

; 5f80
.print_money  
        ld      bc,$0518
        ld      hl,V_money
        call    prt24bit
        ret     

; 5f8a
text_months:
        defm    "JA"
        defb    'N'+128
        defm    "FE"
        defb    'B'+128
        defm    "MA"
        defb    'R'+128
        defm    "AP"
        defb    'R'+128
        defm    "MA"
        defb    'Y'+128
        defm    "JU"
        defb    'N'+128
        defm    "JU"
        defb    'L'+128
        defm    "AU"
        defb    'G'+128
        defm    "SE"
        defb    'P'+128
        defm    "OC"
        defb    'T'+128
        defm    "NO"
        defb    'V'+128
        defm    "DE"
        defb    'C'+128

; Print the date on screen
; Routine $5fae
print_date:                                 ; $5FAE / 24494
.L5fae
        ld      a,(V_month)
        ld      hl,text_months
        call    get_word_from_table
        ld      bc,$0417
        ld      a,3
        call    print_string
        ld      hl,(V_year)
        call    prthou
        ret     

;5fc6 24518
; Text table
text_table:
        defm    "BULLDOZE $"
        defb    '1' + 128
        defm    "ROAD $1"
        defb    '0' + 128
        defm    "POWER LINES $"
        defb    '5' + 128
        defm    "RAILROAD $2"
        defb    '0' + 128
        defm    "PARK $1"
        defb    '0' + 128
        defm    "RESIDENTIAL $10"
        defb    '0' + 128
        defm    "COMMERCIAL $10"
        defb    '0' + 128
        defm    "INDUSTRIAL $10"
        defb    '0' + 128
        defm    "POLICE STATION $50"
        defb    '0' + 128
        defm    "FIRE STATION $50"
        defb    '0' + 128
        defm    "STADIUM $300"
        defb    '0' + 128
        defm    "POWER STATION $500"
        defb    '0' + 128
        defm    "SEAPORT $500"
        defb    '0' + 128
        defm    "AIRPORT $1000"
        defb    '0' + 128


L6088:
; Code 14 = levels
        defm    "EAS"
        defb    'Y' + 128
        defm    "MEDIU"
        defb    'M' + 128
        defm    "HAR"
        defb    'D' + 128

; Code 17 = city size

        defm    "VILLAG"
        defb    'E' + 128
        defm    "TOW"
        defb    'N' + 128
        defm    "CIT"
        defb    'Y' + 128
        defm    "CAPITA"
        defb    'L' + 128
        defm    "METROPOLI"
        defb    'S' + 128
        defm    "MEGALOPOLI"
        defb    'S' + 128

; Code 23 - 60c1
        defb    ' ' + 128

; Code 24
.alert_msg_demand_zones                     ; $60C2 / 24770
.L60c2
        defm    "MORE RESIDENTIAL ZONES NEEDE"      ;24
        defb    'D' + 128
        defm    "MORE COMMERCIAL ZONES NEEDE"
        defb    'D' + 128
        defm    "MORE INDUSTRIAL ZONES NEEDE"       ;26
        defb    'D' + 128
.alert_msg_demand_infra                     ; $6117 / 24855
.L6117
        defm    "NEED BIGGER ROAD NETWOR"           ;28
        defb    'K' + 128
        defm    "NEED LARGER RAIL SYSTE"            ;30
        defb    'M' + 128
        defm    "NEED A POWER PLAN"                 ;32
        defb    'T' + 128
.alert_msg_demand_special                   ; $6158 / 24920
.L6158
        defm    "THE PEOPLE WANT A STADIU"          ;34
        defb    'M'+128
        defm    "INDUSTRY NEEDS A SEA POR"           ;36
        defb    'T' + 128
        defm    "COMMERCE NEEDS AN AIRPOR"
        defb    'T' + 128
        defm    "PEOPLE DEMAND FIRE DEP"
        defb    'T' + 128
.alert_msg_demand_services                  ; $61BA / 25018
.L61ba
        defm    "PEOPLE DEMAND POLICE DEP"
        defb    'T' + 128
        defm    "CITIZENS UPSET,TAXES TOO HIG"
        defb    'H' + 128
        defm    "TRANSPORT SYSTEM FALLING APAR"
        defb    'T' + 128
        defm    "FIRE DEPT NEEDS FUND"
        defb    'S' + 128
        defm    "THE POLICE NEED FUND"
        defb    'S' + 128
        defm    "ZONES NEED POWE"
        defb    'R' + 128
.alert_msg_disasters                        ; $6248 / 25160
.L6248
        defm    "BROWNOUTS DETECTE"
        defb    'D' + 128
        defm    "NUCLEAR MELTDOW"
        defb    'N' + 128
        defm    "TOO MUCH POLLUTIO"
        defb    'N' + 128
        defm    "CRIME TOO HIG"
        defb    'H' + 128
        defm    "TRAFFIC JAMS ARE BA"
        defb    'D' + 128
        defm    "FIRES HAVE BEEN DETECTE"
        defb    'D' + 128
        defm    "COASTAL FLOODING DETECTE"
        defb    'D' + 128
        defm    "MAJOR EARTHQUAKE DETECTE"
        defb    'D' + 128
        defm    "AIR CRASH !!"
        defb    '!' + 128
        defm    "TORNADO DETECTE"
        defb    'D' + 128

; $6305 - look up current tool name from text_table and print it
.print_selected_tool_name
L6305:
        ld      hl,text_table  ;table above
        ld      a,(V_selected_tool)
        call    get_word_from_table
        ld      bc,$0401
        ld      a,19
        call    print_string
        ret     

; Get the word from the table
; Entry: hl = table
;         a = word number to get
.get_word_from_table  
        and     a
        ret     z
        ld      e,0
.L631b  ld      d,a
.L631c  bit     7,(hl)
        jr      z,L6327                 ; (7)
        inc     e
        ld      a,d
        cp      e
        jr      nz,L6327                ; (2)
.L6325  inc     hl
        ret     
.L6327  inc     hl
        jr      L631c                   ; (-14)



; 632a
; Print a string
; Entry: hl = string to print
;        bc = xy coordinates
;         a = maximum width
print_string:
.L632a  push    af
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        pop     af
        ld      c,a
.L6335  ld      a,(hl)
        and     127
        push    hl
        push    bc
        call    prchar
        call    incprpos
        pop     bc
        pop     hl
.L6342  bit     7,(hl)
        jr      nz,L634a                ; (4)
        inc     hl
        dec     c
        jr      L6335                   ; (-21)
.L634a  ld      a,c
        and     a
        ret     z
        ret     m
        ld      b,a
.L634f  push    bc
        ld      a,32
        call    prchar
        call    incprpos
        pop     bc
        djnz    L634f                   ; (-12)
        ret     

check_cursor_keys:
.L635c  ld      a,(keystore+5)
        and     2           ;'O'
        call    z,pointer_left
        ld      a,(keystore+5)
        and     1           ;'P'
        call    z,pointer_right
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,pointer_up
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,pointer_down
        ret     

pointer_right:
.L637d  ld      hl,V_pointerxy
        ld      a,(hl)
        add     a,1
        cp      63
        jp      nc,draw_map
        ld      (hl),a
        ret     

pointer_left:
.L638a  ld      hl,V_pointerxy
        ld      a,(hl)
        sub     1
        cp      255
        jp      z,draw_map
        ld      (hl),a
        ret     

pointer_up:
.L6397  ld      hl,V_pointerxy+1
        ld      a,(hl)
        cp      64
        jr      c,L63a6                 ; (7)
        ld      a,(keystore+4)
        and     16              ;'6'
        jr      z,L63ae                 ; (8)
.L63a6  ld      a,(hl)
        sub     2
        cp      250
        ret     nc
        ld      (hl),a
        ret     
.L63ae  ld      a,(hl)
        sub     2
        cp      64
        jp      c,draw_map
        ld      (hl),a
        ret     

pointer_down:
.L63b8  ld      hl,V_pointerxy+1
        ld      a,(hl)
        add     a,2
        cp      185
        jr      nc,L63c4                ; (2)
        ld      (hl),a
        ret     
.L63c4  ld      (hl),184
        jp      draw_map

V_pointer_charxy:   defw        0   ; VAR $63C9 / 25545 - pointer coords reduced to chars
        defb    0, 0            ; padding

handle_space_action:                                    ; $63CD / 25549 - SPACE action: convert pointer to char-cell, disable sim, dispatch menu/tool/place, re-enable sim
.L63cd  ld      a,(keystore+7)
        and     1       ;'SPACE'
        ret     nz

        ld      bc,(V_pointerxy)
        srl     b
        srl     b
        srl     b
        srl     c
        ld      (V_pointer_charxy),bc
        call    try_select_build_tool                   ;See if an icon is selected?
        ld      a,1
        ld      (V_simulation_disabled),a
        call    do_view_change
        call    handle_menus
        call    place_tool_at_cursor
        xor     a
        ld      (V_simulation_disabled),a
        ret     

wait_for_space_key_release:
.L63f9  ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,wait_for_space_key_release                 ; (-7)
        ret     


; Handle menu selection
;
handle_menus:
.L6401  ld      a,(V_pointer_charxy+1)
        and     a                   ;Only valid on first road
        ret     nz
        call    wait_for_space_key_release
        call    select_menu_from_pointer
        jr      wait_for_space_key_release                   ; (-21)

select_menu_from_pointer:                                    ; $640E / 25614 - Determine which top-bar menu to open from pointer X; load IX = menu struct
.L640e  ld      a,(V_pointerxy)
        ld      ix,menu_system
        cp      14
        jp      c,open_menu
        ld      ix,menu_options
        cp      30
        jp      c,open_menu
        ld      ix,menu_disaster
        cp      48
        jp      c,open_menu
        ld      ix,menu_windows     ;42178
        jp      open_menu

V_road_tile_variant:    defb    0       ; VAR $6433 / 25651 - road tile variant selector (bit 4 of current tile's flags; picks between two medium-traffic graphics)

draw_scrolling_map_row:                                    ; $6434 / 25652 - Set up and draw one row of the scrolling map view; uses tick counter for road animation frame
.L6434  ld      a,(V_ui_tick_counter)
        and     16
        ld      (V_road_tile_variant),a
        ld      a,(V_ui_tick_counter)
        and     15
        add     a,8
        ld      b,a
        ld      c,0
        call    xypos
        ld      (SMC_print_tile_hl+1),hl
        ld      bc,(V_view_topleft)
        ld      a,(V_ui_tick_counter)      
        and     15
        add     a,b
        ld      b,a
        call    levelmap_xypos
        ld      de,64
        ld      b,1
        jp      L651d

V_current_tile:        defb        $37,$00                ; VAR $6462 / 25698 - current tile being printed

L6464:
        ld      l,$3b
        jr      L6475

; Print a tile
; Entry: a = tile number
.print_tile
.L6468  ld      l,a
        ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L64d6                ; (103)
        call    replace_zone_with_power_if_needed
        call    update_road_tile_for_traffic
.L6475
        ld      h,0
        ld      (V_current_tile),hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 536
        add     hl,de

; Print the tile from hl
.SMC_print_tile_hl
.L6481  ld      de,18432        ;SCREEN address, SMC
        ld      b,8
.L6486  ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     d
        djnz    L6486                   ; (-6)
        ld      bc,(V_current_tile)             ; udg being printed
        ld      hl,(V_tile_colour_offset)
        add     hl,bc
        ld      a,(hl)                  ;get colour
        ex      de,hl
        jp      dotextcol_1

; Replace R/I/C with the "need power" tile
replace_zone_with_power_if_needed:
.L6499  ld      a,l
        cp      84
        ret     c
        cp      87
        ret     nc
        ld      a,(V_ui_tick_counter)
        bit     5,a
        ret     z
        ld      l,TILE_NEED_POWER            ;Need power icon
        ret     

; Process road - changes graphics to indicate business
;
; Entry: l = tile at the coordinates
; Exit:  l = tile to actually print
update_road_tile_for_traffic:
.L64a9  ld      a,l
        ld      b,52            ;tile what?
        cp      TILE_H_ROAD               ;
        jr      z,L64b5                 ; (5)
        ld      b,54            ;tile what?
        cp      TILE_V_ROAD
        ret     nz
.L64b5  push    hl
        push    de
        push    bc
        ld      hl,(V_map_render_ptr)
        call    map_addr_to_xy           ;Get coords of address
        call    get_traffic_density_value
        ld      a,(hl)
        pop     bc
        pop     de
        pop     hl
        cp      220
        jr      nc,L64d3                ; (10)
        cp      150
        ret     c
        ld      a,(V_road_tile_variant)
        and     a
        jr      z,L64d3                 ; (1)
        inc     b
.L64d3  ld      l,b
        ret

        defb    0               ; padding

.L64d6  ld      hl,V_current_zone_width_to_print
        dec     (hl)
        ld      a,(ix+0)
        ld      ix,25813
        ld      hl,V_ui_tick_counter
        bit     5,(hl)
        jr      z,L64ef                 ; (7)
        and     240
        cp      160
        jp      z,L6464

.L64ef  ld      hl,udgs + 3390
        ld      (V_tile_colour_offset),hl
        ld      hl,(V_left_tile_index)
        ld      (V_current_tile),hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 1288
        add     hl,de
        jp      SMC_print_tile_hl

V_tile_colour_offset:   defw    0       ; VAR $6505 / 25861 - 6505/25861 offset to colour for tiles

;6507
.V_view_topleft        defb    $1e, $25        ; VAR $6507 / 25863 - oordinates of top left of view

;6509
V_map_render_ptr:    defw    0       ; VAR $6509 / 25865 - current map render address (pointer into level map, kept in sync with screen tile printer)
        
; draw level on screen?
.draw_map
.L650b  ld      hl,18432
        ld      (SMC_print_tile_hl+1),hl          ;SMC code nobbling
        ld      bc,(V_view_topleft)          ;Coordinates for mapview top left corner
        call    levelmap_xypos
        ld      de,64
        ld      b,16                ;16 rows to show
.L651d  ld      c,32                ;each with 32 columns
.L651f  ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L652b                ; (6)
        ld      a,(hl)
        cp      128
        call    nc,L655b                ;
.L652b  ld      (V_map_render_ptr),hl              ;Holds the map pointer?
        exx     
        ld      hl,udgs + 3296
        ld      (V_tile_colour_offset),hl
        call    print_tile
        ld      hl,(SMC_print_tile_hl+1)
        inc     l
        jr      nz,L6541                ; (3)
draw_map_screen_addr:
        ld      hl,20480
.L6541  ld      (SMC_print_tile_hl+1),hl              ;SMC code nobbling
        ld      hl,(V_left_tile_index)
        inc     hl
        ld      (V_left_tile_index),hl
        exx     
        inc     hl
        dec     c
        jr      nz,L651f                ; (-49)
        xor     a
        ld      (V_current_zone_width_to_print),a
        add     hl,de
        djnz    L651d                   ; (-58)
        ret     

V_current_zone_width_to_print:  defb    0   ; VAR $6558 / 25944 - how much of the current zone width to print
V_left_tile_index:    defw    0   ; VAR $6559 / 25945 - index for furthest left tile of the zone


; Called when printing tiles >= 128
; Entry hl = map position
.L655b  push    hl
        pop     ix          ;ix = position on map
        xor     a
        ld      (V_zone_x_offset),a
        exx     
        ld      a,(ix+0)
        cp      192
        call    nc,find_left_edge_of_zone
            ;ix = map coordinate of furthest left column of zone
        ld      a,(V_zone_x_offset)
        ld      c,a
        ld      b,0
        ld      a,(ix+0)
        and     7
        sub     c
        ld      (V_current_zone_width_to_print),a       ;width of zone that we need to print
        ld      a,(ix+1)
        and     63
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      a,(ix+2)
        and     7
        or      l
        ld      l,a
        add     hl,bc
        ld      (V_left_tile_index),hl      ;tile index toprint
        exx     
        ret     

V_zone_x_offset:    defb    0       ; VAR $6592 / 26002 - how far the current x coordiante is in the zone

; Steps back in X to find the start of a special zone
find_left_edge_of_zone:
.L6593  ld      hl,V_zone_x_offset
.L6596  ld      a,(ix+0)
        and     192
        cp      192
        ret     nz
        inc     (hl)
        dec     ix
        jr      L6596                   ; (-13)

V_print_end_pos:    defw    $40bd          ; VAR $65A3 / 26019 - saved screen address after last printed number (textpos at end of prt24bit_cde)


; Print a 16 bit number with sign
; Uses 24 bit routine
; Entry: hl=number to print
;         bc=xypos

.prt16bit  
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        ld      c,0
        call    prt24bit_cde
        ret     

; I think this prints a 24 bit number...but perhaps not...
; Entry: bc = xypos
;          hl = pointer to number to print

.prt24bit  
        push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      c,(hl)
        ex      de,hl

prt24bit_cde:
.L65c1  xor     a
        ld      (V_num_print_state),a
        ld      (V_num_print_state+1),a
        call    prneg24
        push    hl
        push    bc
        exx     
        pop     bc
        pop     hl
        ld      b,240                ;-1000000
        ld      de,48576
        exx     
        call    print_24bit_digit
        exx     
        ld      b,254                ;-100000
        ld      de,31072
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-10000
        ld      de,55536
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-1000
        ld      de,64536
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-100
        ld      de,65436
        exx     
        call    print_24bit_digit
        exx     
        ld      b,255                ;-10
        ld      de,65526
        exx     
        call    print_24bit_digit
        exx     
        push    hl
        exx     
        pop     hl
        ld      b,l
        call    print_digit_nonzero
        ld      hl,(textpos)
        ld      (V_print_end_pos),hl
        ld      a,(V_num_print_state+1)
        and     a
        ret     z

        ld      b,a

.L661f  push    bc
        ld      a,32
        call    prchar
        call    incprpos
        pop     bc
        djnz    L661f                   ; (-12)
        ret     

; If a number is negative, print a - sign and cpl (to positive)
; So we can then print as number

.prneg24  
        bit     7,c
        ret     z
        ld      a,c
        cpl     
        ld      c,a
        ld      a,h
        cpl     
        ld      h,a
        ld      a,l
        cpl     
        ld      l,a
        ld      de,1
        add     hl,de
        ld      a,c
        adc     a,0
        ld      c,a
        push    hl
        push    bc
        ld      a,'-'
.L6644
        call    replace_with_direct_prchar_call
        call    incprpos
        pop     bc
        pop     hl
        ret     

V_num_print_state:        defw       $0202       ; VAR $664D / 26189 - number printing state: byte 0 = leading-zero suppression flag (0=still suppressing); byte 1 = count of suppressed leading zeros (printed as trailing spaces)


print_24bit_digit:                                    ; $664F / 26191 - Extract one decimal digit from 24-bit C':HL' via repeated addition; print via print_digit_nonzero
.L664f  ld      b,0
.L6651  inc     b
        exx     
        add     hl,de
        ld      a,c
        adc     a,b
        ld      c,a
        exx     
        jr      c,L6651                 ; (-9)
        exx     
        sbc     hl,de
        ld      a,c
        sbc     a,b
        ld      c,a
        exx     
        dec     b
        ld      a,(V_num_print_state)
        and     a
        jr      nz,print_digit_nonzero                ; (7)
        ld      a,b
        and     a
        jr      z,L667b                 ; (15)
        ld      (V_num_print_state),a

print_digit_nonzero:                                    ; $666F / 26223 - Print digit in B if non-zero, else advance suppress-leading-zero state
.L666f  ld      a,b
        add     a,48
        ld      (V_digit_char_buf),a
        call    replace_with_direct_prchar_call
        jp      incprpos

.L667b  ld      hl,V_num_print_state+1
        inc     (hl)
        ret     

; 24 bit arithmetic routines
; operators: chl = chl - bde

.l_sub24  
        and     a
        sbc     hl,de
        ld      a,c
        sbc     a,b
        ld      c,a
        ret     

; chl = chl + bde
.l_add24  
        add     hl,de
        ld      a,c
        adc     a,b
        ld      c,a
        ret     

; Multiply 16x16 -> 24
; c'hl' =  hl * de ?

L_mult_24_16x16:
.L668c  push    de
        exx     
        pop     de
        ld      hl,0
        ld      c,l
        exx     
        ld      c,h
        ld      a,l
        ld      b,16
.L6698  exx     
        add     hl,hl
        rl      c
        exx     
        sla     a
        rl      c
        jr      nc,L66ad                ; (10)
        exx     
        ex      af,af'
        add     hl,de
        ld      a,c
        adc     a,0
        ld      c,a
        ex      af,af'
        exx     
        add     hl,de
.L66ad  djnz    L6698                  ; (-23)
        exx     
        push    hl
        push    bc
        exx     
        pop     bc
        pop     hl
        ret     

; Divide?
div24_chl_by_a:                                    ; $66B6 / 26294 - 24-bit divide C:HL by A, result in C:HL; used for tax/population percentages
.L66b6  ld      e,c
        ld      b,24
        ld      c,a
        xor     a
.L66bb  add     hl,hl
        rl      e
        rla     
        jr      c,L66c4                 ; (3)
        cp      c
        jr      c,L66cc                 ; (8)
.L66c4  sub     c
        ld      d,a
        inc     hl
        ld      a,e
        adc     a,0
        ld      e,a
        ld      a,d
.L66cc  djnz    L66bb                  ; (-19)
        ld      c,e
        ret     

; Division routine?
; hl = hl / de, de = hl % de

L_div16x16:
.L66d0  ld      a,d
        or      e
        jr      z,L66ee                 ; (26)
        ld      b,h
        ld      c,l
        ld      hl,0
        ld      a,16
.L66db  scf     
        rl      c
        rl      b
        adc     hl,hl
        sbc     hl,de
        jr      nc,L66e8                ; (2)
        add     hl,de
        dec     c
.L66e8  dec     a
        jr      nz,L66db                ; (-16)
        ld      h,b
        ld      l,c
        ret     
.L66ee  ld      hl,0
        ret     


open_menu:                                    ; $66F2 / 26354 - Clear top box, draw menu icons, run menu interaction loop; entry for all top-bar menus
.L66f2  call    cls_print_topbox
        call    render_status_bar
        call    run_menu
        call    draw_map
        ld      a,57
        ld      (textcol),a
just_a_ret:
        ret     

; Print routine

;6704
.print_routine  
        pop     ix
print_routine_ix:
.L6706  ld      a,(ix+0)
        cp      8
        jr      c,L6719                 ; (12)
        call    cls_map
        call    cls_print_topbox
        call    render_status_bar
        jp      run_menu

.L6719  call    cls_black
        call    prt_ctrl
        defb        T_SETCOL,71
        defb        T_BOX,0,0,32,24
        defb        T_END
        call        render_status_bar
        call        run_menu
        ld      a,57
        ld      (textcol),a
        call    cls_white
        jp      ingame_scrdraw

; Clear the screen and print the top box
.cls_print_topbox
.L6738  call    cls_map
        call    prt_ctrl
        defb        T_SETCOL,68
        defb        T_BOX,8,0,32,16
        defb        T_END
        ret

;6757/26439
V_cmd_stream_base:    defw    0       ; VAR $6747 / 26439 - saved IX register (base pointer into current display command stream)
V_status_row:    defb    0       ; VAR $6749 / 26441 - current status panel row (initialised from command stream, incremented each row)


; Zeros...
V_status_slot_table:                    ; VAR $69A0 / 27040 - Status bar slot table and display command stream buffer; IY base for render_status_bar
        defb        $0C, $3C, $A5, $0E, $52, $A5
        defb        $10, $6A, $A5, $16, $8C, $A5, $FF

        defs        107       ;What's up here? - Selection table? LOOK!

V_update_slot_count:    defb    0       ; VAR $67C2 / 26562 - count of registered display-update slots (incremented by register_update_slot each time an item is registered)

render_status_bar:                                    ; $67C3 / 26563 - Initialise status-bar update: set IY=V_status_slot_table, save IX, clear slot count, load first row from IX stream
.L67c3  ld      iy,V_status_slot_table
        ld      (V_cmd_stream_base),ix
        xor     a
        ld      (V_update_slot_count),a
        ld      a,(ix+0)
        ld      (V_status_row),a
        inc     ix

render_status_bar_item:                                    ; $67D7 / 26583 - Process one command from IX stream: dispatch on opcode (print string, register slot, blank, separator)
.L67d7  ld      hl,V_status_row
        inc     (hl)
        ld      a,1
        ld      (textxy),a
        ld      a,(ix+0)
        cp      4
        jr      z,L6801                 ; (26)
        cp      2
        jr      z,L681f                 ; (52)
        cp      3
        jr      z,L682f                 ; (64)
        cp      1
        jr      z,L684c                 ; (89)
        cp      0
        jr      z,status_bar_print_and_next                 ; (47)
        cp      8
        jr      z,L67fc                 ; (1)
        ret     


.L67fc  call    register_update_slot
        jr      status_bar_print_and_next                   ; (37)

.L6801  ld      (iy+0),255
        ret     


; Save current row and IX into update slots table, increment slot count
.register_update_slot
.L6806  ld      a,(V_status_row)
        ld      (iy+0),a
        push    ix
        pop     hl
        ld      (iy+1),l
        ld      (iy+2),h
        ld      de,3
        add     iy,de
        ld      hl,V_update_slot_count
        inc     (hl)
        ret     


.L681f  call    register_update_slot
        inc     ix
        inc     ix

status_bar_print_and_next:                                    ; $6826 / 26662 - Advance IX past inline string, call print_status_string_at_row, loop to next item
.L6826  inc     ix
        call    print_status_string_at_row
        inc     ix
        jr      render_status_bar_item                   ; (-88)

.L682f  inc     ix
        ld      a,(V_status_row)
        ld      b,a
        ld      c,0
        ld      (textxy),bc
        ld      a,32
        ld      (V_text_col_width),a
        ld      a,64
        ld      b,65
        ld      c,66
        call    print_zone_tile_row
        jr      render_status_bar_item                   ; (-116)

V_setting_display_val:    defb    0   ; VAR $684B / 26699 - temp: boolean setting value read from map, used to print ON/OFF in status panel

.L684c  call    register_update_slot
        inc     ix
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      a,(hl)
        ld      (V_setting_display_val),a
        inc     ix
        inc     ix
        call    print_status_string_at_row
        call    set_textpos_to_status_end
        ld      a,(V_setting_display_val)
        and     a
        jr      z,L6876                 ; (11)
        call    prt_ctrl
        defm        "ON"
        defb        T_END
        inc        ix
        jp      render_status_bar_item

.L6876  call    prt_ctrl
        defm        "OFF"
        defb        T_END
        inc     ix
        jp      render_status_bar_item

print_status_string_at_row:                                    ; $6882 / 26754 - Set textpos to status row col 1, walk IX string printing chars with embedded format codes
.L6882  ld      a,(V_status_row)
        ld      b,a
        ld      c,1
        call    xypos
        ld      (textpos),hl

.L688e  ld      a,(ix+0)
        and     a
        jp      p,L689d
        and     127
        call    prchar
        jp      incprpos

.L689d  cp      33
        jr      z,L68b7                 ; (22)
        cp      6
        jr      z,L68be                 ; (25)
        cp      7
        jr      z,L68d5                 ; (44)
        cp      5
        jr      z,L68eb                 ; (62)
        call    prchar
        call    incprpos
        inc     ix
        jr      L688e                   ; (-41)

.L68b7  call    set_textpos_to_status_end
        inc     ix
        jr      L688e                   ; (-48)

.L68be  ld      a,(ix+1)
        and     a
        call    nz,L6910
        ld      l,(ix+2)
        ld      h,(ix+3)
        call    prtthou
        ld      de,6
        add     ix,de
        jr      L688e                   ; (-71)

.L68d5  ld      a,(ix+1)
        and     a
        call    nz,L6910
        ld      l,(ix+2)
        ld      h,0
        call    prhund
        ld      de,4
        add     ix,de
        jr      L688e                   ; (-93)

.L68eb  ld      a,(ix+1)
        and     a
        call    nz,L6910
        ld      l,(ix+2)
        ld      h,(ix+3)
        ld      c,(ix+4)
        call    prt24bit_cde
        ld      de,5
        add     ix,de
        jr      L688e                   ; (-119) - inner loop entry of print_status_string_at_row

status_row_to_table_ptr:                                    ; $6905 / 26885 - Multiply V_status_row x 3 + base; return HL = pointer into status string table
.L6905  ld      b,a
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,26490
        add     hl,bc
        ret     


.L6910  ld      a,(V_status_row)
        call    status_row_to_table_ptr
        ld      a,(textxy)
        ld      (hl),a
        push    ix
        pop     de
        inc     hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        ret     


set_textpos_to_status_end:                                    ; $6922 / 26914 - Set textxy to (status_row, 24), update textpos; positions cursor at end of status line
.L6922  ld      a,(V_status_row)
        ld      b,a
        ld      c,24
        ld      (textxy),bc
        call    xypos
        ld      (textpos),hl
        ret     


toggle_status_row_attrs:                                    ; $6933 / 26931 - XOR 30 cell attributes at col 1 of V_status_row with 70 (flash highlight toggle)
.L6933  ld      c,1
        call    cxytoattr
        ld      b,30
.L693a  ld      a,(hl)
        xor     70
        ld      (hl),a
        inc     l
        djnz    L693a                   ; (-7)
        ret     

.V_menu_draw_hook        defw        0                ; VAR $6942 / 26946 - sommat with printing address

; Menu interaction loop: Q=up, A=down, SPACE=select
.run_menu
.L6944  ld      a,(V_update_slot_count)
        and     a
        ret     z
        xor     a
        ld      (V_menu_selection),a
        call    invoke_display_hook
.L6950  call    toggle_menu_row_highlight
.L6953  ld      b,8
.L6955  halt    
        djnz    L6955                   ; (-3)
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,menu_up
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,menu_down
        ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6971                 ; (2)
        jr      L6953                   ; (-30)

.L6971  ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6971                 ; (-7)
        call    get_menu_slot_ptr
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(hl)
        cp      2                   ;Code 2 is jump to routine
        jp      z,L6a4e
        cp      1
        jp      z,L6a44
        cp      8
        jr      z,L6996                 ; (7)
        ret     


V_menu_max_rows:    defb    0       ; VAR $6990 / 27024 - max options/row
V_menu_selection_ptr:    defw    0       ; VAR $6991 / 27025 -

V_menu_count_xy: defw        0       ; VAR $6993 / 27027 - xy coordinates for menu?

V_key_repeat_counter:    defb    0       ; VAR $6995 / 27029 -

.L6996  ld      a,10
        ld      (V_key_repeat_counter),a
        call    toggle_menu_row_highlight
        call    get_menu_slot_ptr
        ld      a,(hl)
        ld      (V_menu_count_xy+1),a
        call    status_row_to_table_ptr
        ld      a,(hl)
        ld      (V_menu_count_xy),a
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        inc     hl
        inc     hl
        ld      (V_menu_selection_ptr),hl
        inc     hl
        ld      a,(hl)
        ld      (V_menu_max_rows),a
        ld      a,69
        ld      (textcol),a

menu_interaction_loop:                                    ; $69C0 / 27072 - Main menu event loop: decrement repeat timer, handle Q/A navigation, wait for repeat delay
.L69c0  call    decrement_repeat_timer
        call    print_menu_item_count
        ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6a04                 ; (55)
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,L69ec
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,L69fa
        call    invoke_display_hook
        ld      a,(V_key_repeat_counter)
        and     a
        jr      z,menu_interaction_loop                 ; (-38)
        ld      b,a

.L69e7  halt    
        djnz    L69e7                   ; (-3)
        jr      menu_interaction_loop                   ; (-44)

; Move down the menu list?
.L69ec  ld      a,(V_menu_max_rows)
        inc     a
        ld      c,a
        ld      hl,(V_menu_selection_ptr)
        ld      a,(hl)
        inc     a
        cp      c
        ret     z
        ld      (hl),a
        ret     

; Move up the menu list?
.L69fa  ld      hl,(V_menu_selection_ptr)
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6a04  ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6a04                 ; (-7)
        ld      a,71
        ld      (textcol),a
        call    print_menu_item_count
        jp      L6950

; Print the menu item count (from V_menu_selection_ptr) at the menu position
.print_menu_item_count
.L6a16  ld      bc,(V_menu_count_xy)
        call    xypos
        ld      (textpos),hl
        ld      hl,(V_menu_selection_ptr)
        ld      l,(hl)
        ld      h,0
        call    prhund
        ret     


; Call the display hook stored in V_menu_draw_hook (if non-zero)
.invoke_display_hook
.L6a2a  ld      hl,(V_menu_draw_hook)
        ld      a,h
        or      l
        ret     z
        jp      (hl)

decrement_repeat_timer:                                    ; $6A31 / 27185 - Call twiddlekeys; if key held decrement repeat delay, if released reset to 10
.L6a31  call    twiddlekeys
        jr      z,L6a3e                 ; (8)
        ld      hl,V_key_repeat_counter
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ret     


.L6a3e  ld      a,10
        ld      (V_key_repeat_counter),a
        ret     


.L6a44  inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(hl)
        xor     1
        ld      (hl),a
        ret     


.L6a4e  inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)

menu_up:
.L6a54  ld      hl,V_menu_selection
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        call    toggle_menu_row_highlight
        ld      (hl),a
; XOR screen attributes on the current menu selection row (highlight/unhighlight)
.toggle_menu_row_highlight
.L6a60  push    hl
        push    af
        call    get_menu_slot_ptr
        ld      b,(hl)
        call    toggle_status_row_attrs
        pop     af
        pop     hl
        ret     

menu_down:
.L6a6c  ld      a,(V_update_slot_count)
        ld      b,a
        ld      hl,V_menu_selection
        ld      a,(hl)
        inc     a
        cp      b
        ret     z
        call    toggle_menu_row_highlight
        ld      (hl),a
        jr      toggle_menu_row_highlight                   ; (-29)


V_menu_selection:    defb        0   ; VAR $6A7D / 27261 - Current menu selection

; Return hl = pointer into update slots table for current menu selection (selection * 3)
.get_menu_slot_ptr
.L6a7e  ld      a,(V_menu_selection)
        ld      b,a
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,V_status_slot_table
        add     hl,bc
        ret     

V_InitialSeed:   defw    3       ; VAR $6A8C / 27276 - initial random seed

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
D_blob_shape_table:                     ; $6AD3 / 27347 - ellipse (w-exp, h-exp) pairs for terrain paint blobs; indexed by (rand & 3)*2
        defb    $04, $04    ; square-ish
        defb    $05, $03    ; wide
        defb    $03, $05    ; tall
        defb    $04, $04    ; square-ish



; Paint b filled ellipse blobs of tile c onto the map.
; Entry: b = number of strokes, c = tile to paint, e = step-size mask (ANDed with random, min 2)
.paint_landscape_strokes
.L6adb  ld      a,c
        ld      (V_stroke_tile),a         ; set tile type for draw_filled_ellipse_stroke
        ld      a,e
        ld      (SMC_27367+1),a     ; patch the AND mask used for step size

.L6ae3  push    bc                  ; save stroke counter and tile
        ; randomise step size (2-7)
        call    get_random_number
SMC_27367:
        and     7                   ; SMC: mask = e parameter (7 or 3)
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

V_levelmap_bounds_flag:   defb        0   ; VAR $6BDA / 27610 - ?? unused?

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


V_stroke_center:        defw    0           ; VAR $6C02 / 27650 - landscape stroke center (x,y), random 16-79
V_stroke_step:        defb    $05         ; VAR $6C04 / 27652 - landscape stroke step size (random 2-7, controls drawing density)
V_stroke_tile:        defb    $02         ; VAR $6C05 / 27653 - landscape stroke tile type to paint (TILE_DIRT=2 for land pass, TILE_WATER=0 for water pass)
V_stroke_constraint:        defb    $00         ; VAR $6C06 / 27654 - landscape stroke constraint tile (0=paint anywhere; else only overwrite cells containing this tile)
V_stroke_dims:        defw    $0404       ; VAR $6C07 / 27655 - landscape stroke half-dimensions (w,h) loaded via ldi from D_blob_shape_table



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
        ld      (SMC_27676+1),hl ; initialise dy = s (high byte), dx low byte = 0
        ld      h,l
        ld      (SMC_27673+1),hl ; initialise dx = 0
        ld      b,49             ; 49 steps traces one full ellipse path

.L6c18  push    bc              ; save outer loop counter
SMC_27673:
        ld      hl,0            ; SMC: current dx (updated each iteration)
SMC_27676:
        ld      de,0            ; SMC: current dy (updated each iteration)
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
        ld      (SMC_27673+1),hl ; save updated dx for next iteration
        ld      (SMC_27676+1),de ; save updated dy for next iteration

        ; --- compute map position and span width for this step ---
        ld      bc,(V_stroke_center)    ; bc = (y_center, x_center)
        ld      a,d             ; dy high byte = row offset
        add     a,b
        ld      b,a             ; b = y_center + dy_high
        ld      a,h             ; dx high byte = col offset (negative at equator)
        add     a,c
        ld      c,a             ; c = x_center + dx_high (left edge of span)
        ld      a,(SMC_27673+2) ; dx_high (high byte of stored dx)
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

do_view_change:
.L6cbf  ld      bc,(V_pointer_charxy)
        ld      a,c
        and     a               ;Menu row
        ret     nz
        ld      a,b             ;We want x == 2
        cp      2              
        ret     nz
        call    wait_for_space_key_release
.L6ccd  ld      a,(keystore+5)
        and     1       ;'P'
        call    z,L6d0f
        ld      a,(keystore+5)
        and     2       ;'O'
        call    z,L6d05
        ld      a,(keystore+2)
        and     1       ;'Q'
        call    z,L6d19
        ld      a,(keystore+1)
        and     1       ;'A'
        call    z,L6d23
        halt    
        call    draw_map
        call    display_sprites
        ld      hl,V_ui_tick_counter
        ld      a,(hl)
        add     a,4
        ld      (hl),a
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      nz,L6ccd                ; (-53)
        jp      wait_for_space_key_release

.L6d05  ld      hl,V_view_topleft
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6d0f  ld      hl,V_view_topleft
        ld      a,(hl)
        inc     a
        cp      64
        ret     z
        ld      (hl),a
        ret     


.L6d19  ld      hl,V_view_topleft+1
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6d23  ld      hl,V_view_topleft+1
        ld      a,(hl)
        inc     a
        cp      80
        ret     z
        ld      (hl),a
        ret     


read_digit_key_select_tool:                                    ; $6D2D / 27949 - Read digit keys 0-9 (SHIFT held, no SYM) and select matching build tool by index
.L6d2d  ld      a,(keystore)
        and     1           ;'SHIFT'
        ret     z

        ld      a,(keystore+7)
        and     2           ;'SYM'
        ret     nz

        call    getkeyval
        ret     c

        cp      48
        jr      nz,L6d45                ; (4)
        ld      b,9
        jr      try_select_zone_tool                   ; (40)

.L6d45  cp      49
        ret     c
        cp      58
        ret     nc
        sub     49
        ld      b,a
        jr      try_select_zone_tool                   ; (29)

;6d50
V_selected_tool:    defb        1       ; VAR $6D50 / 27984 - currently selected build tool/zone type index (0=bulldoze,1=road,2=power,3=rail,4=park,5=residential,6=commercial,7=industrial,8=police,9=fire,10=stadium,11=power plant,12=seaport,13=airport)

.try_select_build_tool                      ; $6D51 / 27985
.L6d51
        ld      bc,(V_pointer_charxy)
        ld      a,b
        and     a
        ret     z
        cp      3
        ret     nc
        ld      a,c
        cp      2
        ret     c
        cp      30
        ret     nc
        call    wait_for_space_key_release
        ld      a,(V_pointer_charxy)
        sub     2
        srl     a
        ld      b,a
try_select_zone_tool:                                    ; $6D6D / 28013 - Check player can afford zone B; if yes and different from current, select it and refresh cursor/icons
.L6d6d  push    bc
        call    get_cost_for_zone
        ld      b,0
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        call    l_sub24
        ld      a,c
        pop     bc
        and     a
        ret     m

        ld      a,(V_selected_tool)
        cp      b
        ret     z

        ld      a,b
        ld      (V_selected_tool),a
        call    doicons
        call    L6305

update_cursor_and_greyout:                                    ; $6D90 / 28048 - Set cursor to selected tool size, draw it; grey out unaffordable zone icons
.L6d90  ld      a,(V_selected_tool)
        sla     a
        add     a,2
        ld      c,a
        ld      b,1
        ld      de,$0202
        ld      (V_zone_cursor_size),de
        call    draw_cursor_xor
        call    greyout_unaffordable_zones
        call    get_zone_size
        ld      (V_zone_cursor_size),de
        ret     


D_zone_sizes:                        ; $6DAF / 28079
                        ; $6DAF / 28079
        defb    $01, $01    ;Bulldozer
        defb    $01, $01    ;Road
        defb    $01, $01    ;Power lines
        defb    $01, $01    ;Rail road
        defb    $01, $01    ;Park
        defb    $03, $03    ;Residential
        defb    $03, $03    ;Commercial
        defb    $03, $03    ;Industrial
        defb    $03, $03    ;Police station
        defb    $03, $03    ;Fire station
        defb    $04, $04    ;Stadium
        defb    $04, $04    ;Power plant
        defb    $04, $04    ;Seaport
        defb    $06, $06    ;Airport

; Get the size of a zone
;
; Exit: e = zone size x
;       d = zone size y
.get_zone_size
.L6dcb  ld      a,(V_selected_tool)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,D_zone_sizes
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ret     


greyout_unaffordable_zones:                                    ; $6DDA / 28122 - Iterate all zone types; grey out each one the player cannot afford
.L6dda  ld      bc,$e00

.L6ddd  push    bc
        ld      a,c
        call    get_cost_for_zone
        ld      b,0
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        call    l_sub24
        ld      a,c
        and     a
        jp      p,L6df8
        pop     bc
        push    bc
        call    grey_out_zone_icon
.L6df8  pop     bc
        inc     c
        djnz    L6ddd                   ; (-31)
        ret     

; Marks the zone as unclickable - used when we haven't enough money
; ot pay for it
grey_out_zone_icon:
.L6dfd  sla     c
        inc     c
        inc     c
        ld      b,1
        call    xypos
        ld      d,170
        ld      b,16
.L6e0a  ld      c,2
        push    hl
.L6e0d  ld      a,(hl)
        and     d
        ld      (hl),a
        inc     l
        dec     c
        jr      nz,L6e0d                ; (-7)
        pop     hl
        ld      a,d
        cpl     
        ld      d,a
        call    drow
        djnz    L6e0a                   ; (-19)
        ret     

; 28190
zone_costs:
        defw    1
        defw    10
        defw    5
        defw    20
        defw    10
        defw    100
        defw    100
        defw    100
        defw    500         ;Police
        defw    500         ;Fire
        defw    3000
        defw    4000
        defw    5000
        defw    10000       ;airport

; Gets the cost for the selected icon index
; Entry: a = zone index number
; Exit: de = cost
get_cost_for_zone:
.L6e3a  add     a,a
        ld      e,a
        ld      d,0
        ld      hl,zone_costs
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ret     

; Spend some money
; Entry: de = money to subtract
; Exit: nc = success
;        c = not enough money
.spend_money
.L6e46  push    hl
        push    bc
        ld      b,0
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        call    l_sub24
        and     a
        jp      p,L6e5c
        pop     bc
        pop     hl
        scf     
        ret     
.L6e5c  ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        pop     bc
        pop     hl
        or      a
        ret     


V_cursor_map_coords:    defw    0       ; VAR $6E67 / 28263 - cursor map coordinates saved by levelmap_xypos_from_cursor (appears written but not read back; possibly vestigial)
V_raw_coords_flag:    defb    0       ; VAR $6E69 / 28265 - raw-coordinates flag: when set, view offset is NOT added (use absolute map coords rather than view-relative)

; Gets coordinates on the levelmap - based on ccursor?
.levelmap_xypos_from_cursor
.L6e6a  call    get_cursor_charxy
        ld      (V_cursor_map_coords),bc
        jp      levelmap_xypos

; Load cursor character-cell coordinates into bc
.get_cursor_charxy
.L6e74  ld      bc,(V_pointer_charxy)

; Add view scroll offset to convert cursor char coords to map coords
; (skipped if V_raw_coords_flag raw-coordinates flag is set)
.cursor_to_map_coords
.L6e78  ld      a,(V_raw_coords_flag)
        and     a
        ret     nz
        ld      hl,V_view_topleft    ;
        ld      a,c
        add     a,(hl)
        ld      c,a
        inc     hl
        ld      a,b
        sub     8
        add     a,(hl)
        ld      b,a
        ret     


join_neighbour_cells_raw:                                    ; $6E8A / 28298 - join_up_neighbour_cells bypassing cursor-to-map scroll offset (raw coords)
.L6e8a  ld      a,1
        ld      (V_raw_coords_flag),a
        call    L6e9b
        xor     a
        ld      (V_raw_coords_flag),a
        ret     

; Join up neighbour paths for power cables, road, rail
join_up_neighbour_cells:
.L6e97  ld      bc,(V_pointer_charxy)
.L6e9b  push    hl
        push    de
        push    bc
        call    get_tile_join_type_flag
        ld      (V_tile_conn_flags),a
        call    join_neighbour_cell
        dec     b
        call    join_neighbour_cell
        inc     b
        dec     c
        call    join_neighbour_cell
        inc     c
        inc     c
        call    join_neighbour_cell
        inc     b
        dec     c
        call    join_neighbour_cell
        pop     bc
        pop     de
        pop     hl
        ret     


get_tile_join_type_flag:                                    ; $6EBE / 28350 - Return connection flag (2=rail, 4=road, 8=other) for V_neighbour_tile_to_check
.L6ebe  ld      a,(V_neighbour_tile_to_check)
        cp      7
        jr      z,L6ecc                 ; (7)
        cp      20
        jr      z,L6ecf                 ; (6)
        ld      a,8
        ret     


.L6ecc  ld      a,4
        ret     


.L6ecf  ld      a,2
        ret    


; Variable reused in a few places for convenience
V_neighbour_tile_to_check:    defb    $00         ; VAR $6ED2 / 28370 - cell to check for neight

;6ed3/28371
D_road_join_offsets:                    ; $6ED3 / 28371 - (type, tile) pairs for road/rail tile adjacency joining
        defb    $00, $01, $00, $02 
        defb    $00, $03, $00, $06 
        defb    $01, $01, $04, $09
        defb    $05, $08, $07, $0A
    
; ?? Joins up roads and rail together using the offset table above
; Enters: bc = xy coordinates
join_neighbour_cell:                                    ; $6EE3 / 28387 - Check one neighbouring cell and update its tile to join with adjacent road/rail/power
.L6ee3  push    bc
        call    cursor_to_map_coords           ;Adds something to the incoming coordinates
        call    check_neighbour_tile_match
        jr      nc,L6f0e        ;Coordinate out of range
        call    get_neighbours
        ld      e,d
        ld      d,0
        ld      hl,D_road_join_offsets
        add     hl,de
        ld      a,(V_neighbour_tile_to_check)
        add     a,(hl)
        pop     bc
        push    bc
        push    af
        call    cursor_to_map_coords
        call    levelmap_xypos
        pop     af
        ld      b,a
        ld      a,(hl)
        call    tile_to_flags
        bit     0,a                     ;Power?
        jr      nz,L6f0e                ; (1)
        ld      (hl),b
.L6f0e  pop     bc
        ret     

V_tile_conn_flags:    defb        0   ; VAR $6F10 / 28432 - current tile connection flags bitmask (from tile_to_flags, used in path-joining neighbour check)
V_force_tile_match:    defb        0   ; VAR $6F11 / 28433 - force tile-type match flag: when set, get_neighbours bypasses connection flags and compares tile type directly

check_neighbour_tile_match:                                    ; $6F12 / 28434 - Check tile at BC against V_neighbour_tile_to_check range [e, e+11]; set C if match
.L6f12  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ret     nc
        ld      a,(V_neighbour_tile_to_check)
        ld      e,a
        ld      a,(hl)
        cp      e
        jr      c,L6f2a                 ; (10)
        ld      a,e
        add     a,11
        ld      e,a
        ld      a,(hl)
        cp      e
        jr      nc,L6f2a                ; (2)
.L6f28  scf     
        ret     


.L6f2a  ld      a,(V_force_tile_match)
        and     a
        jr      nz,L6f3a                ; (10)
        ld      a,(hl)
        call    tile_to_flags
        ld      hl,V_tile_conn_flags
        and     (hl)
        jr      nz,L6f28                ; (-18)
.L6f3a  or      a
        ret     

; Checks that coordinates up down left right are ??;
; 
; Exit: d = state of surrounding cells
; Cell to bit mapping:
;  0
; 1 2
;  3
get_neighbours:
.L6f3c  push    bc
        ld      d,0
        dec     b
        call    check_neighbour_tile_match
        rl      d
        inc     b
        dec     c
        call    check_neighbour_tile_match
        rl      d
        inc     c
        inc     c
        call    check_neighbour_tile_match
        rl      d
        inc     b
        dec     c
        call    check_neighbour_tile_match
        rl      d
        pop     bc
        ret     

V_path_tile_coords:    defw    0       ; VAR $6F5C / 28508 - map coords of last-placed path tile (saved for subsequent join_up_neighbour_cells call)
V_path_tile_type:    defb    0       ; VAR $6F5E / 28510 - tile type to place in path routine (0=plain tile, neighbour_tile+11=crossing variant)

place_path_tile_with_join:                                    ; $6F5F / 28511 - Call get_join_type then fall into place_path_tile; alternate entry with join detection
.L6f5f  call    get_cursor_charxy

place_path_tile:                                    ; $6F62 / 28514 - Place path tile at BC if valid map cell and is empty/joinable; charge for bridge if on water
.L6f62  push    de
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        pop     de
        ret     nc

        ld      a,(hl)
        exx     
        ld      hl,D_joinable_tile_list
        ld      bc,8
        cpir    
        exx     
        jr      z,L6f9a                 ; (35)
        cp      0
        jr      z,L6f7d                 ; (2)
        scf     
        ret     


.L6f7d  ld      a,(V_path_tile_type)
        ld      (hl),a
        and     a
        jr      z,L6f8e                 ; (10)
        exx     
        ld      de,(V_t_1zone_cost_on_water)
        call    spend_money
        exx     
        ret     c


.L6f8e  ld      (V_path_tile_coords),bc
        ld      a,b
        add     a,d
        ld      b,a
        ld      a,c
        add     a,e
        ld      c,a
        jr      place_path_tile                   ; (-56)

.L6f9a  or      a
        ret     

;6f9c/28572
; Suspect this holds a mapping between tile and some feature

; Tile 69 = fire
; Bit 7 = can set on fire?
; bit 3 = needs power?      val 8
; bit 2 = transport - road? val 4
; bit 1 = transport - rail? val 2
D_tile_flags:                        ; $6F9C / 28572
                        ; $6F9C / 28572
        defb    $00, $00, $00, $00, $00, $00, $80, $84
        defb    $84, $84, $84, $84, $84, $84, $84, $84
        defb    $84, $84, $85, $85, $82, $82, $82, $82
        defb    $82, $82, $82, $82, $82, $82, $82, $83
        ;32
        defb    $83, $88, $88, $88, $88, $88, $88, $88
        defb    $88, $88, $88, $88, $89, $89, $87, $87
        defb    $8D, $8D, $8B, $8B, $00, $00, $00, $00
        defb    $80, $80, $00, $18, $D9, $D9, $D9, $D9
        ;64
        defb    $D9, $D9, $D9, $D9, $00, $00, $00, $00 
        defb    $00, $99, $99, $99, $99, $99, $99, $99 
        defb    $99, $B9, $B9, $B9, $B9, $B9, $B9, $05
        defb    $05, $00
        
;addresses for the icon handling
;28662
zone_action_jump_table:
        defw    action_zone_bulldoze
        defw    action_zone_road
        defw    action_zone_power
        defw    action_zone_rail
        defw    action_zone_park        ;$D4, $73
        defw    action_zone_residential ;$FA, $73
        defw    action_zone_commercial  ;$14, $74
        defw    action_zone_industrial  ;$2E, $74
        defw    action_zone_police      ;$48, $74
        defw    action_zone_fire        ;$62, $74, 
        defw    action_zone_stadium     ;$83, $74 
        defw    action_zone_power_station   ;$B4, $74
        defw    action_zone_seaport     ;$F6, $74, 
        defw    action_zone_airport     ;$2B, $75


place_tool_at_cursor:                                    ; $7012 / 28690 - Main tool-placement dispatcher: check cursor in map, place joinables or dispatch zone action
.L7012  ld      a,(V_pointer_charxy+1)
        cp      8
        ret     c
        ld      a,(V_cursor_validity+1)
        and     a
        ret     z
        call    place_joinables
        ret     c           ;We placed a joinable over another squre
        call    check_bulldoze_then_place       ;check if we can place/auto bulldoze
        jp      nc,L702d
        call    play_place_sound
        jp      wait_all_keys_pressed

.L702d  ld      a,(V_selected_tool)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,zone_action_jump_table            ;get the handler for the icon
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      (SMC_28735+1),hl          ;store the address following
SMC_28735:
        call    0               ;TODO: Why not just call  jp(hl)

wait_all_keys_pressed:                                    ; $7042 / 28738 - Spin until A+Q+P+O+SPACE all simultaneously held; used as confirmation gate
.L7042  ld      a,(keystore+1)
        and     1       ;'A'
        ret     z
        ld      a,(keystore+2)
        and     1       ;'Q'
        ret     z
        ld      a,(keystore+5)
        and     1       ;'P'
        ret     z
        ld      a,(keystore+5)
        and     2       ;'O'
        ret     z
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      z,wait_all_keys_pressed                 ; (-31)
        ret     

;7062
D_power_tile_conversions:                        ; $7062 / 28770
                        ; $7062 / 28770
        ;If we place power on one of these
        defb   $07, $08, $14, $15, $38, $39
        ;It converts to...
        defb   $31, $30, $32, $33, $21, $22
;706e 

D_road_tile_conversions:                        ; $706E / 28782
                        ; $706E / 28782
        ;If we place road on one of these
        defb    $14, $15, $21, $22, $38, $39 
        defb    $2E, $2F, $30, $31, $07, $08

D_rail_tile_conversions:                        ; $707A / 28794
                        ; $707A / 28794
        ;If we place rail on one of these
        defb    $07, $08, $21, $22, $38, $39
        defb    $2F, $2E, $33, $32, $14, $15
        

; Place a joinable (road,rail,power) 
place_joinables:
.L7086  ld      a,(V_selected_tool)
        and     a
        jp      z,L709c
        cp      1
        jp      z,place_road
        cp      2
        jp      z,place_power
        cp      3
        jp      z,place_rail

.L709c  or      a
        ret     

place_road:
.L709e  call    levelmap_xypos_from_cursor
.L70a1  ld      a,(hl)
        ld      hl,D_road_tile_conversions
        ld      bc,6
        cpir    
        jp      nz,L709c        ;no match
        ld      de,10
        ld      a,TILE_H_ROAD
place_tile:
.L70b2  ld      (V_neighbour_tile_to_check),a
        call    spend_money
        ret     c
        ld      bc,5
        add     hl,bc       ;hl = 28782 + 6 + 5
        ld      a,(hl)      ;
        push    af
        call    levelmap_xypos_from_cursor
        pop     af
        ld      (hl),a
        call    join_up_neighbour_cells
        call    draw_map
        scf     
        ret     

place_rail:
.L70cc  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        ld      hl,D_rail_tile_conversions
        ld      bc,6
        cpir    
        jp      nz,L709c
        ld      de,20               ;Cost
        ld      a,TILE_H_RAIL
        jp      place_tile

place_power:
.L70e3  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        ld      hl,D_power_tile_conversions
        ld      bc,6
        cpir    
        jp      nz,L709c
        ld      de,5                ;Power
        ld      a,TILE_H_POWER
        jp      place_tile

; Types used for auto-bulldoze
;70fa/28922
D_autobulldoze_free_tiles:              ; $70FA / 28922 - tiles that do not need explicit bulldoze (free to build on)
        defb    TILE_DIRT, TILE_WATER            ;DIRT, WATER
;70fc/28944
D_autobulldoze_tile_types:              ; $70FC / 28924 - tile types auto-bulldozeable; searched by cpir in bulldoze check
        defb    $02, $03, $01, $05, $04, $06
 
V_auto_bulldoze_flag:    defb        0       ; VAR $7102 / 28930 - auto-bulldoze mode flag (2=large zone needs bulldoze check, 0=small tool; written but not subsequently read - possibly vestigial)

check_bulldoze_then_place:                                    ; $7103 / 28931 - From cursor position: if tile empty place zone, else if auto-bulldoze enabled bulldoze first
.L7103  call    levelmap_xypos_from_cursor
        ld      a,(hl)      ;Is it empty?
        cp      0
        jp      z,L7113
        ld      a,(V_auto_bulldoze)
        and     a
        jp      z,check_can_place_zone

.L7113  ld      a,2
        ld      (V_auto_bulldoze_flag),a
        ld      a,(V_selected_tool)
        and     a
        jp      z,L7171
        cp      4
        jp      nc,L7129
        ld      a,0
        ld      (V_auto_bulldoze_flag),a

.L7129  call    get_zone_size
        push    de
        call    levelmap_xypos_from_cursor
        pop     bc
        ld      a,c
        ld      (auto_bulldoze_nun_columns+1),a

; Think this is doing the auto bulldoze
.L7135  push    hl
auto_bulldoze_nun_columns:
        ld      c,0         ;SMC

.L7138  ld      a,(hl)
        push    hl      ;Address of top left of zone
        push    bc      ;Size of zone
        ld      hl,D_autobulldoze_tile_types
        ld      bc,7
        cpir    
        pop     bc
        pop     hl
        jp      z,L714b ;If we haven't one of those types then we must bulldoze
        pop     hl
        scf     
        ret     
.L714b  push    hl
        push    bc
        ld      hl,D_autobulldoze_free_tiles
        ld      bc,2
        cpir    
        pop     bc
        pop     hl
        jp      z,L7165     ;If we have sea/water, no need to autobulldoze
        ld      de,1
        call    spend_money
        jp      c,L7165
        ld      (hl),TILE_DIRT     ;DIRT
.L7165  inc     hl
        dec     c
        jp      nz,L7138
        pop     hl
        ld      de,96
        add     hl,de
        djnz    L7135                   ; (-60)
.L7171  or      a
        ret     

; Check whether we can place a zone
; Exit: nc = can place
;        c = can't place
check_can_place_zone:
.L7173  call    get_zone_size
        push    de
        call    levelmap_xypos_from_cursor
        pop     bc
        ld      a,c
        ld      (SMC_29056+1),a
.L717f  push    hl
SMC_29056:
        ld      c,0
.L7182  ld      a,(hl)
        cp      2                   ;DIRT
        jr      z,L718a                 ; (3)
        pop     hl
        scf     
        ret     
.L718a  inc     hl
        dec     c
        jr      nz,L7182                ; (-12)
        pop     hl
        ld      de,96
        add     hl,de
        djnz    L717f                   ; (-22)
        or      a
        ret     

; Place a zone:
; Entry:    ix = tiles to place
place_zone:                                 ; $7197 / 29079
.L7197  
        call    get_zone_size
        push    de
        call    levelmap_xypos_from_cursor
        pop     bc      ;c = size x, b = sizey

; Entry: hl = map position
;        bc = yx size to place
place_zone_direct:
.L719f  ld      a,c
        ld      (SMC_29092+1),a
.L71a3  push    hl
SMC_29092:
        ld      c,0
.L71a6  ld      a,(ix+0)
        ld      (hl),a
        inc     hl
        inc     ix
        dec     c
        jr      nz,L71a6                ; (-10)
        pop     hl
        ld      de,96
        add     hl,de
        djnz    L71a3                   ; (-20)
        ret   


V_t_1zone_cost_on_land:    defw    0   ; VAR $71B8 / 29112 - : Cost of a placing a single zone
V_t_1zone_cost_on_water:      defw    0   ; VAR $71BA / 29114 - : Cost on land
;71b8/29112


; Place a 1x1 zone
; Entry: hl = price on land
;        de = price on water
;         a = tile to place
;71bc
place_zone_1x1:
L71bc:
        ld      (V_t_1zone_cost_on_land),hl
        ld      (V_t_1zone_cost_on_water),de
        ld      (V_neighbour_tile_to_check),a
        call    levelmap_xypos_from_cursor
        ld      a,(hl)
        cp      TILE_WATER
        jr      z,L721e                 ; It's water..
        cp      TILE_DIRT
        jr      nz,play_place_sound                ; It's not dirt
        ld      de,(V_t_1zone_cost_on_land)    ; Can we spend it?
        call    spend_money
        ret     c
        ld      a,(V_neighbour_tile_to_check)               ; Yes we cam, place it
        ld      (hl),a
        call    join_up_neighbour_cells
        jp      draw_map

play_place_sound:                                    ; $71E4 / 29156 - Play placement sound if A/Q/P/O keys all held (sound gate check)
.L71e4  ld      a,(keystore+1)
        and     1       ;'A'
        ret     z
        ld      a,(keystore+2)
        and     1       ;'Q'
        ret     z
        ld      a,(keystore+5)
        and     1       ;'P;
        ret     z
        ld      a,(keystore+5)
        and     2       ;'O'
        ret     z
        jp      soundfx2

;71ff/29183
D_neighbour_type_index:                 ; $71FF / 29183 - 4-bit neighbour bitmask -> join-type index (0=no join)
        defb    $00, $01, $02, $00, $03, $00, $00, $00
        defb    $04, $00, $00, $00, $00, $00, $00, $00

D_join_tile_triplets:                   ; $720F / 29199 - join-type -> (E, D, fn) triplet for tile placement
        defb    $00, $00, $00, $00, $FF, $0C, $FF, $00 
        defb    $0B, $01, $00, $0B, $00, $01, $0C
        

L721e:
        call    get_cursor_charxy
        ld      a,1
        ld      (V_force_tile_match),a
        call    get_neighbours
        xor     a
        ld      (V_force_tile_match),a
        ld      a,d
        and     a
        ret     z

        ld      e,a
        ld      d,0
        ld      hl,D_neighbour_type_index
        add     hl,de
        ld      a,(hl)
        and     a
        ret     z

        ld      b,a
        add     a,a
        add     a,b
        ld      e,a
        ld      hl,D_join_tile_triplets
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        ld      (SMC_29270+1),a
        ld      a,0
        ld      (V_path_tile_type),a
        call    place_path_tile_with_join
        ret     nc

        ld      a,(V_neighbour_tile_to_check)
SMC_29270:
        add     a,11
        ld      (V_path_tile_type),a
        call    place_path_tile_with_join
        call    join_up_neighbour_cells
        ld      bc,(V_path_tile_coords)
        call    join_neighbour_cells_raw
        jp      draw_map


;726b/29291
D_joinable_tile_list:                   ; $726B / 29291 - tile IDs that accept road/rail/power joins; searched by cpir
        defb    $2c, $2d, $1f, $20
        defb    $12, $13, $57,$58

;7273/29299
unbulldozeable_tiles:
        defb    TILE_WATER, TILE_DIRT, TILE_RADIOACTIVE
        


action_zone_bulldoze:
        call    levelmap_xypos_from_cursor
        ld      a,(hl)
        cp      128                     ;Full zone
        jp      nc,L7308
        cp      81
        jr      c,L7288                 ;1x1 zones
        cp      87
        jp      c,L7367                 ;RIC in the centre

.L7288  ld      hl,D_joinable_tile_list
        ld      bc,8
        cpir    
        jr      z,L72ca                 ; (56)
        ld      hl,unbulldozeable_tiles
        ld      bc,3
        cpir    
        ret     z                       ;No need to bulldoze these
        cp      60                      ;Bulldoze any tile under 60
        jr      c,L72a3                 ; (4)
        cp      81
        jr      c,L72d8                 ; (53)
.L72a3  ld      de,1
        call    spend_money
        ret     c
        call    levelmap_xypos_from_cursor
        ld      (hl),2          ;DIRT
rejoin_bulldozed_neighbours:                                    ; $72AF / 29359 - After bulldozing to DIRT, join_up_neighbour_cells for power/rail/road then redraw
.L72af  ld      a,7
        ld      (V_neighbour_tile_to_check),a
        call    join_up_neighbour_cells
        ld      a,33
        ld      (V_neighbour_tile_to_check),a
        call    join_up_neighbour_cells
        ld      a,20
        ld      (V_neighbour_tile_to_check),a
        call    join_up_neighbour_cells
        jp      draw_map


.L72ca  ld      de,1
        call    spend_money
        ret     c
        call    levelmap_xypos_from_cursor
        ld      (hl),0              ;WATER?
        jr      rejoin_bulldozed_neighbours                   ; (-41)

.L72d8  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      de,1
        call    spend_money
        ret     c
        ld      (hl),58
        jr      rejoin_bulldozed_neighbours                   ; (-62)

; If V_demolish_wait is set, wait for SPACE key release or timeout before continuing
.wait_if_demolish_pending
.L72ed  ld      a,(V_demolish_wait)
        and     a
        ret     z

        ld      de,40000

.L72f5  ld      a,(keystore+7)
        and     1       ;'SPACE'
        ret     nz

        dec     de
        ld      a,d
        or      e
        jr      nz,L72f5                ; (-11)
        ret     


; Zone bulldoze costs
D_bulldoze_costs:                        ; $7301 / 29441
                        ; $7301 / 29441
        defb    0
        defb    1
        defb    4
        defb    9
        defb    16
        defb    25
        defb    36


.L7308  call    wait_if_demolish_pending
        ret     nz

        push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96
find_zone_top_row:                                    ; $7315 / 29461 - Walk IX upward (-96) until bit 5 set (top row of zone); locates zone header tile
.L7315  bit     5,(ix+0)
        jr      nz,L731f                ; (4)
        add     ix,de
        jr      find_zone_top_row                   ; (-10)

.L731f  ld      a,(ix+0)
        and     7
        ld      c,a
        ld      b,0
        ld      hl,D_bulldoze_costs
        add     hl,de
        ld      e,(hl)
        ld      d,0
        call    spend_money
        ret     c

        ld      a,(ix+0)
        and     7

bulldoze_zone_rows:                                    ; $7337 / 29495 - Fill zone W*H tiles with rubble row by row via IX, then animate bulldoze sequence
.L7337  ld      (SMC_bulldoze_zone_width+1),a
        ld      b,a
; Clear the whole zone and step through the bulldoze sequence
.L733b  push    ix
SMC_bulldoze_zone_width:
        ld      c,0             ;SMC
.L733f  ld      (ix+0),70
        inc     ix
        dec     c
        jr      nz,L733f                ; (-9)
        pop     ix
        ld      de,96
        add     ix,de
        djnz    L733b                   ; (-22)
        call    draw_map
        call    bulldoze_degrade_tile
        call    draw_map
        call    bulldoze_degrade_tile
        call    draw_map
        call    bulldoze_degrade_tile
        call    draw_map
        ret     


.L7367  call    wait_if_demolish_pending
        ret     nz
        ld      de,9            ;3x3 RIC zone = $9 to bulldoze
        call    spend_money
        ret     c
        ld      bc,-97
        add     hl,bc
        push    hl
        pop     ix
        ld      a,3
        jr      bulldoze_zone_rows                   ; (-70)

D29565:
        defb    $46, $47, $48
        defb    $47, $48, $02

; Degrade any bulldozed tiles through the sequence
bulldoze_degrade_tile:
.L7383  call    get_cursor_charxy
        ld      a,b
        sub     6
        ld      b,a
        ld      c,0
        call    levelmap_xypos
        push    hl
        pop     ix
        ld      de,1152
.L7395  ld      a,(ix+0)
        ld      hl,D29565
        ld      bc,3
        cpir    
        jr      nz,L73aa                ; (8)
        ld      bc,2
        add     hl,bc
        ld      a,(hl)
        ld      (ix+0),a
.L73aa  inc     ix
        dec     de
        ld      a,d
        or      e
        jr      nz,L7395                ; (-28)
        ret     

;73b2
action_zone_road:
        ld      hl,10   ;price on land
        ld      de,50   ;price on water
        ld      a,7     ;tile (road)
        jp      place_zone_1x1

;73bd
action_zone_rail:
        ld      hl,20   ;on land
        ld      de,100  ;on water
        ld      a,20    ;rail
        jp      place_zone_1x1

; 73c8
action_zone_power:
        ld      hl,5    ;on land
        ld      de,25   ;on water
        ld      a,33    ;power
        jp      place_zone_1x1

        defb    0               ; padding

;73d4
action_zone_park:
        call    levelmap_xypos_from_cursor
        cp      2           ;BUG? This seems to be the x position?
        jp      z,play_place_sound
        ld      de,10
        call    spend_money
        ret     c

        ld      c,TILE_PARK
        call    get_random_number
        and     7
        jr      nz,L73ed                ; (1)
        inc     c
.L73ed  ld      (hl),c
        jp      draw_map

default_residential_tiles:
        defb    $49, $4a, $4b
        defb    $50, $54, $4c
        defb    $4f, $4e, $4d

;73fa
action_zone_residential:
        ld      de,100
        call    spend_money
        ret     c
        ld      ix,default_residential_tiles
        call    place_zone
        jp      draw_map


;29707/740b
default_commercial_tiles:
        defb    $49, $4a, $4b
        defb    $50, $55, $4c
        defb    $4f, $4e, $4d

action_zone_commercial:
        ld      de,100
        call    spend_money
        ret     c
        ld      ix,default_commercial_tiles
        call    place_zone
        jp      draw_map

default_industrial_tiles:
        defb    $49, $4a, $4b
        defb    $50, $56, $4c
        defb    $4f, $4e, $4d

;742e
action_zone_industrial:
        ld      de,100
        call    spend_money
        ret     c
        ld      ix,default_industrial_tiles
        call    place_zone
        jp      draw_map

default_police_tiles:
        defb    $a3, $c0, $c0
        defb    $83, $c0, $c3
        defb    $83, $c0, $c6

action_zone_police:
        ld      de,500
        call    spend_money
        ret     c
        ld      ix,default_police_tiles
        call    place_zone
        jp      draw_map

default_fire_tiles:
        defb    $a3, $c1, $c1
        defb    $83, $c1, $c4
        defb    $83, $c1, $c7

action_zone_fire:
        ld      de,500
        call    spend_money
        ret     c
        ld      ix,default_fire_tiles
        call    place_zone
        jp      draw_map

default_stadium_tiles:
        defb    $a4, $c4, $c4, $c0
        defb    $84, $c5, $c0, $c0
        defb    $84, $c5, $c4, $c0
        defb    $84, $c6, $c0, $c0

;7483
action_zone_stadium:
        ld      de,3000
        call    spend_money
        ret     c
        ld      ix,29811
        call    place_zone
        jp      draw_map

default_coal_power_station_tile:
        defb    $b4, $c6, $c4, $c0
        defb    $84, $c7, $c0, $c0
        defb    $84, $c7, $c4, $c0
        defb    $84, $c8, $c0, $c0

default_nuclear_power_station_tiles:
        defb    $b4, $c8, $c4, $c0
        defb    $84, $c9, $c0, $c0
        defb    $84, $c9, $c4, $c0
        defb    $84, $ca, $c0, $c0


action_zone_power_station:
        ld      de,3000         ;Do we actually have 3000?
        ld      hl,(V_money)
        and     a
        sbc     hl,de
        ret     c
        ld      ix,menu_power
        call    open_menu
        ld      de,5000
        ld      ix,default_nuclear_power_station_tiles
        ld      a,(V_power_type_chosen)
        and     a
        ret     z
        cp      1           ;Nuclear
        jr      z,L74dc                 ; (7)
        ld      de,3000
        ld      ix,default_coal_power_station_tile
.L74dc  call    spend_money
        ret     c
        call    place_zone
        jp      draw_map


default_seaport_tiles:
        defb    $a4, $ca, $c4, $c0
        defb    $84, $cb, $c0, $c0
        defb    $84, $cb, $c4, $c0
        defb    $84, $cc, $c0, $c0


action_zone_seaport:
        ld      de,5000
        call    spend_money
        ret     c
        ld      ix,default_seaport_tiles
        call    place_zone
        jp      draw_map


default_airport_tiles:
        defb    $a6, $cc, $c4, $c0, $c0, $c0
        defb    $86, $cd, $c2, $c0, $c0, $c0
        defb    $86, $ce, $c0, $c0, $c0, $c0
        defb    $86, $ce, $c6, $c0, $c0, $c0
        defb    $86, $cf, $c4, $c0, $c0, $c0
        defb    $86, $d0, $c2, $c0, $c0, $c0
    
action_zone_airport:
        ld      de,10000
        call    spend_money
        ret     c
        ld      ix,29959
        call    place_zone
        jp      draw_map


V_minimap_start:    defw        0   ; VAR $753C / 30012 - 753c/30012, address of mini map being handled


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
        add     a,17
        ld      l,a
        ld      h,$5b            ;23296+17 -> 23296+17+8 FIXME RELOC
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
        add     a,17
        ld      e,a
        ld      d,$5b           ;Bit set 80 40 20 10 8 4 2 1
        ld      a,(de)
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

D_cardinal_offsets:                     ; $76DC / 30428 - (dx, dy) pairs for 4 cardinal directions: N, E, S, W
        defb    $00, $ff
        defb    $01, $00
        defb    $00,$01
        defb    $ff,$00

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

V_PowerStackNum:    defb        0       ; VAR $76FD / 30461 - power BFS queue tail index (2 bytes per entry, wraps within queue)

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

; Sprite printing?
; Entry: a = sprite number
display_transport_sprite:
.L7735  ld      hl,(V_view_topleft)
        ld      e,a
        ld      a,b
        cp      h
        ret     c

        ld      a,h
        add     a,14
        cp      b
        ret     c

        ld      a,b
        sub     h
        add     a,8
        ld      b,a
        ld      a,c
        cp      l
        ret     c

        ld      a,l
        add     a,30
        cp      c
        ret     c

        ld      a,c
        sub     l
        ld      c,a
        ld      a,(V_ui_tick_counter)
        and     15
        add     a,8
        cp      b
        ret     c

        ld      l,e
        ld      h,0
        add     hl,hl       ;16x16 blob printer?
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,transport_sprites
        add     hl,de
        ex      de,hl
        call    xypos
        ld      b,16

.L776c  push    hl
        ld      a,(hl)
        ld      c,a
        sla     a
        or      c
        ld      c,a
        ld      a,(hl)
        and     c
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de

.L777a  inc     l
        ld      a,(hl)
        ld      c,a
        sra     a
        or      c
        ld      c,a
        ld      a,(hl)
        and     c
        ld      c,a
        ld      a,(de)
        or      c
        ld      (hl),a
        inc     de
        pop     hl
        call    drow
        djnz    L776c                   ; (-34)
        ret     

; Does something with the transport sprite
display_sprites:                                    ; $778F / 30607 - Draw train/aircrash/tornado sprites if active; clear sprite if tile no longer valid
.L778f  ld      a,(V_transport_active)
        and     a
        jr      z,L77b3                 ; (30)
        ld      bc,(V_transport_pos)
        call    levelmap_xypos_with_check
        ld      a,(hl)
        cp      31
        jr      z,L77b3                 ; (18)
        cp      32
        jr      z,L77b3                 ; (14)
        ld      a,(V_transport_active)
        and     a
        ld      bc,(V_transport_pos)
        ld      a,(V_transport_sprite)
        call    nz,display_transport_sprite

.L77b3  ld      a,(V_aircrash_active)
        and     a
        ld      bc,(V_CrashXY)
        ld      a,0
        call    nz,display_transport_sprite
        ld      a,r
        and     1
        inc     a
        ld      d,a
        ld      a,(V_tornado_active)
        and     a
        ld      bc,(V_tornado_pos)
        ld      a,d
        call    nz,display_transport_sprite
        ret     

V_transport_pos:    defw    0       ; VAR $77D3 / 30675 - transport sprite current map position (b=y, c=x)

V_transport_sprite:    defb    0       ; VAR $77D5 / 30677 - transport sprite type index (passed to display_transport_sprite)

V_transport_active:    defb        0       ; VAR $77D6 / 30678 - transport sprite active (1=train/tram moving, 0=idle)
V_transport_prev_dir:    defb        0       ; VAR $77D7 / 30679 - previous direction taken (prevents U-turns)
V_transport_dir:    defb        0       ; VAR $77D8 / 30680 - current direction being evaluated (0-3)
V_transport_new_dir:    defb        0       ; VAR $77D9 / 30681 - confirmed next direction after rail check
V_transport_steps:    defb        0       ; VAR $77DA / 30682 - steps remaining before direction re-roll
V_transport_wander:    defb        0       ; VAR $77DB / 30683 - wander counter (decrements; sprite despawns at 0)


move_transport_sprite:                                    ; $77DC / 30684 - If transport active and on rail tile, step sprite in current direction; else despawn
.L77dc  ld      a,(V_transport_active)
        and     a
        ret     z
        ld      bc,(V_transport_pos)
        call    levelmap_xypos
        ld      a,(hl)
        call    tile_to_flags
        and     2                       ;rail?
        jr      nz,L77f5                ; (5)
        xor     a
        ld      (V_transport_active),a
        ret     


.L77f5  ld      bc,(V_transport_pos)
        call    get_random_number
        and     3
        ld      (V_transport_dir),a
        ld      a,4
        ld      (V_transport_steps),a

.L7806  ld      a,(V_transport_dir)
        and     3
        ld      (V_transport_new_dir),a
        ld      hl,V_transport_prev_dir
        cp      (hl)
        jr      z,L7822                 ; (14)
        ld      a,(V_transport_new_dir)               ;Direction to look in
        call    levelmap_addr_in_direction                   ;Move in direction
        ld      a,(hl)
        call    tile_to_flags
        and     2
        jr      nz,L783d                ; (27)

.L7822  ld      hl,V_transport_dir
        inc     (hl)
        ld      hl,V_transport_steps
        dec     (hl)
        jr      nz,L7806                ; (-38)
        ld      hl,V_transport_wander
        ld      a,(hl)
        inc     a
        ld      (hl),a
        cp      5
        ret     nz

        ld      (hl),0
        ld      a,5
        ld      (V_transport_prev_dir),a
        ret     


.L783d  ld      a,(V_transport_new_dir)
        call    coords_add_direction_offset               ;Move coords in direction
        ld      a,(V_transport_new_dir)
        add     a,2
        and     3
        ld      (V_transport_prev_dir),a
        ld      (V_transport_pos),bc
        ld      c,3
        and     1
        jr      nz,L7858                ; (1)
        inc     c

.L7858  ld      a,c
        ld      (V_transport_sprite),a
        ret     


maybe_spawn_transport:                                    ; $785D / 30813 - If no transport active and 1:64 chance, spawn transport sprite at current simulation position
.L785d  ld      a,(37650)
        cp      8
        ld      a,(V_transport_active)
        and     a
        ret     nz

        call    get_random_number
        and     63
        ret     nz

        ld      hl,(V_map_iter_xy)
        ld      (V_transport_pos),hl
        ld      a,1
        ld      (V_transport_active),a
        ret     

V_aircrash_active:    defb        0       ; VAR $7879 / 30841 - aircrash in progress (1=active, 0=none)
V_CrashXY:    defw        0       ; VAR $787A / 30842 - aircrash current map position (b=y, c=x)
V_aircrash_col:    defb        0       ; VAR $787C / 30844 - aircrash target display column
V_aircrash_countdown:    defb        0       ; VAR $787D / 30845 - aircrash movement timer (decrements each tick)


move_aircrash_sprite:                                    ; $787E / 30846 - If aircrash active and not at target column, decrement countdown; at zero ignite 2x2 cells
.L787e  ld      a,(V_aircrash_active)
        and     a
        ret     z
        ld      a,(V_CrashXY)
        ld      hl,V_aircrash_col
        cp      (hl)
        jr      z,L78af                 ; (35)
        ld      hl,V_CrashXY
        dec     (hl)
        ld      hl,V_aircrash_countdown
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ret     nz
        ld      bc,(V_CrashXY)          ;And here we start an aircrash?
        call    set_cell_on_fire
        inc     c
        call    set_cell_on_fire
        dec     c
        inc     b
        call    set_cell_on_fire
        inc     c
        call    set_cell_on_fire
        call    play_crash_sound
.L78af  xor     a
        ld      (V_aircrash_active),a
        ret     


; Get map address for bc coords and ignite cell if flammable
.set_cell_on_fire
.L78b4  push    bc
        call    levelmap_xypos
        call    ignite_cell_if_flammable
        pop     bc
        ret     


play_crash_sound:                                    ; $78BD / 30909 - Play crash sound effect (127 iterations of soundfx1 with ramping pitch)
.L78bd  ld      b,255
        ld      e,0

.L78c1  push    bc
        call    soundfx1
        pop     bc
        inc     e
        djnz    L78c1                   ; (-8)
        ret     


; Randomly trigger a fire or flood event at the current simulation position
.sim_maybe_start_fire_or_flood
.L78ca  ld      a,(V_aircrash_active)
        and     a
        ret     nz

        call    get_random_number
        and     1
        ret     nz

        call    get_random_number
        and     1
        jr      z,L78f0                 ; (20)
        ld      bc,(V_map_iter_xy)
        ld      a,c
        ld      (V_aircrash_col),a
        ld      c,96
        ld      (V_CrashXY),bc

activate_aircrash:                                    ; $78EA / 30954 - Set V_aircrash_active=1; entry after CrashXY and aircrash column set up
.L78ea  ld      a,1
        ld      (V_aircrash_active),a
        ret     


.L78f0  ld      bc,(V_map_iter_xy)
        xor     a
        ld      (V_aircrash_col),a
        ld      (V_CrashXY),bc
        jr      activate_aircrash                   ; (-20)

.sim_start_aircrash
.L78fe  ld      a,(V_safe_AirportPop)
        and     a
        ret     z
        ld      a,25
        call    set_alert_message
        call    get_random_number
        and     15
        add     a,7
        ld      (V_aircrash_countdown),a
        ret     

.sim_start_meltdown
.L7913  ld      a,(V_safe_NuclearPop)       ;number of nuclear plants?
        and     a
        ret     z
        ld      a,18
        call    set_alert_message
        ld      a,1
        ld      (V_meltdown_triggered),a
        jr      play_crash_sound                   ; (-103)

V_meltdown_triggered:    defb        0       ; VAR $7924 / 31012 - meltdown triggered

; Nuclear meltdown - spread radiation everywhere?
place_fallout:
.L7925  ld      a,(V_meltdown_triggered)
        and     a
        ret     z
        xor     a
        ld      (V_meltdown_triggered),a
        ld      a,69
        ld      (V_fill_tile),a
        ld      hl,(V_map_iter_addr)
        call    fill_zone_with_tile
        ld      hl,(V_map_iter_xy)
        ld      a,h
        sub     20
        ld      d,a
        ld      a,l
        sub     20
        ld      e,a
        ld      b,45
.L7946  ld      c,45
        push    de
.L7949  push    bc
        ld      b,d
        ld      c,e
        call    get_random_number
        and     15
        call    z,L795e
        pop     bc
        inc     e
        dec     c
        jr      nz,L7949                ; (-16)
        pop     de
        inc     d
        djnz    L7946                   ; (-23)
        ret     


.L795e  call    levelmap_xypos_with_check
        ret     nc
        ld      a,(hl)
        bit     7,a
        ret     nz
        cp      TILE_WATER
        ret     z
        ld      (hl),TILE_RADIOACTIVE
        ret     



.sim_start_tornado
.L796c  ld      a,26
        call    set_alert_message
        ld      a,1
        ld      (V_tornado_active),a

.L7976  call    get_random_number       ;Get a starting coordinate in 64x64 grid
        and     63
        add     a,16
        ld      b,a
        call    get_random_number
        and     63
        add     a,16
        ld      c,a
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      TILE_DIRT               ;DIRT
        jr      nz,L7976                ; (-26)
        ld      (V_tornado_pos),bc
        ret     

V_tornado_pos:    defw    0       ; VAR $7995 / 31125 - tornado current map position (b=y, c=x); random dirt start
V_tornado_active:    defb    0       ; VAR $7997 / 31127 - tornado active (1=in progress, 0=none); cleared with 1/256 chance each tick

; Something to do with parks?
move_tornado:                                    ; $7998 / 31128 - If tornado active: 1/256 chance despawn; every 8 ticks steer toward CCxy centroid, else random walk
.L7998  ld      a,(V_tornado_active)
        and     a
        ret     z
        call    get_random_number
        and     a
        jr      nz,L79a7                ; (4)
        xor     a
        ld      (V_tornado_active),a
.L79a7  ld      bc,(V_tornado_pos)
        call    get_random_number
        and     7
        jr      nz,L79ea                ; (56)
        ld      hl,(V_CCxy)
        ld      a,h
        sub     b
        jr      z,L79be                 ; (5)
        sbc     a,a
        or      1
        add     a,b
        ld      b,a
.L79be  ld      a,l
        sub     c
        jr      z,L79c7                 ; (5)
        sbc     a,a
        or      1
        add     a,c
        ld      c,a
.L79c7  push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      0
        ret     z
        ld      (V_tornado_pos),bc
tornado_destroy_cell:                                    ; $79D4 / 31188 - At BC+1,+1: if in map and tile is flammable (bit 7 set), convert to rubble (tile 58)
.L79d4  inc     c
        inc     b
        call    levelmap_xypos_with_check
        ret     nc
        ld      a,(hl)
        call    tile_to_flags
        bit     7,a
        ret     z
        ld      a,(hl)
        bit     7,a
        jp      nz,L7bbb
        ld      (hl),58
        ret     


.L79ea  call    get_random_number
        and     3
        call    coords_add_direction_offset               ;Move coords in direction
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      0
        ret     z
        ld      (V_tornado_pos),bc
        jr      tornado_destroy_cell                   ; (-45)

; Converts kempston into directional keypresses
kempston_to_keystore:                                    ; $7A01 / 31233 - Read Kempston joystick and synthesise equivalent key-store bits (P/O/A/Q/SPACE)
.L7a01  call    read_kempston
        ld      c,a
        bit     0,c
        jr      nz,L7a0e                ; (5)
        ld      hl,keystore+5
        res     0,(hl)      ;'P'

.L7a0e  bit     1,c
        jr      nz,L7a17                ; (5)
        ld      hl,keystore+5
        res     1,(hl)      ;'O'

.L7a17  bit     2,c
        jr      nz,L7a20                ; (5)
        ld      hl,keystore+1
        res     0,(hl)      ;'A'

.L7a20  bit     3,c
        jr      nz,L7a29                ; (5)
        ld      hl,keystore+2
        res     0,(hl)      ;'Q'

.L7a29  bit     4,c
        ret     nz

        ld      hl,keystore+7
        res     0,(hl)      ;'SPACE'
        ret     


cursor_keys_sym_shift:                                    ; $7A32 / 31282 - Read SYM+SHIFT held; if both, translate cursor keys to P/O/A/Q; alternate scroll input path
.L7a32  ld      a,(keystore+7)
        and     2           ;'SYM'
        ret     z


.L7a38  ld      a,(keystore)
        and     1           ;'SHIFT'
        ret     z

        ld      a,(keystore+4)
        ld      c,a
        bit     3,c
        jr      nz,L7a4b                ; (5)
        ld      hl,keystore+5
        res     0,(hl)      ;'P'

.L7a4b  bit     4,c
        jr      nz,L7a54                ; (5)
        ld      hl,keystore+5
        res     1,(hl)      ;'O'

.L7a54  bit     2,c
        jr      nz,L7a5d                ; (5)
        ld      hl,keystore+1
        res     0,(hl)      ;'A'

.L7a5d  bit     1,c
        jr      nz,L7a66                ; (5)
        ld      hl,keystore+2
        res     0,(hl)      ;'Q'

.L7a66  bit     0,c
        ret     nz

        ld      hl,keystore+7
        res     0,(hl)      ;'SPACE'
        ret     


scroll_view_arrow_keys:                                    ; $7A6F / 31343 - Handle cursor-key map scrolling (SHIFT not held); calls draw_map if scrolled
.L7a6f  ld      a,(keystore)
        and     1           ;'SHIFT'
        ret     nz

        ld      hl,0
        ld      a,(keystore+4)
        and     4           ;'8'
        call    z,L6d0f
        ld      a,(keystore+3)
        and     16          ;'5'
        call    z,L6d05
        ld      a,(keystore+4)
        and     8           ;'7'
        call    z,L6d19
        ld      a,(keystore+4)
        and     16          ;'6'
        call    z,L6d23
        ld      a,h
        or      l
        ret     z

        jp      draw_map

draw_minimap_menu:                                    ; $7A9E / 31390 - Draw the minimap selection panel (boxes, map names list) using prt_ctrl sequences
.L7a9e  call    setminimap_col
        call    prt_ctrl
        defb        T_SETCOL,69
        defb        T_BOX,0,0,8,9
        defb        T_BOX,3,2,5,5
        defb        T_BOX,17,0,8,7
        defb        T_SETCOL,66
        defb        T_SETXY,1,2
        defm        "MAPS"
        defb        T_SETCOL,68
        defb        T_SETXY,9,0
        defm        "CITY"
        defb        T_SETXY,10,0
        defm        "POLLUTN"
        defb        T_SETXY,11,0
        defm        "POLICE"
        defb        T_SETXY,12,0
        defm        "FIREDEP"
        defb        T_SETXY,13,0
        defm        "TRAFFIC"
        defb        T_SETXY,14,0
        defm        "POWER"
        defb        T_SETXY,15,0
        defm        "TRANSPT"
        defb        T_SETXY,16,0
        defm        "CRIME"
        defb        T_END
.draw_minimap_legend                        ; $7B09 / 31497
.L7b09
        call        prt_ctrl
        defb        T_SETCOL,70
        defb        T_SETXY,4,3
        defm        "123"
        defb        T_SETXY,5,3
        defm        "456"
        defb        T_SETXY,6,3
        defm        "789"
        defb        T_SETXY,18,1
        defm        "  MAX"
        defb        T_SETXY,22,1
        defm        "  MIN"
        defb        T_SETCOL,127
        defb        T_SETXY,18,1
        defm        " "
        defb        T_SETCOL,118
        defb        T_SETXY,19,1
        defm        " "
        defb        T_SETCOL,100
        defb        T_SETXY,20,1
        defm        " "
.draw_minimap_legend_colours                ; $7B42 / 31554
.L7b42
        defb        T_SETCOL,82
        defb        T_SETXY,21,1
        defm        " "
        defb        T_SETCOL,73
        defb        T_SETXY,22,1
        defm        " "
        defb        T_END
        ret

.V_minimap_frame_counter        defb        0        ; VAR $7B50 / 31568 - incremented each minimap loop iteration; low 2 bits rate-limit key input

show_mini_maps:
.L7b51  xor     a
        ld      (V_show_mini_maps),a
        call    draw_minimap_menu

.L7b58  call    toggle_minimap_section_flash
        call    highlight_minimap_label
        call    start_minimap_render
        call    highlight_minimap_label
        call    toggle_minimap_section_flash
        ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L7b7d                ; (16)
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      z,L7b7d                 ; (9)
        call    handle_minimap_key_input
        ld      hl,V_minimap_frame_counter
        inc     (hl)
        jr      L7b58                   ; (-37)

.L7b7d  call    cls_white
        call    ingame_scrdraw
        jp      draw_map

; Thing this gets the top left of the zone for a map position
fill_zone_with_tile:                                    ; $7B86 / 31622 - Find top-left of zone at HL, fill entire zone area with V_fill_tile tile
.L7b86  push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96

.L7b8f  bit     5,(ix+0)
        jr      nz,L7b99                ; (4)
        add     ix,de
        jr      L7b8f                   ; (-10)

.L7b99  ld      a,(ix+0)
        and     7
        ld      (SMC_31652+1),a
        ld      b,a
.L7ba2  push    ix
SMC_31652:
        ld      c,0
.L7ba6  ld      a,(V_fill_tile)
        ld      (ix+0),a
        inc     ix
        dec     c
        jr      nz,L7ba6                ; (-11)
        pop     ix
        ld      de,96
        add     ix,de
        djnz    L7ba2                   ; (-24)
        ret     


.L7bbb  push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96

tornado_find_zone_top:                                    ; $7BC4 / 31684 - Walk IX upward (-96) until bit 5 set; used by tornado zone-destruction path
.L7bc4  bit     5,(ix+0)
        jr      nz,L7bce                ; (4)
        add     ix,de
        jr      tornado_find_zone_top                   ; (-10)

.L7bce  ld      a,(ix+0)
        and     7
        ld      (SMC_31705+1),a
        ld      b,a
.L7bd7  push    ix
SMC_31705:
        ld      c,0
.L7bdb  ld      a,58
        ld      (ix+0),a
        inc     ix
        dec     c
        jr      nz,L7bdb                ; (-10)
        pop     ix
        ld      de,96
        add     ix,de
        djnz    L7bd7                   ; (-23)
        ret     


; 5x5 attenuation kernel for police and fire stations.  Each entry is a SHIFT
; COUNT: the station's effectiveness (V_PoliceEffect/V_FireEffect, 0-15) is
; shifted right by (value-1) before being added to the coverage minimap, so
; 1 = full strength at the centre, 2 = half, and 9 = shifted away to nothing.
; Cells are capped at 15.
D_station_influence_kernel:                        ; $7BEF / 31727
                        ; $7BEF / 31727
        defb    $09, $09, $02, $09, $09 
        defb    $09, $02, $01, $02, $09
        defb    $02, $01, $01, $01, $02 
        defb    $09, $02, $01, $02, $09 
        defb    $09, $09, $02, $09, $09


V_FireEffect:    defb        0       ; VAR $7C08 / 31752 -

apply_fire_station_kernel:                                    ; $7C09 / 31753 - Apply D_station_influence_kernel 5x5 around current pos to fire coverage minimap
.L7c09  ld      bc,(V_map_iter_xy)
        ld      ix,D_station_influence_kernel
        call    get_fire_minimap_value           ;Fire map
        ld      de,50
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
        ld      bc,24
        add     hl,bc
        dec     d
        jr      nz,L7c1c                ; (-20)
        ret     

V_PoliceEffect:    defb    0       ; VAR $7C31 / 31793 -

apply_police_station_kernel:                                    ; $7C32 / 31794 - Apply D_station_influence_kernel 5x5 around current pos to police coverage minimap
.L7c32  ld      bc,(V_map_iter_xy)
        ld      ix,D_station_influence_kernel
        call    get_police_minimap_value           ;Get police minimap address
        ld      de,50           ;Go 8 tiles up and two left??
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
        ld      bc,24           ;4 rows down
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

V_traffic_bfs_steps:    defb    $ff       ; VAR $7CBF / 31935 - traffic BFS step limit (initialised to 5, decremented per step; $ff = inactive)


apply_stadium_kernel_from_iter:                                    ; $7CC0 / 31936 - Load BC from V_map_iter_xy and IX from D_stadium_effect_kernel, then call apply_stadium_kernel
.L7cc0  ld      bc,(V_map_iter_xy)
        ld      ix,D_stadium_effect_kernel 

; NB the target is returned by get_land_value_minimap_value; despite that name it is
; the POLLUTION minimap (minimaps+1152), the same one decay_pollution_minimap and
; do_minimap_pollution use.
apply_stadium_kernel:                                    ; $7CC8 / 31944
.L7cc8  call    get_land_value_minimap_value       ;minimaps+2304
        ld      de,98
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
        ld      bc,48
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


V_zone_best_coords:    defw        0       ; VAR $7D2B / 32043 - map coords of highest-value zone tile (candidate for upgrade)


V_zone_size_to_scan:    defw    0       ; VAR $7D2D / 32045 - size of zone to scan

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
        ld      a,(32046)
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

V_zone_parks:    defb        0       ; VAR $7E17 / 32279 - park tile count within 3x3 zone scan
V_zone_seas:    defb        0       ; VAR $7E18 / 32280 - sea/water tile count within 3x3 zone scan
V_zone_trees:    defb        0       ; VAR $7E19 / 32281 - tree tile count within 3x3 zone scan
V_zone_transport_count:    defb        0       ; VAR $7E1A / 32282 - transport tile count within 3x3 zone scan
V_zone_transport_score:    defb        0       ; VAR $7E1B / 32283 - accumulated transport score (capped at 127)
V_zone_land_value_base:    defb        0       ; VAR $7E1C / 32284 - combined land value base score (parks + transport - pollution)


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

V_zone_police_score:    defb    0       ; VAR $7E69 / 32361 - police coverage score for zone (proximity to police station)

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

V_zone_tax_penalty:    defb        0       ; VAR $7E9A / 32410 - tax rate * 8 + difficulty bonus; subtracted from zone land value

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

V_zone_landval_local:    defb        0       ; VAR $7EBF / 32447 - zone's local land value from the land value minimap
V_zone_traffic_density:    defb        0       ; VAR $7EC0 / 32448 - zone's traffic density from traffic minimap
V_zone_landval_final:    defb        0       ; VAR $7EC1 / 32449 - final computed land value for this zone (0-255)
V_zone_landval_mult:    defw        0       ; VAR $7EC2 / 32450 - land value demand multiplier (scales growth/shrink probability)

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

V_zone_growth_factor:    defb    0       ; VAR $7F10 / 32528 - zone growth probability factor (land value based)
V_zone_half_landval:    defb    0       ; VAR $7F11 / 32529 - half of zone land value (used in population growth threshold)

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

V_com_growth_index:    defb    0       ; VAR $7F43 / 32579 -
V_com_growth_scaled:    defb    0       ; VAR $7F44 / 32580 - unused?


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

V_ind_growth_index:    defb    0       ; VAR $7F5D / 32605 -
V_ind_growth_scaled:    defb    0       ; VAR $7F5E / 32606 - unused?


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
V_powerstation_list:    defs        32          ; VAR $7F78 / 32632 - : 32632/7f78 - list of map addresses for all power stations (16 x 2-byte entries, zero-terminated)


build_powerstation_list:                                    ; $7F98 / 32664 - Scan levelmap for power station tiles (coal/nuclear); store addresses into V_powerstation_list
.L7f98  ld      ix,V_powerstation_list
        ld      hl,levelmap         ;Search for a power station
        ld      bc,9216             ;somehow we know it exists?
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
        ld      (ix+0),l
        inc     ix
        ld      (ix+0),h
        inc     ix
        inc     hl
        jr      powerstation_list_scan_loop                   ; (-42)


V_brownout_detected:    defb    0       ; VAR $7FCC / 32716 - (32716/7fcc) - brownouts detected

generate_power_map:
.L7fcd  call    build_powerstation_list
        ld      hl,minimaps + 5760              ;Clear power map
        ld      de,minimaps + 5760 + 1
        ld      bc,1151
        ld      (hl),0
        ldir    
        xor     a
        ld      (V_brownout_detected),a
        ld      ix,V_powerstation_list                  ;Map address of power stations
power_bfs_per_station:                                    ; $7FE5 / 32741 - For each station in V_powerstation_list: set power budget, start BFS from station coords
.L7fe5  ld      l,(ix+0)
        ld      h,(ix+1)
        ld      a,h
        or      l
        ret     z
        inc     hl
        ld      a,(hl)                      ;Find power station type
        and     63
        dec     hl
        ld      de,1350                     ;Amount of power available for nuclear
        cp      8
        jr      z,L7ffd                 ; (3)
        ld      de,450                      ;Coal power is a lot less

.L7ffd  ld      (V_power_units_left),de              ;Power available
        call    map_addr_to_xy
        ld      (V_power_bfs_pos),bc              ;Current coordinates
        push    ix
        call    power_bfs_start                   ;Start tracing the connections
        pop     ix
        inc     ix
        inc     ix
        jr      power_bfs_per_station                   ; (-48)

;8015
V_power_bfs_down:        defb    0       ; VAR $8015 / 32789 - power BFS downward traversal flag (set if going south, prevents backtrack)
V_power_bfs_up:        defb    0       ; VAR $8016 / 32790 - power BFS upward traversal flag (set if going north, prevents backtrack)
V_power_bfs_pos:        defw    0       ; VAR $8017 / 32791 - power BFS current map coordinates (b=y, c=x)
V_power_units_left: defw    0          ; VAR $8019 / 32793 - power units remaining from current station (coal=450, nuclear=1350; decrements each powered tile)
V_powersp:  defw    0       ; VAR $801B / 32795 - saved stack when aborting power search 

V_powerqueue:   defs    256 ; VAR $801D / 32797 - list of coordinates to check for power connection



;
; Power distribution for ONE power station - a scan-line flood fill over every
; tile that conducts power (check_tile_needs_power: not yet powered AND either a
; zone or a tile with flag bit 3, i.e. power line / station).
;
;   1. seed the queue with a $FFFF end marker and the station's coordinates
;   2. pop a seed; run LEFT until the next tile does not conduct
;   3. run RIGHT along the row: power each tile (set_tile_as_powered) and look at
;      the tiles directly above and below (power_bfs_expand_row).  A neighbour
;      that conducts is queued as a new seed - but only once per run, tracked
;      by V_power_bfs_up / V_power_bfs_down - so a long wire running alongside
;      is not queued for every cell.
;   4. repeat until the end marker is popped.
;
; Each powered tile uses up one unit of the station's budget (V_power_units_left:
; 450 coal, 1350 nuclear).  When it hits zero set_tile_as_powered abandons the
; whole search by reloading SP from V_powersp - which makes this routine return
; straight to its caller - and bumps V_brownout_detected.
power_bfs_start:                                    ; $811D / 33053
.L811d  call    check_tile_needs_power
        ret     nz              ;We don't need power
        ld      ix,V_powerqueue            ;801d
        ld      (V_powersp),sp
        ld      bc,$ffff        ;Place an endmarker
        call    powerqueue_push_bc          
        ld      bc,(V_power_bfs_pos)      ;Current coordinate we're dealing with
        call    powerqueue_push_bc
power_bfs_next:                                    ; $8136 / 33078 - Pop next coords from power queue; return if sentinel (BFS complete)
.L8136  call    powerqueue_pop_to_bc           ;Get next cell 
        ld      a,b             ;Check if we're at the end
        cp      255
        ret     z
power_bfs_scan_left:                                    ; $813D / 33085 - From current BC, scan left (dec C) until tile does not need power; column scan entry
.L813d  call    check_tile_needs_power
        jr      nz,L8145                ; We don't need power
        dec     c
        jr      power_bfs_scan_left                   ; Go left and try again

.L8145  inc     c                       ;Check right
        call    check_tile_needs_power
        jr      nz,power_bfs_next                ;Power not needed, go get next starting point
        xor     a
        ld      (V_power_bfs_down),a           ;Down power check indicator
        ld      (V_power_bfs_up),a           ;Up power check indicator
.L8152  call    set_tile_as_powered ;Turns power on for tile
        dec     b                   ;Up a row
        ld      hl,V_power_bfs_down
        call    power_bfs_expand_row
        inc     b                   ;And then below
        inc     b
        ld      hl,V_power_bfs_up
        call    power_bfs_expand_row
        dec     b                   ;And then to the right
        inc     c
        call    check_tile_needs_power
        jr      z,L8152                 ; (-25)
        jr      power_bfs_next                   ; (-55)

power_bfs_expand_row:                                    ; $816D / 33133 - From BC in power BFS, check tiles above/below for power need; push unvisited to queue
.L816d  call    check_tile_needs_power
        jr      nz,L818c                ; (26)
        ld      a,(hl)                  ;Flag that we've already checked in this direction
        and     a
        ret     nz
        ld      (hl),1
                                        ;Fall into adding another point for consideration
powerqueue_push_bc:                                    ; $8177 / 33143 - Push BC coords onto V_powerqueue at IX; guard against overflow
.L8177  push    ix
        pop     hl
        ld      de,V_powerqueue+256     ;FIXME: Check that we've not run out of space
        and     a
        sbc     hl,de
        ret     nc
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
        ld      a,h
        or      l
        ret     nz
        ; Abort power search - we've run out of power to distribute
        ld      sp,(V_powersp)
        ld      hl,V_brownout_detected
        inc     (hl)
        ret     

;33245
V_city_score:           defs    3   ; VAR $81DD / 33245 - calculated city score
V_previous_city_score:  defs    3   ; VAR $81E0 / 33248 - previous city score


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

V_unemployment:    defw    0       ; VAR $8265 / 33381 - unemployment level (derived from industrial demand; feeds concern score)


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


V_RValve:    defw    0       ; VAR $827C / 33404 - residential demand index (positive = demand, negative = surplus)
V_CValve:    defw    0       ; VAR $827E / 33406 - commercial demand index
V_IValve:    defw    0       ; VAR $8280 / 33408 - industrial demand index


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
.L830c  ld      a,1             ;Enable the simulation task
        ld      (V_simulation_disabled),a
        ld      hl,63214
        ld      (V_task1_stack),hl
        ld      hl,start_simulation
        ld      (63234),hl
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
;     - Coal gives 450 units, Nuclear gives 1350 units (V_power_units_left)
;     - BFS via V_powerqueue (256-byte queue of BC coords)
;     - set_tile_as_powered marks power minimap bit; decrements unit counter
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
; BUDGET (DoBudget - runs in November, month==11):
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

.V_zone_dispatch_suppress            defb        0       ; VAR $835D / 33629 -
.V_sim_loop_counter defb       0       ; VAR $835E / 33630 - loop counter for simulation (increments each time through)

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
        ld      bc,6911
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
V_pollution_count:        defw        0   ; VAR $847C / 33916 - pollution tile count (denominator for average)
V_landval_accum:        defw        0   ; VAR $847E / 33918 - land value accumulator (used by update_stats for tornado centroid)

      
;33920
reset_simulation_vars:
.L8480  ld      hl,V_CityPop           ;wipe out all populations
        ld      de,V_CityPop+1
        ld      bc,60
        ld      (hl),0
        ldir    
        xor     a
        ld      (V_zone_extent),a
        ld      (V_zone_extent+2),a
        cpl     
        ld      (V_zone_extent+1),a
        ld      (V_zone_extent+3),a
        ret     

V_LVAverage:     defw    0           ; VAR $849C / 33948 - land value total snapshot (copy of V_landval_accum; used for display)

V_safe_AirportPop:        defw    0           ; VAR $849E / 33950
V_safe_NuclearPop:        defw    0           ; VAR $84A0 / 33952

;V_CCxy
V_CCxy:    defb $20, $20       ; VAR $84A2 / 33954 - midpoint of active zone extent (x,y); used as tornado spawn target


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
        ld      hl,(V_pollution_sum)
        ld      de,(V_pollution_count)
        call    L_div16x16
        ld      a,l
        ld      (V_PolluteAverage),a             ;V_PolluteAverage = average pollution level
        ret

V_PolluteAverage:    defb        0       ; VAR $84DD / 34013 - average pollution level city-wide (V_pollution_sum / V_pollution_count)


; Decay pollution minimap and compute average (runs every other tick)
decay_pollution_minimap:                                    ; $84DE / 34014 - On odd ticks: decay all 2304 pollution minimap cells and compute V_PolluteAverage
.L84de  ld      a,(V_sim_loop_counter)
        and     1
        ret     z
        ld      hl,minimaps+1152        ;pollution minimap
        ld      bc,2304
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
        ld      bc,1151
        ld      (hl),0
        ldir    
        ret     

V_TrafficAverage:    defb        0       ; VAR $851A / 34074 - average traffic density city-wide (rolling average from DecTrafficMem)

; Decay traffic density minimap every tick; compute rolling average -> V_TrafficAverage
; Decay tiers: value<24 -> 0, 24-199 -> sub 24, 200-255 -> sub 34
DecTrafficMem:
.L851b  ld      hl,minimaps+3456
        ld      bc,2304

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

V_traffic_active:    defb    0       ; VAR $8568 / 34152 - traffic BFS active (1=road traffic, 2=rail traffic)
V_Zsource:    defb    0       ; VAR $8569 / 34153 - tile-flag mask for the traffic walk: the transport bits (4=road, 2=rail) of the start tile; only neighbours sharing a bit are walkable

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
        ld      ix,31899
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

V_LDir:    defb    0       ; VAR $85D4 / 34260 - traffic BFS previous direction (prevents immediate U-turns)
V_PosStackN:    defb    0       ; VAR $85D5 / 34261 - traffic BFS steps taken so far (trip ends at 30)


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

V_traffic_rand_dir:    defb    0       ; VAR $8606 / 34310 - traffic BFS initial random direction (0-3) for this step
V_traffic_cur_dir:    defb    0       ; VAR $8607 / 34311 - traffic BFS current direction being tried
V_traffic_attempts:    defb    0       ; VAR $8608 / 34312 - traffic BFS attempts remaining before step fails (tries all 4 directions)


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

V_zone_neighbour_filter:    defw    0           ; VAR $865E / 34398 -

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
        ld      b,96
        ld      d,0
.L8690  ld      c,96
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

V_ZonePwrFlg: defb    0       ; VAR $86C5 / 34501 - zone is powered this cell (1=yes, 0=no)
V_zone_proc_type: defb    0       ; VAR $86C6 / 34502 - zone processing type (1=big zone centre, 2=compact RIC tile)
V_CChr: defb    0       ; VAR $86C7 / 34503 - raw tile type of the zone centre tile (used to index D_zone_handler_config)
V_zone_unpow_tile: defb    0       ; VAR $86C8 / 34504 - unpowered tile variant for check_ric_power

; Scan full 96x96 map; evaluate zone tiles and dispatch to zone handlers
; Called once per simulation tick
process_ric_zones:
.L86c9  ld      hl,levelmap
        ld      b,96
        ld      d,0
.L86d0  ld      c,96
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

V_ric_tile_current: defb    0   ; VAR $873B / 34619 - current RIC tile state byte (powered/unpowered variant)


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


V_map_iter_xy: defw    0       ; VAR $8785 / 34693 - map coordinates whilst iterating
V_map_iter_addr: defw    0       ; VAR $8787 / 34695 - map address whilst iterating


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

V_zone_extent:    defb    0, 255, 0, 255      ; VAR $87C8 / 34760 - zone bounding box: minX, maxX, minY, maxY (reset to 0,255,0,255 each tick)



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
        defb    $ff,$ff                 ;sentinel

V_zone_handler_params:                                        ; VAR $8869 / 34921
        defb    $00, $00         ;VAR 8869/34921 - density/sub-type from D_zone_handler_config for current zone

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

V_rail_upgrade_mask:    defb    $FF         ; VAR $88C5 / 35013 -

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

V_road_upgrade_mask:    defb    0       ; VAR $8902 / 35074 -

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

V_flood_timer:  defb    $32         ; VAR $8985 / 35205 -

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

V_fill_tile:    defb    0       ; VAR $8998 / 35224 -
V_fill_mode_flag:    defb    0       ; VAR $8999 / 35225 -
V_fire_neighbour_count:    defb    0       ; VAR $899A / 35226 -

fire_spread_to_neighbours:                                    ; $899B / 35227 - Scan 4 neighbours of current zone; probabilistically bulldoze flammable tiles to spread fire
.L899b  xor     a
        ld      (V_fire_neighbour_count),a
        ld      e,4
.L89a1  push    de
        ld      bc,(V_map_iter_xy)
        ld      a,e
        dec     a
        call    coords_add_direction_offset               ;Move coords in direction
        call    levelmap_xypos
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
D_zone_ring_offsets:                    ; $8A08 / 35336
;8a08
        defb    $FF, $FF, $49, $FF, $00, $4A, $FF, $01
        defb    $4B, $00, $FF, $50, $00, $01, $4C, $01
        defb    $FF, $4F, $01, $00, $4E, $01
        
        
        defb    $01, $4D


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
.L8a53  call    levelmap_xypos
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
.L8a83  call    levelmap_xypos
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
        srl     a
        ld      bc,(V_map_iter_xy)
        ld      de,136
        jp      write_zone_print_entries

;35735
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


.L8ba9  ld      ix,residential_zone_1
; Called by the simulator to place a zone
; This is used to up/downgrade a zone
sim_place_zone_3x3:
.L8bad  ld      bc,(V_map_iter_xy)
        call    levelmap_xypos
        ld      bc,$0303
        jp      place_zone_direct

D_density_class_table:                  ; $8BBA / 35770 - population count index -> density class 0-3
        defb    $00, $00, $01, $01, $01, $02
        defb    $02, $03, $03, $03
        

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
        ld      c,a
        ld      b,0
        ld      hl,D_density_class_table
        add     hl,bc
        ld      a,(hl)
        ld      bc,(V_map_iter_xy)
        ld      de,172
        jp      write_zone_print_entries

;8c41, 35905 
commercial_zone_1:
        defb    $49, $4a, $4b
        defb    $50, $52, $4c
        defb    $4f, $4e, $4d


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
        srl     a
        ld      bc,(V_map_iter_xy)
        ld      de,208
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

industrial_zone_1:
        defb    $49, $4a, $4b
        defb    $50, $53, $4c
        defb    $4f, $4e, $4d


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


V_display_population:        defb    0,0,0        ; VAR $8E8A / 36490 - current cumulative population (copy for budget display)
V_prev_year_population:        defb    0,0,0        ; VAR $8E8D / 36493 - previous year's population (for budget comparison)
V_population:   defb    0,0,0        ; VAR $8E90 / 36496 - running population snapshot (updated each November)



; Simulation stops whilst waiting for budget confirmation, this variable is checked
.V_wait_for_budget_confirm defb    0   ; VAR $8E93 / 36499 - set waiting for budget to complete


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
        ret     nz                              ;Only do full budget in November
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
        ld      a,1
        ld      (V_wait_for_budget_confirm),a

        ; Busy loop waiting for other process to complete budget
.L8ee1  ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L8ee1                ; (-6)
        jr      apply_budget_to_money                   ; (6)

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


V_concern_crime:    defb    0       ; VAR $8F01 / 36609 - crime concern
V_concern_house_price:    defb    0       ; VAR $8F02 / 36610 - house price concern

V_transport_total:    defw    0       ; VAR $8F03 / 36611 - road/transport total (for city score display)


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


V_hospital_demand:    defb    0       ; VAR $8F2F / 36655 - hopsital demand
V_church_demand:    defb    0       ; VAR $8F30 / 36656 - church demand

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
V_sim_speed_block:  defb    $08, $07, $07, $07, $01     ; VAR $8F67 / 36711 - 5-byte simulation speed control block (default = NORMAL speed)

; Speed settings table: 5 bytes per row, indexed by V_simulation_speed (0=FAST..3=PAUSED)
D_sim_speed_params:                        ; $8F6C / 36716
                        ; $8F6C / 36716
        defb    $08, $01, $0f, $01, $00     ;FAST   (month every tick)
        defb    $04, $03, $1f, $03, $01     ;NORMAL (month every 2 ticks)
        defb    $03, $07, $3f, $07, $03     ;SLOW   (month every 4 ticks)
        defb    $ff, $ff, $ff, $ff, $ff     ;PAUSED (never advance month)


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

V_money:       defb  0,0,0   ; VAR $8F97 / 36759 - money!! - 8f99
            defb    0       ;UNUSED
V_month:     defb  0       ; VAR $8F9B / 36763 - (8f9b) - Month
V_year:      defw  1902    ; VAR $8F9C / 36764 - (8f9c) - Year
V_8f9e:      defb  0       ; VAR $8F9E / 36766 - unreferenced, likely struct padding
V_ui_tick_counter:      defb  0       ; VAR $8F9F / 36767 - UI thread tick counter; incremented each UI loop, selects road animation frame



; Real entry to the game

.gameentry
        ld      a,1
        ld      (V_simulation_disabled),a
        call    initialise_simulation_variables
        call    cls_white
        call    ingame_scrdraw
        call    change_fire_tile
        call    change_flood_tile
        ld      ix,menu_difficulty_text
        call    cls_print_topbox
        call    render_status_bar
        call    run_menu
        call    create_landscape
        call    draw_map
        ld      a,57
        ld      (textcol),a

ui_main_loop_tick:                                    ; $8FCC / 36812 - One tick of the UI main loop: draw pointer, validate cursor, wait 2000 cycles, update display
.L8fcc  call    prpointer
        call    validate_cursor_position           ;Inverse the selected zone size
        ld      bc,2000
.L8fd5  dec     bc
        ld      a,b
        or      c
        jr      nz,L8fd5                ; (-5)
        call    validate_cursor_position           ;Restore the selected zone size
        call    blankpointer
        call    check_cursor_keys
        call    display_sprites
        call    handle_space_action
        ld      a,1
        ld      (V_simulation_disabled),a
        call    draw_scrolling_map_row
        call    scroll_view_arrow_keys
        xor     a
        ld      (V_simulation_disabled),a
        call    ui_periodic_tasks
        call    read_digit_key_select_tool
        call    L9058
        ld      a,(V_wait_for_budget_confirm)
        and     a
        call    nz,show_budget
        ld      hl,V_ui_tick_counter
        inc     (hl)
        ld      a,(V_show_mini_maps)
        and     a
        call    nz,show_mini_maps
        ld      a,(keystore+6)
        and     1       ;'ENTER'
        call    z,show_mini_maps
        jr      ui_main_loop_tick                   ; (-81)

ui_periodic_tasks:                                    ; $901D / 36893 - Every-N-tick dispatcher: alert messages, flood/fire animation, money/date refresh, disasters
.L901d  ld      a,(V_ui_tick_counter)
        and     31
        call    z,display_alert_message
        ld      a,(V_ui_tick_counter)
        and     15
        call    z,L904d
        ld      a,(V_ui_tick_counter)
        and     15
        jp      z,print_money
        cp      1
        jp      z,print_date
        cp      2
        jr      z,change_flood_tile                 ; animation
        cp      3
        jr      z,change_fire_tile                 ; animation
        cp      4
        jp      z,sim_start_disaster
        cp      5
        jp      z,L9144
        ret     


.L904d  call    move_aircrash_sprite
        call    move_tornado
        jp      move_transport_sprite

.V_displayed_money        defw        0        ; VAR $9056 / 36950 - cached money value from last icon redraw; compared each tick to detect change and trigger redraw

.L9058  ld      de,(V_money)
        ld      hl,(V_displayed_money)
        and     a
        sbc     hl,de
        ret     z
        ld      (V_displayed_money),de
        call    doicons
        jp      update_cursor_and_greyout


; Animation by copying the udgs
; Flood
change_flood_tile:
.L906d  ld      de,60560                ;udg 69
        ld      hl,60728
        call    get_random_number
        and     3
        ld      b,a
        ld      a,(V_ui_tick_counter)
        add     a,b
        and     16
        jr      z,L9084                 ; (3)
        ld      hl,60736
.L9084  ld      bc,8
        ldir    
        ret     

; Copying in the UDG area?
; Flames?
change_fire_tile:
.L908a  ld      de,60552                ;udg 68
        ld      hl,60744
        call    get_random_number
        and     3
        ld      b,a
        ld      a,(V_ui_tick_counter)
        add     a,b
        and     16
        jr      z,L90a1                 ; (3)
        ld      hl,60752
.L90a1  ld      bc,8
        ldir    
        ret     

.sim_start_fire
.L90a7  ld      a,22
        call    set_alert_message
        call    play_rising_tone
.L90af  ld      hl,levelmap
        ld      bc,9216
.L90b5  call    get_random_number
        and     127
        call    z,ignite_cell_if_flammable
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L90b5                ; (-14)
        ret     
; Set cell to TILE_FIRE if it is flammable (skips zones, trees, and non-flammable tiles)
; Entry: hl = map address
.ignite_cell_if_flammable
.L90c4  ld      a,(hl)      ;Don't start fire in pd,fd,stadium etc?
        bit     7,a
        ret     nz
        call    tile_to_flags
        bit     7,a         ;Flammable?
        ret     z
        ld      a,(hl)
        cp      6           ;trees
        ret     z
        ld      (hl),TILE_FIRE
        ret     


.sim_start_flood
.L90d5  ld      a,23
        call    set_alert_message
        call    play_falling_tone
.L90dd  ld      hl,levelmap
        ld      bc,9216
.L90e3  ld      a,(hl)
        bit     7,a
        jr      nz,L90fc                ; (20)
        and     a           ;Water
        jr      z,L90fc                 ; (17)
        cp      2           ;Dirt
        jr      z,L90fc                 ; (13)
        cp      6           ;Floodable
        jr      nc,L90fc                ; (9)
        call    get_random_number
        and     31
        jr      nz,L90fc                ; (2)
        ld      (hl),TILE_FLOOD     ;Flood character?
.L90fc  inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L90e3                ; (-31)
        ld      a,50
        ld      (V_flood_timer),a
        ret     


play_rising_tone:                                    ; $9108 / 37128 - Play 127-step rising-pitch sound effect (soundfx1 with increasing pitch)
.L9108  ld      b,127
.L910a  push    bc
        ld      a,b
        and     63
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    L910a                   ; (-11)
        ret     


play_falling_tone:                                    ; $9116 / 37142 - Play 127-step falling-pitch sound effect (soundfx1 with decreasing pitch)
.L9116  ld      b,127
.L9118  push    bc
        ld      a,b
        cpl     
        and     127
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    L9118                   ; (-12)
        ret     

.sim_start_earthquake
.L9125  ld      a,24
        call    set_alert_message
        ld      b,255
        ld      c,0

.L912e  push    bc
        ld      e,c
        srl     e
        srl     e
        srl     e
        srl     e
        call    soundfx1
        pop     bc
        inc     c
        djnz    L912e                   ; (-17)
        call    L90af
        jr      L90dd                   ; (-103)

.L9144  ld      a,(42045)
        and     a
        ret     nz
        call    get_random_number
        ld      hl,(V_random_seed)
        ld      a,h
        and     7
        or      l
        ret     nz
        call    get_random_number
        and     7
        ret     z
        cp      7
        ret     z
        cp      6
        jr      nz,L9169                ; (8)
        call    get_random_number
        and     7
        ret     nz
        ld      a,6
.L9169  ld      (V_disaster_option),a
        ret     


V_disaster_option:  defb       $0   ; VAR $916D / 37229 - which disasters are enabled

sim_start_disaster:
.L916e  ld      hl,V_disaster_option
        ld      a,(hl)
        and     a
        ret     z
        ld      (hl),0
        cp      1           ;FIRE
        jp      z,sim_start_fire
        cp      2           ;FLOOD
        jp      z,sim_start_flood
        cp      3           ;EARTHQUAKE
        jr      z,sim_start_earthquake                 ; (-95)
        cp      4           ;AIR CRASH
        jp      z,sim_start_aircrash
        cp      5           ;TORNADO
        jp      z,sim_start_tornado
        cp      6           ;NUCLEAR MELTDOWN
        jp      z,sim_start_meltdown
        ret     

; Show budget
show_budget:
.L9194  ld      a,1
        ld      (V_simulation_disabled),a
        call    calculate_tax
        call    run_budget
        ld      hl,37702        ;TODO - in budget screen

.L91a2  ld      (V_menu_draw_hook),hl
        ld      ix,text_budget
        call    print_routine_ix
        ld      hl,0
        ld      (V_menu_draw_hook),hl
        xor     a
        ld      (V_simulation_disabled),a
        ld      (V_wait_for_budget_confirm),a
        jp      draw_map

;91bc/37308
.text_budget
        defb     $00, $00
        defm    "         FISCAL BUDGE"
        defb    'T' + 128
        defb    $03, $08
        defm    "TAX RATE!   "
        defb    $07, $01

        ;@91e4
SMC_tax_rate:
        defb    $07, $14
        defb    '%' + $80
        defb    $03, $00
        defm    "TAX COLLECTED       "
        defb    '$' + 128
        defb    $03, $00
        defb    $a0, $00
        defm    "       AMOUNT  AMOUNT    FUN"
        defb    'D' + 128
        defb    $00
        defm    "       REQSTD  ALLCTD    LEVE"
        defb    'L' + 128
        defb    $00, $a0
        defb    $08
        defm    "TRANS  $       $!  "
        defb    $07, $01

;9256
SMC_transport_percent:
        defb    $64, $64
        defb    '%'+128
        defb    $8
        defm    "POLICE $       $!  "
        defb    $7, $1
;926f
SMC_police_percent:
        defb    $64,$64
        defb    '%'+128
        defb    $8
        defm    "FIRE   $       $!  "
        defb    $07, $01
;9288
SMC_fire_percent:
        defb    $64, $64
        defb    '%'+128, $00
        defb    $a0
        defb    $03, $00, $a0, $00
        defm    "CASH FLOW           "
        defb    '$' + 128
        defb    0
L92a7:
        defm    "PREVIOUS FUND       "
        defb    '$' + 128
        defb    0
        defm    "                    --------"
        defb    '-' + 128
        defb    0
L92db:
        defm    "CURRENT FUNDS       "
        defb    '$'+128
        defb    $03, $02, $03, $67
        defm    "    GO WITH THESE FIGURE"
        defb    'S'+128
        defb    4

V_tax_collected:    defb    0,0,0       ; VAR $930E / 37646 - , 930e


V_Transport_Funding_Requested:                    defw        0   ; VAR $9311 / 37649 - budget, transport funding
V_Budget_Police_Funding_Requested:    defw        0   ; VAR $9313 / 37651 - budget how much police funding
V_Budget_Fire_Funding_Requested:      defw        0   ; VAR $9315 / 37653 - budget how much fire funding
   
V_Transport_Funding_Allocated:  defw    0       ; VAR $9317 / 37655
V_Police_Funding_Allocated:  defw    0       ; VAR $9319 / 37657
V_Fire_Funding_Allocated:  defw    0       ; VAR $931B / 37659


V_expenditure:  defb    0,0,0           ; VAR $931D / 37661 - how much we spent this budget

V_cashflow:        defb    0,0,0       ; VAR $9320 / 37664 - cashflow


V_previous_money:        defb    0,0,0           ; VAR $9323 / 37667 - previous money before budget
V_money_after_budget:            defb    0,0,0           ; VAR $9326 / 37670 - money after budget


calculate_tax:                                    ; $9329 / 37673 - Compute tax = population / 100 * tax_rate; result in V_tax_collected
.L9329  ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      a,100
        call    div24_chl_by_a
        ld      a,(SMC_tax_rate)           ;Tax rate
        ld      e,a
        ld      d,0
        call    L_mult_24_16x16
        ld      (V_tax_collected),hl
        ld      a,c
        ld      (V_tax_collected+2),a
        ret     

        ld      a,71
        ld      (textcol),a
        call    run_budget
        call    print_budget_amounts
        ld      a,69

.L9353  ld      (textcol),a
        ret

        defb    0               ; padding

run_budget:                                    ; $9358 / 37720 - Save previous money, calculate tax, compute all department allocations and cashflow
.L9358  ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        ld      (V_previous_money),hl
        ld      a,c
        ld      (V_previous_money+2),a
        call    alloc_transport_funding
        call    alloc_police_funding
        call    alloc_fire_funding
        call    cap_transport_funding_to_balance
        call    cap_police_funding_to_balance
        call    cap_fire_funding_to_balance
        call    calc_expenditure_and_cashflow
        ret     


alloc_transport_funding:                                    ; $937C / 37756 - Allocate transport funding: requested * percent / 100 -> V_Transport_Funding_Allocated
.L937c  ld      a,(SMC_transport_percent)
        ld      hl,(V_Transport_Funding_Requested)
        call    apply_funding_percent
        ld      (V_Transport_Funding_Allocated),hl
        ret     


alloc_police_funding:                                    ; $9389 / 37769 - Allocate police funding: requested * percent / 100 -> V_Police_Funding_Allocated
.L9389  ld      a,(SMC_police_percent)
        ld      hl,(V_Budget_Police_Funding_Requested)
        call    apply_funding_percent
        ld      (V_Police_Funding_Allocated),hl
        ret     


alloc_fire_funding:                                    ; $9396 / 37782 - Allocate fire funding: requested * percent / 100 -> V_Fire_Funding_Allocated
.L9396  ld      a,(SMC_fire_percent)
        ld      hl,(V_Budget_Fire_Funding_Requested)
        call    apply_funding_percent
        ld      (V_Fire_Funding_Allocated),hl
        ret     


calc_expenditure_and_cashflow:                                    ; $93A3 / 37795 - Sum all dept allocations -> expenditure; tax - expenditure -> cashflow
.L93a3  ld      hl,(V_Transport_Funding_Allocated)
        ld      de,(V_Police_Funding_Allocated)
        ld      bc,0
        call    l_add24
        ld      de,(V_Fire_Funding_Allocated)
        call    l_add24
        ld      (V_expenditure),hl
        ld      a,c
        ld      (V_expenditure+2),a
        ld      b,c
        ex      de,hl
        ld      hl,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      c,a
        call    l_sub24
        ld      (V_cashflow),hl
        ld      a,c
        ld      (V_cashflow+2),a
        ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        ld      de,(V_expenditure)
        ld      a,(V_expenditure+2)
        ld      b,a
        call    l_sub24
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      (V_money_after_budget),hl
        ld      a,c
        ld      (V_money_after_budget+2),a
        ret     

V_budget_working_reg:    defb   0,0,0       ; VAR $93F6 / 37878 -


cap_transport_funding_to_balance:                                    ; $93F9 / 37881 - If transport allocation would overdraft (money+tax < transport), cap to available balance
.L93f9  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      (V_budget_working_reg),hl
        ld      a,c
        ld      (V_budget_working_reg+2),a
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z
        ld      hl,(V_budget_working_reg)
        ld      a,(V_budget_working_reg+2)
        ld      c,a
        ld      (V_Transport_Funding_Allocated),hl
        ret     


cap_police_funding_to_balance:                                    ; $9429 / 37929 - If police allocation would overdraft, cap it to available balance
.L9429  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        ld      (V_budget_working_reg),hl
        ld      a,c
        ld      (V_budget_working_reg+2),a
        ld      de,(V_Police_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z
        ld      hl,(V_budget_working_reg)
        ld      a,(V_budget_working_reg+2)
        ld      c,a
        ld      (V_Police_Funding_Allocated),hl
        ret     


cap_fire_funding_to_balance:                                    ; $9462 / 37986 - If fire allocation would overdraft, cap it to available balance
.L9462  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        ld      de,(V_Police_Funding_Allocated)
        ld      b,0
        call    l_sub24
        ld      (V_budget_working_reg),hl
        ld      a,c
        ld      (V_budget_working_reg+2),a
        ld      de,(V_Fire_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z

        ld      hl,(V_budget_working_reg)
        ld      a,(V_budget_working_reg+2)
        ld      c,a
        ld      (V_Fire_Funding_Allocated),hl
        ret     

print_budget_amounts:
.L94a4  ld      bc,$0516        ;Tax collectd
        ld      hl,V_tax_collected
        call    prt24bit
        ld      bc,$1216        ;previous fund
        ld      hl,V_previous_money
        call    prt24bit
        ld      hl,(V_Transport_Funding_Allocated)      ;transport allocated
        ld      bc,$0b11
        call    prt16bit
        ld      hl,(V_Transport_Funding_Requested)      ;transport requested
        ld      bc,$0b09
        call    prt16bit
        ld      hl,(V_Police_Funding_Allocated)      ;police allocated
        ld      bc,$0c11
        call    prt16bit
        ld      hl,(V_Budget_Police_Funding_Requested)
        ld      bc,$0c09
        call    prt16bit
        ld      hl,(V_Fire_Funding_Allocated)      ;fire allocated
        ld      bc,$0d11
        call    prt16bit
        ld      hl,(V_Budget_Fire_Funding_Requested)
        ld      bc,$0d09
        call    prt16bit
        ld      bc,$1116        ;cashflow
        ld      hl,V_cashflow       
        call    prt24bit
        ld      bc,$1416        ;current funds
        ld      hl,V_money_after_budget       
        call    prt24bit
        ret     


apply_funding_percent:                                    ; $94FF / 38143 - Multiply HL by A/100 (16x8 -> 24-bit); returns allocated amount in HL
.L94ff  ld      e,a
        ld      d,0
        call    L_mult_24_16x16
        ld      a,100
        jp      div24_chl_by_a


;950a/38154
D_funding_effect_mask:                  ; $950A / 38154 - funding ratio index -> road effect bitmask (16 levels)
        defb    $0F, $1F, $1F, $3F, $3F, $7F, $7F, $FF
        defb    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

D_funding_effect_level:                 ; $951A / 38170 - funding ratio index -> service effectiveness 0-15 (16 levels)
        defb    $00, $03, $06, $07, $08, $0A, $0C, $0F
        defb    $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
        

;
; Turn the budget's allocated/requested figures into in-game effectiveness.
; ratio = allocated / (requested / 8), so full funding gives 8; the result indexes
; the two 16-entry tables above:
;   transport -> V_road_upgrade_mask / V_rail_upgrade_mask (crumble mask:
;                $FF = never crumbles, $0F = 1 in 16 per tile per tick)
;   police    -> V_PoliceEffect (0..15)    fire -> V_FireEffect (0..15)
; A service with a request below 20 is left at its best setting (mask $FF / level 15).
; SUSPECT: the fire section tests V_Transport_Funding_Requested rather than
; V_Budget_Fire_Funding_Requested for its "< 20" check (copy/paste from the first
; block) - so fire effectiveness is gated on the transport request.
alloc_funding_levels:                                    ; $952A / 38186
.L952a  ld      a,255
        ld      hl,(V_Transport_Funding_Requested)
        ld      de,20
        and     a
        sbc     hl,de
        jr      c,L9555                 ; (30)
        ld      hl,(V_Transport_Funding_Requested)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ex      de,hl
        ld      hl,(V_Transport_Funding_Allocated)
        call    L_div16x16
        ld      c,l
        ld      b,0
        ld      hl,D_funding_effect_mask
        add     hl,bc
        ld      a,(hl)
.L9555  ld      (V_rail_upgrade_mask),a
        ld      (V_road_upgrade_mask),a
        ld      a,15
        ld      hl,(V_Budget_Police_Funding_Requested)
        ld      de,20
        and     a
        sbc     hl,de
        jr      c,L9586                 ; (30)
        ld      hl,(V_Budget_Police_Funding_Requested)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ex      de,hl
        ld      hl,(V_Police_Funding_Allocated)
        call    L_div16x16
        ld      c,l
        ld      b,0
        ld      hl,D_funding_effect_level
        add     hl,bc
        ld      a,(hl)

.L9586  ld      (V_PoliceEffect),a
        ld      a,15
        ld      hl,(V_Transport_Funding_Requested)
        ld      de,20
        and     a
        sbc     hl,de
        jr      c,L95b4                 ; (30)
        ld      hl,(V_Budget_Fire_Funding_Requested)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ex      de,hl
        ld      hl,(V_Fire_Funding_Allocated)
        call    L_div16x16
        ld      c,l
        ld      b,0
        ld      hl,D_funding_effect_level
        add     hl,bc
        ld      a,(hl)

.L95b4  ld      (V_FireEffect),a
        ret     

; Evaluation?
show_evaluation:
L95b8:
        ld      a,1
        ld      (V_simulation_disabled),a
        ld      hl,print_stats        
        ld      (V_menu_draw_hook),hl
        ld      ix,text_evaluation    
        call    print_routine_ix
        ld      hl,0
        ld      (V_menu_draw_hook),hl
        xor     a
        ld      (V_simulation_disabled),a
        jp      draw_map
 
;95d7
.text_evaluation
        defb        0,0
        defm        "          EVALUATIO"
        defb        'N'+128
        defb        3,0
        defm        "IS THE MAYOR DOING A GOOD JOB"
        defb        '?'+128
        defb        0,160,0
        defm        "           000% Ye"
        defb        's'+128
        defb        0
        defb        "           000% N"
        defb        'o'+128
        defb        3,0
        defb        "WHAT ARE THE WORST PROBLEMS"
        defb        '?'+128
        defb        0,160,0
        defm        "Traffic 000%    Pollution 000"
        defb        '%'+128
        defb        0
        defb        "  Crime 000%         "
        defm        "Fire 000"
        defb        '%'+128
        defb        0
        defm        "  Taxes 000% House prices 000"
        defb        '%'+128
        defb        0
        defm        "             Unemployment 000"
        defb        '%'+128
        defb        3,0
        defm        "POPULATIO"
        defb        'N'+128
        defb        0
        defm        "MIGRATIO"
        defb        'N'+128
        defb        0
        defm        "ASSESSED VALUE    "
        defb        '$'+128
        defb        3,0
        defm        "CATAGORY   :"
        defb        '-'+128
        defb        0
        defm        "GAME LEVEL :"
        defb        '-'+128
        defb        0
        defm        "CITY SCORE :- 50"
        defb        '0'+128

; Hmmm TODO
        defb        2,3
        defm        "g!     O"
        defb        'K'+128
        defb        4        ;inc b

; 38711
print_stats:                                ; $9737 / 38711
.L9737
        call    determine_city_class    ;VILLAGE, TOWN etc etc
        call    print_evaluation_stats
        ld      hl,V_display_population
        ld      a,(hl)
        inc     hl
        or      (hl)
        inc     hl
.L9744  or      (hl)
        ret     z
        call    print_evaluation_concerns
.L9749  call    print_city_score
        call    print_mayor_rating
        ret     


; 9750, 38746
; Population sizes to transition
D_population_boundaries:                        ; $9750 / 38736
                        ; $9750 / 38736
        defb    $d0, $07, $00       ;2000
        defb    $10, $27, $00       ;10000
        defb    $50, $c3, $00       ;50000
        defb    $a0, $86, $01       ;100000
        defb    $20, $a1, $07       ;500000

V_citysize:     defb    0       ; VAR $975F / 38751 - city size

; Calculate the city type
determine_city_class:
.L9760  xor     a
        ld      (V_citysize),a
        ld      ix,D_population_boundaries
        ld      b,5
.L976a  push    bc
        ld      de,(V_population)
        ld      a,(V_population+2)
        ld      b,a
.L9773  ld      l,(ix+0)
        ld      h,(ix+1)
        ld      c,(ix+2)
.L977c  call    l_sub24
        pop     bc
        and     a
        ret     p
        ld      hl,V_citysize
        inc     (hl)
        inc     ix
        inc     ix
        inc     ix
        djnz    L976a                   ; (-36)
        ret


V_eval_migration:    defb    0,0,0       ; VAR $978F / 38799 - migration

print_evaluation_stats:
.L9792  ld      hl,text_table
        ld      a,(V_difficulty)
        add     a,14            ;Levels
        call    get_word_from_table
        ld      bc,$140f
        ld      a,8
        call    print_string
        ld      hl,text_table
        ld      a,(V_citysize)
        add     a,17
        call    get_word_from_table
        ld      bc,$130f
        ld      a,10
        call    print_string
        ld      hl,V_display_population
        ld      bc,$0f14
        call    prt24bit
        ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      de,(V_prev_year_population)
        ld      a,(V_prev_year_population+2)
        ld      b,a
        call    l_sub24
        ld      (V_eval_migration),hl
        ld      a,c
        ld      (V_eval_migration+2),a
        ld      hl,V_eval_migration        ;Migration?
        ld      bc,$1014
        call    prt24bit
        ld      hl,V_previous_city_score        ;Assessed value (*1000)
        ld      bc,$1114
        call    prt24bit
        ld      hl,(V_print_end_pos)
        ld      (textpos),hl
        call    print_zero_digit           ;Print 3 trailing 0s to multiply by 1000
        call    print_zero_digit

print_zero_digit:                                    ; $97F8 / 38904 - Print ASCII '0' at current textpos and advance; appends trailing zeros for x1000
.L97f8  ld      a,48
        call    prchar
        call    incprpos
        ret     

.V_eval_concern_total        defw        0        ; VAR $9801 / 38913 - accumulator for total concern score during evaluation screen

print_evaluation_concerns:
.L9803  ld      a,(V_TrafficAverage)           ;Traffic concern
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        ld      (V_eval_concern_total),hl
        ld      bc,$0A09
        call    prstat
        ld      a,(V_PolluteAverage)           ;Pollution concern
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0a1b
        call    prstat
        pop     hl                  
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(V_concern_crime)           ;Crime concern
        srl     a
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0b09
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(V_LVAverage)           ;Fire concern
        ld      l,a
        ld      h,0
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        add     hl,de
        call    ckpercent
        push    hl
        ld      bc,$0b1b
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(SMC_tax_rate)           ;Tax rate
        ld      l,a
        ld      h,0
        ld      de,$fffd
        add     hl,de
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,hl
        call    ckpercent
        push    hl
        ld      bc,$0c09
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      a,(V_concern_house_price)           ;House prices concern
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0c1b
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      hl,(V_unemployment)          ;Unemployment concern
        call    ckpercent
        push    hl
        ld      bc,$0d1b
        call    prstat
        pop     hl
        ld      de,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      de,(V_unPwrdZCnt)
        srl     d
        rr      e
        srl     d
        rr      e
        ld      hl,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ld      de,0
        ld      a,(V_alertmessage)
        and     a
        jr      z,L98dc                 ; (3)
        ld      de,4
.L98dc  ld      hl,(V_eval_concern_total)
        add     hl,de
        ld      (V_eval_concern_total),hl
        ret     

; Check that a number is within a % range if not, set it to be so
; Entry: hl = number
; Exit:  hl = fixed number

.ckpercent  
        ld      a,h
        and     a
        jr      z,L98ee                 ; (6)
        jp      m,sethl0
        jp      p,sethl100
.L98ee  ld      a,l
        cp      101
        ret     c
.sethl100  
        ld      hl,100
        ret     
.sethl0 ld      hl,0000
        ret     

.V_city_score_display        defw        0        ; VAR $98FA / 39162 - final clamped city score 0-1000 for display; computed by print_city_score

print_city_score:
.L98fc  ld      hl,(V_eval_concern_total)
        ld      d,h
        ld      e,l
        add     hl,hl
        add     hl,de
        ex      de,hl
        ld      hl,250
        and     a
        sbc     hl,de
        add     hl,hl
        add     hl,hl
        call    clamp_hl_to_1000
        ld      (V_city_score_display),hl
        ld      bc,$150F
        call    prt16bit
        ret     


clamp_hl_to_1000:                                    ; $9919 / 39193 - If H<0 return HL=0; else return min(HL, 1000)
.L9919  ld      a,h
        and     a
        jp      p,L9922
        ld      hl,0
        ret     

; Subtract hl from 1000?
; Entry: hl = number
; Exit:  de=hl = factor
.L9922  ex      de,hl
        ld      hl,1000
        and     a
        sbc     hl,de
        jr      nc,L992d                ; (2)
        ld      d,h
        ld      e,l
.L992d  ex      de,hl
        ret     

V_mayor_rating: defb    0,0         ; VAR $992F / 39215 - mayor rating, db yes, db no


; Think this is mayor rating
print_mayor_rating:
.L9931  ld      hl,0
        ld      (V_mayor_rating),hl
        ld      b,100
.L9939  call    get_random_number
        ld      hl,(V_random_seed)
        ld      a,h
        and     3
        ld      h,a
        ld      de,(V_city_score_display)
        and     a
        sbc     hl,de
        jr      nc,L9951                ; (5)
        ld      hl,V_mayor_rating
        jr      increment_mayor_rating_bucket                   ; (3)

.L9951  ld      hl,V_mayor_rating+1
increment_mayor_rating_bucket:                                    ; $9954 / 39252 - Increment the appropriate mayor rating bucket (good/bad) based on concern score comparison
.L9954  inc     (hl)
        djnz    L9939                   ; (-30)
        ld      a,(V_mayor_rating)       ;Yes good job
        ld      l,a
        ld      h,0
        ld      bc,$050c
        call    print_hundred_at_bc
        ld      a,(V_mayor_rating+1)       ;No bad job
        ld      l,a
        ld      h,0
        ld      bc,$060c
        call    print_hundred_at_bc
        ret     

; Print a statistic
; If it's above 20% then change the colour
; Entry:  hl = statistic
;          bc = xy posn

.prstat  
        push    hl
        ld      a,l
        cp      20
        jr      c,L997b                 ; (5)
        ld      a,66
        ld      (textcol),a
.L997b  call    xypos
        ld      (textpos),hl
        pop     hl
        call    prhund
        ld      a,71
        ld      (textcol),a
        ret     


print_hundred_at_bc:                                    ; $998B / 39307 - Set textpos from BC coords, print HL as 3-digit percentage
.L998b  push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        jp      prhund


V_alertmessage: defb    0       ; VAR $9996 / 39318 - alert message

.display_alert_message
.L9997  ld      a,(V_alertmessage)
        add     a,23
        ld      hl,text_table
        call    get_word_from_table
        ld      a,29
        ld      bc,$0601
        jp      print_string
        defb    0               ; padding


V_TotalZPop:    defw    0       ; VAR $99AB / 39339 - TotalZPop used for sending alert messages


; Main alert setting loop?
; See https://github.com/osgcc/simcity/blob/master/src/sim/s_msg.c for
; conditions...
SendMessages:
.L99ad  xor     a
        ld      (V_alertmessage),a
        ld      hl,(V_ResZPop)     ;residential population
        ld      de,(V_ComZPop)     ;commercial population
        add     hl,de
        ld      de,(V_IndZPop)     ;industrial population
        add     hl,de
        ld      (V_TotalZPop),hl

        ; if ((TotalZPop >>2) >= ResZPop)
        ld      hl,(V_TotalZPop)
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,(V_ResZPop)
        and     a
        sbc     hl,de
        ld      a,1         ;More residential
        jp      z,set_alert_message
        jp      nc,set_alert_message
        ; if ((TotalZPop >>3) >= ComZPop)
        ld      hl,(V_TotalZPop)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,(V_ComZPop)
        and     a
        sbc     hl,de
        ld      a,2         ;More commercial
        jp      z,set_alert_message
        jp      nc,set_alert_message
        ; if ((TotalZPop >>3) >= IndZPop)
        ld      hl,(V_TotalZPop)
        srl     h
        rr      l
        srl     h
        rr      l
        srl     h
        rr      l
        ld      de,(V_IndZPop)
        and     a
        sbc     hl,de
        ld      a,3         ;More industrial
        jp      z,set_alert_message
        jp      nc,set_alert_message

        ld      hl,V_display_population
        ld      a,(hl)
        inc     hl
        or      (hl)
        inc     hl
        or      (hl)
        ret     z

        ; if ((TotalZPop > 10) && ((TotalZPop <<1) > RoadTotal))
        ; This seems buggy? The << 1 isn't performed
        ld      hl,(V_TotalZPop)
        ld      de,10
        and     a
        sbc     hl,de
        jr      c,L9a3a                 ; (15)
        ld      hl,(V_TotalZPop)
        ld      de,(V_RoadTotal)
        and     a
        sbc     hl,de
        ld      a,4
        call    nc,set_alert_message

        ; if ((TotalZPop > 50) && (TotalZPop > RailTotal))
.L9a3a  ld      hl,(V_TotalZPop)
        ld      de,50
        and     a
        sbc     hl,de
        jr      c,L9a54                 ; (15)
        ld      hl,(V_TotalZPop)
        ld      de,(V_RailTotal)
        and     a
        sbc     hl,de
        ld      a,5
        call    nc,set_alert_message

        ; if ((TotalZPop > 10) && (PowerPop == 0))
.L9a54  ld      hl,(V_TotalZPop)
        ld      de,10
        and     a
        sbc     hl,de
        jr      c,L9a6e                 ; (15)
        ld      hl,(V_NuclearPop)
        ld      de,(V_CoalPop)
        add     hl,de
        ld      a,h
        or      l
        ld      a,6                     ;Need power
        jp      z,set_alert_message

        ; ORIG: if ((ResPop > 500) && (StadiumPop == 0)) {
.L9a6e  ld      a,(V_StadiumPop)
        and     a
        jr      nz,L9a82                ; (14)
        ld      hl,(V_ResZPop)
        ld      de,20
        and     a
        sbc     hl,de
        ld      a,7                     ;Need stadium
        jp      nc,set_alert_message

        ; ORIG: if ((IndPop > 70) && (PortPop == 0)) {
.L9a82  ld      a,(V_PortPop)
        and     a
        jr      nz,L9a96                ; (14)
        ld      hl,(V_IndZPop)
        ld      de,30
        and     a
        sbc     hl,de
        ld      a,8             ; Need port
        jp      nc,set_alert_message

        ; ORG: if ((ComPop > 100) && (APortPop == 0)) {
.L9a96  ld      a,(V_AirportPop)
        and     a
        jr      nz,L9aaa                ; (14)
        ld      hl,(V_ComZPop)
        ld      de,30
        and     a
        sbc     hl,de
        ld      a,9                 ;Need airport
        jp      nc,set_alert_message

.L9aaa  ld      a,(V_FirePop)
        and     a
        jr      nz,L9abe                ; (14)
        ld      hl,(V_TotalZPop)
        ld      de,30
        and     a
        sbc     hl,de
        ld      a,10
        jp      nc,set_alert_message

.L9abe  ld      a,(V_PolicePop)
        and     a
        jr      nz,L9ad2                ; (14)
        ld      hl,(V_TotalZPop)
        ld      de,25
        and     a
        sbc     hl,de
        ld      a,11
        jp      nc,set_alert_message

.L9ad2  ld      a,(SMC_tax_rate)
        cp      12
        ld      a,12                    ;Taxes too high
        jp      nc,set_alert_message


        ld      hl,(V_RailTotal)
        ld      de,(V_RoadTotal)
        add     hl,de
        ld      a,h
        or      l
        jr      z,L9af2                 ; (10)
        ld      a,(V_rail_upgrade_mask)
        cp      255
        ld      a,13
        jp      nz,set_alert_message

.L9af2  ld      hl,(V_FirePop)
        ld      a,h
        or      l
        jr      z,L9b03                 ; (10)
        ld      a,(V_FireEffect)
        cp      15
        ld      a,14
        jp      nz,set_alert_message

.L9b03  ld      hl,(V_PolicePop)
        ld      a,h
        or      l
        jr      z,L9b14                 ; (10)
        ld      a,(V_PoliceEffect)
        cp      15
        ld      a,15
        jp      nz,set_alert_message

.L9b14  ld      hl,(V_unPwrdZCnt)
        ld      de,10
        and     a
        sbc     hl,de
        ld      a,16
        jp      nc,set_alert_message
        ld      a,(V_brownout_detected)
        and     a
        ld      a,17            ;BROWNOUT DETECTED
        jp      nz,set_alert_message

        ld      a,(V_PolluteAverage)
        cp      60
        ld      a,19
        call    nc,set_alert_message
        ld      a,(V_concern_crime)
        cp      20

.L9b3a  ld      a,20
        call    nc,set_alert_message
        ld      a,(V_TrafficAverage)
        cp      60
        ld      a,21
        call    nc,set_alert_message
        ret     


set_alert_message:
.L9b4a  ld      (V_alertmessage),a
        ret     

; 39758/9b4e
D_minimap_section_coords:               ; $9B4E / 39758 - (row, col) char-cell pairs for 9 minimap section flash highlight positions
        defb    $4, $3
        defb    $4, $4
        defb    $4, $5
        defb    $5, $3
        defb    $5, $4
        defb    $5, $5
        defb    $6, $3
        defb    $6, $4
        defb    $6, $5


toggle_minimap_section_flash:                                    ; $9B60 / 39776 - Flash attribute at D_minimap_section_coords[V_minimap_section] by XOR 128
.L9b60  ld      a,(V_minimap_section)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,D_minimap_section_coords
        add     hl,bc
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        call    cxytoattr
        ld      a,(hl)
        xor     128             ;Toggle flash?
        ld      (hl),a
        ret     

; Highlight for the minimap map selector text
highlight_minimap_label:                                    ; $9B76 / 39798 - Highlight current minimap label row (V_minimap_selection_index+9) by XOR-ing 8 attributes
.L9b76  ld      a,(V_minimap_selection_index)
        add     a,9
        ld      b,a
        ld      c,0
        call    cxytoattr
        ld      b,8
.L9b83  ld      a,(hl)
        xor     %01000110       ;Switch between bright while and dull blue ink
        ld      (hl),a
        inc     l
        djnz    L9b83                   ; (-7)
        ret     


handle_minimap_key_input:                                    ; $9B8B / 39819 - Process Q/A/digit keys to change V_minimap_selection_index or V_minimap_section
.L9b8b  ld      a,(V_minimap_frame_counter)
        and     3
        jr      nz,L9ba3                ; (17)
        ld      hl,V_minimap_selection_index
        ld      a,(keystore+2)
        and     1       ;'Q'
        jr      z,L9bb7                 ; (27)
        ld      a,(keystore+1)
        and     1       ;'A'
        jr      z,L9bbd                 ; (26)

.L9ba3  ld      a,(keystore+7)
        and     2       ;'SYM'
        ret     nz
        call    getkeyval           ;Selection between 0 and 9 into 39979
        ret     c
        sub     49
        ret     c
        cp      9
        ret     nc
        ld      (V_minimap_section),a
        ret     


.L9bb7  ld      a,(hl)
        dec     a
        and     7
        ld      (hl),a
        ret     


.L9bbd  ld      a,(hl)
        inc     a
        and     7
        ld      (hl),a
        ret     


render_road_tile_traffic:                                    ; $9BC3 / 39875 - Render road tile at current screen position with traffic overlay
.L9bc3  ld      l,a
        ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L9be8                ; (30)
        call    update_road_tile_for_traffic
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 536
        add     hl,de

SMC_39894:          
blit_road_tile_rows:                                    ; $9BD6 / 39894 - Blit 4 pixel rows from UDG data into road tile screen address (SMC_39894); inner road rendering loop
.L9bd6  ld      de,16392            ;SMC, screen address of road tile
        inc     hl
        call    blit_road_pixel_row
        inc     d
        call    blit_road_pixel_row
        inc     d
        call    blit_road_pixel_row
        inc     d
        jr      blit_road_pixel_row                   ; (17)

.L9be8  ld      hl,V_current_zone_width_to_print
        dec     (hl)
        ld      hl,(V_left_tile_index)
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 1288
        add     hl,de
        jr      blit_road_tile_rows                   ; (-34)


        defb    0               ; padding


; This does the traffic effect for roads?
blit_road_pixel_row:                                    ; $9BF9 / 39929 - Pack 4 pixel bits from UDG data into road tile screen byte, merging with existing pixels
.L9bf9  ld      a,(hl)
        and     128
        ld      c,a
        ld      a,(hl)
        and     32
        rlca    
        or      c
        ld      c,a
        ld      a,(hl)
        and     8
        rlca    
        rlca    
        or      c
        ld      c,a
        ld      a,(hl)
        and     2
        rlca    
        rlca    
        rlca    
        or      c
        ld      c,a
        ld      b,15
        ld      a,(V_road_tile_attr)
        and     a
        jr      z,L9c24                 ; (10)
        ld      b,240
        rrc     c
        rrc     c
        rrc     c
        rrc     c
.L9c24  ld      a,(de)
        and     b
        or      c
        ld      (de),a
        inc     hl
        inc     hl
        ret     


;9c2b/39979
V_minimap_section:    defb        0       ; VAR $9C2B / 39979 - selected minimap quadrant
        defb    0, 0            ; padding ($9C2C-$9C2D / 39980-39981, unreferenced)

V_minimap_scan_xy:        defw    0       ; VAR $9C2E / 39982 -

V_road_tile_attr:        defb    0       ; VAR $9C30 / 39984 -
V_minimap_xy:    defw    0       ; VAR $9C31 / 39985 - xypos in minimap being printed


; Address within the levelmap that 0-8 keys correspond to

;39987
D_minimap_offsets:                        ; $9C33 / 39987
                        ; $9C33 / 39987
        defw    levelmap
        defw    levelmap+24
        defw    levelmap+48
        defw    levelmap+2304
        defw    levelmap+2304+24
        defw    levelmap+2304+48
        defw    levelmap+4608
        defw    levelmap+4608+24
        defw    levelmap+4608+48
;9c45/40005
        ;The yx coordinates of those address?
        defb    0,0
        defb    0,24
        defb    0,48
        defb    24,0
        defb    24,24
        defb    24,48
        defb    48,0
        defb    48,24
        defb    48,48


start_minimap_render:                                    ; $9C57 / 40023 - Initialise minimap render state (screen ptr, coords) then scan 48x48 cells
.L9c57  ld      hl,16392
        ld      (SMC_39894+1),hl
        xor     a
        ld      (V_road_tile_attr),a
        ld      a,16
        ld      (V_road_tile_variant),a
        ld      a,(V_minimap_section)
        add     a,a
        ld      c,a
        ld      b,0

.L9c6d  ld      hl,D_minimap_offsets
        add     hl,bc
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      bc,17       ;Step onto the xy coordinats
        add     hl,bc
        ld      b,(hl)
        inc     hl
        ld      c,(hl)
        ld      (V_minimap_scan_xy),bc
        ld      a,b
        ld      (V_minimap_xy+1),a
        ex      de,hl
        ld      b,48

.L9c86  ld      de,(SMC_39894+1)
        push    de
        ld      a,(V_minimap_scan_xy)
        ld      (V_minimap_xy),a
        ld      c,48

.L9c93  ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L9c9f                ; (6)
        ld      a,(hl)
        cp      128
        call    nc,L655b

.L9c9f  ld      (V_map_render_ptr),hl
        exx     
        call    render_road_tile_traffic                   ;Mark traffic on the map
        ld      c,33                    ;White paper, blue ink
        call    set_tile_attribute                   ;Set attribute
        call    check_if_minimaps_should_be_displayed
        ld      hl,V_road_tile_attr
        ld      a,(hl)
        xor     1
        ld      (hl),a
        jr      nz,L9cbe                ; (7)
        ld      hl,(SMC_39894+1)
        inc     hl
        ld      (SMC_39894+1),hl

.L9cbe  ld      hl,(V_left_tile_index)
        inc     hl
        ld      (V_left_tile_index),hl
        ld      hl,V_minimap_xy
        inc     (hl)
        exx     
        inc     hl
        dec     c
        jr      nz,L9c93                ; (-59)
        pop     de
        ex      de,hl
        call    drow
        call    drow
        call    drow
        call    drow
        ld      (SMC_39894+1),hl
        ex      de,hl
        ld      de,48
        add     hl,de
        xor     a
        ld      (V_current_zone_width_to_print),a
        ld      a,(V_minimap_xy+1)
        inc     a
        ld      (V_minimap_xy+1),a
        push    hl
        push    bc
        call    twiddlekeys
        pop     bc
        pop     hl
        ret     nz
        djnz    L9c86                   ; (-115)
        ret     


; Attributes related to minimap?
D_minimap_attr_intensity:               ; $9CFA / 40186 - attribute intensity scale for minimap overlay (0..127, 8 levels)
        defb    $00, $49, $52, $5b, $64, $6d, $76, $7f

; Print the attribute intensity for a zone
; Eg: Pollution, traffic, Crime, pollution, police, fire
do_minimap_attr_intensity:
.L9d02  and     a
        ret     z
        ld      c,a
        ld      b,0
        ld      hl,D_minimap_attr_intensity
        add     hl,bc
        ld      c,(hl)
set_tile_attribute:                                    ; $9D0C / 40204 - Write attribute byte C to attr address derived from current SMC_39894+1 screen pointer
.L9d0c  ld      hl,(SMC_39894+1)
        ld      a,h
        rrca    
        rrca    
        rrca    
        and     3
        or      88
        ld      h,a
        ld      (hl),c
        ret     


set_road_tile_attributes:                                    ; $9D1A / 40218 - Write road tile attributes (from V_road_tile_attr) to 4 attribute rows at current screen position
.L9d1a  ld      d,15
        ld      b,160
        ld      c,80
        ld      a,(V_road_tile_attr)
        and     a
        jr      z,L9d2c                 ; (6)
        ld      d,240
        ld      b,10
        ld      c,5

.L9d2c  ld      hl,(SMC_39894+1)
        ld      a,(hl)
        and     d
        or      b
        ld      (hl),a
        inc     h
        ld      a,(hl)
        and     d
        or      c
        ld      (hl),a
        inc     h
        ld      a,(hl)
        and     d
        or      b
        ld      (hl),a
        inc     h
        ld      a,(hl)
        and     d
        or      c
        ld      (hl),a
        ret     

V_minimap_selection_index:  defb    $06     ; VAR $9D43 / 40259 - which minimap is selected


check_if_minimaps_should_be_displayed:      ; $9D44 / 40260
.L9d44
        ld      a,(V_minimap_selection_index)
        cp      0
        ret     z
        ld      a,1
        ld      (V_simulation_disabled),a
        ld      hl,(V_minimap_start)
        push    hl
        ld      hl,minimap_return
        push    hl
        ld      a,(V_minimap_selection_index)
        cp      1           ;Pollution
        jr      z,do_minimap_pollution                 ; (122)
        cp      2           ;Police
        jp      z,do_minimap_police
        cp      3           ;Fire
        jp      z,do_minimap_fire
        cp      4           ;Traffic
        jr      z,do_minimap_traffic                 ; (103)
        cp      5           ;Power
        jr      z,do_minimap_power                 ; (71)
        cp      6           ;Transport
        jr      z,do_minimap_transport                 ; (80)
                            ;Crime?
        jr      L9d7f                   ; (9)
minimap_return:
        pop     hl
        ld      (V_minimap_start),hl
        xor     a
        ld      (V_simulation_disabled),a
        ret     

; Think this one is crime...
.L9d7f  ld      hl,(V_map_render_ptr)
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      bc,(V_minimap_xy)
        call    manhattan_dist_to_centroid
        cp      32
        jr      c,L9d96                 ; (2)
        ld      a,31
.L9d96  ld      b,a
        ld      a,32
        sub     b
        jr      nc,L9d9d                ; (1)
        xor     a
.L9d9d  srl     a
        sub     15
        neg     
        ld      e,a
        ld      bc,(V_minimap_xy)
        call    get_police_minimap_value
        ld      d,a
        ld      a,e
        sub     d
        jr      nc,L9db1                ; (1)
        xor     a
.L9db1  srl     a
        call    do_minimap_attr_intensity
        ret     


.do_minimap_power  
        ld      bc,(V_minimap_xy)
        call    get_power_map_addr
        ld      a,(hl)
        and     e
        ret     z
        jp      set_road_tile_attributes

.do_minimap_transport                       ; $9DC4 / 40388
.L9dc4
        ld      hl,(V_map_render_ptr)
        ld      a,(hl)
        call    tile_to_flags
        and     6
        ret     z
        ld      a,5
        jp      set_road_tile_attributes


.do_minimap_traffic  
        ld      hl,minimaps+3456        ;46800
        jr      L9ddb                   ; (3)

.do_minimap_pollution  
        ld      hl,minimaps+1152
.L9ddb  ld      (V_minimap_start),hl
        ld      bc,(V_minimap_xy)
        call    minimap_xypos_50
        srl     a
        srl     a
        srl     a
        srl     a
        srl     a
        jp      do_minimap_attr_intensity

.do_minimap_fire  
        ld      hl,minimaps
        jr      L9dfa                   ; (3)

.do_minimap_police  
        ld      hl,minimaps+576
.L9dfa  ld      (V_minimap_start),hl
        ld      bc,(V_minimap_xy)
        call    minimap_xypos_25
        srl     a
        jp      do_minimap_attr_intensity

; Save?
;9e09
action_save:
        call    menu_enter_filename
        ld      bc,$100c
        ld      (V_input_xy),bc
        ld      hl,V_tapeheader            
        ld      (V_input_target_ptr),hl  ;destination for string
        call    input_string
        call    save_and_wait_for_keypress
        ld      hl,V_money
        ld      de,V_tape_money
        ld      bc,7
        ldir    
        ld      hl,SMC_cityname
        ld      de,D_43332
        ld      bc,12
        ldir    
        di      
        ld      ix,V_tapeheader
        ld      de,31
        ld      a,255
        scf     
        call    restart_rom
        ld      b,30
        call    pause5000
        ld      ix,levelmap
        ld      de,9216
        ld      a,255
        scf     
        call    restart_rom
        xor     a
        out     (254),a
        ei      
        ret     

action_load:
        call    menu_enter_filename
        ld      bc,$100C
        ld      (V_input_xy),bc
        ld      hl,V_load_filename
        ld      (V_input_target_ptr),hl
        call    input_string
        di      
        call    cls_white        ;why?!?!?
        call    cls_black
        call    prt_ctrl
        defb        T_BOX,0,0,32,24
        defb        T_SETXY,9,11
        defm        "SEARCHING"
        defb        T_END
L9e89:
        ld      ix,V_tapeheader
        ld      de,31   ;12 char filename, 7b money, 12b something else
        ld      a,255
        scf     
        call    load
        jr      nc,L9f0c                ; (116)
        call    print_tape_found_header
        ld      hl,V_load_filename
        ld      b,12

.L9ea0  ld      a,(hl)
        cp      32
        jr      nz,L9eaa                ; (5)
        inc     hl
        djnz    L9ea0                   ; (-8)
        jr      load_city_from_tape                   ; (20)

.L9eaa  ld      hl,V_tapeheader
        ld      ix,V_load_filename
        ld      b,12

.L9eb3  ld      a,(hl)
        cp      (ix+0)
        jr      nz,L9e89                ; (-48)
        inc     ix
        inc     hl
        djnz    L9eb3                   ; (-11)

load_city_from_tape:                                    ; $9EBE / 40638 - Print LOADING, call tape load routine; on success copy money/name into live vars and redraw
.L9ebe  call    prt_ctrl
        defb         T_SETXY,13,12
        defm        "LOADING"
        defb        T_END
        ld      ix,levelmap
        ld      de,9216
        ld      a,255
        scf     
        call    load
        jr      nc,L9efc                ; (33)
        ld      hl,V_tape_money
        ld      de,V_money
        ld      bc,7
        ldir    
        ld      hl,D_43332
        ld      de,SMC_cityname
        ld      bc,12
        ldir    
        ei      
        xor     a
        out     (254),a
        call    cls_white
        call    ingame_scrdraw
        ret     


.L9efc  ei      
        xor     a
        out     (254),a
        call    cls_white
        call    ingame_scrdraw
        call    menu_tape_loading_error
        jp      start_city

.L9f0c  ei      
        xor     a
        out     (254),a
        call    cls_white
        call    ingame_scrdraw
        call    menu_tape_loading_error
        ret     


print_tape_found_header:                                    ; $9F1A / 40730 - Print 'FOUND :- ' then the 12-char tape header name at textpos
.L9f1a  call    prt_ctrl
        defb        T_SETXY,11,9
        defm        "FOUND :- "
        defb        T_END

        ld      hl,V_tapeheader
        ld      b,12
.L9f2f  push    hl
        push    bc
        ld      a,(hl)
        cp      32
        call    nc,prchar
        call    incprpos
        pop     bc
        pop     hl
        inc     hl
        djnz    L9f2f                   ; (-16)
        ret     

.V_power_type_chosen        defb        0        ; VAR $9F40 / 40768 - which power station has been chosen

menu_power:                                 ; $9F41 / 40769
.L40769
        defb        8,0
        defm        "          SELECT TYP"
        defb        'E'+128
        defb        3
        defb        0,160,0,160,0,160,0,160
        defb        2
        defw        action_power_nuclear
        defm        "  NUCLEAR POWER STATION $500"
        defb        '0'+128
        defb        0,160
        defb        2
        defw        action_power_coal       ;202,159
        defm        "    COAL POWER STATION $300"
        defb        '0'+128
        defb        0,160,0,160,0,160
        defb        3
        defb        2
        defw        action_power_none
        defm        "             NON"
        defb        'E'+128
        defb        4

action_power_none:
        ld      a,0
        ld      (V_power_type_chosen),a
        ret 

action_power_nuclear:                       ; $9FC3 / 40899
.L9fc3
        ld      a,1
        ld      (V_power_type_chosen),a
        ret     
action_power_coal:                          ; $9FCA / 40906
.L9fca
        ld      a,2
        ld      (V_power_type_chosen),a
        ret


;9fd0
.menu_are_you_sure  
    call    print_routine
        defb        8,0
        defm        "         ARE YOU SURE "
        defb        '?'+128
        defb        3
        defb        0,160,0,160,0,160,0,160
        defb        2
        defw        clear_carry
        defm        "           NO THANK"
        defb        'S'+128
        defb        0,160
        defb        2
        defw        set_carry
        defm        "          YES  PLEAS"
        defb        'E'+128
        defb        4

clear_carry:
        or        a
        ret
set_carry:
        scf
        ret

.La02b
menu_system:                                ; $A02B / 41003
        defb        8,0
        defm        "            SYSTE"
        defb        'M'+128
        defb        3
        defb        2
        defw        menu_about
        defm        "ABOUT SIM CIT"
        defb        'Y'+128
        defb        2
        defw        action_start_new_city      ;a0b7
        defm        "START NEW CIT"
        defb        'Y'+128
        defb        2
        defw        use_old_landscape       ;220,165
        defm        "USE OLD LANDSCAP"
        defb        'E'+128
        defb        3
        defb        2
        defw        menu_load_city               ;243,161
        defm        "LOAD CIT"
        defb        'Y'+128
        defb        2
        defw        menu_save_city
        defm        "SAVE CIT"
        defb        'Y'+128
        defb        3
        defb        2
        defw        action_exit_simcity     ;177,160           ;a0b1
        defm        "EXIT SIMCIT"
        defb        'Y'+128
        defb        0,160,0,160
        defb        3
        defb        2
        defw        just_a_ret
        defm        "EXIT MEN"
        defb        'U'+128
        defb        4

action_exit_simcity:
        call    menu_are_you_sure
        ret     nc
        jr      action_start_new_city                   ; (0)

action_start_new_city:
.La0b7  call    menu_are_you_sure

.La0ba  ret     nc

        ld      hl,(V_random_seed)
        ld      (V_InitialSeed),hl

start_city:
.La0c1  call    menu_difficulty
        jp      create_landscape


menu_about:
La0c7:
        call    print_routine
        defb    8,0
        defm    "  SIMCITY THE CITY SIMULATO"
        defb    'R' + 128,0
        defm    "   (C) 1989  MAXIS SOFTWAR"
        defb    'E' + 128, 0
        defm    "  CONCEPT & DESIGN  W.Wrigh"
        defb    't' + 128, 3, 0
        defm    "  FOR  PROBE SOFTARE LIMITE"
        defb    'D'+128, 0
La140:
        defm    "SPECTRUM PROGRAMMING  A.R.Lil"
        defb    'l'+128, 0
La15f:
        defm    "SPECTRUM GRAPHICS A.Lill & J."
        defb    'L'+128, 3, 0
La17f:
        defm    "FOR MORE INFO :- INFOGRAME"
        defb    'S' + 128, 0
        defm    "   84 Rue du 1er Mars 1943"
        defb    ','+128, 0
La1b7:
        defm    "   69625 Villeurbanne Cedex"
        defb    ',' + 128, 0
        defm    "   France"
        defb    '.' + 128
        defb    3,2
        defw    just_a_ret
        defm    "              O"
        defb    'K' + 128
        defb    4


menu_load_city:         ;La1f3:
La1f3:
        call    print_routine
        defb    8,0
        defm    "         LOADING MEN"
        defb    'U'+128
        defb    3
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    2
        defw    action_load
        defm    "        LOAD FROM TAP"
        defb    'E' + 128
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    3
        defb    2
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4


; Save menu...
menu_save_city:
La247:
        call    print_routine
        defb    8,0
        defm    "          SAVING MEN"
        defb    'U' + 128
        defb    3
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    2
        defw    action_save ;9e09
        defm    "         SAVE TO TAP"
        defb    'E' + 128
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    3
        defb    2
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4

    

menu_enter_filename:                        ; $A29A / 41626
.La29a  call    print_routine
        defb    $0c, 00
        defm    "        TYPE FILE NAM"
        defb    'E' + 128
        defb    0
.La2b6
        defm    "       THEN PRESS ENTE"
        defb    'R' + 128
        defb    $00, $a0
        defb    $00
        defm    "FILENAME :"
        defb    ' ' + 128
        defb    4

.menu_tape_loading_error
;a2dc
        call    print_routine
        defb    $0e, $00
        defm    "      TAPE LOADING ERRO"
        defb    'R'+ 128
        defb    2
        defw    just_a_ret
        defb    $a0
        defb    4


save_and_wait_for_keypress:
.La2fe  call    print_start_tape_prompt
.La301  ld      a,127
.La303  in      a,($fe)
.La305  rra     
        ret     nc
.La307  jr      La301                  ; (-8)



print_start_tape_prompt:                                    ; $A309 / 41737 - Print 'START TAPE AND PRESS SPACE' prompt at current textpos
.La309  call    print_routine
        defb    $0e
        defb    0
        defm    "  START TAPE AND PRESS SPAC"
        defb    'E' + 128
        defb    4

;a32b
V_auto_bulldoze:    defb    1   ; VAR $A32B / 41771 - auto bulldoze
V_auto_budget:      defb    0   ; VAR $A32C / 41772 - auto budget
V_sound_enabled:    defb    1   ; VAR $A32D / 41773 - sound enabled
V_demolish_wait:    defb    1   ; VAR $A32E / 41774 - auto demolish wait


;a32f
menu_options:
        defb    $08
        defb    0
        defm    "            OPTION"
        defb    'S' + 128
        defb    $03, $01
        defw    V_auto_bulldoze    ;a32b
        defm    "AUTO-BULLDOZ"
        defb    'E' + 128
        defb    $00, $a0
        defb    $1
        defw    V_auto_budget    ;a32c
        defm    "AUTO-BUDGE"
        defb    'T'+128
        defb    $00, $a0
        defb    $01
        defw    V_sound_enabled    ;a32d
        defm    "SOUN"
        defb    'D' + 128
        defb    $00, $a0
        defb    $01
        defw    V_demolish_wait    ;a32e
        defm    "ZONE DEMOLISH WAI"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    menu_simulation_speed    ;a3ac
        defm    "SIMULATION SPEE"
        defb    'D' + 128
        defb    $00, $a0
        defb    $3
        defb    $2
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4

V_simulation_speed: defb    1   ; VAR $A3AB / 41899 - (41899/a3ab) - simulation speed

;a3ac
menu_simulation_speed:
        call    print_routine
        defb    $08, $00
        defm    "     SET SIMULATION SPEE"
        defb    'D' + 128
        defb    $03
        defb    $00, $a0
        defb    $02
        defw    action_speed_fast    ;a421
menu_t_fast:
La3d0:
        defm    "  FAS"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_normal    ;a428
menu_t_normal:
La3db:
        defm    "  NORMA"
        defb    'L' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_slow    ;a420
menu_t_slow:
La3e8:
        defm    "  SLO"
        defb    'W' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_paused    ;a436
menu_t_paused:
        defm    "  PAUSE"
        defb    'D' + 128
        defb    $00, $a0, $00, $a0
        defb    $03
        defb    $02
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    4

    ;a40d

set_speed:
.La40d  ld      (V_simulation_speed),a       ;Simulation speed
        ; Clear out any '*' marking previous setting
        ; and set the '*' next to the selected one
        ld      a,32
        ld      (menu_t_fast),a
.La415  ld      (menu_t_normal),a
        ld      (menu_t_slow),a
        ld      (menu_t_paused),a
        ld      (hl),'*'
        ret     

action_speed_fast:
La421:
        ld      a,0
        ld      hl,menu_t_fast        ;Points to fast
        jr      set_speed                   ; (-27)

action_speed_normal:
La428:
        ld      a,1
        ld      hl,menu_t_normal        ;Points to normal
        jr      set_speed                   ; (-34)

action_speed_slow:
La42f:
        ld      a,2
        ld      hl,menu_t_slow        ;Points to slow
        jr      set_speed                   ; (-41)

action_speed_paused:
La436:
        ld      a,3
        ld      hl,menu_t_paused        ;Points to paused
        jr      set_speed                   ; (-48)

;a43d

V_disaster_reset:   defb    0       ; VAR $A43D / 42045 - a43d/42045 - used when resetting disasters

;a43e
menu_disaster:
        defb    $08, $00
        defm    "           DISASTER"
        defb    'S' + 128
        defb    $03
        defb    $02
        defw    action_set_disaster    ;a4ba
La458:
        defm    "FIR"
        defb    'E' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "FLOO"
        defb    'D' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
La467:
        defm    "EARTHQUAK"
        defb    'E' + 128
        defb    $03
        defb    $02
        defw     action_set_disaster   ;a4ba
La475:
        defm    "AIR CRAS"
        defb    'H' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
La481:
        defm    "TORNAD"
        defb    'O' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "NUCLEAR MELTDOW"
        defb    'N' + 128
        defb    $03
        defb    $01
        defw    V_disaster_reset    ;a43d
        defm    "DISABLE AL"
        defb    'L' + 128
        defb    $00, $a0
        defb    $03
        defb    $02
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    $04


action_set_disaster:
;a4ba
        ld      a,(V_menu_selection)
.La4bd  inc     a
        ld      (V_disaster_option),a
        ret     

;a4c2
menu_windows:
        defb    $08, $00
        defm    "            WINDOW"
        defb    'S' + 128
        defb    $03
        defb    $02
        defw    action_set_show_maps    ;a512
        defm    "MAP"
        defb    'S' + 128
        defb    $00, $a0
        defb    $02
        defw    show_budget    ;9194
        defm    "BUDGE"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    show_evaluation    ;95b8
La4ef:
        defm    "EVALUATIO"
        defb    'N' + 128
        defb    $00, $a0, $00, $a0, $00, $a0, $00, $a0, $00, $a0
        defb    $03
        defb    $02
        defw    just_a_ret
        defm    "EXIT MEN"
        defb    'U' + 128
        defb    $04

;a511
V_show_mini_maps:   defb    0       ; VAR $A511 / 42257 - set to show mini maps

action_set_show_maps:                       ; $A512 / 42258
.La512
        ld      a,1
        ld      (V_show_mini_maps),a
        ret     

; A518
V_difficulty:   defb    0       ; VAR $A518 / 42264 - (42264) - difficulty level

menu_difficulty:
.La519  call    print_routine
menu_difficulty_text:                       ; $A51C / 42268
.L42268
        defb        8,0
        defm        "    SELECT DIFFICULTY LEVE"
        defb        'L'+128
        defb        3,0,160
        defb        2
        defw        action_difficulty
La53f:
        defm        "         1 - EAS"
        defb        'Y'+128
        defb        0,160
        defb        2
        defw        action_difficulty
La555:
        defm        "         2 - MEDIU"
        defb        'M'+128
        defb        0,160
        defb        2
        defw        action_difficulty
La56d:
        defm        "         3 - DIFFICUL"
        defb        'T'+128
        defb        0,160,0,160,0,160,0,160
        defb        3,2
        defw        action_input_city_name
; 42383
        defm        "      INPUT NEW CITY NAM"
        defb        'E'+128
        defb        4

.La5a9
action_difficulty:                          ; $A5A9 / 42409
        ld      a,(V_menu_selection)
        ld      (V_difficulty),a
        ret     


action_input_city_name:
.La5b0  ld      hl,$0501
.La5b3  ld      (V_input_xy),hl
        ld      hl,SMC_cityname
        ld      (V_input_target_ptr),hl
        ld      a,57
        ld      (SMC_42936+1),a
        ld      a,185
        ld      (SMC_42944+1),a
        call    input_string
        ld      a,71
        ld      (SMC_42936+1),a
        ld      a,199
        ld      (SMC_42944+1),a
        call    toggle_menu_row_highlight
        call    ingame_txt
        jp      run_menu


use_old_landscape:
La5dc:
        ld      hl,(V_InitialSeed)
        ld      (SMC_42523),hl
        call    print_routine
        defb        8,0
        defm        "       USE OLD LANDSCAP"
        defb        'E'+128
        defb        3,0
        defm        " CURRENT LANDSCAPE GENE "
;42521
        defb        6,0
SMC_42523:
        defb        0,0,0
        defb        0,160,3,0,160,0,160
        defb        2
        defw        input_new_gene      ;114,166        ;variable pickup?
        defm        "        INPUT NEW GEN"
        defb        'E'+128
        defb        0,160
        defb        2           ;a0c1
        defw        start_city
        defm        "  START CITY WITH THIS GEN"
        defb        'E'+128
        defb        0,160,0,160,0,160
        defb        3
        defb        2
        defw        just_a_ret
        defm        "EXIT MEN"
        defb        'U'+128
        defb        4

input_new_gene:
La672:
        ld      hl,$0b19
        ld      (V_input_xy),hl
        ld      hl,V_InitialSeed
        ld      (V_input_target_ptr),hl
        ld      hl,$0501
        ld      (V_input_isnumber),hl
        call    input_entry
        ld      d,1
        jr      nc,La68c                ; (1)
        dec     d

.La68c  push    de
        ld      hl,$0b19
        ld      (textxy),hl
        ld      hl,(V_InitialSeed)
        call    set_textpos_from_textxy
        call    toggle_menu_row_highlight
        pop     de
        ld      a,d
        ld      (V_menu_selection),a
        jp      L6950

text_generating_landscape:
        defb     $0d, $00
        defm    "       CREATING LANDSCAP"
        defb    'E' + 128
        defb    $00, $a0
        defb    $00
        defm    "          PLEASE WAI"
        defb    'T' + 128
        defb    4

V_input_xy:    defw    0       ; VAR $A6D8 / 42712 - coordinates for input
V_input_target_ptr:    defw    0       ; VAR $A6DA / 42714 - destination for input?

V_input_cursor_pos:    defb    0       ; VAR $A6DC / 42716 - current length of input?

;a6dd/42717
V_input_isnumber:   defb    0       ; VAR $A6DD / 42717 - we want a number
V_input_maxlen:     defb    0       ; VAR $A6DE / 42718 - maximum length of the string

V_input_buffer:            defs    18      ; VAR $A6DF / 42719 - input buffer


; Enter a percentage
.La6f1  ld      hl,$0301
        ld      (V_input_isnumber),hl
        jr      input_entry                   ; (6)

; Input string
input_string:
.La6f9  ld      hl,$0b00
        ld      (V_input_isnumber),hl      ;Set some flags for input

  
input_entry:
.La6ff  xor     a
        ld      (V_input_cursor_pos),a
.La703  ld      a,(V_input_isnumber)
        and     a
        call    nz,La7d4        ;If numeric clear the buffer
.La70a  call    rdkeys
        call    getkeyval
        jr      c,La757                 ; (69)
        cp      8
        jp      z,La836
        ld      b,a
        ld      hl,(42735)
        ld      a,h
        or      l
        jr      z,La725                 ; (6)
        dec     hl
        ld      (42735),hl
        jr      input_set_zero_and_redraw                   ; (56)

.La725  ld      hl,La762
        push    hl
        ld      a,(keystore)
        and     1       ;'SHIFT'
        jr      nz,La742                ; (18)
        ld      hl,V_input_cursor_pos
        ld      a,b
        cp      56
        jr      z,La799                 ; (97)
        ld      a,b
        cp      53
        jr      z,input_cursor_left                 ; (86)
        ld      a,b
        cp      48
        jr      z,La77d                 ; (59)

.La742  ld      a,(V_input_isnumber)
        and     a
        jr      z,La751                 ; (9)
        ld      a,b
        cp      48
        jr      c,La756                 ; (9)
        cp      58
        jr      nc,La756                ; (5)

.La751  ld      a,b
        cp      32
        jr      nc,La76d                ; (23)

.La756  pop     hl

.La757  ld      hl,0
        ld      (42735),hl

input_set_zero_and_redraw:                                    ; $A75D / 42845 - Set input value to 0, store in buffer, redraw input field; used for budget input reset
.La75d  call    redraw_input_field
        jr      La70a                   ; (-88)
.La762  ld      hl,1000
        ld      (42735),hl
        call    redraw_input_field
        jr      La70a                   ; (-99)

.La76d  ld      a,(V_input_cursor_pos)
        ld      e,a
        ld      d,0
        ld      hl,(V_input_target_ptr)
        add     hl,de
        ld      (hl),b
        ld      hl,V_input_cursor_pos
        jr      La799                   ; (28)

.La77d  call    input_clear_cursor_char
        ld      hl,V_input_cursor_pos
        call    input_cursor_left

input_clear_cursor_char:                                    ; $A786 / 42886 - Write space to V_input_buffer[V_input_cursor_pos] (erase char at cursor position)
.La786  ld      a,(V_input_cursor_pos)
        ld      e,a
        ld      d,0
        ld      hl,(V_input_target_ptr)
        add     hl,de
        ld      (hl),32
        ret     


input_cursor_left:                                    ; $A793 / 42899 - Decrement input cursor position (HL points to counter); stops at 0
.La793  ld      a,(hl)
        sub     1
        ret     c
        ld      (hl),a
        ret     


.La799  ld      a,(V_input_maxlen)
        ld      c,a
        ld      a,(hl)
        inc     a
        cp      c
        ret     z
        ld      (hl),a
        ret     


redraw_input_field:                                    ; $A7A3 / 42915 - Redraw the numeric input field at V_input_xy, highlighting cursor with inverse colour
.La7a3  ld      bc,(V_input_xy)
        call    xypos
        ld      (textpos),hl
        ld      hl,(V_input_target_ptr)
        ld      a,(V_input_maxlen)
        ld      b,a
        ld      c,0

.La7b6  push    bc
        push    hl
SMC_42936:
        ld      e,71                ;SMC - 42937
        ld      a,(V_input_cursor_pos)
        cp      c
        jr      nz,La7c2                ; (2)
SMC_42944:
        ld      e,199               ;SMC - 42945

.La7c2  ld      a,e
        ld      (textcol),a
        ld      a,(hl)
        call    prchar
        call    incprpos
        pop     hl
        pop     bc
        inc     hl
        inc     c
        djnz    La7b6                   ; (-29)
        ret     


.La7d4  ld      hl,V_input_buffer
        ld      de,V_input_buffer+1
        ld      bc,11
        ld      (hl),32
        ldir    
        call    input_value_to_digits
        ld      hl,V_input_buffer
        ld      (V_input_target_ptr),hl
        ret     

V_input_target_saved:    defw    0       ; VAR $A7EB / 42987 -

input_value_to_digits:                                    ; $A7ED / 42989 - Convert 16-bit value at V_input_target_ptr pointer to 5 decimal ASCII digits in V_input_buffer
.La7ed  ld      hl,(V_input_target_ptr)
        ld      (V_input_target_saved),hl
        ld      iy,V_input_buffer
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(V_input_maxlen)
        ld      c,a
        ld      b,5
        ld      de,-10000
        call    extract_decimal_digit
        ld      de,-1000
        call    extract_decimal_digit
        ld      de,-100
        call    extract_decimal_digit
        ld      de,-10
        call    extract_decimal_digit
        ld      a,l
        call    store_digit_and_advance
        ret     


extract_decimal_digit:                                    ; $A81E / 43038 - Extract one decimal digit from HL using DE (power of 10); store as ASCII in (IY+)
.La81e  ld      a,c
        cp      b
        jr      c,La834                 ; (18)
        xor     a
.La823  inc     a
        add     hl,de
        jr      c,La823                 ; (-4)
        sbc     hl,de
        dec     a
store_digit_and_advance:                                    ; $A82A / 43050 - Convert A to ASCII digit, store in V_digit_char_buf and (IY+), advance IY; tail of extract_decimal_digit
.La82a  add     a,48
        ld      (V_digit_char_buf),a
        ld      (iy+0),a
        inc     iy
.La834  dec     b
        ret     


.La836  ld      a,(V_input_isnumber)
        and     a
        scf     
        ret     z
        call    input_buffer_to_hl
        ret     c
        ex      de,hl
        ld      hl,(V_input_target_saved)
        ld      (hl),e
        inc     hl
        ld      (hl),d
        or      a
        ret     


; Checks if the value in e is a number
; Entry: e = character
; Exit:  nc = number
;         c = not number
isnumber:
.La849  ld      a,e
        cp      58
        ccf     
        ret     c
        cp      48
        ret     c
        sub     48
        ret     


input_buffer_to_hl:                                    ; $A854 / 43092 - Convert V_input_buffer ASCII digit string to binary number in HL; return NC on success
.La854  ld      iy,V_input_buffer
        ld      hl,0
.La85b  xor     a
        add     hl,hl
        rla     
        ld      d,h
        ld      e,l
        add     hl,hl
        rla     
        add     hl,hl
        rla     
        add     hl,de
        rla     
        and     a
        jr      nz,La882                ; (25)
        ld      e,(iy+0)
        call    isnumber
        ccf     
        ret     nc
        ld      e,a
        ld      d,0
        add     hl,de
        ret     c
        inc     iy
        ld      e,(iy+0)
        call    isnumber
        ccf     
        ret     nc
        jr      La85b                   ; (-39)

.La882  scf     
        ret     



; Some 2x2 graphics here, stored by line - masked - transport characters?
;43140
transport_sprites:
        BINARY      "assets/transport.spr"
  

V_load_filename:    defs    12,32          ; VAR $A924 / 43300 - filename we want to load

; Tape header buffer for loading/saving
; 
; 12 bytes filename
;
;
; 12 bytes city name at D_43332
V_tapeheader:                                        ; VAR $A930 / 43312
        defs    12             ;VAR 43312/a930
V_tape_money:    defs    8               ; VAR $A93C / 43324
   

D_43332:    defm        "HERESVILLE  "          ; $A944 / 43332 - default city name


; End of tape header

; La950      
; At $a94e
; Coverage/density minimaps, 6912 bytes.  Cell (x,y) of the 96x96 level map lives at
; (y/N)*W + x/N, N = 4 for the 24x24 maps and 2 for the 48x48 ones:
;   +0     fire coverage      24x24  (   576)  0..15
;   +576   police coverage    24x24  (   576)  0..15
;   +1152  pollution          48x48  (  2304)  decays every other tick
;   +3456  traffic density    48x48  (  2304)  +20 per trip, decays every tick
;   +5760  power              1 bit per tile, 12 bytes per row (1152)
; (get_land_value_minimap_value is a misnomer: it addresses the pollution map)
minimaps:                                   ; $A950 / 43344
.La950
        defs        6912
;
; level- 9216 filled with 0x02
; At 50256
.levelmap
        defs        9216,2

; The UDGs for the images
; data of some description?
; at 59472
        BINARY        "assets/udgs.bin"


V_tickcount:        defb    0       ; VAR $F704 / 63236 - tickcount for taskswap
;f705
V_simulation_disabled: defb    1     ; VAR $F705 / 63237 - simulation enabled
                
                defb    0       ;Unused

V_task0_stack:  defw    0       ; VAR $F707 / 63239 - task 0 stack (ui)
V_task1_stack:  defw    0       ; VAR $F709 / 63241 - task 1 stack (simulator)

;f70b
.interrupt
        push    ix
        push    iy
        push    hl
        push    de
        push    bc
        push    af
        ex      af,af'
        exx     
        push    hl
        push    de
        push    bc
        push    af
        call    rdkeys
        ld      a,(V_simulation_disabled)
        and     a
        jr      nz,Lf73e                ; (28)
        ld      hl,V_tickcount
        ld      a,(hl)
        and     a
        jr      z,Lf733                 ; (10)
        ld      (V_task1_stack),sp
        ld      sp,(V_task0_stack)
        jr      task_switcher_toggle                   ; (8)

.Lf733  ld      (V_task0_stack),sp
        ld      sp,(V_task1_stack)

task_switcher_toggle:                                    ; $F73B / 63291 - Toggle task flag (XOR 1), restore all registers and return to switched-to task
.Lf73b  xor     1
        ld      (hl),a

.Lf73e  pop     af
        pop     bc
        pop     de
        pop     hl
        ex      af,af'
        exx     
        pop     af
        pop     bc
        pop     de
        pop     hl
        pop     iy
        pop     ix
        ei      
        ret     


; Vars for print routne
.V_digit_char_buf        defb        0       ; VAR $F74E / 63310 -
.textpos        defw        0        ;VAR - f74f text print address
.textxy                defw        0        ;VAR - text xy posn
.textcol        defb        0        ;VAR - text colour

; Print to screen at address specified by (textpos)
; And colour textcol
; Uses ROM plot routine

prchar:
Lf754:
        ld      l,a
        ld      h,0
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      bc,15360
        add     hl,bc
        ex      de,hl
        ld      hl,(textpos)
        ld      b,8

.Lf764  ld      a,(de)
        ld      c,a
        srl     c
        or      c
        ld      (hl),a
        inc     de
        inc     h
        djnz    Lf764                   ; (-10)

.dotextcol  
        ld      a,(textcol)
        cp      255
        ret     z
.dotextcol_1  
        ld      c,a
        dec     h
        ld      a,h
        rrca    
        rrca    
        rrca    
        and     3
        or      88
        ld      h,a
        ld      (hl),c
        ret     

; Reads keyboard ports and dumps results
; at keystore

.rdkeys  
        ld      hl,keystore
        ld      bc,65278
        ld      d,8
.Lf789  in      a,(c)
        ld      (hl),a
        inc     l
        rlc     b
        dec     d
        jr      nz,Lf789                ; (-9)
        call    kempston_to_keystore
        jp      cursor_keys_sym_shift
        ret     

        jp      $fe0f
        jp      $fe0f

; Load tape file

.load  
        inc     d
        ex      af,af'
        dec     d
        ld      a,15
        out     (254),a
        call    zx_rom_tape_load
        ret     


restart_rom:                                    ; $F7AA / 63402 - Jump to ROM address $04C6 (warm restart / error handler entry)
.Lf7aa  jp      $04c6

; Pause 5000

.pause5000  
        push    bc
        ld      bc,5000
.Lf7b1  dec     bc
        ld      a,b
        or      c
        jp      nz,Lf7b1
        pop     bc
        djnz    pause5000                   ; (-13)
        ret     

