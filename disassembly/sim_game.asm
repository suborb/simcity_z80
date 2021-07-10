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

V_kempston:   defb    1       ;VAR 23423 - kempston enabled or not

read_kempston:
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

.V_23474        defb        0        ;VAR - holds key pressed value

; Munch up the previously read keys and make something
; meaningful out of them
; It seems that V_23474 will hold the key status...

.munchkeys  
        ld      hl,keystore
        ld      bc,2304
        ld      d,254
L5bbb:  ld      a,(hl)
        cpl     
        and     31
        and     d
        jr      nz,L5bd2                ; (16)
        ld      d,255
        ld      a,c
        add     a,5
        ld      c,a
        inc     hl
        djnz    L5bbb                   ; (-16)
        ld      a,255
        ld      (V_23474),a
        scf     
        ret     
.L5bd2  rrca    
        jr      nc,L5bdb                ; (6)
        ld      a,c
        ld      (V_23474),a
.L5bd9  or      a
        ret     
.L5bdb  inc     c
        jr      L5bd2                   ; (-12)
        nop     

; Return the key just pressed
; Returns an ASCII code - I'm sure this code is just generic z80 with 
; Machine specific bits tagged on here and there!
; Entry: none
; Exit:  a = ASCII key just pressed
;         c set if no key/nc if key

.getkeyval  
        call    munchkeys
        ret     c
        ld      a,(V_23474)
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

V_random_seed: defw        0        ;VAR 23748 - random seed

; Random number generator?
get_random_number:
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

.D_23788        defb        0,120,112,120,92,8,0,0
.D_23796        defb        7,3,7,3,1,35,247,255

.V_pointerxy        defw        $0135        ;VAR 23804 - pointer xypos

; Print the pointer

.prpointer
        ld        bc,(V_pointerxy)
        srl        b
        srl        b
        srl        b
        srl        c
        call    xypos
        ld      (V_23868),hl
        ld      ix,V_23860
        ld      iy,D_23796
        ld      de,D_23788
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

.V_23860        defs        8        ;VAR - used to hold what was under pointer
.V_23868        defw        0        ;VAR - old pointer posn

.blankpointer  
        ld      hl,(V_23868)
        ld      de,V_23860
        ld      b,8
.L5d46  ld      a,(de)
        ld      (hl),a
        inc     de
        call    drow
        djnz    L5d46                   ; (-8)
        ret     

.V_23887        defw        $0101        ;VAR 23887 - zone size related
.V_23889        defw        0        ;VAR - unknown
.V_23891        defw        0        ;VAR - unknown

; Some pointer control routine

.L5d55  xor     a
        ld      (V_23891),a
        ld      (V_23891+1),a
        ld      bc,(V_pointerxy)
        ld      a,b
        cp      64
        ret     c
        ld      (V_23891),a
        ld      a,b
        sub     64
        srl     a
        srl     a
        srl     a
        ld      b,a
        ld      a,c
        srl     a
        ld      c,a
        ld      (V_23889),bc
        ld      a,b
        add     a,8
        ld      b,a
        ld      hl,(V_23887)
        ld      a,b
        add     a,h
        cp      25
        ret     nc
        ld      a,c
        add     a,l
        cp      33
        ret     nc
        ld      a,1
        ld      (V_23891+1),a
.L5d8f  call    xypos
        ld      bc,(V_23887)
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
        call    L5e66        ;
        ret     

.prdigit 
        xor     a
.L5e5f  inc     a
        add     hl,de
        jr      c,L5e5f                 ; (-4)
        sbc     hl,de
        dec     a
.L5e66  add     a,48
        ld      (63310),a
        push    hl
        call    replace_with_direct_prchar_call
        ld      hl,(textpos)
        inc     hl
        ld      (textpos),hl
        pop     hl
        ret     


endctrl:
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

.V_24213        defw        0                ;VAR - holds textxy


.L5e97  ld      b,(hl)
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (textxy),bc
        ld      (V_24213),de
        ld      a,(textxy)
        ld      (SMC_24334+1),a
        ld      a,56
        ld      b,57
        ld      c,58
        call    L5ed3
        ld      a,(V_24213+1)
        sub     2
        ld      b,a

.L5ebb  push    bc
        ld      a,63
        ld      b,32
        ld      c,59
        call    L5ed3
        pop     bc
        djnz    L5ebb                   ; (-13)
        ld      a,62
        ld      b,61
        ld      c,60
        call    L5ed3
        ret     

.L24274
        defb        $01
        defb        $32
        defb        $e9
.L5ed3
        ld      e,(hl)
        ld      a,b
        ld      (SMC_24312+1),a
        ld      a,c
        ld      (SMC_24326+1),a
        ld      bc,(textxy)
        call    xypos
        ld      (textpos),hl
        ld      a,64
        call    prudg
        ld      a,(V_24213)
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
        call    L6d90
        call    L6305
        call    print_date
        call    print_money
        ret     

.ingame_txt  
        call    prt_ctrl
        defb        T_SETCOL,57
        defb        T_SETXY,5,1
SMC_cityname:
.D_24424                ;VAR        (12) - townname
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
print_date:
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
        defm    "FIRE STATION $10"
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
.L60c2
        defm    "MORE RESIDENTIAL ZONES NEEDE"      ;24
        defb    'D' + 128
        defm    "MORE COMMERCIAL ZONES NEEDE"
        defb    'D' + 128
        defm    "MORE INDUSTRIAL ZONES NEEDE"       ;26
        defb    'D' + 128
.L6117
        defm    "NEED BIGGER ROAD NETWOR"           ;28
        defb    'K' + 128
        defm    "NEED LARGER RAIL SYSTE"            ;30
        defb    'M' + 128
        defm    "NEED A POWER PLAN"                 ;32
        defb    'T' + 128
.L6158
        defm    "THE PEOPLE WANT A STADIU"          ;34
        defb    'M'+128
        defm    "INDUSTRY NEEDS A SEA POR"           ;36
        defb    'T' + 128
        defm    "COMMERCE NEEDS AN AIRPOR"
        defb    'T' + 128
        defm    "PEOPLE DEMAND FIRE DEP"
        defb    'T' + 128
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
.L6248
        defm    "BROWNOUT DETECTE"
        defb    'D' + 128
        defm    "NUCLEAR MELTDOW"
        defb    'N' + 128
        defm    "TOO MUCH POLLUTIO"
        defb    'N' + 128
        defm    "CRIME TOO HIG"
        defb    'H' + 128
        defm    "TRAFFIC JAMES ARE BA"
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

; $6305
L6305:
        ld      hl,text_table  ;table above
        ld      a,(V_27984)
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

V_pointer_charxy:   defw        0   ;VAR 25545/63c9 - pointer coords reduced to chars
        nop     
        nop     

.L63cd  ld      a,(keystore+7)
        and     1       ;'SPACE'
        ret     nz

        ld      bc,(V_pointerxy)
        srl     b
        srl     b
        srl     b
        srl     c
        ld      (V_pointer_charxy),bc
        call    L6d51                   ;See if an icon is selected?
        ld      a,1
        ld      (V_simulation_disabled),a
        call    do_view_change
        call    handle_menus
        call    L7012
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
        call    L640e
        jr      wait_for_space_key_release                   ; (-21)

.L640e  ld      a,(V_pointerxy)
        ld      ix,menu_system
        cp      14
        jp      c,L66f2
        ld      ix,menu_options
        cp      30
        jp      c,L66f2
        ld      ix,menu_disaster
        cp      48
        jp      c,L66f2
        ld      ix,menu_windows     ;42178
        jp      L66f2

V_25651:    defb    0       ;VAR 256511/6433

.L6434  ld      a,(V_36767)
        and     16
        ld      (V_25651),a
        ld      a,(V_36767)
        and     15
        add     a,8
        ld      b,a
        ld      c,0
        call    xypos
        ld      (SMC_print_tile_hl+1),hl
        ld      bc,(V_25863)
        ld      a,(V_36767)      
        and     15
        add     a,b
        ld      b,a
        call    levelmap_xypos
        ld      de,64
        ld      b,1
        jp      L651d

V_current_tile:        defb        $37,$00                ;VAR 6462/25698 - current tile being printed

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
        ld      a,(V_36767)
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
        ld      hl,(V_25865)
        call    L7635           ;Get coords of address
        call    get_traffic_density_value
        ld      a,(hl)
        pop     bc
        pop     de
        pop     hl
        cp      220
        jr      nc,L64d3                ; (10)
        cp      150
        ret     c
        ld      a,(V_25651)
        and     a
        jr      z,L64d3                 ; (1)
        inc     b
.L64d3  ld      l,b
        ret     

        nop     

.L64d6  ld      hl,V_current_zone_width_to_print
        dec     (hl)
        ld      a,(ix+0)
        ld      ix,25813
        ld      hl,V_36767
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

V_tile_colour_offset:   defw    0       ;6505/25861 offset to colour for tiles

;6507
.V_25863        defb    $1e, $25        ;VAR  6507/25863 coordinates of top left of view

;6509
V_25865:    defw    0       ;VAR 25865/6509
        
; draw level on screen?
.draw_map
.L650b  ld      hl,18432
        ld      (SMC_print_tile_hl+1),hl          ;SMC code nobbling
        ld      bc,(V_25863)          ;Coordinates for mapview top left corner
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
.L652b  ld      (V_25865),hl              ;Holds the map pointer?
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

V_current_zone_width_to_print:  defb    0   ;VAR 6558/25944 - how much of the current zone width to print
V_left_tile_index:    defw    0   ;VAR 6559/25945 - index for furthest left tile of the zone


; Called when printing tiles >= 128
; Entry hl = map position
.L655b  push    hl
        pop     ix          ;ix = position on map
        xor     a
        ld      (V_26002),a
        exx     
        ld      a,(ix+0)
        cp      192
        call    nc,find_left_edge_of_zone
            ;ix = map coordinate of furthest left column of zone
        ld      a,(V_26002)
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

V_26002:    defb    0       ;VAR 26002 - how far the current x coordiante is in the zone

; Steps back in X to find the start of a special zone
find_left_edge_of_zone:
.L6593  ld      hl,V_26002
.L6596  ld      a,(ix+0)
        and     192
        cp      192
        ret     nz
        inc     (hl)
        dec     ix
        jr      L6596                   ; (-13)

V_26019:    defw    0           ;VAR 26019/65a3 - holds xy coords temporarily?


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
        ld      (V_26189),a
        ld      (V_26189+1),a
        call    prneg24
        push    hl
        push    bc
        exx     
        pop     bc
        pop     hl
        ld      b,240                ;-1000000
        ld      de,48576
        exx     
        call    L664f
        exx     
        ld      b,254                ;-100000
        ld      de,31072
        exx     
        call    L664f
        exx     
        ld      b,255                ;-10000
        ld      de,55536
        exx     
        call    L664f
        exx     
        ld      b,255                ;-1000
        ld      de,64536
        exx     
        call    L664f
        exx     
        ld      b,255                ;-100
        ld      de,65436
        exx     
        call    L664f
        exx     
        ld      b,255                ;-10
        ld      de,65526
        exx     
        call    L664f
        exx     
        push    hl
        exx     
        pop     hl
        ld      b,l
        call    L666f
        ld      hl,(textpos)
        ld      (V_26019),hl
        ld      a,(V_26189+1)
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

V_26189:        defw        0       ;VAR 26189/664d


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
        ld      a,(V_26189)
        and     a
        jr      nz,L666f                ; (7)
        ld      a,b
        and     a
        jr      z,L667b                 ; (15)
        ld      (V_26189),a

.L666f  ld      a,b
        add     a,48
        ld      (63310),a
        call    prchar
        jp      incprpos

.L667b  ld      hl,V_26189+1
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


.L66f2  call    cls_print_topbox
        call    L67c3
        call    L6944
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
        call    L67c3
        jp      L6944

.L6719  call    cls_black
        call    prt_ctrl
        defb        T_SETCOL,71
        defb        T_BOX,0,0,32,24
        defb        T_END
        call        L67c3
        call        L6944
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
V_26439:    defw    0       ;VAR 26439
V_26441:    defb    0       ;VAR 26441


; Zeros...
V_26442:
        defb        $0C, $3C, $A5, $0E, $52, $A5
        defb        $10, $6A, $A5, $16, $8C, $A5, $FF

        defs        107       ;What's up here? - Selection table? LOOK!

V_26562:    defb    0       ;VAR 26562

.L67c3  ld      iy,V_26442
        ld      (V_26439),ix
        xor     a
        ld      (V_26562),a
        ld      a,(ix+0)
        ld      (V_26441),a
        inc     ix

.L67d7  ld      hl,V_26441
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
        jr      z,L6826                 ; (47)
        cp      8
        jr      z,L67fc                 ; (1)
        ret     


.L67fc  call    L6806
        jr      L6826                   ; (37)

.L6801  ld      (iy+0),255
        ret     


.L6806  ld      a,(V_26441)
        ld      (iy+0),a
        push    ix
        pop     hl
        ld      (iy+1),l
        ld      (iy+2),h
        ld      de,3
        add     iy,de
        ld      hl,V_26562
        inc     (hl)
        ret     


.L681f  call    L6806
        inc     ix
        inc     ix

.L6826  inc     ix
        call    L6882
        inc     ix
        jr      L67d7                   ; (-88)

.L682f  inc     ix
        ld      a,(V_26441)
        ld      b,a
        ld      c,0
        ld      (textxy),bc
        ld      a,32
        ld      (V_24213),a
        ld      a,64
        ld      b,65
        ld      c,66
        call    L5ed3
        jr      L67d7                   ; (-116)

V_26699:    defb    0   ;VAR 26699/684b

.L684c  call    L6806
        inc     ix
        ld      l,(ix+0)
        ld      h,(ix+1)
        ld      a,(hl)
        ld      (V_26699),a
        inc     ix
        inc     ix
        call    L6882
        call    L6922
        ld      a,(V_26699)
        and     a
        jr      z,L6876                 ; (11)
        call    prt_ctrl
        defm        "ON"
        defb        T_END
        inc        ix
        jp      L67d7

.L6876  call    prt_ctrl
        defm        "OFF"
        defb        T_END
        inc     ix
        jp      L67d7

.L6882  ld      a,(V_26441)
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

.L68b7  call    L6922
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
        jr      L688e                   ; (-119)

.L6905  ld      b,a
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,26490
        add     hl,bc
        ret     


.L6910  ld      a,(V_26441)
        call    L6905
        ld      a,(textxy)
        ld      (hl),a
        push    ix
        pop     de
        inc     hl
        ld      (hl),e
        inc     hl
        ld      (hl),d
        ret     


.L6922  ld      a,(V_26441)
        ld      b,a
        ld      c,24
        ld      (textxy),bc
        call    xypos
        ld      (textpos),hl
        ret     


.L6933  ld      c,1
        call    cxytoattr
        ld      b,30
.L693a  ld      a,(hl)
        xor     70
        ld      (hl),a
        inc     l
        djnz    L693a                   ; (-7)
        ret     

.V_26496        defw        0                ;VAR - sommat with printing address

.L6944  ld      a,(V_26562)
        and     a
        ret     z
        xor     a
        ld      (V_menu_selection),a
        call    L6a2a
.L6950  call    L6a60
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
        call    L6a7e
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


V_27024:    defb    0       ;VAR 27024/6990     max options/row
V_27025:    defw    0       ;VAR 27025/6991

V_27027: defw        0       ;VAR 27027/6993 - xy coordinates for menu?

V_27029:    defb    0       ;VAR 27029/6995

.L6996  ld      a,10
        ld      (V_27029),a
        call    L6a60
        call    L6a7e
        ld      a,(hl)
        ld      (V_27027+1),a
        call    L6905
        ld      a,(hl)
        ld      (V_27027),a
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        inc     hl
        inc     hl
        ld      (V_27025),hl
        inc     hl
        ld      a,(hl)
        ld      (V_27024),a
        ld      a,69
        ld      (textcol),a

