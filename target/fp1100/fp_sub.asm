; The Casio FP-1100's video, from the Z80: the screen belongs to the sub-CPU, which runs the small program in sub.s.in.  This is the Z80's end of
; it: fp_boot takes the sub-CPU over (the ROM's own program there takes a loader into the video RAM with its "define character" command and runs it, and the loader brings in the real
; program), fp_art sends it the pictures, and from then on a byte goes to the program at a time by the handshake in fp_send.
;
; The sub program's commands (target/fp1100/sub.s.in) are sent as a byte each; the functions here are the C ones (smallc: the last
; argument at sp+2) and keep IX and IY.

        INCLUDE "sub.inc"
        defc    SUB_SIZE = SUB_P1END - SUB_MAIN                       ; page 1
        defc    SUB2_SIZE = (SUB_SUBEND - SUB_PAGE2 + 7) & $FFF8       ; the rest, in 8 byte units

        SECTION code_user
        PUBLIC  _fp_addr, _fp_bank, _fp_tiles, _fp_cell, _fp_ovl, _fp_pat, _fp_inv, _fp_keys, _fp_tick, _fp_fill, _fp_text, _fp_mini, _fp_byte, _fp_dim


; A to the sub program: wait until it is ready (bit 7 of port $FF80 set), put the byte on port $FFC0, pulse INT2 ($FF80: $C0 then $20), wait for the
; acknowledgement (bit 7 clear).  Keeps BC, DE and HL.
fp_send:
        push    bc
        push    de
        ld      bc,$FF80
fs1:    in      e,(c)
        bit     7,e
        jr      z,fs1
        ld      c,$C0
        out     (c),a
        ld      c,$80
        ld      e,$C0
        out     (c),e
        ld      e,$20
        out     (c),e
fs2:    in      e,(c)
        bit     7,e
        jr      nz,fs2
        pop     de
        pop     bc
        ret

        PUBLIC  _fp_boot, _fp_art
        EXTERN  asm_fp1100_disk_rw, __DATA_END_tail

