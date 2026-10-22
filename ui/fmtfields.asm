; The table drawing of ui/textfmt.h in assembler (the C version was 900 bytes).
;
;     fmt_count = n;  fmt_run(fields) __z88dk_fastcall
;
; draws n fields from the table at HL a row at a time (row 0xFF is never a row): a text, a string through a pointer,
; or a number of one to three bytes, right aligned ending at the column, with a minus sign and a unit character
; after it, or left aligned (and with 000 after it for thousands).  Each finished row is handed to the C function
; fmt_flush(buf) with fmt_row set, which writes it to the text area.  A field is 6 bytes:
;     row, col, kind, unit, pointer (2)        kinds: 0 text, 1 string pointer, 2 u8, 3 u16, 4 u24, 5 s24, 6 u24 left, 7 thousands
        MODULE  fmtfields
        INCLUDE "sections.asm"

        IFNDEF  FMT_WIDTH
        defc    FMT_WIDTH = 40          ; a narrower display's row is its width (the Makefile: -Ca-DFMT_WIDTH=32)
        ENDIF

        PUBLIC  _fmt_run, _fmt_count, _fmt_row
        EXTERN  _bcd24
        EXTERN  _fmt_flush

        IN_DATA
_fmt_count: defb    0
_fmt_row:   defb    0
        IN_BSS
fr_f:       defw    0                   ; the next field
fr_row:     defb    0                   ; the row being built
fr_col:     defb    0
fr_kind:    defb    0
fr_unit:    defb    0
fr_neg:     defb    0
fr_len:     defb    0
fr_buf:     defs    FMT_WIDTH+1
fr_t:       defs    7
fr_d:       defs    8
        IN_CODE

_fmt_run:
        ld      (fr_f),hl
        ld      a,255
        ld      (fr_row),a
fr_next:
        ld      a,(_fmt_count)
        or      a
        jp      z,fr_done
        dec     a
        ld      (_fmt_count),a
        ld      hl,(fr_f)
        ld      a,(fr_row)
        ld      b,a
        ld      a,(hl)                  ; this field's row
        cp      b
        jr      z,fr_same
        push    af
        ld      a,b
        cp      255
        call    nz,fr_flush             ; the row before is finished
        pop     af
        ld      (fr_row),a
        call    fr_blank
        ld      hl,(fr_f)
fr_same:
        inc     hl
        ld      a,(hl)                  ; column
        ld      (fr_col),a
        inc     hl
        ld      a,(hl)                  ; kind
        ld      (fr_kind),a
        inc     hl
        ld      a,(hl)                  ; unit
        ld      (fr_unit),a
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; de = the pointer
        inc     hl
        ld      (fr_f),hl
        ld      a,(fr_kind)
        cp      2
        jr      nc,fr_number
        ex      de,hl                   ; a string, or a pointer to one
        and     a
        jr      z,fr_text
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ex      de,hl
fr_text:
        call    fr_dest                 ; de = buf + col
fr_copy:
        ld      a,(hl)
        or      a
        jr      z,fr_next
        ld      (de),a
        inc     hl
        inc     de
        jr      fr_copy

; a number: its bytes into fr_t (zero filled), the magnitude if signed, then digits
fr_number:
        ex      de,hl                   ; hl = the number
        xor     a
        ld      (fr_t),a
        ld      (fr_t+1),a
        ld      (fr_t+2),a
        ld      (fr_neg),a
        ld      a,(fr_kind)
        dec     a                       ; 2 -> 1 byte, 3 -> 2, the rest 3
        cp      3
        jr      c,fr_size
        ld      a,3
fr_size:
        ld      c,a
        ld      b,0
        ld      de,fr_t
        ldir
        ld      a,(fr_kind)
        cp      5
        jr      nz,fr_digits
        ld      a,(fr_t+2)
        add     a,a
        jr      nc,fr_digits            ; positive
        ld      a,1
        ld      (fr_neg),a
        ld      hl,fr_t                 ; 0 - the value
        ld      a,(hl)
        cpl
        add     a,1
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        cpl
        adc     a,0
        ld      (hl),a
        inc     hl
        ld      a,(hl)
        cpl
        adc     a,0
        ld      (hl),a
fr_digits:
        ld      hl,fr_t
        call    _bcd24                  ; fr_t+3..6: the 8 digits, two to a byte
        ld      hl,fr_t+6
        ld      de,fr_d
        ld      b,0                     ; digits so far
        ld      c,4
fr_unpack:
        ld      a,(hl)
        rrca
        rrca
        rrca
        rrca
        and     15
        call    fr_digit
        ld      a,(hl)
        and     15
        call    fr_digit
        dec     hl
        dec     c
        jr      nz,fr_unpack
        ld      a,b
        or      a
        jr      nz,fr_have
        ld      a,'0'                   ; no digit at all: the number is 0
        ld      (de),a
        inc     b
fr_have:
        ld      a,b
        ld      (fr_len),a
        call    fr_dest                 ; de = buf + col, hl = the same
        ld      c,b
        ld      b,0
        ld      a,(fr_kind)
        cp      6
        jr      nc,fr_left
        ld      a,(fr_unit)             ; right aligned: the unit in the column, the digits before it
        or      a
        jr      z,fr_nounit
        ld      (de),a
fr_nounit:
        ex      de,hl
        and     a
        sbc     hl,bc                   ; start of the digits
        ld      a,(fr_neg)
        or      a
        jr      z,fr_put
        dec     hl
        ld      (hl),'-'
        inc     hl
fr_put:
        ex      de,hl
        ld      hl,fr_d
        ldir
        jp      fr_next
fr_left:
        ld      hl,fr_d
        ldir
        ld      a,(fr_kind)
        cp      7
        jp      nz,fr_next
        ld      a,(fr_len)              ; thousands: 000 after the digits unless the number is 0
        dec     a
        jr      nz,fr_zeros
        ld      a,(fr_d)
        cp      '0'
        jp      z,fr_next
fr_zeros:
        ld      a,'0'
        ld      (de),a
        inc     de
        ld      (de),a
        inc     de
        ld      (de),a
        jp      fr_next

; a = a digit: written (as a character at DE, counted in B) unless it is a leading zero
fr_digit:
        or      a
        jr      nz,fr_emit
        ld      a,b
        or      a
        ret     z
        xor     a
fr_emit:
        add     a,'0'
        ld      (de),a
        inc     de
        inc     b
        ret

; de = hl = fr_buf + the column
fr_dest:
        ld      a,(fr_col)
        ld      e,a
        ld      d,0
        push    hl
        ld      hl,fr_buf
        add     hl,de
        ex      de,hl
        pop     hl
        ret

fr_blank:
        ld      hl,fr_buf
        ld      de,fr_buf+1
        ld      bc,FMT_WIDTH-1
        ld      (hl),' '
        ldir
        xor     a
        ld      (de),a
        ret

fr_flush:
        ld      a,(fr_row)
        ld      (_fmt_row),a
        ld      hl,fr_buf
        jp      _fmt_flush

fr_done:
        ld      a,(fr_row)
        cp      255
        ret     z
        jr      fr_flush