.L69c0  call    L6a31
        call    L6a16
        ld      a,(keystore+7)
        and     1           ;'SPACE'
        jr      z,L6a04                 ; (55)
        ld      a,(keystore+2)
        and     1           ;'Q'
        call    z,L69ec
        ld      a,(keystore+1)
        and     1           ;'A'
        call    z,L69fa
        call    L6a2a
        ld      a,(V_27029)
        and     a
        jr      z,L69c0                 ; (-38)
        ld      b,a

.L69e7  halt    
        djnz    L69e7                   ; (-3)
        jr      L69c0                   ; (-44)

; Move down the menu list?
.L69ec  ld      a,(V_27024)
        inc     a
        ld      c,a
        ld      hl,(V_27025)
        ld      a,(hl)
        inc     a
        cp      c
        ret     z
        ld      (hl),a
        ret     

; Move up the menu list?
.L69fa  ld      hl,(V_27025)
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
        call    L6a16
        jp      L6950

.L6a16  ld      bc,(V_27027)
        call    xypos
        ld      (textpos),hl
        ld      hl,(V_27025)
        ld      l,(hl)
        ld      h,0
        call    prhund
        ret     


.L6a2a  ld      hl,(V_26496)
        ld      a,h
        or      l
        ret     z
        jp      (hl)

.L6a31  call    twiddlekeys
        jr      z,L6a3e                 ; (8)
        ld      hl,V_27029
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ret     


.L6a3e  ld      a,10
        ld      (V_27029),a
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
        call    L6a60
        ld      (hl),a
.L6a60  push    hl
        push    af
        call    L6a7e
        ld      b,(hl)
        call    L6933
        pop     af
        pop     hl
        ret     

menu_down:
.L6a6c  ld      a,(V_26562)
        ld      b,a
        ld      hl,V_menu_selection
        ld      a,(hl)
        inc     a
        cp      b
        ret     z
        call    L6a60
        ld      (hl),a
        jr      L6a60                   ; (-29)


V_menu_selection:    defb        0   ;VAR 6a7d/27261 - Current menu selection

.L6a7e  ld      a,(V_menu_selection)
        ld      b,a
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,V_26442
        add     hl,bc
        ret     

V_InitialSeed:   defw    3       ;VAR 6a8c/27276 - initial random seed
 
create_landscape:
.L6a8e  call    initialise_simulation_variables
        ld      hl,levelmap
        ld      de,levelmap+1
        ld      bc,9215
        ld      (hl),0
        ldir    
        ld      ix,text_generating_landscape
        call    cls_map
        call    cls_print_topbox
        call    L67c3
        ld      hl,(V_InitialSeed)
        ld      (V_random_seed),hl
        xor     a
        ld      (V_27654),a
        ld      bc,32770
        ld      e,7
        call    L6adb
        ld      a,2
        ld      (V_27653),a
        call    L6ba5           ;Generate part f the map
        ld      a,2
        ld      (V_27654),a
        ld      bc,$2006
        ld      e,3
        call    L6adb
        ret     

D_27347:
        defb    $04, $04, $05, $03, $03, $05, $04, $04



.L6adb  ld      a,c
        ld      (V_27653),a
        ld      a,e
        ld      (SMC_27367+1),a

.L6ae3  push    bc
        call    get_random_number
SMC_27367:
        and     7
        cp      2
        jr      nc,L6aef                ; (2)
        ld      a,2

.L6aef  ld      (V_27652),a
        call    get_random_number
        and     63
        add     a,16
        ld      (V_27650),a
        call    get_random_number
        and     63
        add     a,16
        ld      (V_27650+1),a
        call    get_random_number
        and     3
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,D_27347
        add     hl,bc
        ld      de,V_27655
        ldi     
        ldi     
        call    L6c09
        pop     bc
        djnz    L6ae3                   ; (-61)
        ret     


; 6b21/27425

; Split into two tables:
; 65 bytes - what dirt surrounds
; 65 bytes - get converted into this character
D_27425:
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


; Part of the map generation routine?

.L6ba5  ld      b,96
.L6ba7  ld      c,96
.L6ba9  push    bc
        push    bc
        call    levelmap_xypos_with_check   ;OPT: might as well skip check
        pop     bc
        ld      a,(hl)
        and     a
        jr      nz,L6bd3                ; (32)
        call    L6c84                   ; Check for a dirt surround
        ld      a,d
        and     a
        jr      z,L6bd3                 ; Dirt does not surround this square
        push    bc
        ld      hl,D_27425
        ld      bc,66
        cpir    
        pop     bc
        jr      nz,L6bd3                ; (13)
        ld      de,65
        add     hl,de
        ld      e,(hl)
        call    levelmap_xypos_with_check    ;OPT: might as well skip check
        ld      a,(hl)
        and     a
        jr      nz,L6bd3                ; (1)
        ld      (hl),e
.L6bd3  pop     bc
        dec     c
        jr      nz,L6ba9                ; (-46)
        djnz    L6ba7                   ; (-50)
        ret     

V_27610:   defb        0   ; 6dda/27610 - ?? unused?

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
levelmap_xypos:
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
        ld      (V_27610),a
        ret


V_27650:        defw    0           ;VAR 6c02/2760
V_27652:        defb    $05         ;VAR 6c04/27652
V_27653:        defb    $02         ;VAR 6c05/27653
V_27654:        defb    $00         ;VAR 6c06/27654
V_27655:        defw    $0404       ;VAR 6c07/27655 (ldi into here)



.L6c09  ld      a,(V_27652)
        ld      h,a
        ld      l,0
        ld      (SMC_27676+1),hl
        ld      h,l
        ld      (SMC_27673+1),hl
        ld      b,49

.L6c18  push    bc
SMC_27673:
        ld      hl,0            ;SMC 27674
SMC_27676:
        ld      de,0            ;SMC 27677
        ld      b,d
        ld      c,e
        ld      a,(V_27655)

.L6c24  sra     b
        rr      c
        dec     a
        jr      nz,L6c24                ; (-7)
        inc     bc
        and     a
        sbc     hl,bc
        ex      de,hl
        ld      b,d
        ld      c,e
        ld      a,(V_27655+1)

.L6c35  sra     b
        rr      c
        dec     a
        jr      nz,L6c35                ; (-7)
        inc     bc
        add     hl,bc
        ex      de,hl
        ld      (SMC_27673+1),hl
        ld      (SMC_27676+1),de
        ld      bc,(V_27650)
        ld      a,d
        add     a,b
        ld      b,a
        ld      a,h
        add     a,c
        ld      c,a
        ld      a,(SMC_27673+2)
        neg     
        add     a,a
        ld      d,a

.L6c57  push    bc
        call    levelmap_xypos_with_check
        pop     bc
        ld      a,(V_27654)
        and     a
        jr      z,L6c69                 ; (7)
        push    bc
        ld      b,a
        ld      a,(hl)
        cp      b
        pop     bc
        jr      nz,L6c6d                ; (4)

.L6c69  ld      a,(V_27653)
        ld      (hl),a

.L6c6d  inc     c
        dec     d
        jr      nz,L6c57                ; (-26)
        pop     bc
        djnz    L6c18                   ; (-92)
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

; Check the squares around a coordinate to see if they are empty
;
; Entry:    bc = coordinates
; Exit:      d = clearness:
; Bit numbers:
;
;  765
;  4 3
;  210
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
        call    L778f
        ld      hl,V_36767
        ld      a,(hl)
        add     a,4
        ld      (hl),a
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      nz,L6ccd                ; (-53)
        jp      wait_for_space_key_release

.L6d05  ld      hl,V_25863
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6d0f  ld      hl,V_25863
        ld      a,(hl)
        inc     a
        cp      64
        ret     z
        ld      (hl),a
        ret     


.L6d19  ld      hl,V_25863+1
        ld      a,(hl)
        dec     a
        cp      255
        ret     z
        ld      (hl),a
        ret     


.L6d23  ld      hl,V_25863+1
        ld      a,(hl)
        inc     a
        cp      80
        ret     z
        ld      (hl),a
        ret     


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
        jr      L6d6d                   ; (40)

.L6d45  cp      49
        ret     c
        cp      58
        ret     nc
        sub     49
        ld      b,a
        jr      L6d6d                   ; (29)

;6d50
V_27984:    defb        1       ;VAR 6d50/27984 

;6d51
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

        ld      a,(V_27984)
        cp      b
        ret     z

        ld      a,b
        ld      (V_27984),a
        call    doicons
        call    L6305

.L6d90  ld      a,(V_27984)
        sla     a
        add     a,2
        ld      c,a
        ld      b,1
        ld      de,$0202
        ld      (V_23887),de
        call    L5d8f
        call    L6dda
        call    get_zone_size
        ld      (V_23887),de
        ret     


D_zone_sizes:
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
.L6dcb  ld      a,(V_27984)
        add     a,a
        ld      e,a
        ld      d,0
        ld      hl,D_zone_sizes
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ret     


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


V_28263:    defw    0       ;VAR 28263/6e67
V_28265:    defb    0       ;VAR 28265/6e69

; Gets coordinates on the levelmap - based on ccursor?
.levelmap_xypos_from_cursor
.L6e6a  call    L6e74
        ld      (V_28263),bc
        jp      levelmap_xypos

.L6e74  ld      bc,(V_pointer_charxy)

; Possibly the 
.L6e78  ld      a,(V_28265)
        and     a
        ret     nz
        ld      hl,V_25863    ;
        ld      a,c
        add     a,(hl)
        ld      c,a
        inc     hl
        ld      a,b
        sub     8
        add     a,(hl)
        ld      b,a
        ret     


.L6e8a  ld      a,1
        ld      (V_28265),a
        call    L6e9b
        xor     a
        ld      (V_28265),a
        ret     

; Join up neighbour paths for power cables, road, rail
join_up_neighbour_cells:
.L6e97  ld      bc,(V_pointer_charxy)
.L6e9b  push    hl
        push    de
        push    bc
        call    L6ebe
        ld      (V_28432),a
        call    L6ee3
        dec     b
        call    L6ee3
        inc     b
        dec     c
        call    L6ee3
        inc     c
        inc     c
        call    L6ee3
        inc     b
        dec     c
        call    L6ee3
        pop     bc
        pop     de
        pop     hl
        ret     


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
V_neighbour_tile_to_check:    defb    $00         ;VAR 28370 - cell to check for neight

;6ed3/28371
D_28371:
        defb    $00, $01, $00, $02 
        defb    $00, $03, $00, $06 
        defb    $01, $01, $04, $09
        defb    $05, $08, $07, $0A
    
; ?? Joins up roads and rail together using the offset table above
; Enters: bc = xy coordinates
.L6ee3  push    bc
        call    L6e78           ;Adds something to the incoming coordinates
        call    L6f12
        jr      nc,L6f0e        ;Coordinate out of range
        call    get_neighbours
        ld      e,d
        ld      d,0
        ld      hl,D_28371
        add     hl,de
        ld      a,(V_neighbour_tile_to_check)
        add     a,(hl)
        pop     bc
        push    bc
        push    af
        call    L6e78
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

V_28432:    defb        0   ;VAR 28432/6f10
V_28433:    defb        0   ;VAR 28433/6f11

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


.L6f2a  ld      a,(V_28433)
        and     a
        jr      nz,L6f3a                ; (10)
        ld      a,(hl)
        call    tile_to_flags
        ld      hl,V_28432
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
        call    L6f12
        rl      d
        inc     b
        dec     c
        call    L6f12
        rl      d
        inc     c
        inc     c
        call    L6f12
        rl      d
        inc     b
        dec     c
        call    L6f12
        rl      d
        pop     bc
        ret     

V_28508:    defb    0       ;VAR 28508/6f5c
V_28510:    defb    0       ;VAR 28510/6f5e

.L6f5f  call    L6e74

.L6f62  push    de
        push    bc
        call    levelmap_xypos_with_check
        pop     bc
        pop     de
        ret     nc

        ld      a,(hl)
        exx     
        ld      hl,D_29291
        ld      bc,8
        cpir    
        exx     
        jr      z,L6f9a                 ; (35)
        cp      0
        jr      z,L6f7d                 ; (2)
        scf     
        ret     


.L6f7d  ld      a,(V_28510)
        ld      (hl),a
        and     a
        jr      z,L6f8e                 ; (10)
        exx     
        ld      de,(V_t_1zone_cost_on_water)
        call    spend_money
        exx     
        ret     c


.L6f8e  ld      (V_28508),bc
        ld      a,b
        add     a,d
        ld      b,a
        ld      a,c
        add     a,e
        ld      c,a
        jr      L6f62                   ; (-56)

.L6f9a  or      a
        ret     

;6f9c/28572
; Suspect this holds a mapping between tile and some feature

; Tile 69 = fire
; Bit 7 = can set on fire?
; bit 3 = needs power?      val 8
; bit 2 = transport - road? val 4
; bit 1 = transport - rail? val 2
D_28572:
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


.L7012  ld      a,(V_pointer_charxy+1)
        cp      8
        ret     c
        ld      a,(V_23891+1)
        and     a
        ret     z
        call    place_joinables
        ret     c           ;We placed a joinable over another squre
        call    L7103       ;check if we can place/auto bulldoze
        jp      nc,L702d
        call    L71e4
        jp      L7042

.L702d  ld      a,(V_27984)
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
        jr      z,L7042                 ; (-31)
        ret     

;7062
D_28770:
        ;If we place power on one of these
        defb   $07, $08, $14, $15, $38, $39
        ;It converts to...
        defb   $31, $30, $32, $33, $21, $22
;706e 

D_28782: 
        ;If we place road on one of these
        defb    $14, $15, $21, $22, $38, $39 
        defb    $2E, $2F, $30, $31, $07, $07

D_28794:
        ;If we place rail on one of these
        defb    $08, $07, $08, $21, $22, $38
        defb    $39, $2F, $2E, $33, $32, $14
        
        defb    $15

; Place a joinable (road,rail,power) 
place_joinables:
.L7086  ld      a,(V_27984)
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
        ld      hl,D_28782
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
        ld      hl,D_28794
        ld      bc,6
        cpir    
        jp      nz,L709c
        ld      de,20               ;Cost
        ld      a,TILE_H_RAIL
        jp      place_tile

place_power:
.L70e3  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        ld      hl,D_28770
        ld      bc,6
        cpir    
        jp      nz,L709c
        ld      de,5                ;Power
        ld      a,TILE_H_POWER
        jp      place_tile

; Types used for auto-bulldoze
;70fa/28922
D_28922:
        defb    TILE_DIRT, TILE_WATER            ;DIRT, WATER
;70fc/28944
D_28924:
        defb    $03, $01, $05, $04, $06, $02
 
V_28930:    defb        0       ;VAR 28930/7102

.L7103  call    levelmap_xypos_from_cursor
        ld      a,(hl)      ;Is it empty?
        cp      0
        jp      z,L7113
        ld      a,(V_auto_bulldoze)
        and     a
        jp      z,check_can_place_zone

.L7113  ld      a,2
        ld      (V_28930),a
        ld      a,(V_27984)
        and     a
        jp      z,L7171
        cp      4
        jp      nc,L7129
        ld      a,0
        ld      (V_28930),a

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
        ld      hl,D_28924
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
        ld      hl,D_28922
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
place_zone:
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


V_t_1zone_cost_on_land:    defw    0   ; VAR: Cost of a placing a single zone
V_t_1zone_cost_on_water:      defw    0   ; VAR: Cost on land
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
        jr      nz,L71e4                ; It's not dirt
        ld      de,(V_t_1zone_cost_on_land)    ; Can we spend it?
        call    spend_money
        ret     c
        ld      a,(V_neighbour_tile_to_check)               ; Yes we cam, place it
        ld      (hl),a
        call    join_up_neighbour_cells
        jp      draw_map

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
D_29183:
        defb    $00, $01, $02, $00, $03, $00, $00, $00
        defb    $04, $00, $00, $00, $00, $00, $00, $00

D_29199:
        defb    $00, $00, $00, $00, $FF, $0C, $FF, $00 
        defb    $0B, $01, $00, $0B, $00, $01, $0C
        

