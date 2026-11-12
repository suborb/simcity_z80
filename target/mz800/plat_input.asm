; Sharp MZ-800 keyboard and frame timer, polled (no interrupts).
; Keyboard: the 8255 matrix, strobe 0-9 in port A ($D0) bits 0-3, the keys in port B ($D1), a pressed key reading 0 (the table is Takeda's key_map; MAME's has the legends).  Letters are
; lower case, upper with SHIFT; SHIFT and a cursor key give the far moves; DEL is Backspace and BREAK is Esc.
; mz_key_scan() returns a key newly down, and a held key once it repeats (after 18 frames, then every 4), else 0.  Frames are counted by mz_wait_frame().
        SECTION code_driver
        PUBLIC  _mz_key_scan
        PUBLIC  _mz_ticks
        PUBLIC  _mz_wait_frame

; uint8_t mz_key_scan(void)
_mz_key_scan:
        ld      a,$88                   ; strobe 8: SHIFT is bit 0
        out     ($d0),a
        in      a,($d1)
        and     1
        ld      (shift),a               ; 0 = shift down
        ld      hl,keytab
        ld      c,0                     ; the strobe
ks_row: ld      a,c
        or      $80
        out     ($d0),a
        in      a,($d1)
        cpl
        ld      b,8
ks_bit: rra
        jr      nc,ks_next
        ld      d,a                     ; (the rest of the row)
        ld      a,(hl)
        or      a
        jr      nz,ks_found
        ld      a,d
ks_next: inc    hl
        djnz    ks_bit
        ; the row's remaining entries are skipped by the loop above, which has consumed all 8
        inc     c
        ld      a,c
        cp      10
        jr      nz,ks_row
        xor     a                       ; nothing is down
        ld      (last),a
        ld      l,a
        ret
ks_found:
        ld      e,a                     ; the code
        ld      a,(shift)
        or      a
        jr      nz,ks_noshift
        ld      a,e                     ; SHIFT is down: lower case letters to upper, the cursor keys to the far moves
        cp      'a'
        jr      c,ks_s2
        cp      'z'+1
        jr      nc,ks_s2
        sub     32
        jr      ks_s3
ks_s2:  cp      KEY_LEFT
        jr      c,ks_s4
        cp      KEY_UP+1
        jr      nc,ks_s4
        add     a,20                    ; 8..11 -> 28..31
ks_s3:  ld      e,a
ks_s4:
ks_noshift:
        ld      a,(last)
        cp      e
        ld      a,(ticks)
        jr      z,ks_same
        ld      a,e                     ; a new key
        ld      (last),a
        ld      a,(ticks)
        ld      (lt),a
        xor     a
        ld      (rep),a
        ld      l,e
        ret
ks_same:
        ld      hl,lt
        cp      (hl)
        jr      z,ks_none               ; (already looked at this frame)
        ld      (hl),a
        ld      a,(rep)
        inc     a
        ld      (rep),a
        sub     18
        jr      c,ks_none
        and     3
        jr      nz,ks_none
        ld      l,e
        ret
ks_none: ld     l,0
        ret

        defc    KEY_LEFT = 8
        defc    KEY_UP = 11

; uint16_t mz_ticks(void): the frames counted by mz_wait_frame
_mz_ticks:
        ld      hl,(ticks)
        ret

; void mz_wait_frame(void): until the start of the next vertical blank ($CE bit 6 is low during it), and the frame is counted
_mz_wait_frame:
wf1:    in      a,($ce)
        and     $40
        jr      z,wf1                   ; (one in progress: wait for its end)
wf2:    in      a,($ce)
        and     $40
        jr      nz,wf2
        ld      hl,(ticks)
        inc     hl
        ld      (ticks),hl
        IFDEF   HAVE_SOUND
        EXTERN  ay_poll
        jp      ay_poll                 ; (a tick of the sound: the frame has just begun)
        ELSE
        ret
        ENDIF

        SECTION rodata_user
