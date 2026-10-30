; MSX2 platform, the VDP's side: screen 5 (256x192, 4 bits a pixel, a byte two pixels, the left one in the high nibble, a line 128 bytes).  The video RAM
; is addressed with 17 bits: the low 14 through the port and the rest by R#14, which every address set here writes, so any address up to $FFFF is fine.
;     page 0, $0000-$5FFF   the screen: the game's 32 x 24 cells of 8x8 pixels, a cell's first byte at row * 1024 + col * 4
;     page 1, $8000-$FFFF   the picture atlas (TILES.DAT, tools/st_tiles_3bpp.py --msx2): picture n at pixel ((n & 31) * 8, 256 + (n >> 5) * 8)
; A map cell is one VDP command, HMMM (copy a rectangle of the video RAM), which the VDP runs while the Z80 goes on; every routine here that touches the video RAM
; waits for the last command first.  The routines take their arguments the way the game's C code passes them (smallc: first argument first, the caller
; cleans up).  The BIOS's frame interrupt stays on (it counts JIFFY, which plat_idle waits for): nothing here reads status register 0 (that would eat the
; frame flag), and the two byte VDP sequences (a register, an address) are inside DI.

        MODULE  plat_msx2
        SECTION code_user

        defc    VDP_DATA = $98
        defc    VDP_CMD = $99
        defc    VDP_PAL = $9A
        defc    VDP_IND = $9B

; Waits for the VDP to finish a command (status register 2, bit 0), leaving R#15 at 0.  Interrupts must be off.  Uses a.
vdp_wait_di:
        IFDEF   VDP_TEST                ; (test/msx2/vdp.py: the port reads of a host run have no VDP to answer)
        ret
        ENDIF
        ld      a,2
        out     (VDP_CMD),a
        ld      a,$8F
        out     (VDP_CMD),a
vw_loop:
        in      a,(VDP_CMD)
        rra
        jr      c,vw_loop
        xor     a
        out     (VDP_CMD),a
        ld      a,$8F
        out     (VDP_CMD),a
        ret

; The video RAM address de for writing (va_w) or reading (va_r).  Interrupts must be off.  Uses a.
va_w:
        ld      a,d
        rlca
        rlca
        and     3
        out     (VDP_CMD),a
        ld      a,$8E
        out     (VDP_CMD),a
        ld      a,e
        out     (VDP_CMD),a
        ld      a,d
        and     $3F
        or      $40
        out     (VDP_CMD),a
        ret
va_r:
        ld      a,d
        rlca
        rlca
        and     3
        out     (VDP_CMD),a
        ld      a,$8E
        out     (VDP_CMD),a
        ld      a,e
        out     (VDP_CMD),a
        ld      a,d
        and     $3F
        out     (VDP_CMD),a
        ret

; The address of pixel line b, pixel column a (even), in de: b * 128 + a / 2.  Uses a.
va_line:
        ld      d,b
        ld      e,0
        srl     d
        rr      e
        srl     a
        or      e
        ld      e,a
        ret

; void msx_cmd(const uint8_t *regs) __smallc
; Starts a VDP command from 15 bytes for registers 32 to 46 (SX, SY, DX, DY, NX, NY as words, then CLR, ARG, CMD).
        PUBLIC  _msx_cmd
_msx_cmd:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
mc_go:
        di
        call    vdp_wait_di
        ld      a,32                    ; R#17 = 32: from register 32, incrementing
        out     (VDP_CMD),a
        ld      a,$91
        out     (VDP_CMD),a
        ld      b,15
        ld      c,VDP_IND
        otir
        ei
        ret

; void msx_tile(uint8_t col, uint8_t row, uint16_t n) __smallc
; Picture n of the atlas to cell (col, row) (HMMM of 8x8 pixels).
        PUBLIC  _msx_tile