L721e:
        call    L6e74
        ld      a,1
        ld      (V_28433),a
        call    get_neighbours
        xor     a
        ld      (V_28433),a
        ld      a,d
        and     a
        ret     z

        ld      e,a
        ld      d,0
        ld      hl,D_29183
        add     hl,de
        ld      a,(hl)
        and     a
        ret     z

        ld      b,a
        add     a,a
        add     a,b
        ld      e,a
        ld      hl,D_29199
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        ld      (SMC_29270+1),a
        ld      a,0
        ld      (V_28510),a
        call    L6f5f
        ret     nc

        ld      a,(V_neighbour_tile_to_check)
SMC_29270:
        add     a,11
        ld      (V_28510),a
        call    L6f5f
        call    join_up_neighbour_cells
        ld      bc,(V_28508)
        call    L6e8a
        jp      draw_map


;726b/29291
D_29291:
        defb    $2c, $2d, $1f, $20
        defb    $12, $13, $57,$58

;7273/29299
unbulldozeable_tiles:
        defb    TILE_WATER, TILE_DIRT, TILE_NEED_POWER
        


action_zone_bulldoze:
        call    levelmap_xypos_from_cursor
        ld      a,(hl)
        cp      128
        jp      nc,L7308
        cp      81
        jr      c,L7288                 ; (5)
        cp      87
        jp      c,L7367

.L7288  ld      hl,D_29291
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
        jr      L72af                   ; (-41)

.L72d8  call    levelmap_xypos_from_cursor
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      de,1
        call    spend_money
        ret     c
        ld      (hl),58
        jr      L72af                   ; (-62)

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
D_7301:
        defb    0
        defb    1
        defb    4
        defb    9
        defb    16
        defb    25
        defb    36


.L7308  call    L72ed
        ret     nz

        push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96
.L7315  bit     5,(ix+0)
        jr      nz,L731f                ; (4)
        add     ix,de
        jr      L7315                   ; (-10)

.L731f  ld      a,(ix+0)
        and     7
        ld      c,a
        ld      b,0
        ld      hl,D_7301
        add     hl,de
        ld      e,(hl)
        ld      d,0
        call    spend_money
        ret     c

        ld      a,(ix+0)
        and     7

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


.L7367  call    L72ed
        ret     nz

        ld      de,9
        call    spend_money
        ret     c

        ld      bc,65439
        add     hl,bc
        push    hl
        pop     ix
        ld      a,3
        jr      L7337                   ; (-70)

D29565:
        defb    $46, $47, $48
        defb    $47, $48, $02

; Degrade any bulldozed tiles through the sequence
bulldoze_degrade_tile:
.L7383  call    L6e74
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

        nop     

;73d4
action_zone_park:
        call    levelmap_xypos_from_cursor
        cp      2           ;BUG? This seems to be the x position?
        jp      z,L71e4
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
        defb    $c5, $c0, $c0, $c0
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
        call    L66f2
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


V_minimap_start:    defw        0   ;753c/30012, address of mini map being handled


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


.L7579  ld      hl,minimaps+2304
        ld      (V_minimap_start),hl
        jr      minimap_xypos_50                   ; (-67)


; Traffic density map
get_traffic_density_value:
.L7581  ld      hl,minimaps+3456
        ld      (V_minimap_start),hl
        jr      minimap_xypos_50                   ; (-75)

; Police minimap - get value
.L7589  ld      hl,minimaps+576
        ld      (V_minimap_start),hl
        jr      minimap_xypos_25                   ; (-55)

; Fire minimap - get value
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
        jr      L75ac                   ; (8)
.L75a4  ld      c,a
        ld      b,0
        ld      hl,D_28572              ;Tile flag table
        add     hl,bc
        ld      a,(hl)
.L75ac  pop     hl
        pop     de
        pop     bc
        ret     


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
        call    L75cd
        ld      a,131
        call    L75cd
        ld      a,131
        call    L75cd
        ret     


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

        pop     de
        ret     

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

;Get address for power minimap
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

; Convert map address into coordinates
; Entry: hl = pointer into level map
; Exit:  b = rows from top
;        l = column?
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
l_mult_hlxde:
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

;Does something on a minimap 50%
;
;Exit: a = ???
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

D_30338:
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
.L768e  push    bc
        ld      a,(hl)
        bit     7,a
        jr      z,L76c9                 ; (53)
        push    hl
        pop     ix
        call    find_left_edge_of_zone
        ld      de,-96

.L769d  bit     5,(ix+0)
        jr      nz,L76a7                ; (4)
        add     ix,de
        jr      L769d                   ; (-10)

.L76a7  ld      a,(ix+1)
        and     63
        ld      e,a
        ld      hl,D_34835
        ld      bc,4

.L76b3  ld      a,(hl)
        cp      255
        ret     z
        cp      e
        jr      z,L76bd                 ; (3)
        add     hl,bc
        jr      L76b3                   ; (-10)

.L76bd  inc     hl
        ld      c,(hl)
        ld      b,0
        ld      hl,D_30338
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

D_30428:    
        defb    $00, $ff
        defb    $01, $00
        defb    $00,$01
        defb    $ff,$00

; Entry: bc = coordinates
;         a = direction
; Exit:  bc = original coordinates
;        hl = levelmap of coords + direction

.L76e4  push    bc
        call    L76ed
        call    levelmap_xypos
        pop     bc
        ret     


.L76ed  add     a,a
        ld      e,a
        ld      d,0
        ld      hl,D_30428
        add     hl,de
        ld      a,c
        add     a,(hl)
        ld      c,a
        inc     hl
        ld      a,b
        add     a,(hl)
        ld      b,a
        ret     

V_30461:    defb        0       ;VAR 30461/76fd

.L76fe  ld      hl,V_30461
        inc     (hl)
        call    L7714
        ld      (hl),c
        inc     hl
        ld      (hl),b
        ret     


.L7709  call    L7714
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        ld      hl,V_30461
        dec     (hl)
        ret     


.L7714  ld      a,(V_30461)
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
.L7735  ld      hl,(V_25863)
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
        ld      a,(V_36767)
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
.L778f  ld      a,(V_30678)
        and     a
        jr      z,L77b3                 ; (30)
        ld      bc,(V_30675)
        call    levelmap_xypos_with_check
        ld      a,(hl)
        cp      31
        jr      z,L77b3                 ; (18)
        cp      32
        jr      z,L77b3                 ; (14)
        ld      a,(V_30678)
        and     a
        ld      bc,(V_30675)
        ld      a,(V_30677)
        call    nz,display_transport_sprite

.L77b3  ld      a,(V_30841)
        and     a
        ld      bc,(V_30842)
        ld      a,0
        call    nz,display_transport_sprite
        ld      a,r
        and     1
        inc     a
        ld      d,a
        ld      a,(V_31127)
        and     a
        ld      bc,(V_31125)
        ld      a,d
        call    nz,display_transport_sprite
        ret     

V_30675:    defw    0       ;VAR 30675/77d3

V_30677:    defb    0       ;VAR 30677/77d5

V_30678:    defb        0       ;VAR 30678/77d6
V_30679:    defb        0       ;VAR 30679/77d7
V_30680:    defb        0       ;VAR 30680/77d8
V_30681:    defb        0       ;VAR 30681/77d9
V_30682:    defb        0       ;VAR 30682/77da
V_30683:    defb        0       ;VAR 30683/77db


.L77dc  ld      a,(V_30678)
        and     a
        ret     z

        ld      bc,(V_30675)
        call    levelmap_xypos
        ld      a,(hl)
        call    tile_to_flags
        and     2                       ;rail?
        jr      nz,L77f5                ; (5)
        xor     a
        ld      (V_30678),a
        ret     


.L77f5  ld      bc,(V_30675)
        call    get_random_number
        and     3
        ld      (V_30680),a
        ld      a,4
        ld      (V_30682),a

.L7806  ld      a,(V_30680)
        and     3
        ld      (V_30681),a
        ld      hl,V_30679
        cp      (hl)
        jr      z,L7822                 ; (14)
        ld      a,(V_30681)               ;Direction to look in
        call    L76e4                   ;Move in direction
        ld      a,(hl)
        call    tile_to_flags
        and     2
        jr      nz,L783d                ; (27)

.L7822  ld      hl,V_30680
        inc     (hl)
        ld      hl,V_30682
        dec     (hl)
        jr      nz,L7806                ; (-38)
        ld      hl,V_30683
        ld      a,(hl)
        inc     a
        ld      (hl),a
        cp      5
        ret     nz

        ld      (hl),0
        ld      a,5
        ld      (V_30679),a
        ret     


.L783d  ld      a,(V_30681)
        call    L76ed               ;Move coords in direction
        ld      a,(V_30681)
        add     a,2
        and     3
        ld      (V_30679),a
        ld      (V_30675),bc
        ld      c,3
        and     1
        jr      nz,L7858                ; (1)
        inc     c

.L7858  ld      a,c
        ld      (V_30677),a
        ret     


.L785d  ld      a,(37650)
        cp      8
        ld      a,(V_30678)
        and     a
        ret     nz

        call    get_random_number
        and     63
        ret     nz

        ld      hl,(V_map_iter_xy)
        ld      (V_30675),hl
        ld      a,1
        ld      (V_30678),a
        ret     

V_30841:    defb        0       ;VAR 30841/787a
V_30842:    defw        0       ;VAR 30842/787b
V_30844:    defb        0       ;VAR 30844/787d
V_30845:    defb        0       ;VAR 30845/787e


.L787e  ld      a,(V_30841)
        and     a
        ret     z
        ld      a,(V_30842)
        ld      hl,V_30844
        cp      (hl)
        jr      z,L78af                 ; (35)
        ld      hl,V_30842
        dec     (hl)
        ld      hl,V_30845
        ld      a,(hl)
        and     a
        ret     z
        dec     (hl)
        ret     nz
        ld      bc,(V_30842)          ;And here we start an aircrash?
        call    L78b4
        inc     c
        call    L78b4
        dec     c
        inc     b
        call    L78b4
        inc     c
        call    L78b4
        call    L78bd
.L78af  xor     a
        ld      (V_30841),a
        ret     


.L78b4  push    bc
        call    levelmap_xypos
        call    L90c4
        pop     bc
        ret     


.L78bd  ld      b,255
        ld      e,0

.L78c1  push    bc
        call    soundfx1
        pop     bc
        inc     e
        djnz    L78c1                   ; (-8)
        ret     


.L78ca  ld      a,(V_30841)
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
        ld      (V_30844),a
        ld      c,96
        ld      (V_30842),bc

.L78ea  ld      a,1
        ld      (V_30841),a
        ret     


.L78f0  ld      bc,(V_map_iter_xy)
        xor     a
        ld      (V_30844),a
        ld      (V_30842),bc
        jr      L78ea                   ; (-20)

.sim_start_aircrash
.L78fe  ld      a,(V_safe_AirportPop)
        and     a
        ret     z
        ld      a,25
        call    set_alert_message
        call    get_random_number
        and     15
        add     a,7
        ld      (V_30845),a
        ret     

.sim_start_meltdown
.L7913  ld      a,(V_safe_NuclearPop)       ;number of nuclear plants?
        and     a
        ret     z
        ld      a,18
        call    set_alert_message
        ld      a,1
        ld      (V_meltdown_triggered),a
        jr      L78bd                   ; (-103)

V_meltdown_triggered:    defb        0       ;VAR 31012/7924 - meltdown triggered

; Nuclear meltdown - spread radiation everywhere?
place_fallout:
.L7925  ld      a,(V_meltdown_triggered)
        and     a
        ret     z
        xor     a
        ld      (V_meltdown_triggered),a
        ld      a,69
        ld      (V_35224),a
        ld      hl,(V_map_iter_addr)
        call    L7b86
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
        ld      (V_31127),a

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
        ld      (V_31125),bc
        ret     

V_31125:    defw    0       ;VAR 31125/7995
V_31127:    defb    0       ;VAR 31127/7997

; Something to do with parks?
.L7998  ld      a,(V_31127)
        and     a
        ret     z
        call    get_random_number
        and     a
        jr      nz,L79a7                ; (4)
        xor     a
        ld      (V_31127),a
.L79a7  ld      bc,(V_31125)
        call    get_random_number
        and     7
        jr      nz,L79ea                ; (56)
        ld      hl,(V_33954)
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
        ld      (V_31125),bc
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
        call    L76ed               ;Move coords in direction
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        cp      0
        ret     z

        ld      (V_31125),bc
        jr      L79d4                   ; (-45)

; Converts kempston into directional keypresses
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
.L7b42
        defb        T_SETCOL,82
        defb        T_SETXY,21,1
        defm        " "
        defb        T_SETCOL,73
        defb        T_SETXY,22,1
        defm        " "
        defb        T_END
        ret

.V_31568        defb        0        ;VAR? - Unknown

show_mini_maps:
.L7b51  xor     a
        ld      (V_show_mini_maps),a
        call    L7a9e

.L7b58  call    L9b60
        call    L9b76
        call    L9c57
        call    L9b76
        call    L9b60
        ld      a,(V_wait_for_budget_confirm)
        and     a
        jr      nz,L7b7d                ; (16)
        ld      a,(keystore+7)
        and     1       ;'SPACE'
        jr      z,L7b7d                 ; (9)
        call    L9b8b
        ld      hl,V_31568
        inc     (hl)
        jr      L7b58                   ; (-37)

.L7b7d  call    cls_white
        call    ingame_scrdraw
        jp      draw_map

; Thing this gets the top left of the zone for a map position
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
.L7ba6  ld      a,(V_35224)
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

.L7bc4  bit     5,(ix+0)
        jr      nz,L7bce                ; (4)
        add     ix,de
        jr      L7bc4                   ; (-10)

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


; Represents the influence of police/fire station
D_31727:
        defb    $09, $09, $02, $09, $09 
        defb    $09, $02, $01, $02, $09
        defb    $02, $01, $01, $01, $02 
        defb    $09, $02, $01, $02, $09 
        defb    $09, $09, $02, $09, $09


V_31752:    defb        0       ;VAR 31752/7c08

.L7c09  ld      bc,(V_map_iter_xy)
        ld      ix,D_31727
        call    L7591           ;Fire map
        ld      de,50
        and     a
        sbc     hl,de
        ld      d,5
.L7c1c  push    hl
        ld      e,5
.L7c1f  call    L7c5f
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

V_31793:    defb    0       ;VAR 31793/7c31

.L7c32  ld      bc,(V_map_iter_xy)
        ld      ix,D_31727
        call    L7589           ;Get police minimap address
        ld      de,50           ;Go 8 tiles up and two left??
        and     a
        sbc     hl,de
        ld      d,5             ;5x5 zone around it?
.L7c45  push    hl
        ld      e,5
.L7c48  call    L7c5a           ;Add some intensity?
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


.L7c5a  ld      a,(V_31793)
        jr      L7c62                   ; (3)

.L7c5f  ld      a,(V_31752)

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


D_31863:
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

V_31935:    defb    $ff       ;VAR 31935/7cbf


.L7cc0  ld      bc,(V_map_iter_xy)
        ld      ix,D_31863 

.L7cc8  call    L7579       ;minimaps+2304
        ld      de,98
        and     a
        sbc     hl,de
        ld      d,6
.L7cd3  push    hl
        ld      e,6
.L7cd6  call    L7ce8
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


.L7ce8  ld      a,(V_31935)
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


.L7cfe  ld      bc,(V_map_iter_xy)
        call    L7579
        call    L7668
        ld      (V_32447),a
        ld      e,a
        ld      d,0
        ld      hl,(V_33914)
        add     hl,de
        ld      (V_33914),hl
        ld      hl,(V_33916)
        inc     hl
        ld      (V_33916),hl
        ret     


.L7d1d  ld      bc,(V_map_iter_xy)
        call    get_traffic_density_value
        call    L7668
        ld      (V_32448),a
        ret     


V_32043:    defw        0       ;VAR 32043/7d2b


V_zone_size_to_scan:    defw    0       ;VAR 32045/7d2d - size of zone to scan

.L7d2f  ld      (V_zone_size_to_scan),hl
        jr      L7d3a                   ; (6)