; strobe 0 to 9, bit 0 to 7 (Takeda's key_map): 0 = no code
keytab: defb    13, ':', ';', 0, 0, 0, 0, 0                     ; 0: CR : ; (caps) tab F9 pgup pgdn
        defb    0, 0, 0, ']', '[', '@', 'z', 'y'                ; 1
        defb    'x', 'w', 'v', 'u', 't', 's', 'r', 'q'          ; 2
        defb    'p', 'o', 'n', 'm', 'l', 'k', 'j', 'i'          ; 3
        defb    'h', 'g', 'f', 'e', 'd', 'c', 'b', 'a'          ; 4
        defb    '8', '7', '6', '5', '4', '3', '2', '1'          ; 5
        defb    '.', ',', '9', '0', ' ', '-', '^', '\\'         ; 6
        defb    '/', '_', 8, 9, 10, 11, 8, 0                    ; 7: / _ left right down up DEL INS
        defb    0, 0, 0, 0, 0, 0, 0, 27                         ; 8: SHIFT ... CTRL BREAK (Esc)
        defb    0, 0, 0, 0, 0, 0, 0, 0                          ; 9: F5 F4 F3 F2 F1

        SECTION bss_user
ticks:  defw    0
shift:  defb    1
last:   defb    0
lt:     defb    0
rep:    defb    0

; the plane selection of the video RAM, for the C code: mz_wf(f) sets the write format ($CC), mz_rf(f) the read format ($CD: bit 0 plane I, bit 1 plane II)
        SECTION code_driver
        PUBLIC  _mz_wf
        PUBLIC  _mz_rf
_mz_wf: ld      a,l
        out     ($cc),a
        ret
_mz_rf: ld      a,l
        out     ($cd),a
        ret

; mz_vram(on): the video RAM paged in at $8000 (and the character generator at $1000) or out
        PUBLIC  _mz_vram
_mz_vram:
        ld      a,l
        or      a
        jr      z,vr_off
        in      a,($e0)
        ret
vr_off: in      a,($e1)
        ret

; void mz_recolour(uint8_t *cell, uint8_t n, uint8_t ink, uint8_t paper) __smallc: n cells from video RAM address `cell` ($8000 + 320 * row + column): the glyph pixels take pen
; ink, the rest pen paper.  The background is the pen of the cell's top left pixel (the font keeps the left column and top row clear), so the glyph is whatever differs from it
; in either plane.  Read per plane through $CD, written back through $CC, with the video RAM paged in only for that.
        PUBLIC  _mz_recolour
_mz_recolour:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; paper
        inc     hl
        inc     hl
        ld      c,(hl)                  ; ink
        inc     hl
        inc     hl
        ld      b,(hl)                  ; n
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the cell
        ld      (rc_cell),de
        ld      d,a                     ; d = paper
        ; plane masks: ink I = FF if bit 0, ink II = FF if bit 1; likewise paper; x = ink xor paper
        ld      a,c
        and     1
        neg
        ld      e,a                     ; ink I
        ld      a,d
        and     1
        neg
        ld      (rc_p0),a
        xor     e
        ld      (rc_x0),a
        ld      a,c
        and     2
        rrca
        neg
        ld      e,a                     ; ink II
        ld      a,d
        and     2
        rrca
        neg
        ld      (rc_p1),a
        xor     e
        ld      (rc_x1),a
rc_cell_l:
        push    bc
        in      a,($e0)                 ; the video RAM in
        ld      a,1
        out     ($cd),a
        ld      hl,(rc_cell)
        ld      de,tb0
        call    rc_read
        ld      a,2
        out     ($cd),a
        ld      hl,(rc_cell)
        ld      de,tb1
        call    rc_read
        ld      a,(tb0)
        and     1
        neg
        ld      (rc_bg0),a
        ld      a,(tb1)
        and     1
        neg
        ld      (rc_bg1),a
        ld      hl,tb0
        ld      de,tb1
        ld      b,8
rc_px:  ld      a,(rc_bg0)
        xor     (hl)
        ld      c,a                     ; plane I differs from the background
        ld      a,(rc_bg1)
        ex      de,hl
        xor     (hl)                    ; plane II differs
        ex      de,hl
        or      c
        ld      (rc_m),a                ; m: the glyph's pixels
        ld      c,a
        ld      a,(rc_x0)
        and     c
        ld      c,a
        ld      a,(rc_p0)
        xor     c
        ld      (hl),a                  ; new plane I
        inc     hl
        ld      a,(rc_m)
        ld      c,a
        ld      a,(rc_x1)
        and     c
        ld      c,a
        ld      a,(rc_p1)
        xor     c
        ld      (de),a                  ; new plane II
        inc     de
        dec     b
        jp      nz,rc_px
        ld      a,1
        out     ($cc),a
        ld      hl,tb0
        ld      de,(rc_cell)
        call    rc_write
        ld      a,2
        out     ($cc),a
        ld      hl,tb1
        ld      de,(rc_cell)
        call    rc_write
        in      a,($e1)                 ; the video RAM out
        ld      hl,(rc_cell)
        inc     hl
        ld      (rc_cell),hl
        pop     bc
        dec     b
        jp      nz,rc_cell_l
        ret

rc_read:                                ; 8 bytes from hl (40 apart) to de
        ld      b,8
rcr1:   ld      a,(hl)
        ld      (de),a
        inc     de
        ld      a,l
        add     a,40
        ld      l,a
        jr      nc,rcr2
        inc     h
rcr2:   djnz    rcr1
        ret

rc_write:                               ; 8 bytes from hl to de (40 apart)
        ld      b,8
rcw1:   ld      a,(hl)
        ld      (de),a
        inc     hl
        ld      a,e
        add     a,40
        ld      e,a
        jr      nc,rcw2
        inc     d
rcw2:   djnz    rcw1
        ret

        SECTION bss_user
rc_cell: defw   0
rc_m:   defb    0
rc_p0:  defb    0
rc_p1:  defb    0
rc_x0:  defb    0
rc_x1:  defb    0
rc_bg0: defb    0
rc_bg1: defb    0
tb0:    defs    8
tb1:    defs    8
