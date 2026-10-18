; zx_start: lines 1-342 of disassembly/sim_game.asm (zx)
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