;scan 3x3 zone
.L7d34  ld      hl,$0303
        ld      (V_zone_size_to_scan),hl

.L7d3a  xor     a
        ld      (V_32282),a
        ld      (V_32279),a
        ld      (V_32280),a
        ld      (V_32281),a
        ld      (V_32283),a
        ld      hl,$ffff
        ld      (V_32043),hl
        push    bc
        dec     b
        ld      a,(V_zone_size_to_scan)
        ld      e,a

.L7d56  call    L7d88
        inc     c
        dec     e
        jr      nz,L7d56                ; (-7)
        pop     bc
        dec     c
        ld      a,(32046)
        ld      d,a

.L7d63  push    bc
        call    L7d88
        inc     c
        ld      a,(V_zone_size_to_scan)
        ld      e,a

.L7d6c  call    L7dea
        inc     c
        dec     e
        jr      nz,L7d6c                ; (-7)
        call    L7d88
        pop     bc
        inc     b
        dec     d
        jr      nz,L7d63                ; (-24)
        inc     c
        ld      a,(V_zone_size_to_scan)
        ld      e,a

.L7d80  call    L7d88
        inc     c
        dec     e
        jr      nz,L7d80                ; (-7)
        ret     


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
        ld      hl,V_32282
        inc     (hl)
        call    L7dd8
        ld      l,12

.L7db2  ld      a,(V_32283)
        add     a,l
        cp      128
        jr      c,L7dbc                 ; (2)
        ld      a,127

.L7dbc  ld      (V_32283),a
        ret     


.L7dc0  ld      hl,V_32280
        inc     (hl)
        ld      l,16
        jr      L7db2                   ; (-22)

.L7dc8  ld      hl,V_32279
        inc     (hl)
        ld      l,14
        jr      L7db2                   ; (-30)

.L7dd0  ld      hl,V_32281
        inc     (hl)
        ld      l,16
        jr      L7db2                   ; (-38)

.L7dd8  ld      a,(V_32043)
        cp      255
        jr      z,L7de5                 ; (6)
        call    get_random_number
        and     1
        ret     z
.L7de5  ld      (V_32043),bc
        ret     


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
        ld      hl,V_34921
        add     a,(hl)
        ld      (hl),a
        ret     


.L7e03  ld      hl,(V_33954)
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

V_32279:    defb        0       ;VAR 32279/7e17
V_32280:    defb        0       ;VAR 32280/7e18
V_32281:    defb        0       ;VAR 32281/7e19
V_32282:    defb        0       ;VAR 32282/7e1a
V_32283:    defb        0       ;VAR 32283/7e1b
V_32284:    defb        0       ;VAR 32284/7e1c


.L7e1d  ld      a,(V_34501)
        and     a
        jr      z,L7e54                 ; (49)
        ld      a,(V_32282)
        and     a
        jr      z,L7e54                 ; (43)
        ld      a,(V_34152)
        and     a
        jr      nz,L7e36                ; (7)
        call    L7d1d
        cp      50
        jr      c,L7e54                 ; (30)

.L7e36  call    L7e5a
        ld      hl,V_32283
        add     a,(hl)
        ld      hl,V_32284
        ld      (hl),a
        ld      e,a
        ld      d,0
        ld      hl,(V_33906)
        add     hl,de
        ret     c
        ld      (V_33906),hl
.L7e4c  ld      hl,(V_33908)
        inc     hl
        ld      (V_33908),hl
        ret     


.L7e54  xor     a
        ld      (V_32284),a
        jr      L7e4c                   ; (-14)

.L7e5a  ld      bc,(V_map_iter_xy)
        call    L7e03
        ld      b,a
        ld      a,127
        sub     b
        ret     nc

        xor     a
        ret     

        nop

V_32361:    defb    0       ;VAR 32361/7e69

.L7e6a  ld      bc,(V_map_iter_xy)
        call    L7589
        ld      c,a
        ld      hl,V_32284
        ld      a,255
        sub     (hl)
        srl     a
        srl     a
        srl     a
        srl     a
        sub     c
        jr      nc,L7e84                ; (1)
        xor     a

.L7e84  ld      (V_32361),a
        ld      e,a
        ld      d,0
        ld      hl,(V_33902)
        add     hl,de
        ret     c

        ld      (V_33902),hl
        ld      hl,(V_33904)
        inc     hl
        ld      (V_33904),hl
        ret     

V_32410:    defb        0       ;VAR 32410/7e9a

.L7e9b  ld      a,(SMC_tax_rate)           ;Tax rate
        ld      b,a
        add     a,a
        add     a,a
        add     a,a
        ld      (V_32410),a
        ld      a,(V_difficulty)
        and     a
        ret     z

        ld      a,(V_32410)
        add     a,b
        ld      (V_32410),a
        ld      a,(V_difficulty)
        cp      2
        ret     z

        ld      a,(V_32410)
        add     a,b
        ld      (V_32410),a
        ret     

V_32447:    defb        0       ;VAR 32447/7ebf
V_32448:    defb        0       ;VAR 32448/7ec0
V_32449:    defb        0       ;VAR 32449/7ec1
V_32450:    defw        0       ;VAR 32450/7ec2

.L7ec4  call    L7e1d
        call    L7e6a
        call    L7e9b
        ld      a,(V_32447)
        cp      28
        jr      nc,L7eff                ; (43)
        ld      a,(V_32284)
        and     a
        jr      z,L7eff                 ; (37)
        ld      hl,V_32447
        sub     (hl)
        jr      nc,L7ee1                ; (1)
        xor     a

.L7ee1  ld      hl,V_32361
        sub     (hl)
        jr      nc,L7ee8                ; (1)
        xor     a

.L7ee8  ld      hl,V_32410
        sub     (hl)
        jr      nc,L7eef                ; (1)
        xor     a

.L7eef  ld      l,a
        ld      h,0
        ld      de,(V_32450)
        add     hl,de
        call    L7f04
        ld      a,l
        ld      (V_32449),a
        ret     


.L7eff  xor     a
        ld      (V_32449),a
        ret     


.L7f04  ld      a,h
        and     a
        ret     z
        jp      p,L7f0d
        ld      l,0
        ret     
.L7f0d  ld      l,255
        ret     

V_32528:    defb    0       ;VAR 32528/7f10
V_32529:    defb    0       ;VAR 32529/7f11

.L7f12  call    L7ec4
        ld      a,(V_32449)
        srl     a
        ld      (V_32529),a
        ld      a,(V_32449)
        sub     128
        jr      nc,L7f26                ; (2)
        ld      a,255

.L7f26  srl     a
        srl     a
        srl     a
        srl     a
        ld      b,a
        ld      (V_32528),a
        ld      a,(V_32449)
        cp      128
        ret     c

        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        add     a,80
        ld      (V_32529),a
        ret     

V_32579:    defb    0       ;VAR 32579/7f43
V_32580:    defb    0       ;VAR 32580/7f4f - unused?


.L7f45  call    L7ec4
        ld      a,(V_32449)
        ld      l,a
        ld      h,0
        ld      a,25
        call    L_div_hl_a
        ld      a,l
        ld      (V_32579),a
        add     a,a
        add     a,a
        ld      (V_32580),a
        ret     

V_32605:    defb    0       ;VAR 32605/7f5d
V_32606:    defb    0       ;VAR 32606/7f5e - unused?


.L7f5f  call    L7ec4
        ld      a,(V_32449)
        ld      l,a
        ld      h,0
        ld      a,31
        call    L_div_hl_a
        ld      a,l
        ld      (V_32605),a
        add     a,a
        add     a,a
        add     a,a
        ld      (V_32606),a
        ret     


; Holds result f searching the map - address within map?
V_32632:    defs        32          ;VAR: 32632/7f78 - ??


.L7f98  ld      ix,V_32632
        ld      hl,levelmap         ;Search for a power station
        ld      bc,9216             ;somehow we know it exists?
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
        jr      nz,L7fa2                ; (-19)
        ld      (ix+0),0            ;End markers
        ld      (ix+1),0
        ret     
.L7fbe  dec     hl
        ld      (ix+0),l
        inc     ix
        ld      (ix+0),h
        inc     ix
        inc     hl
        jr      L7fa2                   ; (-42)


V_brownout_detected:    defb    0       ;VAR (32716/7fcc) - brownouts detected

generate_power_map:
.L7fcd  call    L7f98
        ld      hl,minimaps + 5760              ;Clear power map
        ld      de,minimaps + 5760 + 1
        ld      bc,1151
        ld      (hl),0
        ldir    
        xor     a
        ld      (V_brownout_detected),a
        ld      ix,V_32632                  ;Map address of power stations
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

.L7ffd  ld      (V_32793),de              ;Power available
        call    L7635
        ld      (V_32791),bc              ;Current coordinates
        push    ix
        call    L811d                   ;Start tracing the connections
        pop     ix
        inc     ix
        inc     ix
        jr      L7fe5                   ; (-48)

;8015
V_32789:        defb    0       ;VAR 32789/8015
V_32790:        defb    0       ;VAR 32790/8016
V_32791:        defw    0       ;VAR 32791/8017
V_32793: defw    0          ;VAR 32793/8019 - power available from power station we are processing
V_powersp:  defw    0       ;VAR 32795/801b - saved stack when aborting power search 

V_powerqueue:   defs    256 ;VAR 32797/801c - list of coordinates to check for power connection



.L811d  call    check_tile_needs_power
        ret     nz              ;We don't need power
        ld      ix,V_powerqueue            ;801d
        ld      (V_powersp),sp
        ld      bc,$ffff        ;Place an endmarker
        call    L8177          
        ld      bc,(V_32791)      ;Current coordinate we're dealing with
        call    L8177
.L8136  call    L818f           ;Get next cell 
        ld      a,b             ;Check if we're at the end
        cp      255
        ret     z
.L813d  call    check_tile_needs_power
        jr      nz,L8145                ; We don't need power
        dec     c
        jr      L813d                   ; Go left and try again

.L8145  inc     c                       ;Check right
        call    check_tile_needs_power
        jr      nz,L8136                ;Power not needed, go get next starting point
        xor     a
        ld      (V_32789),a           ;Down power check indicator
        ld      (V_32790),a           ;Up power check indicator
.L8152  call    set_tile_as_powered ;Turns power on for tile
        dec     b                   ;Up a row
        ld      hl,V_32789
        call    L816d
        inc     b                   ;And then below
        inc     b
        ld      hl,V_32790
        call    L816d
        dec     b                   ;And then to the right
        inc     c
        call    check_tile_needs_power
        jr      z,L8152                 ; (-25)
        jr      L8136                   ; (-55)

.L816d  call    check_tile_needs_power
        jr      nz,L818c                ; (26)
        ld      a,(hl)                  ;Flag that we've already checked in this direction
        and     a
        ret     nz
        ld      (hl),1
                                        ;Fall into adding another point for consideration
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
        ld      hl,(V_32793)          ;We have one less tile we can give power to
        dec     hl
        ld      (V_32793),hl
        ld      a,h
        or      l
        ret     nz
        ; Abort power search - we've run out of power to distribute
        ld      sp,(V_powersp)
        ld      hl,V_brownout_detected
        inc     (hl)
        ret     

;33245
V_city_score:           defs    3   ;VAR 33245 - calculated city score
V_previous_city_score:  defs    3   ;VAR 33248 - previous city score


; cf s_eval.c::GetAssValue()
calculate_city_score:
.L81e3  ld      hl,(V_city_score)
        ld      a,(V_city_score+2)
        ld      c,a
        ld      (V_previous_city_score),hl
        ld      a,c
        ld      (V_previous_city_score+2),a
        ld      hl,(V_RoadTotal)      ;RoadTotal
        ld      de,5
        call    L_mult_24_16x16
        ld      (V_city_score),hl
        ld      a,c
        ld      (V_city_score+2),a
        ld      hl,(V_RailTotal)      ;RailTotal
        ld      de,10
        call    L824f
        ld      hl,(V_PolicePop)     ;PolicePop
        ld      de,1000
        call    L824f
        ld      hl,(V_FirePop)     ;FireStPop
        ld      de,1000
        call    L824f
        ld      hl,(V_HospitalPop)     ;HospPop
        ld      de,400
        call    L824f
        ld      hl,(V_StadiumPop)      ;StadiumPop
        ld      de,3000
        call    L824f
        ld      hl,(V_PortPop)      ;PortPop
        ld      de,5000
        call    L824f
        ld      hl,(V_AirportPop)      ;APortPop
        ld      de,10000
        call    L824f
        ld      hl,(V_CoalPop)      ;CoalPop
        ld      de,3000     
        call    L824f
        ld      hl,(V_NuclearPop)     ;NuclearPop
        ld      de,6000               

.L824f  call    L_mult_24_16x16
        ld      de,(V_city_score)
        ld      a,(V_city_score+2)
        ld      b,a
        call    l_add24
        ld      (V_city_score),hl
        ld      a,c
        ld      (V_city_score+2),a
        ret     

V_33381:    defw    0       ;VAR 33381/8265 - unemployment?


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
        ld      (V_33381),hl      ;unemployment
        ret     


V_33404:    defw    0       ;VAR 33404/827c
V_33406:    defw    0       ;VAR 33406/827e
V_33408:    defw    0       ;VAR 33408/8280


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
        ld      (V_33404),hl

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
        ld      (V_33406),hl  ;(airport *4) + ((((res + ind) / 2) - com) * 8) - 30

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
        ld      (V_33408),hl
        ret     


.L82ee  push    hl
        push    bc
        ex      de,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl
        add     hl,hl       ;*16
        ex      de,hl
        ld      b,0
        ld      hl,(V_33859)
        ld      a,(V_33859+2)
        ld      c,a
        call    l_add24
        ld      (V_33859),hl
        ld      a,c
        ld      (V_33859+2),a
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
        call    L83a1
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


;Simulation code runs here
.V_33629            defb        0       ;VAR 835e/33629
.V_sim_loop_counter defb       0       ;VAR 835e/33630 - loop counter for simulation (increments each time through)

start_simulation:
        call    L83a1                           ;Initialise all simulation vars
.L8362  call    reset_simulation_vars           ;Clears simulation loop variables
        call    set_simulation_speed
        call    generate_power_map              ;Power minimap + brownout detection
        call    L86c9                           ;Process zones
        call    create_police_fire_minimaps     ;Create minimaps for police/fire
        call    L84de                           ;Generate pollution map
        call    DecTrafficMem                   ;Traffic?
        call    L8282                           ;Determines demand for stadium etc?
        call    L8f05                           ;Some stats...
        call    calculate_city_score
        call    set_unemployment
        call    census_church_hosp
        call    SendMessages
        call    L84a4                           ;More stats?
        ld      a,(V_sim_loop_counter)
        ld      hl,V_36711+4
        and     (hl)
        jr      nz,L839b                ; (6)
        call    DoBudget
        call    increment_month
.L839b  ld      hl,V_sim_loop_counter
        inc     (hl)
        jr      L8362                   ; (-63)

; Initialises the simulation variables
.L83a1  ld      hl,8224
        ld      (V_33954),hl
        ld      hl,minimaps
        ld      de,minimaps+1
        ld      bc,6911
        ld      (hl),0
        ldir    
        ld      a,255
        ld      (V_35013),a
        ld      (V_35074),a
        ld      a,15
        ld      (V_31793),a
        ld      (V_31752),a
        xor     a
        ld      (V_36610),a
        ld      (V_36609),a
        ld      (V_34074),a
        ld      (V_sim_loop_counter),a
        ld      (V_wait_for_budget_confirm),a
        ld      (V_hospital_demand),a
        ld      (V_church_demand),a
        ld      (V_30678),a
        ld      (V_30841),a
        ld      (V_30845),a
        ld      (V_meltdown_triggered),a
        ld      (V_31127),a
        ld      (V_33629),a
        ld      hl,0
        ld      (V_Transport_Funding_Requested),hl
        ld      (V_Budget_Police_Funding_Requested),hl
        ld      (V_Budget_Fire_Funding_Requested),hl
        ld      (V_Transport_Funding_Allocated),hl
        ld      (V_Police_Funding_Allocated),hl
        ld      (V_Fire_Funding_Allocated),hl
        ld      (V_33381),hl
        ld      (V_36611),hl
        ld      (V_safe_AirportPop),hl
        ld      (V_safe_NuclearPop),hl
        ld      (V_33948),hl
        ld      (V_33404),hl
        ld      (V_33406),hl
        ld      (V_33408),hl
        ld      c,0
        ld      h,0
        ld      l,0
        ld      (V_population),hl
        ld      a,c                     ;OPT
        ld      (V_population+2),a
        ld      (V_36493),hl
        ld      a,c                     ;OPT
        ld      (V_36493+2),a
        ld      (V_city_score),hl
        ld      a,c                     ;OPT
        ld      (V_city_score+2),a
        ld      (V_previous_city_score),hl
        ld      a,c                     ;OPT
        ld      (V_previous_city_score+2),a
        ld      (V_36490),hl
        ld      a,c                     ;OPT
        ld      (V_36490+2),a
        ret     

