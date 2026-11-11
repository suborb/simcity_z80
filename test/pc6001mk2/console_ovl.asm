        SECTION code_user
        PUBLIC  _done
        PUBLIC  _stop
        PUBLIC  _peek_char
        PUBLIC  _scroll_up
        EXTERN  generic_console_vpeek
        EXTERN  generic_console_scrollup
_done:  ld      a,2
        out     ($f8),a
_stop:  jr      _stop

; uint16_t peek_char(uint8_t x, uint8_t y) __smallc: the character, or $100 if there is none
_peek_char:
        ld      hl,2
        add     hl,sp
        ld      b,(hl)                  ; y (the last argument is nearest)
        inc     hl
        inc     hl
        ld      c,(hl)                  ; x
        ld      e,0
        push    ix
        call    generic_console_vpeek
        pop     ix
        ld      l,a
        ld      h,0
        ret     nc
        ld      hl,$100
        ret

_scroll_up:
        push    ix
        call    generic_console_scrollup
        pop     ix
        ret