_msx_tile:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)                  ; n
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      c,(hl)                  ; col
        add     a,a
        add     a,a
        add     a,a
        ld      (mt_blk + 6),a          ; DY
        ld      a,c
        add     a,a
        add     a,a
        add     a,a
        ld      (mt_blk + 4),a          ; DX
        ld      a,e
        and     31
        add     a,a
        add     a,a
        add     a,a
        ld      (mt_blk),a              ; SX = (n & 31) * 8
        ld      a,e
        rlca
        rlca
        rlca
        and     7
        ld      b,a
        ld      a,d
        add     a,a
        add     a,a
        add     a,a
        or      b                       ; n >> 5
        add     a,a
        add     a,a
        add     a,a
        ld      (mt_blk + 2),a          ; SY = (n >> 5) * 8 (+ 256: the high byte)
        ld      hl,mt_blk
        jr      mc_go
mt_blk: defb    0,0, 0,1, 0,0, 0,0, 8,0, 8,0, 0,0,$D0

; void msx_wr(uint8_t y, uint8_t x, const uint8_t *src, uint16_t len) __smallc
; len pixels (even, each a byte of 0 to 15) from src to pixel line y from column x (even).
        PUBLIC  _msx_wr
_msx_wr:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; len
        inc     hl
        ld      b,(hl)
        srl     b
        rr      c                       ; the bytes
        inc     hl
        ld      e,(hl)                  ; src
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; x
        inc     hl
        inc     hl
        ld      b,(hl)                  ; y
        ex      de,hl                   ; hl = src
        call    va_line
        ld      a,c
        or      a
        ret     z
        di
        push    hl
        push    bc
        call    vdp_wait_di
        call    va_w
        pop     bc
        pop     hl
mw_loop:
        ld      a,(hl)
        inc     hl
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        or      (hl)
        inc     hl
        out     (VDP_DATA),a
        dec     c
        jr      nz,mw_loop
        ei
        ret

; void msx_rd(uint8_t y, uint8_t x, uint8_t *dst, uint16_t len) __smallc
; len pixels of pixel line y from column x to dst, a byte each.
        PUBLIC  _msx_rd
_msx_rd:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        srl     b
        rr      c
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        inc     hl
        ld      b,(hl)
        ex      de,hl
        call    va_line
        ld      a,c
        or      a
        ret     z
        di
        push    hl
        push    bc
        call    vdp_wait_di
        call    va_r
        pop     bc
        pop     hl
mr_loop:
        in      a,(VDP_DATA)
        ld      b,a
        rrca
        rrca
        rrca
        rrca
        and     15
        ld      (hl),a
        inc     hl
        ld      a,b
        and     15
        ld      (hl),a
        inc     hl
        dec     c
        jr      nz,mr_loop
        ei
        ret

; void vram_write(uint16_t addr, const uint8_t *src, uint16_t len) __smallc
; len bytes (1 to 256) of raw video RAM from addr.
        PUBLIC  _vram_write
_vram_write:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; len (256 is a low byte of 0)
        inc     hl
        inc     hl
        ld      e,(hl)                  ; src
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; addr
        inc     hl
        ld      h,(hl)
        ld      l,a
        ex      de,hl                   ; hl = src, de = addr
        ld      b,c
        di
        push    hl
        push    bc
        call    vdp_wait_di
        call    va_w
        pop     bc
        pop     hl
        ld      c,VDP_DATA
vwr_loop:
        ld      a,(hl)                  ; (not otir: the VDP loses bytes that come every 21 T)
        out     (c),a
        inc     hl
        djnz    vwr_loop
        ei
        ret

; void msx_glyph(uint8_t col, uint8_t row, const uint8_t *art, uint8_t ink, uint8_t paper) __smallc
; The 8 bytes of 1 bit art (bit 7 on the left) in cell (col, row), set pixels in colour ink and the others paper.
        PUBLIC  _msx_glyph