;8443, 33859
V_33859: defb        0,0,0       ;VAR

V_ResZPop: defw        0       ;VAR
V_ComZPop: defw        0       ;VAR

V_IndZPop:  defw        0       ;VAR
V_PolicePop:  defw        0       ;VAR 33868 - Police Population
V_FirePop:  defw        0       ;VAR 33870 - Fire Station Population
V_ChurchPop:  defw        0       ;VAR - church population?
V_HospitalPop:  defw        0       ;VAR 33874 - Hospital population
V_NuclearPop:  defw        0       ;VAR 33876 - Nuclear Population

V_CoalPop:   defw        0       ;VAR 33878 - Coal population

V_StadiumPop:  defw        0       ;VAR 33880 - Stadium population

V_AirportPop:  defw        0       ;VAR 33882  - Airport popluation

V_PortPop:  defw        0       ;VAR 33884 - Port population

V_33886:    defw        0       ;VAR 33886/845e
V_33888:    defw        0       ;VAR 33888/8460
V_33890:    defw        0       ;VAR 33890/8462
V_33892:    defw        0       ;VAR 33892/8464

V_PoliceFund:   defw        0   ;VAR 33894 - police funding needed
V_FireFund:     defw        0   ;VAR 33896 - fire funding needed
V_RailTotal:    defw        0   ;VAR 33898 - rail total
V_RoadTotal:    defw        0   ;VAR 33900 - road total


V_33902:        defw        0   ;VAR 33902/846e

V_33904:        defw        0   ;VAR 33904/8470
V_33906:        defw        0   ;VAR 33906/8472
V_33908:        defw        0   ;VAR 33908/8474
V_33910:        defw        0   ;VAR 33910/8476
V_33912:        defw        0   ;VAR 33912/8478
V_33914:        defw        0   ;VAR 33914/847a
V_33916:        defw        0   ;VAR 33916/847c
V_33918:        defw        0   ;VAR 33918/847e

      
;33920
reset_simulation_vars:
.L8480  ld      hl,V_33859           ;wipe out all populations
        ld      de,V_33859+1
        ld      bc,60
        ld      (hl),0
        ldir    
        xor     a
        ld      (V_34760),a
        ld      (V_34760+2),a
        cpl     
        ld      (V_34760+1),a
        ld      (V_34760+3),a
        ret     

V_33948:     defw    0           ;VAR 33948/8e9c

V_safe_AirportPop:        defw    0           ;VAR 33950/849e - 
V_safe_NuclearPop:        defw    0           ;VAR 33952/849e - 

;V_33954
V_33954:    defb $20, $20       ;VAR 33954/84a2


.L84a4  ld      a,(V_34760)
        ld      hl,V_34760+1
        add     a,(hl)
        srl     a
        ld      (V_33954),a
        ld      a,(V_34760+2)
        ld      hl,V_34760+3
        add     a,(hl)
        srl     a
        ld      (V_33954+1),a
        ld      hl,(V_33918)
        ld      (V_33948),hl
        ld      hl,(V_NuclearPop)
        ld      (V_safe_NuclearPop),hl
        ld      hl,(V_AirportPop)
        ld      (V_safe_AirportPop),hl
        ld      hl,(V_33914)
        ld      de,(V_33916)
        call    L_div16x16
        ld      a,l
        ld      (V_34013),a
        ret     

V_34013:    defb        0       ;VAR 34013/84dd


; Dosomething with pollution?
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

        ld      hl,(V_33914)
        ld      de,(V_33916)
        call    L_div16x16
        ld      a,l
        srl     a
        srl     a
        ld      (V_34013),a
        ret     


.L850c  ld      hl,minimaps
        ld      de,minimaps+1
        ld      bc,1151
        ld      (hl),0
        ldir    
        ret     

V_34074:    defb        0       ;VAR 34074/851a

; DecTrafficMem - s_sim
DecTrafficMem:
.L851b  ld      hl,minimaps+3456
        ld      bc,2304

.L8521  ld      a,(hl)    
        exx     
        and     a
        jr      z,L8539                 ; (19)
        ld      e,a
        ld      d,0
        ld      hl,(V_33910)
        add     hl,de
        jr      c,L8539                 ; (10)
        ld      (V_33910),hl
        ld      hl,(V_33912)
        inc     hl
        ld      (V_33912),hl

.L8539  exx     
        ld      a,(hl)
        cp      24
        jr      c,L854d                 ; (14)
        cp      200
        jr      c,L8548                 ; (5)
        sub     34
        ld      (hl),a
        jr      L854f                   ; (7)

.L8548  sub     24
        ld      (hl),a
        jr      L854f                   ; (2)

.L854d  ld      (hl),0

.L854f  inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L8521                ; (-52)
        ld      hl,(V_33910)
        ld      de,(V_33912)
        call    L_div16x16
        ld      a,l
        srl     a
        srl     a
        ld      (V_34074),a
        ret     

V_34152:    defb    0       ;VAR 34152/8568
V_34153:    defb    0       ;VAR 34153/8569

.L856a  xor     a
        ld      (V_34152),a
        ld      a,(V_32282)
        and     a
        ret     z

        ld      bc,(V_32043)
        push    bc
        call    levelmap_xypos
        pop     bc
        ld      a,(hl)
        call    tile_to_flags
        and     6
        ld      (V_34153),a
        xor     a
        ld      (V_30461),a
        call    L76fe
        call    L85d6
        ret     c

        ld      a,1
        ld      (V_34152),a
        call    L8599
        ret     


.L8599  ld      a,(V_34153)
        bit     2,a
        ret     z


.L859f  ld      a,(V_30461)
        and     a
        ret     z

        call    L7709
        call    get_traffic_density_value
        ld      a,(hl)
        add     a,20
        jr      c,L85b3                 ; (4)
        cp      240
        jr      c,L85b5                 ; (2)

.L85b3  ld      a,240

.L85b5  ld      (hl),a
        ld      a,5
        ld      (V_31935),a
        ld      ix,31899
        call    L7cc8
        jr      L859f                   ; (-37)
        xor     a
        ld      (V_34152),a
        ld      hl,(V_33890)
        inc     hl
        ld      a,h
        or      l
        jr      z,L85d3                 ; (3)
        ld      (V_33890),hl

.L85d3  ret     

V_34260:    defb    0       ;VAR 34260/85d4
V_34261:    defb    0       ;VAR 34261/85d5


.L85d6  ld      a,5
        ld      (V_34260),a
        xor     a
        ld      (V_34261),a

.L85df  call    L8609
        jr      c,L85ea                 ; (6)
        call    L8660
        ret     nc

        jr      L85f6                   ; (12)

.L85ea  ld      a,(V_30461)
        and     a
        jr      z,L8604                 ; (20)
        dec     a
        ld      (V_30461),a
        jr      L85fd                   ; (7)

.L85f6  ld      hl,V_34261
        ld      a,(hl)
        add     a,1
        ld      (hl),a

.L85fd  ld      a,(V_34261)
        sub     30
        jr      c,L85df                 ; (-37)

.L8604  scf     
        ret     

V_34310:    defb    0       ;VAR 34310/8606
V_34311:    defb    0       ;VAR 34311/8607
V_34312:    defb    0       ;VAR 34312/8608


.L8609  call    get_random_number
        and     3
        ld      (V_34310),a
        ld      a,4
        ld      (V_34312),a

.L8616  ld      a,(V_34310)
        and     3
        ld      (V_34311),a
        ld      hl,V_34260
        cp      (hl)
        jr      z,L8638                 ; (20)
        ld      a,(V_34311)
        call    L76e4                   ;Get cell in direction
        ld      a,(hl)
        bit     7,a
        jr      nz,L8638                ; (9)
        call    tile_to_flags
        ld      hl,V_34153
        and     (hl)
        jr      nz,L8644                ; (12)

.L8638  ld      hl,V_34310
        inc     (hl)
        ld      hl,V_34312
        dec     (hl)
        jr      nz,L8616                ; (-44)
        scf     
        ret     


.L8644  ld      a,(V_34311)
        call    L76ed               ;Move coords in direction
        ld      a,(V_34311)
        add     a,2
        and     3
        ld      (V_34260),a
        ld      a,(V_34261)
        and     1
        call    z,L76fe
        or      a
        ret     

V_34398:    defw    0           ;VAR 34398/865e

;
; Entry: bc = coordinates
; Exit:  bc = coordinate
;         c =
;        nc = 
.L8660  ld      e,4
.L8662  push    de
        ld      a,e
        dec     a
        call    L76e4                   ;Get cell in direction
        call    L768e
        jr      c,L8677                 ; (10)
        ld      hl,V_34398
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
        call    L850c
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
        call    z,L86b7
        cp      1           ;fire
        call    z,L86bf
        dec     hl
.L86ae  inc     hl
        inc     e
        dec     c
        jr      nz,L8694                ; (-31)
        inc     d
        djnz    L8690                   ; (-38)
        ret     


.L86b7  exx     
        ex      af,af'
        call    L7c32           ;Do police influence
        ex      af,af'
        exx     
        ret     


.L86bf  exx     
        call    L7c09           ;Do fire station map
        exx     
        ret     

V_34501: defb    0       ;VAR - powered???
V_34502: defb    0       ;VAR
V_34503: defb    0       ;VAR
V_34504: defb    0       ;VAR

; Process RIC zones
.L86c9  ld      hl,levelmap
        ld      b,96
        ld      d,0
.L86d0  ld      c,96
        ld      e,0
.L86d4  xor     a
        ld      (V_34501),a
        ld      (V_34502),a
        ld      (V_34504),a
        ld      (V_34503),a
        ld      a,(hl)
        and     $e0
        cp      $a0                     ;Grabs $aX and $bX zones - unpowered?
        call    z,set_zone_power_state  ;Check the power for the zone, bit 4,(hl) indicates power
        ld      a,(hl)                  ;$
        cp      $51
        jr      c,L86f3                 ; "Regular tile"
        cp      $57
        call    c,check_ric_power       ;Process RIC
.L86f3  ld      a,(V_33629)             ;?? When does this ever get set?
        and     a
        jr      nz,L8703                ; (10)
        ld      a,(V_34502)
        and     a
        call    nz,L8789
        call    L8898
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
        ld      (V_34502),a
        push    hl
        push    hl
        exx     
        pop     hl
        pop     ix
        ld      a,(ix+1)
        and     63
        ld      (V_34503),a
        cp      6
        jr      z,L8739                 ; (22)
        cp      8
        jr      z,L8739                 ; (18)
        res     4,(hl)
        call    L7615                   ;Get minimap power map+mask
        ld      a,(hl)
        and     e
        jr      z,L8739                 ;Doesn't have power....
        set     4,(ix+0)                ;We've got power!
        ld      a,1
        ld      (V_34501),a
.L8739  exx     
        ret     

V_34619: defb    0   ;VAR


; Process RIC characters
check_ric_power:
.L873c  ld      a,2
        ld      (V_34502),a
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
        ld      (V_34504),a
        ld      (V_34619),a
        push    de
        call    L7615                   ;Get minimap power map+mask
        ld      a,(hl)
        and     e
        pop     de
        jr      z,L8779                 ;No power
        ld      a,e                     ;Set powr flag
        ld      (V_34619),a
        ld      a,1
        ld      (V_34501),a
.L8779  exx     
        ld      a,(V_34619)
        cp      (ix+0)
        ret     z                       ;Power state hasn't changed
        ld      (ix+0),a
.L8784  ret     


V_map_iter_xy: defw    0       ;VAR 34693- map coordinates whilst iterating
V_map_iter_addr: defw    0       ;VAR 34695 - map address whilst iterating


.L8789  ld      (V_map_iter_addr),hl
        ld      (V_map_iter_xy),de
        exx     
        ld      hl,L8789_return
        push    hl
        call    L87aa
        call    L87cc
        ld      a,(V_34502)
        cp      2
        jr      z,L87e4                 ; Handling RIC
        cp      1
        jp      z,L886b                 ; Handling other zones
        pop     hl
L8789_return:
        exx     
        ret     


.L87aa  ld      a,(V_34501)
        and     a
        jr      z,L87bc                 ; (12)
        ld      hl,(V_33888)
        inc     hl
        ld      a,h
        or      l
        jr      z,L87bb                 ; (3)
        ld      (V_33888),hl
.L87bb  ret     


.L87bc  ld      hl,(V_33886)
        inc     hl
        ld      a,h
        or      l
        jr      z,L87c7                 ; (3)
        ld      (V_33886),hl
.L87c7  ret     

V_34760:    defb    0, 255, 0, 255      ;VAR 34760/87c8



.L87cc  ld      a,(V_map_iter_xy)
        ld      hl,V_34760
        call    L87db
        ld      a,(V_map_iter_xy+1)
        ld      hl,V_34760+2
.L87db  cp      (hl)
        jr      c,L87df                 ; (1)
        ld      (hl),a
.L87df  inc     hl
        cp      (hl)
        ret     nc
        ld      (hl),a
        ret     


.L87e4  xor     a
        ld      (V_34921),a
        ld      a,(V_34504)
        cp      84          ;residential powered
        jp      z,L8aa3
        cp      85          ;commercial powered
        jp      z,L8bc4
        cp      86          ;industrial powered
        jp      z,L8c5b
        ret     

; 87fb/34811
; Actions - increasing density etc?
D_34811:
        defw    DoPolice        ;0  police?
        defw    DoFire          ;1  fire
        defw    DoChurch        ;   residential
        defw    DoHospital      ;3
        defw    DoStadium       ;   stadium
        defw    DoCoal          ;5  coal
        defw    DoNuclear       ;   nuclear
        defw    DoPort          ;7  port
        defw    DoAirport       ;   airport
        defw    DoResidential   ;9  residential
        defw    DoCommercial    ;   commercial
        defw    DoIndustrial    ;b


D_34835:
        ;   db XX - compared with 34503
        ;   db index of handler in table above
        ;   db -> 34922
        ;   db -> 34921
        defb    0,0,0,10                ;police
        defb    1,1,0,10                ;fire
        defb    2,2,0,5                 ;church
        defb    3,3,0,10                ;hospital
        defb    4,4,0,$1e               ;stadium
        defb    6,5,0,10                ;coal
        defb    8,6,0,10                ;nuclear
        defb    10,7,0,$1e              ;port
        defb    $0c, $08, $00, $28      ;airport
        defb    $11, $09, $00, $60      ;residential
        defb    $12, $09, $01, $80      ;residential
        defb    $13, $09, $02, $a0      ;residential
        defb    $14, $09, $03, $c0      ;residential
        defb    $15, $0a, $00, $0a      ;commercial
        defb    $16, $0a, $01, $14      ;commercial
        defb    $17, $0a, $02, $1e      ;commercial
        defb    $18, $0a, $03, $28      ;commercial
        defb    $1a, $0b, $00, $10      ;industrial
        defb    $1b, $0b, $01, $20      ;industrial
        defb    $1c, $0b, $02, $30      ;industrial
        defb    $1d, $0b, $03, $40      ;industrial
        defb    $ff, $ff

V_34921:
        defb    $00, $00         ;VAR 8869/34921

