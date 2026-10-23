; The file name editor of the targets that draw their own text (plat_text_input, see ui/platform.h), in assembler: the Multi 8
; and the PC-8801.  It takes its keys from plat_key() (calling plat_idle() while there are none) and draws with plat_put().
;
;     uint8_t plat_text_input(uint8_t col, uint8_t row, char *buf, uint8_t max, uint8_t spaces) __smallc
;
; ENTER ends the line (1 if it has any characters, else 0), ESC cancels (0); left (8) or delete (127) takes the last character
; back; a printable character is added (a space only if `spaces`), up to `max`.  buf is always a string.  Keeps IX.

        MODULE  line_editor
        SECTION code_user
        PUBLIC  _plat_text_input
        EXTERN  _plat_key
        EXTERN  _plat_idle
        EXTERN  _plat_put

_plat_text_input:
        ld      hl,2
        add     hl,sp
        ld      a,(hl)                  ; spaces
        ld      c,'!'
        or      a
        jr      z,le_args
        ld      c,' '                   ; the first character allowed
le_args:
        ld      a,c
        ld      (le_first),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; max
        ld      (le_max),a
        inc     hl
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; buf
        ld      (le_buf),de
        inc     hl
        ld      a,(hl)                  ; row
        ld      (le_row),a
        inc     hl
        inc     hl
        ld      a,(hl)                  ; col
        ld      (le_col),a
        xor     a
        ld      (le_n),a
        ld      (de),a                  ; buf[0] = 0
le_key:
        call    _plat_key
        ld      a,l
        or      a
        jr      nz,le_got
        call    _plat_idle
        jr      le_key
le_got:
        cp      13
        jr      z,le_enter
        cp      27
        jr      z,le_cancel
        cp      8
        jr      z,le_back
        cp      127
        jr      z,le_back
        ld      c,a
        ld      a,(le_first)
        ld      b,a
        ld      a,c
        cp      b
        jr      c,le_key                ; below the first allowed
        cp      127
        jr      nc,le_key
        ld      a,(le_n)
        ld      b,a
        ld      a,(le_max)
        cp      b
        jr      z,le_key                ; full
        jr      c,le_key
        ld      hl,(le_buf)             ; buf[n] = the character, then a new end
        ld      e,b
        ld      d,0
        add     hl,de
        ld      (hl),c
        inc     hl
        ld      (hl),0
        ld      a,(le_col)
        add     a,b                     ; draw it at col + n
        call    le_put                  ; (c = the character)
        ld      hl,le_n
        inc     (hl)
        jr      le_key
le_back:
        ld      a,(le_n)
        or      a
        jr      z,le_key
        dec     a
        ld      (le_n),a
        ld      b,a
        ld      hl,(le_buf)
        ld      e,a
        ld      d,0
        add     hl,de
        ld      (hl),0
        ld      a,(le_col)
        add     a,b
        ld      c,' '
        call    le_put
        jr      le_key
le_enter:
        ld      a,(le_n)
        or      a
        ld      hl,0
        ret     z
        inc     l
        ret
le_cancel:
        ld      hl,0
        ret

; plat_put(col = a, le_row, c)
le_put:
        ld      l,a
        ld      h,0
        push    hl
        ld      a,(le_row)
        ld      l,a
        push    hl
        ld      l,c
        push    hl
        call    _plat_put
        pop     hl
        pop     hl
        pop     hl
        ret

        SECTION bss_user
le_first: defb  0
le_max: defb    0
le_buf: defw    0
le_row: defb    0
le_col: defb    0
le_n:   defb    0