_msx_glyph:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; paper
        and     15
        ld      d,a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; ink
        and     15
        ld      e,a
        inc     hl
        inc     hl
        ld      c,(hl)                  ; art
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      a,(hl)                  ; row
        inc     hl
        inc     hl
        ld      l,(hl)                  ; col
        ld      h,a
        ; the table of the four pairs of pixels, at an address that is a multiple of 4: 0 paper paper, 1 paper ink, 2 ink paper, 3 ink ink
        ld      (gl_ap),bc
        push    hl
        ld      hl,gl_raw + 3
        ld      a,l
        and     $FC
        ld      l,a
        ld      (gl_tb),hl
        ld      a,d
        rlca
        rlca
        rlca
        rlca
        or      d
        ld      (hl),a
        inc     hl
        ld      a,d
        rlca
        rlca
        rlca
        rlca
        or      e
        ld      (hl),a
        inc     hl
        ld      a,e
        rlca
        rlca
        rlca
        rlca
        or      d
        ld      (hl),a
        inc     hl
        ld      a,e
        rlca
        rlca
        rlca
        rlca
        or      e
        ld      (hl),a
        pop     hl                      ; h = row, l = col
        ld      a,h
        add     a,a
        add     a,a
        ld      h,a                     ; row * 4 * 256 = row * 1024
        ld      a,l
        add     a,a
        add     a,a
        ld      l,a                     ; col * 4
        ld      (gl_va),hl
        ld      a,8
        ld      (gl_n),a
        di
        call    vdp_wait_di
gl_row:
        ld      de,(gl_va)
        call    va_w
        ld      hl,(gl_ap)
        ld      c,(hl)
        inc     hl
        ld      (gl_ap),hl
        ld      de,(gl_tb)              ; d = the table's high byte, e = its low byte
        ld      a,c
        rlca
        rlca
        and     3
        or      e
        ld      l,a
        ld      h,d
        ld      a,(hl)
        out     (VDP_DATA),a
        ld      a,c
        rrca
        rrca
        rrca
        rrca
        and     3
        or      e
        ld      l,a
        ld      a,(hl)
        out     (VDP_DATA),a
        ld      a,c
        rrca
        rrca
        and     3
        or      e
        ld      l,a
        ld      a,(hl)
        out     (VDP_DATA),a
        ld      a,c
        and     3
        or      e
        ld      l,a
        ld      a,(hl)
        out     (VDP_DATA),a
        ld      hl,(gl_va)
        ld      de,128
        add     hl,de
        ld      (gl_va),hl
        ld      hl,gl_n
        dec     (hl)
        jr      nz,gl_row
        ei
        ret
gl_raw: defs    8
gl_tb:  defw    0
gl_ap:  defw    0
gl_va:  defw    0
gl_n:   defb    0

; void msx_vreg(uint8_t reg, uint8_t value) __smallc
        PUBLIC  _msx_vreg
_msx_vreg:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; value
        inc     hl
        inc     hl
        ld      c,(hl)                  ; reg
        di
        out     (VDP_CMD),a
        ld      a,c
        or      $80
        out     (VDP_CMD),a
        ei
        ret

; void msx_pal(const uint8_t *entries) __smallc
; The 16 colours of the palette from 32 bytes (red * 16 + blue, then green, each 0 to 7).
        PUBLIC  _msx_pal
_msx_pal:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
        di
        xor     a
        out     (VDP_CMD),a
        ld      a,$90
        out     (VDP_CMD),a
        ld      b,32
        ld      c,VDP_PAL
        otir
        ei
        ret

; uint8_t msx_keyrow(uint8_t row) __smallc
; The keyboard matrix row (0 to 10) from the PPI: a bit is 0 for a key that is down.
        PUBLIC  _msx_keyrow
_msx_keyrow:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        di
        in      a,($AA)
        and     $F0
        or      c
        out     ($AA),a
        in      a,($A9)
        ei
        ld      l,a
        ld      h,0
        ret

; void msx_print(const char *s) __smallc
; DOS function 9: the string, ended by a $, on the console.
        PUBLIC  _msx_print