;Some zone processing stuff?
.L886b  ld      hl,D_34835
        ld      bc,4
        ld      a,(V_34503)
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
        ld      (V_34921+1),a
        inc     hl
        ld      a,(hl)
        ld      (V_34921),a
        sla     c
        ld      b,0
        ld      hl,D_34811
        add     hl,bc
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        jp      (hl)

.L8898  ld      a,(hl)
        cp      128
        ret     nc

        ld      (V_map_iter_addr),hl
        ld      (V_map_iter_xy),de
        exx     
        ld      hl,L8898_return
        push    hl
        cp      TILE_RADIOACTIVE
        jp      z,L8942
        cp      69
        jp      z,L8962
        cp      68          ;Max residential
        jp      z,L8986
        call    tile_to_flags
        bit     2,a
        jr      nz,L88c6                ; (8)
        bit     1,a
        jr      nz,L8903                ; (65)
        pop     hl
L8898_return:
        exx     
        ret     

V_35013:    defb    $FF         ;VAR 35013/88c5

.L88c6  ld      hl,V_35013
        ld      a,(hl)
        inc     a
        jr      z,L88d4                 ; (7)
        call    get_random_number
        and     (hl)
        jp      z,L8956

.L88d4  ld      hl,(V_RailTotal)
        inc     hl
        ld      a,h
        or      l
        jr      z,L88df                 ; (3)
        ld      (V_RailTotal),hl

.L88df  ld      hl,(V_33892)
        inc     hl
        ld      a,h
        or      l
        jr      z,L88ea                 ; (3)
        ld      (V_33892),hl

.L88ea  ld      hl,(V_map_iter_addr)
        ld      a,(hl)
        cp      19
        jr      z,L88f5                 ; (3)
        cp      18
        ret     nz


.L88f5  ld      hl,(V_33892)
        ld      de,3
        add     hl,de
        jr      c,L8901                 ; (3)
        ld      (V_33892),hl

.L8901  ret     

V_35074:    defb    0       ;VAR 35704/8902

.L8903  ld      hl,V_35074
        ld      a,(hl)
        inc     a
        jr      z,L8910                 ; (6)
        call    get_random_number
        and     (hl)
        jr      z,L8956                 ; (70)

.L8910  ld      hl,(V_RoadTotal)
        inc     hl
        ld      a,h
        or      l
        jr      z,L891b                 ; (3)
        ld      (V_RoadTotal),hl

.L891b  ld      hl,(V_33892)
        ld      de,4
        add     hl,de
        jr      c,L8927                 ; (3)
        ld      (V_33892),hl

.L8927  call    L785d
        ld      hl,(V_map_iter_addr)
        ld      a,(hl)
        cp      32
        jr      z,L8935                 ; (3)
        cp      31
        ret     nz


.L8935  ld      hl,(V_33892)
        ld      de,6
        add     hl,de
        jr      c,L8941                 ; (3)
        ld      (V_33892),hl

.L8941  ret     


; Decay radioactive?
.L8942  call    get_random_number
        ld      hl,(V_random_seed)
        ld      a,h
        and     15
        or      l
        jr      z,L8956                 ; (8)
        ld      a,64
        ld      (V_31935),a
        jp      L7cc0

.L8956  ld      hl,(V_map_iter_addr)
        ld      (hl),58
        ret     

place_dirt:
.L895c  ld      hl,(V_map_iter_addr)
        ld      (hl),TILE_DIRT
        ret     


.L8962  ld      hl,(V_33918)
        inc     hl
        ld      a,h
        or      l
        jr      z,L896d                 ; (3)
        ld      (V_33918),hl

.L896d  call    L7591
        inc     a
        ld      b,a
        call    get_random_number
        and     15
        cp      b
        jr      c,L8956                 ; (-36)
        ld      a,69
        ld      (V_35224),a
        xor     a

.L8980  ld      (V_35225),a
        jr      L899b                   ; (22)

V_35205:  defb    $32         ;VAR 8985/35205

.L8986
        ld      hl,V_35205
        ld      a,(hl)
        and     a
        jr      z,place_dirt                 ; (-49)
        dec     (hl)
        ld      a,68
        ld      (V_35224),a
        ld      (V_35225),a
        jr      L899b                   ; (3)

V_35224:    defb    0       ;VAR 35224/8998
V_35225:    defb    0       ;VAR 35225/8999
V_35226:    defb    0       ;VAR 35226/899a

.L899b  xor     a
        ld      (V_35226),a
        ld      e,4
.L89a1  push    de
        ld      bc,(V_map_iter_xy)
        ld      a,e
        dec     a
        call    L76ed               ;Move coords in direction
        call    levelmap_xypos
        jr      nc,L89d3                ; (35)
        ld      a,(V_35225)
        and     a
        jr      nz,L89c2                ; (12)
        ld      a,(hl)
        cp      128
        jr      nc,L89c2                ; (7)
        call    tile_to_flags
        bit     7,a
        jr      z,L89d3                 ; (17)
.L89c2  ld      a,(V_35226)
        inc     a
        ld      (V_35226),a
        call    get_random_number
        and     7
        jr      nz,L89d3                ; (3)
        call    L89ea
.L89d3  pop     de
        dec     e
        jr      nz,L89a1                ; (-54)
        ld      a,(V_35225)
        and     a
        ret     nz
        call    get_random_number
        and     3
        ret     nz
        ld      a,(V_35226)
        and     a
        jp      z,L8956
        ret     


.L89ea  ld      a,(V_35225)
        and     a
        jr      z,L89f3                 ; (3)
        ld      a,(hl)
        and     a
        ret     z
.L89f3  bit     7,(hl)
        jp      nz,L7b86
        push    hl
        ld      hl,D_29291
        ld      bc,8
        cpir    
        pop     hl
        ret     z
        ld      a,(V_35224)
        ld      (hl),a
        ret     


D_35336:
;8a08
        defb    $FF, $FF, $49, $FF, $00, $4A, $FF, $01
        defb    $4B, $00, $FF, $50, $00, $01, $4C, $01
        defb    $FF, $4F, $01, $00, $4E, $01
        
        
        defb    $01, $4D


.L8a20  call    get_random_number
        and     7
        ld      c,a
        add     a,a
        add     a,c
        ld      c,a
        ld      b,0
        ld      ix,D_35336
        add     ix,bc
        ld      a,(V_map_iter_xy)
        add     a,(ix+1)
        ld      c,a
        ld      a,(V_map_iter_xy+1)
        add     a,(ix+0)
        ld      b,a
        ret     


.L8a40  ld      a,(V_36711)
        cp      255
        ret     z

        ld      b,a

.L8a47  push    bc
        call    L8a20
        call    L8a53
        pop     bc
        ret     nc
        djnz    L8a47                   ; (-11)
        ret     


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


.L8a70  ld      a,(V_36711)
        cp      255
        ret     z
        ld      b,a
