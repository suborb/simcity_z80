; The Lynx boot sector: EXT BOOT (after XROM) reads the disk's first sector to some address and runs it there (it copies itself to $CF00).  It starts with what the DOS ROM looks for in a
; disk (NOP, NOP, JR to the code, and "Lynx disks, Copyright Intelligent Software" at offset $14: the header of a CP/M system disk's boot sector), then
; reads the game from the disk with the WD1793 and starts it:
;     IMG_N sectors from track IMG_T sector IMG_S to $0100 (the program, simcity.bin, linked at $0100 and ending below $CF00),
;     ART_N sectors from track ART_T sector ART_S to the alternate green plane ($C000-$FFFF, by way of the buffer BUF and the drawing window: tools/lynx_art.py).
; The sectors are 512 bytes, 10 a track, numbered from 1 (the disk is single sided), and in a line (appmake +cpmdisk -f lynx --linear).  The constants come
; from the Makefile (-D); a read that fails starts again from the beginning.

        org     $CF00
        defc    PORT_BANK = $82
        defc    NORMAL = $08
        defc    DRAW = $C8
        defc    BUF = $E000             ; a sector on its way to the plane (free RAM: the program ends below it and its uninitialised data is cleared later)

        defb    0, 0
        jr      start                   ; to $CF3F: the ROM's own format
        defb    0, $81, 0, $1B          ; (as the system disk's header has them)
        defs    12
        defm    "Lynx disks, Copyright Intelligent Software"
        defb    0

; The ROM runs the sector where it happened to load it (not at $CF00), entering at its offset 2 with HL = the address it jumped to, so the first
; thing (no absolute address is usable yet) is to copy the sector to where it is linked
start:  di
        dec     hl
        dec     hl                      ; the sector's address
        ld      de,$CF00
        ld      bc,512
        ldir
        jp      go
go:     di
        ld      sp,$FFF0
        xor     a
        out     ($80),a                 ; the control port: cassette and the rest off (the BASIC and the DOS leave bits that stop the video RAM being written)
        ld      a,NORMAL
        out     (PORT_BANK),a           ; the user RAM, read and written
        xor     a
        out     ($58),a                 ; drive 0, the motor on (bit 3 clear), side 0
        ld      hl,0
        ld      b,8
ready:  in      a,($50)                 ; (the motor comes up to speed: a wait, bounded)
        rlca
        jr      nc,restore
        dec     hl
        ld      a,h
        or      l
        jr      nz,ready
        djnz    ready
restore:
        xor     a
        ld      (curt),a
        ld      a,$0B                   ; restore, 30 ms a step as the system disk's own boot sector does
        out     ($54),a
        call    wbusy
        ld      hl,$0100                ; the program
        ld      a,IMG_N
        ld      (cnt),a
        ld      d,IMG_T
        ld      e,IMG_S
        call    rd_n
        ld      hl,$C000                ; the art, a sector at a time through BUF
        ld      (dst),hl
        ld      a,ART_N
        ld      (cnt2),a
        ld      d,ART_T
        ld      e,ART_S
art:    ld      hl,BUF
        ld      a,1
        ld      (cnt),a
        call    rd_n
        push    de                      ; (the next sector)
        ld      hl,BUF
        ld      de,(dst)
        ld      bc,512
        ld      a,DRAW
        out     (PORT_BANK),a           ; the window: the stores go to the planes
        ldir
        ld      a,NORMAL
        out     (PORT_BANK),a
        ld      (dst),de
        pop     de
        ld      hl,cnt2
        dec     (hl)
        jr      nz,art
        ld      a,8
        out     ($58),a                 ; the motor off
        ld      sp,$FFF0
        jp      $0100

; cnt sectors from track d sector e to hl on; d and e go to the sector after
rd_n:   call    rd_sec
        inc     e
        ld      a,e
        cp      11
        jr      c,rd_nx
        ld      e,1
        inc     d
rd_nx:  ld      a,(cnt)
        dec     a
        ld      (cnt),a
        jr      nz,rd_n
        ret

; the sector e of the track d to hl on (512 bytes): a failure starts all over
rd_sec: ld      a,(curt)
        cp      d
        jr      z,rs_ons
        ld      a,d
        out     ($57),a                 ; the data register: where to go
        ld      a,$1B                   ; seek (30 ms a step)
        out     ($54),a
        call    wbusy
        ld      a,d
        ld      (curt),a
rs_ons: ld      a,e
        out     ($56),a
        ld      a,$84                   ; read sector, with the head settling delay
        out     ($54),a
        ld      bc,512
rs_b:   in      a,($50)
        bit     1,a                     ; data request?
        jr      nz,rs_g
        rrca
        jr      c,rs_b                  ; still busy
        jp      go                   ; ended without the data
rs_g:   in      a,($53)
        ld      (hl),a
        inc     hl
        dec     bc
        ld      a,b
        or      c
        jr      nz,rs_b
        call    wbusy
        in      a,($50)
        and     $1D                     ; lost data, CRC error, record not found
        ret     z
        jp      go

wbusy:  in      a,($50)
        rrca
        jr      c,wbusy
        ret

curt:   defb    0                       ; the track the heads are on
cnt:    defb    0
cnt2:   defb    0
dst:    defw    0