_msx_print:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        push    ix
        push    iy
        ld      c,9
        call    5
        pop     iy
        pop     ix
        ret

; void msx_getc(void): DOS function 1, a key from the console
        PUBLIC  _msx_getc
_msx_getc:
        push    ix
        push    iy
        ld      c,1
        call    5
        pop     iy
        pop     ix
        ret

; void vram_read(uint16_t addr, uint8_t *dst, uint16_t len) __smallc
; len bytes (1 to 256) of raw video RAM from addr.
        PUBLIC  _vram_read
_vram_read:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)                  ; len (256 is a low byte of 0)
        inc     hl
        inc     hl
        ld      e,(hl)                  ; dst
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)                  ; addr
        inc     hl
        ld      h,(hl)
        ld      l,a
        ex      de,hl                   ; hl = dst, de = addr
        ld      b,c
        di
        push    hl
        push    bc
        call    vdp_wait_di
        call    va_r
        pop     bc
        pop     hl
        ld      c,VDP_DATA
vr_loop:
        in      a,(c)
        ld      (hl),a
        inc     hl
        djnz    vr_loop
        ei
        ret

; uint16_t msx_cget(uint16_t addr) __smallc
; A word of the video RAM, without waiting for the VDP's command (the CPU's access shares the memory with it): the cache of the cells.
        PUBLIC  _msx_cget
_msx_cget:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        di
        call    va_r
        in      a,(VDP_DATA)
        ld      l,a
        in      a,(VDP_DATA)
        ld      h,a
        ei
        ret

; void msx_cset(uint16_t addr, uint16_t value) __smallc
        PUBLIC  _msx_cset
_msx_cset:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        di
        call    va_w
        ld      a,c
        out     (VDP_DATA),a
        ld      a,b
        out     (VDP_DATA),a
        ei
        ret

; void msx_command(uint16_t sx, uint16_t sy, uint16_t dx, uint16_t dy, uint16_t nx, uint16_t ny, uint8_t clr, uint8_t cmd) __smallc
; Starts a VDP command from its parameters (the argument for the command, R#45, is 0).
        PUBLIC  _msx_command
_msx_command:
        ld      hl,17
        add     hl,sp                   ; the high byte of sx, the first argument
        ld      de,cm_blk
        ld      b,6
cm_word:
        ld      a,(hl)
        dec     hl
        ld      c,(hl)
        ex      de,hl
        ld      (hl),c                  ; low byte, then high
        inc     hl
        ld      (hl),a
        inc     hl
        ex      de,hl
        dec     hl                      ; (the next argument's high byte)
        djnz    cm_word
        ld      hl,4
        add     hl,sp
        ld      a,(hl)                  ; clr
        ld      (de),a
        inc     de
        ld      a,(cm_arg)              ; arg: what msx_dir said for this command (the directions of a copy), then 0 again
        ld      (de),a
        inc     de
        xor     a
        ld      (cm_arg),a
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; cmd
        ld      (de),a
        ld      hl,cm_blk
        jp      mc_go
cm_blk: defs    15
cm_arg: defb    0

; void msx_dir(uint8_t arg) __smallc
; The argument register (R#45) of the next msx_command: bit 2 is DIX (copy towards the left), bit 3 DIY (towards the top), as an overlapping copy needs.
        PUBLIC  _msx_dir
_msx_dir:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)
        ld      (cm_arg),a
        ret

; void msx_sync(void)
; Waits for the VDP's command to finish (the cache is read without waiting: after a scroll, which moves it by VDP commands, this makes it whole).
        PUBLIC  _msx_sync
_msx_sync:
        di
        call    vdp_wait_di
        ei
        ret

; void msx_psg15(uint8_t value) __smallc
; PSG register 15 (the joystick connectors' output: the mouse's strobe and the connector select): the BIOS leaves it at $CF.
        PUBLIC  _msx_psg15
_msx_psg15:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        di
        ld      a,15
        out     ($A0),a
        ld      a,c
        out     ($A1),a
        ei
        ret