.L8a77  push    bc
        call    L8a20
        call    L8a83
        pop     bc
        ret     nc
        djnz    L8a77                   ; (-11)
        ret     


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
        call    L7d34
        ld      hl,(V_ResZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8ab7                 ; (3)
        ld      (V_ResZPop),hl

.L8ab7  ld      a,(V_34921)
        ld      e,a
        ld      d,0
        call    L82ee                   ;Adds de to (33859..61)
        ld      a,(V_32282)
        ld      (V_34152),a
        call    get_random_number
        and     63
        ld      hl,V_34921
        sub     (hl)
        jr      nc,L8ada                ; (9)
        ld      hl,$0a0b
        ld      (V_34398),hl
        call    L856a                   ;Some transport check?
.L8ada  call    L7cfe
        ld      hl,(V_33404)
        ld      (V_32450),hl
        call    L7f12
        ld      a,(V_34921)
        cp      16
        jr      c,L8aed                 ; (0) BUG?? L8afe makes more sense?
.L8aed  ld      a,(V_34921)
        cp      63
        jr      nc,L8afe                ; (10)
        ld      hl,V_32529
        cp      (hl)
        jp      c,L8a40
        jp      L8a70


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
        jp      L75b0

.L8b17  xor     a
        ld      (V_hospital_demand),a
        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      de,27
        jp      L75b0

.L8b27  xor     a
        ld      (V_church_demand),a
        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      de,18
        jp      L75b0

DoResidential:
L8b37:
        ld      hl,(V_ResZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8b42                 ; (3)
        ld      (V_ResZPop),hl
.L8b42  ld      bc,(V_map_iter_xy)
        call    L7d34
        ld      a,(V_34921)
        ld      e,a
        ld      d,0
        call    L82ee
        ld      a,(V_32282)
        ld      (V_34152),a
        call    get_random_number
        and     127
        ld      hl,V_34921
        sub     (hl)
        jr      nc,L8b6c                ; (9)
        ld      hl,$0a0b
        ld      (V_34398),hl
        call    L856a
.L8b6c  call    L7cfe
        ld      a,(V_33404)
        ld      (V_32450),a
        call    L7f12
        call    get_random_number
        ld      hl,V_36711+1
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_32528)
        cp      8
        jr      nc,L8ba9                ; (30)
        srl     a
        ld      bc,(V_map_iter_xy)
        ld      de,136
        jp      L75b0

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

D_35770:
        defb    $00, $00, $01, $01, $01, $02
        defb    $02, $03, $03, $03
        

.L8bc4  ld      hl,(V_ComZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8bcf                 ; (3)
        ld      (V_ComZPop),hl

.L8bcf  ld      a,(V_34501)
        and     a
        ret     z

        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      (V_map_iter_xy),bc
        jr      L8beb                   ; (11)

DoCommercial:
L8be0:
        ld      hl,(V_ComZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8beb                 ; (3)
        ld      (V_ComZPop),hl
.L8beb  ld      bc,(V_map_iter_xy)
        call    L7d34
        ld      a,(V_32282)
        ld      (V_34152),a
        call    get_random_number
        and     31
        ld      hl,V_34921
        sub     (hl)
        jr      nc,L8c0c                ; (9)
        ld      hl,$090b
        ld      (V_34398),hl
        call    L856a
.L8c0c  call    L7cfe
        ld      hl,(V_33406)
        ld      (V_32450),hl
        call    L7f45
        call    get_random_number
        ld      hl,V_36711+2
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_32579)
        call    L8ce0
        cp      0
        jr      z,L8c4a                 ; (28)
        dec     a
        ld      c,a
        ld      b,0
        ld      hl,D_35770
        add     hl,bc
        ld      a,(hl)
        ld      bc,(V_map_iter_xy)
        ld      de,172
        jp      L75b0

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

.L8c66  ld      a,(V_34501)
        and     a
        ret     z

        ld      bc,(V_map_iter_xy)
        dec     b
        dec     c
        ld      (V_map_iter_xy),bc
        jr      L8c82                   ; (11)


; Process an industrial zone
DoIndustrial:
L8c77:
        ld      hl,(V_IndZPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8c82                 ; (3)
        ld      (V_IndZPop),hl

.L8c82  ld      bc,(V_map_iter_xy)
        call    L7d34
        ld      a,(V_32282)
        ld      (V_34152),a
        call    get_random_number
        and     63
        ld      hl,V_34921
        sub     (hl)
        jr      nc,L8ca3                ; (9)
        ld      hl,$0909
        ld      (V_34398),hl
        call    L856a

.L8ca3  ld      hl,(V_33408)
        ld      (V_32450),hl
        xor     a
        ld      (V_32447),a
        call    L7f5f
        call    get_random_number
        ld      hl,V_36711+1
        and     (hl)
        jr      nz,L8cd5                ; (28)
        ld      a,(hl)
        cp      255
        jr      z,L8cd5                 ; (23)
        ld      a,(V_32605)
        call    L8ce0
        cp      0
        jr      z,L8cfa                 ; (50)
        dec     a
        srl     a
        ld      bc,(V_map_iter_xy)
        ld      de,208
        call    L75b0

.L8cd5  ld      a,(V_32605)
        add     a,a
        add     a,a
        ld      (V_31935),a
        jp      L7cc0

.L8ce0  push    af
        ld      hl,V_36490
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
        ld      (V_32450),a
        ld      (V_32447),a
        ld      (V_32283),a
        inc     a
        ld      (V_34152),a
        call    L7ec4
        ld      a,255
        ld      (V_31935),a
        jp      L7cc0

DoNuclear:
L8d2f:
        ld      hl,(V_NuclearPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8d3a                 ; (3)
        ld      (V_NuclearPop),hl

.L8d3a  xor     a
        ld      (V_32450),a
        ld      (V_32447),a
        ld      (V_32283),a
        inc     a
        ld      (V_34152),a
        call    L7ec4
        call    place_fallout
        ld      a,48
        ld      (V_31935),a
        jp      L7cc0

DoPolice:
L8d56:
        ld      hl,(V_PoliceFund)
        ld      de,100
        add     hl,de
        jr      c,L8d62                 ; (3)
        ld      (V_PoliceFund),hl
.L8d62  ld      a,(V_34501)
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
.L8d7f  ld      a,(V_34501)
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
        ld      hl,V_36711
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_34501)
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
        ld      hl,V_36711+1
        and     (hl)
        ret     nz
        ld      a,(hl)
        cp      255
        ret     z
        ld      a,(V_34501)
        and     a
        jr      nz,L8dd9                ; TODO: OPT
        ld      ix,residential_zone_2
        jp      sim_place_zone_3x3

.L8dd9  ret     

DoStadium:
L8dda:
        ld      a,(V_34501)
        and     a
        ret     z
        ld      bc,(V_map_iter_xy)
        ld      hl,$0404
        call    L7d2f
        ld      a,(V_32282)
        and     a
        ret     z
        ld      (V_34152),a
        ld      hl,$0909
        ld      (V_34398),hl
        call    get_random_number
        and     31
        call    z,L856a
        ld      a,(V_34152)
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
        ld      a,(V_34501)
        and     a
        ret     z
        ld      bc,(V_map_iter_xy)
        ld      hl,$0404
        call    L7d2f
        ld      a,(V_32280)
        and     a
        ret     z
        ld      a,(V_32282)
        and     a
        ret     z
        ld      (V_34152),a
        ld      hl,$0b0b
        ld      (V_34398),hl
        call    get_random_number
        and     31
        call    z,L856a
        ld      a,(V_34152)
        and     a
        ret     z
        ld      hl,(V_PortPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8e4a                 ; (3)
        ld      (V_PortPop),hl
.L8e4a  ld      a,96
        ld      (V_31935),a
        jp      L7cc0

DoAirport:
L8e52:
        ld      a,(V_34501)
        and     a
        ret     z
        ld      bc,(V_map_iter_xy)
        ld      hl,$0606
        call    L7d2f
        ld      a,(V_32282)
        and     a
        ret     z
        ld      (V_34152),a
        ld      hl,$0a0a
        ld      (V_34398),hl
        call    get_random_number
        and     31
        call    z,L856a
        ld      a,(V_34152)
        and     a
        ret     z
        ld      hl,(V_AirportPop)
        inc     hl
        ld      a,h
        or      l
        jr      z,L8e87                 ; (3)
        ld      (V_AirportPop),hl
.L8e87  jp      L78ca


V_36490:        defb    0,0,0        ;VAR 36490/8e8a
V_36493:        defb    0,0,0        ;VAR 36493/8e8d
V_population:   defb    0,0,0   ;VAR 8e90/36496 - population



; Simulation stops whilst waiting for budget confirmation, this variable is checked
.V_wait_for_budget_confirm defb    0   ;VAR 8e93/36499 - set waiting for budget to complete


; Think this triggers in November for the budget?
.DoBudget
.L8e94  
        ld      hl,(V_33859)
        ld      a,(V_33859+2)
        ld      c,a
        ld      (V_36490),hl
        ld      a,c
        ld      (V_36490+2),a
        ld      a,(V_month)
        cp      11
        ret     nz
        ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      (V_36493),hl
        ld      a,c
        ld      (V_36493+2),a
        ld      hl,(V_33859)
        ld      a,(V_33859+2)
        ld      c,a
        ld      (V_population),hl
        ld      a,c
        ld      (V_population+2),a
        ld      hl,(V_33892)
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
        jr      L8eef                   ; (6)

.L8ee9  call    L9329
        call    L9358

.L8eef  ld      hl,(V_money_after_budget)
        ld      a,(V_money_after_budget+2)
        ld      c,a
        ld      (V_money),hl
        ld      a,c
        ld      (V_money+2),a
        call    L952a
        ret     


V_36609:    defb    0       ;VAR 36609/8f01 - crime concern
V_36610:    defb    0       ;VAR 36610/8f01 - house price concern

V_36611:    defw    0       ;VAR 36611/8f03 


.L8f05  ld      hl,(V_33902)
        ld      de,(V_33904)
        call    L_div16x16
        ld      a,l
        add     a,a
        ld      (V_36609),a       ;Police factor
        ld      hl,(V_33906)
        ld      de,(V_33908)
        call    L_div16x16
        ld      a,l
        srl     a
        srl     a
        srl     a
        ld      (V_36610),a       ;House price concern
        ld      hl,(V_33890)
        ld      (V_36611),hl
        ret     


V_hospital_demand:    defb    0       ;VAR 36655/8f2f - hopsital demand
V_church_demand:    defb    0       ;VAR 36656/8f30 - church demand

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

; Setup the simulation speed
V_36711:  defb    $08, $07, $07, $07, $01     ;VAR 36711

;8f6c, 36716
D_8f6c:
    ;+0
    ;+1
    ;+2
    ;+3
    ;+4 = simulation iterations per month?
        defb    $08, $01, $0f, $01, $00     ;FAST
        defb    $04, $03, $1f, $03, $01     ;NORMAL
        defb    $03, $07, $3f, $07, $03     ;SLOW
        defb    $ff, $ff, $ff, $ff, $ff     ;PAUSED
        

.set_simulation_speed
.L8f80  ld      a,(V_simulation_speed)       ;simulation speed (from menu)
        ld      b,a
        add     a,a         ;*5
        add     a,a
        add     a,b
        ld      c,a
        ld      b,0
        ld      hl,D_8f6c
        add     hl,bc
        ld      de,V_36711
        ld      bc,5
        ldir    
        ret     

; We have a few variables here 7 I think

V_money:       defb  0,0,0   ; VAR - money!! - 8f99
            defb    0       ;UNUSED
V_month:     defb  0       ; VAR 36763 (8f9b) - Month
V_year:      defw  1902    ; VAR 36764 (8f9c) - Year
V_8f9e:      defb  0       ;VAR 36766/8f9e
V_36767:      defb  0       ;VAR 36767 - tick counter for ui thread



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
        call    L67c3
        call    L6944
        call    create_landscape
        call    draw_map
        ld      a,57
        ld      (textcol),a

.L8fcc  call    prpointer
        call    L5d55
        ld      bc,2000
.L8fd5  dec     bc
        ld      a,b
        or      c
        jr      nz,L8fd5                ; (-5)
        call    L5d55
        call    blankpointer
        call    L635c
        call    L778f
        call    L63cd
        ld      a,1
        ld      (V_simulation_disabled),a
        call    L6434
        call    L7a6f
        xor     a
        ld      (V_simulation_disabled),a
        call    L901d
        call    L6d2d
        call    L9058
        ld      a,(V_wait_for_budget_confirm)
        and     a
        call    nz,show_budget
        ld      hl,V_36767
        inc     (hl)
        ld      a,(V_show_mini_maps)
        and     a
        call    nz,show_mini_maps
        ld      a,(keystore+6)
        and     1       ;'ENTER'
        call    z,show_mini_maps
        jr      L8fcc                   ; (-81)

.L901d  ld      a,(V_36767)
        and     31
        call    z,display_alert_message
        ld      a,(V_36767)
        and     15
        call    z,L904d
        ld      a,(V_36767)
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


.L904d  call    L787e
        call    L7998
        jp      L77dc

.V_36950        defw        0        ;VAR - unknown

.L9058  ld      de,(V_money)
        ld      hl,(V_36950)
        and     a
        sbc     hl,de
        ret     z
        ld      (V_36950),de
        call    doicons
        jp      L6d90


; Animation by copying the udgs
; Flood
change_flood_tile:
.L906d  ld      de,60560                ;udg 69
        ld      hl,60728
        call    get_random_number
        and     3
        ld      b,a
        ld      a,(V_36767)
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
        ld      a,(V_36767)
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
        call    L9108
.L90af  ld      hl,levelmap
        ld      bc,9216
.L90b5  call    get_random_number
        and     127
        call    z,L90c4
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,L90b5                ; (-14)
        ret     
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
        call    L9116
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
        ld      (V_35205),a
        ret     


.L9108  ld      b,127
.L910a  push    bc
        ld      a,b
        and     63
        ld      e,a
        call    soundfx1
        pop     bc
        djnz    L910a                   ; (-11)
        ret     


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


V_disaster_option:  defb       $0   ;VAR 916d/37229 - which disasters are enabled

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
        call    L9329
        call    L9358
        ld      hl,37702        ;TODO - in budget screen

.L91a2  ld      (V_26496),hl
        ld      ix,text_budget
        call    print_routine_ix
        ld      hl,0
        ld      (V_26496),hl
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

V_tax_collected:    defb    0,0,0       ;VAR 37646, 930e


V_Transport_Funding_Requested:                    defw        0   ;VAR 37649/9311 - budget, transport funding
V_Budget_Police_Funding_Requested:    defw        0   ;VAR 37651  - budget how much police funding
V_Budget_Fire_Funding_Requested:      defw        0   ;VAR 37653  - budget how much fire funding
   
V_Transport_Funding_Allocated:  defw    0       ;VAR 37655/9317 
V_Police_Funding_Allocated:  defw    0       ;VAR 37657/9319 
V_Fire_Funding_Allocated:  defw    0       ;VAR 37659/931a 


V_expenditure:  defb    0,0,0           ;VAR 37661/931d - how much we spent this budget

V_cashflow:        defb    0,0,0       ;VAR 37664/9320 - cashflow


V_previous_money:        defb    0,0,0           ;VAR 37667/9323 previous money before budget
V_money_after_budget:            defb    0,0,0           ;VAR 37670/9326 money after budget


.L9329  ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      a,100
        call    L66b6
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
        call    L9358
        call    print_budget_amounts
        ld      a,69

.L9353  ld      (textcol),a
        ret     

        nop     

.L9358  ld      hl,(V_money)
        ld      a,(V_money+2)
        ld      c,a
        ld      (V_previous_money),hl
        ld      a,c
        ld      (V_previous_money+2),a
        call    L937c
        call    L9389
        call    L9396
        call    L93f9
        call    L9429
        call    L9462
        call    L93a3
        ret     


.L937c  ld      a,(SMC_transport_percent)
        ld      hl,(V_Transport_Funding_Requested)
        call    L94ff
        ld      (V_Transport_Funding_Allocated),hl
        ret     


.L9389  ld      a,(SMC_police_percent)
        ld      hl,(V_Budget_Police_Funding_Requested)
        call    L94ff
        ld      (V_Police_Funding_Allocated),hl
        ret     


.L9396  ld      a,(SMC_fire_percent)
        ld      hl,(V_Budget_Fire_Funding_Requested)
        call    L94ff
        ld      (V_Fire_Funding_Allocated),hl
        ret     


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

V_37878:    defb   0,0,0       ;VAR 37878/93f6


.L93f9  ld      hl,(V_previous_money)
        ld      a,(V_previous_money+2)
        ld      c,a
        ld      de,(V_tax_collected)
        ld      a,(V_tax_collected+2)
        ld      b,a
        call    l_add24
        ld      (V_37878),hl
        ld      a,c
        ld      (V_37878+2),a
        ld      de,(V_Transport_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z
        ld      hl,(V_37878)
        ld      a,(V_37878+2)
        ld      c,a
        ld      (V_Transport_Funding_Allocated),hl
        ret     


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
        ld      (V_37878),hl
        ld      a,c
        ld      (V_37878+2),a
        ld      de,(V_Police_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z
        ld      hl,(V_37878)
        ld      a,(V_37878+2)
        ld      c,a
        ld      (V_Police_Funding_Allocated),hl
        ret     


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
        ld      (V_37878),hl
        ld      a,c
        ld      (V_37878+2),a
        ld      de,(V_Fire_Funding_Allocated)
        ld      b,0
        call    l_sub24
        bit     7,c
        ret     z

        ld      hl,(V_37878)
        ld      a,(V_37878+2)
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


.L94ff  ld      e,a
        ld      d,0
        call    L_mult_24_16x16
        ld      a,100
        jp      L66b6


;950a/38154
D_38154:
        defb    $0F, $1F, $1F, $3F, $3F, $7F, $7F, $FF
        defb    $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF

D_38170:
        defb    $00, $03, $06, $07, $08, $0A, $0C, $0F
        defb    $0F, $0F, $0F, $0F, $0F, $0F, $0F, $0F
        

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
        ld      hl,D_38154
        add     hl,bc
        ld      a,(hl)
.L9555  ld      (V_35013),a
        ld      (V_35074),a
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
        ld      hl,D_38170
        add     hl,bc
        ld      a,(hl)

.L9586  ld      (V_31793),a
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
        ld      hl,D_38170
        add     hl,bc
        ld      a,(hl)

.L95b4  ld      (V_31752),a
        ret     

; Evaluation?
show_evaluation:
L95b8:
        ld      a,1
        ld      (V_simulation_disabled),a
        ld      hl,print_stats        
        ld      (V_26496),hl
        ld      ix,text_evaluation    
        call    print_routine_ix
        ld      hl,0
        ld      (V_26496),hl
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
        defm        "  Taxes 000% House Prices 000"
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
        defm        "CATEGORY   :"
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
print_stats:
.L9737
        call    determine_city_class    ;VILLAGE, TOWN etc etc
        call    print_evaluation_stats
        ld      hl,V_36490
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
D_population_boundaries:
        defb    $d0, $07, $00       ;2000
        defb    $10, $27, $00       ;10000
        defb    $50, $c3, $00       ;50000
        defb    $a0, $86, $01       ;100000
        defb    $20, $a1, $07       ;500000

V_citysize:     defb    0       ;VAR 975f/38751 - city size

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


V_38799:    defb    0,0,0       ;VAR 38799/978f  - migration

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
        ld      hl,V_36490
        ld      bc,$0f14
        call    prt24bit
        ld      hl,(V_population)
        ld      a,(V_population+2)
        ld      c,a
        ld      de,(V_36493)
        ld      a,(V_36493+2)
        ld      b,a
        call    l_sub24
        ld      (V_38799),hl
        ld      a,c
        ld      (V_38799+2),a
        ld      hl,V_38799        ;Migration?
        ld      bc,$1014
        call    prt24bit
        ld      hl,V_previous_city_score        ;Assessed value (*1000)
        ld      bc,$1114
        call    prt24bit
        ld      hl,(V_26019)
        ld      (textpos),hl
        call    L97f8           ;Print 3 trailing 0s to multiply by 1000
        call    L97f8

.L97f8  ld      a,48
        call    prchar
        call    incprpos
        ret     

.V_38913        defw        0        ;VAR - unknown

print_evaluation_concerns:
.L9803  ld      a,(V_34074)           ;Traffic concern
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        ld      (V_38913),hl
        ld      bc,$0A09
        call    prstat
        ld      a,(V_34013)           ;Pollution concern
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0a16
        call    prstat
        pop     hl                  
        ld      de,(V_38913)
        add     hl,de
        ld      (V_38913),hl
        ld      a,(V_36609)           ;Crime concern
        srl     a
        srl     a
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0b09
        call    prstat
        pop     hl
        ld      de,(V_38913)
        add     hl,de
        ld      (V_38913),hl
        ld      a,(V_33948)           ;Fire concern
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
        ld      de,(V_38913)
        add     hl,de
        ld      (V_38913),hl
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
        ld      de,(V_38913)
        add     hl,de
        ld      (V_38913),hl
        ld      a,(V_36610)           ;House prices concern
        ld      l,a
        ld      h,0
        call    ckpercent
        push    hl
        ld      bc,$0c1b
        call    prstat
        pop     hl
        ld      de,(V_38913)
        add     hl,de
        ld      (V_38913),hl
        ld      hl,(V_33381)          ;Unemployment concern
        call    ckpercent
        push    hl
        ld      bc,$0d1b
        call    prstat
        pop     hl
        ld      de,(V_38913)
        add     hl,de
        ld      (V_38913),hl
        ld      de,(V_33886)
        srl     d
        rr      e
        srl     d
        rr      e
        ld      hl,(V_38913)
        add     hl,de
        ld      (V_38913),hl
        ld      de,0
        ld      a,(V_alertmessage)
        and     a
        jr      z,L98dc                 ; (3)
        ld      de,4
.L98dc  ld      hl,(V_38913)
        add     hl,de
        ld      (V_38913),hl
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

.V_39162        defw        0        ;VAR - unknown

print_city_score:
.L98fc  ld      hl,(V_38913)
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
        call    L9919
        ld      (V_39162),hl
        ld      bc,$150F
        call    prt16bit
        ret     


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

V_mayor_rating: defb    0,0         ;VAR 39215/992f - mayor rating, db yes, db no


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
        ld      de,(V_39162)
        and     a
        sbc     hl,de
        jr      nc,L9951                ; (5)
        ld      hl,V_mayor_rating
        jr      L9954                   ; (3)

.L9951  ld      hl,V_mayor_rating+1
.L9954  inc     (hl)
        djnz    L9939                   ; (-30)
        ld      a,(V_mayor_rating)       ;Yes good job
        ld      l,a
        ld      h,0
        ld      bc,$050c
        call    L998b
        ld      a,(V_mayor_rating+1)       ;No bad job
        ld      l,a
        ld      h,0
        ld      bc,$060c
        call    L998b
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


.L998b  push    hl
        call    xypos
        ld      (textpos),hl
        pop     hl
        jp      prhund


V_alertmessage: defb    0       ;VAR 9996/39318 - alert message

.display_alert_message
.L9997  ld      a,(V_alertmessage)
        add     a,23
        ld      hl,text_table
        call    get_word_from_table
        ld      a,29
        ld      bc,$0601
        jp      print_string
        nop     


V_TotalZPop:    defw    0       ;VAR 99ab/39339 - TotalZPop used for sending alert messages


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

        ld      hl,V_36490
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
        ld      de,(V_RailTotal)
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
        ld      de,(V_RoadTotal)
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
        ld      de,19
        and     a
        sbc     hl,de
        ld      a,11
        jp      nc,set_alert_message

.L9ad2  ld      a,(SMC_tax_rate)
        cp      12
        ld      a,12                    ;Taxes too high
        jp      nc,set_alert_message


        ld      hl,(V_RoadTotal)
        ld      de,(V_RailTotal)
        add     hl,de
        ld      a,h
        or      l
        jr      z,L9af2                 ; (10)
        ld      a,(V_35013)
        cp      255
        ld      a,13
        jp      nz,set_alert_message

.L9af2  ld      hl,(V_FirePop)
        ld      a,h
        or      l
        jr      z,L9b03                 ; (10)
        ld      a,(V_31752)
        cp      15
        ld      a,14
        jp      nz,set_alert_message

.L9b03  ld      hl,(V_PolicePop)
        ld      a,h
        or      l
        jr      z,L9b14                 ; (10)
        ld      a,(V_31793)
        cp      15
        ld      a,15
        jp      nz,set_alert_message

.L9b14  ld      hl,(V_33886)
        ld      de,10
        and     a
        sbc     hl,de
        ld      a,16
        jp      nc,set_alert_message
        ld      a,(V_brownout_detected)
        and     a
        ld      a,17            ;BROWNOUT DETECTED
        jp      nz,set_alert_message

        ld      a,(V_34013)
        cp      60
        ld      a,19
        call    nc,set_alert_message
        ld      a,(V_36609)
        cp      20

.L9b3a  ld      a,20
        call    nc,set_alert_message
        ld      a,(V_34074)
        cp      60
        ld      a,21
        call    nc,set_alert_message
        ret     


set_alert_message:
.L9b4a  ld      (V_alertmessage),a
        ret     

; 39758/9b4e
D_39758:
        defb    $4, $3
        defb    $4, $4
        defb    $4, $5
        defb    $5, $3
        defb    $5, $4
        defb    $5, $5
        defb    $6, $3
        defb    $6, $4
        defb    $6, $5


.L9b60  ld      a,(V_minimap_section)
        add     a,a
        ld      c,a
        ld      b,0
        ld      hl,D_39758
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


.L9b8b  ld      a,(V_31568)
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
.L9bd6  ld      de,16392            ;SMC, screen address of road tile
        inc     hl
        call    L9bf9
        inc     d
        call    L9bf9
        inc     d
        call    L9bf9
        inc     d
        jr      L9bf9                   ; (17)

.L9be8  ld      hl,V_current_zone_width_to_print
        dec     (hl)
        ld      hl,(V_left_tile_index)
        add     hl,hl
        add     hl,hl
        add     hl,hl
        ld      de,udgs + 1288
        add     hl,de
        jr      L9bd6                   ; (-34)


        nop     


; This does the traffic effect for roads?
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
        ld      a,(V_39984)
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
V_minimap_section:    defb        0       ;VAR 9c2b/39979 - selected minimap quadrant

        nop     
        nop     

V_39982:        defw    0       ;VAR 39982/9c2e

V_39984:        defb    0       ;VAR 39984/9c30
V_minimap_xy:    defw    0       ;VAR 9c31/39985 - xypos in minimap being printed


; Address within the levelmap that 0-8 keys correspond to

;39987
D_minimap_offsets:
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


.L9c57  ld      hl,16392
        ld      (SMC_39894+1),hl
        xor     a
        ld      (V_39984),a
        ld      a,16
        ld      (V_25651),a
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
        ld      (V_39982),bc
        ld      a,b
        ld      (V_minimap_xy+1),a
        ex      de,hl
        ld      b,48

.L9c86  ld      de,(SMC_39894+1)
        push    de
        ld      a,(V_39982)
        ld      (V_minimap_xy),a
        ld      c,48

.L9c93  ld      a,(V_current_zone_width_to_print)
        and     a
        jr      nz,L9c9f                ; (6)
        ld      a,(hl)
        cp      128
        call    nc,L655b

.L9c9f  ld      (V_25865),hl
        exx     
        call    L9bc3                   ;Mark traffic on the map
        ld      c,33                    ;White paper, blue ink
        call    L9d0c                   ;Set attribute
        call    check_if_minimaps_should_be_displayed
        ld      hl,V_39984
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
D_40186:
        defb    $00, $49, $52, $5b, $64, $6d, $76, $7f

; Print the attribute intensity for a zone
; Eg: Pollution, traffic, Crime, pollution, police, fire
do_minimap_attr_intensity:
.L9d02  and     a
        ret     z
        ld      c,a
        ld      b,0
        ld      hl,D_40186
        add     hl,bc
        ld      c,(hl)
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


.L9d1a  ld      d,15
        ld      b,160
        ld      c,80
        ld      a,(V_39984)
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

V_minimap_selection_index:  defb    $06     ;VAR 9d43/40259 - which minimap is selected


check_if_minimaps_should_be_displayed:
.L9d44
        ld      a,$43
        sbc     l
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
.L9d7f  ld      hl,(V_25865)
        ld      a,(hl)
        call    tile_to_flags
        bit     4,a
        ret     z
        ld      bc,(V_minimap_xy)
        call    L7e03
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
        call    L7589
        ld      d,a
        ld      a,e
        sub     d
        jr      nc,L9db1                ; (1)
        xor     a
.L9db1  srl     a
        call    L9d02
        ret     


.do_minimap_power  
        ld      bc,(V_minimap_xy)
        call    get_power_map_addr
        ld      a,(hl)
        and     e
        ret     z
        jp      L9d1a

.do_minimap_transport  
.L9dc4
        ld      hl,(V_25865)
        ld      a,(hl)
        call    tile_to_flags
        and     6
        ret     z
        ld      a,5
        jp      L9d1a


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
        jp      L9d02

.do_minimap_fire  
        ld      hl,minimaps
        jr      L9dfa                   ; (3)

.do_minimap_police  
        ld      hl,minimaps+576
.L9dfa  ld      (V_minimap_start),hl
        ld      bc,(V_minimap_xy)
        call    minimap_xypos_25
        srl     a
        jp      L9d02

; Save?
;9e09
action_save:
        call    menu_enter_filename
        ld      bc,$100c
        ld      (V_input_xy),bc
        ld      hl,V_tapeheader            
        ld      (V_42714),hl  ;destination for string
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
        call    Lf7aa
        ld      b,30
        call    pause5000
        ld      ix,levelmap
        ld      de,9216
        ld      a,255
        scf     
        call    Lf7aa
        xor     a
        out     (254),a
        ei      
        ret     

action_load:
        call    menu_enter_filename
        ld      bc,$100C
        ld      (V_input_xy),bc
        ld      hl,V_load_filename
        ld      (V_42714),hl
        call    input_string
        di      
        call    cls_white        ;why?!?!?
        call    cls_black
        call    prt_ctrl
        defb        T_BOX,0,0,32,24
        defb        T_SETXY,8,11
        defm        "SEARCHING"
        defb        T_END
L9e89:
        ld      ix,V_tapeheader
        ld      de,31   ;12 char filename, 7b money, 12b something else
        ld      a,255
        scf     
        call    load
        jr      nc,L9f0c                ; (116)
        call    L9f1a
        ld      hl,V_load_filename
        ld      b,12

.L9ea0  ld      a,(hl)
        cp      32
        jr      nz,L9eaa                ; (5)
        inc     hl
        djnz    L9ea0                   ; (-8)
        jr      L9ebe                   ; (20)

.L9eaa  ld      hl,V_tapeheader
        ld      ix,V_load_filename
        ld      b,12

.L9eb3  ld      a,(hl)
        cp      (ix+0)
        jr      nz,L9e89                ; (-48)
        inc     ix
        inc     hl
        djnz    L9eb3                   ; (-11)

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


.L9f1a  call    prt_ctrl
        defb        T_SETXY,8,9
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

.V_power_type_chosen        defb        0        ;VAR - which power station has been chosen

menu_power:
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

action_power_nuclear:   
.L9fc3
        ld      a,1
        ld      (V_power_type_chosen),a
        ret     
action_power_coal:
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
menu_system:
        defb        8,0
        defm        "            SYSTE"
        defb        'M'+128
        defb        3
        defb        2
        defw        menu_about
        defm        "ABOUT SIM CIT"
        defb        'Y'+128
        defb        3
        defb        2
        defw        action_start_new_city      ;a0b7
        defm        "START NEW CIT"
        defb        'Y'+128
        defb        3
        defb        2
        defw        use_old_landscape       ;220,165
        defm        "USE OLD LANDSCAP"
        defb        'E'+128
        defb        3
        defb        2
        defw        menu_load_city               ;243,161
        defm        "LOAD CIT"
        defb        'Y'+128
        defb        3
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
        jr      La0b7                   ; (0)

action_start_new_city:
.La0b7  call    menu_are_you_sure

.La0ba  ret     nc

        ld      hl,(V_random_seed)
        ld      (V_InitialSeed),hl

start_city:
.La0c1  call    menu_difficulty
        jp      create_landscape


menu_about:
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
        defm    "SPECTRUM PROGRAMMING A.R.Lil"
        defb    'l'+128, 0
        defm    "SPECTRUM GRAPHICS A.Lill & J"
        defb    'L'+128, 3, 0
        defm    "FOR MORE INFO :- INFOGRAME"
        defb    'S' + 128, 0
        defm    "   84 Rue du 1er Mars 1943"
        defb    ','+128, 0
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

    

menu_enter_filename:
.La29a  call    print_routine
        defb    $0c, 00
        defm    "        TYPE FILENAM"
        defb    'E' + 128
        defb    0
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
.La2fe  call    La309
.La301  ld      a,127
.La303  in      a,($fe)
.La305  rra     
        ret     nc
.La307  jr      La301                  ; (-8)



.La309  call    print_routine
        defb    $0e
        defb    0
        defm    "  START TAPE AND PRESS SPAC"
        defb    'E' + 128
        defb    4

;a32b
V_auto_bulldoze:    defb    1   ;VAR a32b/41771 - auto bulldoze
V_auto_budget:      defb    0   ;VAR a32c/41772 - auto budget
V_sound_enabled:    defb    1   ;VAR a32d/41773 - sound enabled
V_demolish_wait:    defb    1   ;VAR a32e/41774 - auto demolish wait


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

V_simulation_speed: defb    1   ;VAR (41899/a3ab) - simulation speed

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
        defm    "  FAS"
        defb    'T' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_normal    ;a428
menu_t_normal:
        defm    "  NORMA"
        defb    'L' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_slow    ;a420
menu_t_slow:
        defm    "  SLO"
        defb    'W' + 128
        defb    $00, $a0
        defb    $02
        defw    action_speed_paused    ;a436
menu_t_paused:
        defm    "  PAUSE"
        defb    'D' + 128
        defb    $00, $a0, $00, $a0
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

V_disaster_reset:   defb    0       ;a43d/42045 - used when resetting disasters

;a43e
menu_disaster:
        defb    $08, $00
        defm    "           DISASTER"
        defb    'S' + 128
        defb    $03
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "FIR"
        defb    'E' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "FLOOD"
        defb    'D' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
        defm    "EARTHQUAK"
        defb    'E' + 128
        defb    $02
        defw     action_set_disaster   ;a4ba
        defm    "AIR CRAS"
        defb    'H' + 128
        defb    $02
        defw    action_set_disaster    ;a4ba
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
        defm    "WINDOW"
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
V_show_mini_maps:   defb    0       ;VAR a511/42257 - set to show mini maps
        nop     

action_set_show_maps:
.La512
        ld      a,1
        ld      (V_show_mini_maps),a
        ret     

; A518
V_difficulty:   defb    0       ;VAR (42264) - difficulty level

menu_difficulty:
.La519  call    print_routine
menu_difficulty_text:
.L42268
        defb        8,0
        defm        "    SELECT DIFFICULTY LEVE"
        defb        'L'+128
        defb        3,0,160
        defb        2
        defw        action_difficulty
        defm        "        1 - EAS"
        defb        'Y'+128
        defb        0,160
        defb        2
        defw        action_difficulty
        defm        "        2 - MEDIU"
        defb        'M'+128
        defb        0,160
        defb        2
        defw        action_difficulty
        defm        "        3 - DIFFICUL"
        defb        'T'+128
        defb        0,160,0,160,0,160,0,160
        defb        3,2
        defw        action_input_city_name
; 42383
        defm        "      INPUT NEW CITY NAM"
        defb        'E'+128
        defb        4

.La5a9
action_difficulty:
        ld      a,(V_menu_selection)
        ld      (V_difficulty),a
        ret     


action_input_city_name:
.La5b0  ld      hl,$0501
.La5b3  ld      (V_input_xy),hl
        ld      hl,SMC_cityname
        ld      (V_42714),hl
        ld      a,57
        ld      (SMC_42936+1),a
        ld      a,185
        ld      (SMC_42944+1),a
        call    input_string
        ld      a,71
        ld      (SMC_42936+1),a
        ld      a,199
        ld      (SMC_42944+1),a
        call    L6a60
        call    ingame_txt
        jp      L6944


use_old_landscape:
        ld      hl,(V_InitialSeed)
        ld      (SMC_42523),hl
        call    print_routine
        defb        8,0
        defm        "       USE OLD LANDSCAP"
        defb        'E'+128
        defb        3,0
        defm        "CURRENT LANDSCAPE GENE "
;42521
        defb        6,0
SMC_42523:
        defw        0
        defb        0
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
        ld      hl,$0b19
        ld      (V_input_xy),hl
        ld      hl,V_InitialSeed
        ld      (V_42714),hl
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
        call    L5e35
        call    L6a60
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

V_input_xy:    defw    0       ;VAR 42712/a6d8 - coordinates for input
V_42714:    defw    0       ;VAR 42714/a6da - destination for input?

V_42716:    defb    0       ;VAR 42716/a6dc -  current length of input?

;a6dd/42717
V_input_isnumber:   defb    0       ;VAR 42717/ we want a number
V_input_maxlen:     defb    0       ;VAR 42718/ maximum length of the string

V_input_buffer:            defs    18      ;VAR - input buffer


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
        ld      (V_42716),a
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
        jr      La75d                   ; (56)

.La725  ld      hl,La76d
        push    hl
        ld      a,(keystore)
        and     1       ;'SHIFT'
        jr      nz,La742                ; (18)
        ld      hl,V_42716
        ld      a,b
        cp      56
        jr      z,La799                 ; (97)
        ld      a,b
        cp      53
        jr      z,La793                 ; (86)
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

.La75d  call    La7a3
        jr      La70a                   ; (-88)
        ld      hl,1000
        ld      (42735),hl
        call    La7a3
        jr      La70a                   ; (-99)

.La76d  ld      a,(V_42716)
        ld      e,a
        ld      d,0
        ld      hl,(V_42714)
        add     hl,de
        ld      (hl),b
        ld      hl,V_42716
        jr      La799                   ; (28)

.La77d  call    La786
        ld      hl,V_42716
        call    La793

.La786  ld      a,(V_42716)
        ld      e,a
        ld      d,0
        ld      hl,(V_42714)
        add     hl,de
        ld      (hl),32
        ret     


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


.La7a3  ld      bc,(V_input_xy)
        call    xypos
        ld      (textpos),hl
        ld      hl,(V_42714)
        ld      a,(V_input_maxlen)
        ld      b,a
        ld      c,0

.La7b6  push    bc
        push    hl
SMC_42936:
        ld      e,71                ;SMC - 42937
        ld      a,(V_42716)
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
        call    La7ed
        ld      hl,V_input_buffer
        ld      (V_42714),hl
        ret     

V_42987:    defw    0       ;VAR 42987/a7eb

.La7ed  ld      hl,(V_42714)
        ld      (V_42987),hl
        ld      iy,V_input_buffer
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a
        ld      a,(V_input_maxlen)
        ld      c,a
        ld      b,5
        ld      de,-10000
        call    La81e
        ld      de,-10000
        call    La81e
        ld      de,-100
        call    La81e
        ld      de,-10
        call    La81e
        ld      a,l
        call    La82a
        ret     


.La81e  ld      a,c
        cp      b
        jr      c,La834                 ; (18)
        xor     a
.La823  inc     a
        add     hl,de
        jr      c,La823                 ; (-4)
        sbc     hl,de
        dec     a
.La82a  add     a,48
        ld      (63310),a
        ld      (iy+0),a
        inc     iy
.La834  dec     b
        ret     


.La836  ld      a,(V_input_isnumber)
        and     a
        scf     
        ret     z
        call    La854
        ret     c
        ex      de,hl
        ld      hl,(V_42987)
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
  

V_load_filename:    defs    12,32          ;VAR 43300 - filename we want to load

; Tape header buffer for loading/saving
; 
; 12 bytes filename
;
;
; 12 bytes city name at D_43332
V_tapeheader:
        defs    12             ;VAR 43312/a930
V_tape_money:    defs    8               ;VAR 43324/
   

D_43332:    defm        "HERESVILLE  "


; End of tape header

; La950      
; At $a94e
minimaps:
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


V_tickcount:        defb    0       ;VAR 63236 - tickcount for taskswap
;f705
V_simulation_disabled: defb    1     ;VAR f705/63237 - simulation enabled
                
                defb    0       ;Unused

V_task0_stack:  defw    0       ;VAR 63239 - task 0 stack (ui)
V_task1_stack:  defw    0       ;VAR 63241 - task 1 stack (simulator)

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
        jr      Lf73b                   ; (8)

.Lf733  ld      (V_task0_stack),sp
        ld      sp,(V_task1_stack)

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
.textpos        defw        0        ;VAR - text print address
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
        call    L7a01
        jp      L7a32
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

