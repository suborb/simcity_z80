; A small, portable Z80 entropy source.  The refresh register changes while
; the user is choosing the difficulty, without needing interrupts or hardware
; timer support.
        SECTION code_clib
        PUBLIC  _plat_entropy
_plat_entropy:
        ld      a,r
        ld      l,a
        ld      h,0
        ret