; The takeover.  The sub-CPU runs the ROM's own program until this puts ours there; its first stage is the ROM's transport, which is the same hardware handshake the ROM's TRNC routines
; (RAM copies at $0000, gone by now: the game is loaded over them) use: a byte is put on port $FFC0, port $FF80 gets $90 then $10 (the first raises INT2 of the sub-CPU, which takes the byte;
; bit 4 keeps the sub-CPU's answer, the INTS interrupt, unmasked) and the sub-CPU answers with INTS (vector $F0, so interrupt mode 2 with a table at $FFF0), the Z80 reading its status from
; $FFC0 (0: taken).  Interrupts are off at all other times.  The first stage uses the ROM's "define character" command to put 40 bytes of loader into the video RAM and "run" to start it;
; the loader brings in the real program (sub.s.in) through fp_send, and after that the ROM's part is out of the picture.
; A byte to the ROM's program: a = the byte.  Keeps all registers.
fb_put:
        push    bc
        push    af
        ld      bc,$FFC0
        out     (c),a
        ld      a,$AA
        ld      (fb_ack),a
        ld      c,$80
        ld      a,$90
        out     (c),a
        ld      a,$10
        out     (c),a
        ei
fb_w:   ld      a,(fb_ack)
        cp      $AA
        jr      z,fb_w
        di
        ld      a,$10
        out     (c),a
        pop     af
        pop     bc
        ret
fb_isr: push    af
        push    bc
        ld      bc,$FFC0
        in      a,(c)
        ld      (fb_ack),a
        pop     bc
        pop     af
        ei
        reti
fb_ack: defb    0

; void fp_boot(void): the takeover.  Call it first (interrupts end up off).
_fp_boot:
        push    ix
        di
        ld      a,$FF
        ld      i,a
        im      2
        ld      hl,fb_isr
        ld      ($FFF0),hl
        ld      a,$21                   ; screen size: 40 columns
        call    fb_put
        xor     a
        call    fb_put
        ld      a,$0D                   ; clear it
        call    fb_put
        ld      a,$12                   ; the cursor to column 4, row 21: where the loader goes
        call    fb_put
        ld      a,4
        call    fb_put
        ld      a,21
        call    fb_put
        ld      hl,fp_loader
        ld      e,5
fb_ld:  ld      a,$20                   ; "define character": 8 bytes into the cell at the cursor, which moves on
        call    fb_put
        ld      b,8
fb_l8:  ld      a,(hl)
        inc     hl
        call    fb_put
        djnz    fb_l8
        dec     e
        jr      nz,fb_ld
        ld      a,$6B                   ; run it
        call    fb_put
        ld      hl,fp_prog              ; the loader takes the program, which is run from the video RAM (inverted: the bus inverts a read)
        ld      de,SUB_SIZE
fb_sp:  ld      a,(hl)
        cpl
        inc     hl
        call    fp_send
        dec     de
        ld      a,d
        or      e
        jr      nz,fb_sp
        ld      a,SUB_ADDR & $FF              ; the second page of the program: into the video RAM at $9100, from the command that takes 8 bytes a time
        call    fp_send
        xor     a
        call    fp_send
        ld      a,$91
        call    fp_send
        ld      hl,fp_prog2
        ld      c,SUB2_SIZE / 8
fb_p2:  ld      a,SUB_PAT & $FF
        call    fp_send
        ld      b,8
fb_p3:  ld      a,(hl)
        cpl
        inc     hl
        call    fp_send
        djnz    fb_p3
        dec     c
        jr      nz,fb_p2
        pop     ix
        ret

; void fp_art(void): the pictures (tools/fp1100_art.py: 457 of 24 bytes, on the disc after the program) into the sub-CPU's spare video RAM, 32 a time through a buffer on the stack, in 32 byte slots:
; the first 256 from $4000 (bank 0), the next 89 from $8000 (bank 1), the last 112 (the icons) from $D000 (bank 2).  A disc error is shown as that many white cells at the top of the screen, and stops.
        defc    ART_COUNT = 345 + 112
        defc    ART_L = 9 + (__DATA_END_tail + 255) / 256       ; the logical sector of the pictures: the disc has the boot sector, 8 of loader, the program, the pictures
_fp_art:
        push    ix
        ld      hl,-768
        add     hl,sp
        ld      sp,hl
        ld      (fa_buf),hl
        ld      hl,ART_COUNT
        ld      (fa_left),hl
        ld      hl,$4000
        ld      (fa_sub),hl
        ld      a,ART_L
        ld      (fa_l),a
fa_chunk:
        ld      a,(fa_l)                ; the next three sectors
        ld      d,a
        srl     d
        srl     d
        srl     d
        srl     d                       ; track = n / 16
        and     15
        inc     a
        ld      c,a                     ; sector = n % 16 + 1
        ld      b,3
        ld      e,0
        ld      hl,(fa_buf)
        xor     a
        call    asm_fp1100_disk_rw
        ld      a,h
        or      l
        jr      nz,fa_fail
        ld      a,(fa_l)
        add     a,3
        ld      (fa_l),a
        ld      hl,(fa_buf)
        ld      b,32
fa_pic: ld      a,SUB_ADDR & $FF
        call    fp_send
        ld      a,(fa_sub)
        call    fp_send
        ld      a,(fa_sub + 1)
        call    fp_send
        push    bc
        ld      b,3
fa_pl:  push    bc
        ld      a,SUB_PAT & $FF
        call    fp_send
        ld      b,8
fa_by:  ld      a,(hl)
        inc     hl
        call    fp_send
        djnz    fa_by
        pop     bc
        djnz    fa_pl
        pop     bc
        ld      de,(fa_sub)             ; the next slot, 32 bytes on; picture 256 is the first of bank 1
        ld      a,e
        add     a,32
        ld      e,a
        jr      nc,fa_nc
        inc     d
fa_nc:  ld      a,d
        cp      $60
        jr      nz,fa_nx
        ld      d,$80
fa_nx:  ld      (fa_sub),de
        push    hl
        ld      hl,(fa_left)
        dec     hl
        ld      (fa_left),hl
        ld      a,h
        or      l
        jr      z,fa_done
        ld      a,l
        cp      112
        jr      nz,fa_more
        ld      a,h
        or      a
        jr      nz,fa_more
        ld      hl,$D000                ; (the last 112 are the icons)
        ld      (fa_sub),hl
fa_more:
        pop     hl
        djnz    fa_pic
        jp      fa_chunk
fa_done:
        pop     hl
        ld      hl,768
        add     hl,sp
        ld      sp,hl
        pop     ix
        ret
fa_fail:                                ; hl = the error: that many white cells
        ld      a,l
        and     15
        jr      nz,fa_n
        inc     a
fa_n:   ld      b,a
        ld      c,1
fa_lp:  push    bc
        ld      a,SUB_ADDR & $FF
        call    fp_send
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        call    fp_send                 ; $2000 + 8 c
        ld      a,$20
        call    fp_send
        ld      a,SUB_CELL & $FF
        call    fp_send
        ld      b,24
fa_wh:  xor     a                       ; (a raw 0 is lit)
        call    fp_send
        djnz    fa_wh
        pop     bc
        inc     c
        djnz    fa_lp
fa_stop:
        halt
        jr      fa_stop
fa_buf: defw    0
fa_left: defw   0
fa_sub: defw    0
fa_l:   defb    0

; void fp_byte(uint8_t b) __z88dk_fastcall: a raw byte to the program
_fp_byte:
        ld      a,l
        jp      fp_send

; void fp_addr(uint16_t a): DE of the program = a
_fp_addr:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      a,SUB_ADDR & $FF
        call    fp_send
        ld      a,e
        call    fp_send
        ld      a,d
        jp      fp_send

; void fp_bank(uint8_t b): the picture region, 0, $40 or $80
_fp_bank:
        ld      hl,2
        add     hl,sp
        ld      l,(hl)
        ld      a,SUB_BANK & $FF
        call    fp_send
        ld      a,l
        jp      fp_send

; void fp_tiles(const uint8_t *idx, uint8_t n): n >= 1 pictures from the current bank at DE, an index each
_fp_tiles:
        ld      hl,2
        add     hl,sp
        ld      b,(hl)
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,SUB_TILES & $FF
        call    fp_send
        ld      a,b
        dec     a
        call    fp_send
ft1:    ld      a,(hl)
        inc     hl
        call    fp_send
        djnz    ft1
        ret

; void fp_cell(const uint8_t *planes): 24 bytes (blue, red, green: eight lines each) to the cell at DE
_fp_cell:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,SUB_CELL & $FF
        call    fp_send
        ld      b,24
        jr      ft1

; void fp_ovl(const uint8_t *planes): 24 bytes ORed into the cell at DE
_fp_ovl:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,SUB_OVL & $FF
        call    fp_send
        ld      b,24
        jr      ft1

; void fp_pat(const uint8_t *p): 8 bytes to (DE+)
_fp_pat:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,SUB_PAT & $FF
        call    fp_send
        ld      b,8
        jr      ft1

; void fp_inv(void): the cell at DE inverted
_fp_inv:
        ld      a,SUB_INV & $FF
        jp      fp_send

; void fp_keys(uint8_t *out): out[0] = 1 if a shift key is down, out[1] = the matrix column (2 to 12) of a key that is down, or 0, out[2] = its row bits (bit n: row n)
_fp_keys:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,SUB_KEYS & $FF
        call    fp_send                 ; (it keeps hl; the acknowledgement first, then the answer: the ready flag of the byte's own wait is also a 1 in bit 7)
        call    fk_one
        call    fk_one
fk_one: ld      bc,$FF80
fk_w:   in      a,(c)
        bit     7,a
        jr      z,fk_w
        and     $7F
        ld      (hl),a
        inc     hl
        ld      e,$C0
        out     (c),e
        ld      e,$20
        out     (c),e
fk_a:   in      e,(c)
        bit     7,e
        jr      nz,fk_a
        ret

; uint8_t fp_tick(void): 1 if the sub-CPU's timer has overflowed since the last call
_fp_tick:
        ld      a,SUB_TICK & $FF
        call    fp_send
        ld      hl,fp_tbuf
        call    fk_one
        ld      a,(fp_tbuf)
        ld      l,a
        ld      h,0
        ret
fp_tbuf: defb   0

; void fp_fill(uint8_t n, uint8_t v): n >= 1 cells from DE written with the byte v in all three planes
_fp_fill:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; v
        inc     hl
        inc     hl
        ld      b,(hl)                  ; n
        ld      a,SUB_FILL & $FF
        call    fp_send
        ld      a,b
        dec     a
        call    fp_send
        ld      a,c
        jp      fp_send

; void fp_text(const uint8_t *chars, uint8_t n, uint8_t attr): n >= 1 characters from DE on, in the attribute's colours
_fp_text:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; attr
        inc     hl
        inc     hl
        ld      b,(hl)                  ; n
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      a,SUB_TEXT & $FF
        call    fp_send
        ld      a,b
        dec     a
        call    fp_send
        ld      a,c
        call    fp_send
ftx1:   ld      a,(hl)
        inc     hl
        call    fp_send
        djnz    ftx1
        ret

; void fp_mini(const uint8_t *data, uint8_t two): a mini map row's bytes to the cells at DE: 72 (one a cell for both lines) or, if two, 144
_fp_mini:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; two
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        ld      bc,72
        or      a
        ld      a,SUB_MINI & $FF
        jr      z,fm1
        ld      bc,144
        ld      a,SUB_MINI2 & $FF
fm1:    call    fp_send
fm2:    ld      a,(hl)
        inc     hl
        call    fp_send
        dec     bc
        ld      a,b
        or      c
        jr      nz,fm2
        ret

; void fp_dim(void): nothing (a placeholder so the C side has one place to hook a screen-blank later)
_fp_dim:
        ret

        SECTION rodata_user
fp_loader:
        BINARY  "build/fp1100/loader.bin"
fp_prog:
        BINARY  "build/fp1100/sub.bin"
fp_prog2:
        BINARY  "build/fp1100/sub2.bin"
