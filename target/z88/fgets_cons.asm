; A local GN_Sip wrapper.  It is the z88dk fgets_cons implementation with
; the cursor placed after an existing buffer, so a file prompt can be seeded.

        SECTION code_clib
        PUBLIC  _z88_fgets_cons
        INCLUDE "stdio.def"
        INCLUDE "syspar.def"
        EXTERN  processcmd

_z88_fgets_cons:
        xor     a
        ld      bc,nq_wcur
        call_oz (os_nq)
        push    bc
        ld      hl,4
        add     hl,sp
        ld      b,(hl)
        inc     hl
        ld      a,b
        or      (hl)
        jr      z,z88_fgets_abort
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      c,0
        dec     b

; GN_Sip uses C as the edit cursor.  Count the existing string, bounded by B.
        push    bc
        push    de
        ld      h,d
        ld      l,e
z88_fgets_seed:
        ld      a,b
        or      a
        jr      z,z88_fgets_seed_done
        ld      a,(hl)
        or      a
        jr      z,z88_fgets_seed_done
        inc     hl
        inc     c
        dec     b
        jr      z88_fgets_seed
z88_fgets_seed_done:
        ld      a,c
        pop     de
        pop     bc
        ld      c,a

z88_fgets_loop:
        push    de
        ld      a,9                     ; edit the seeded buffer; return Escape/special keys
        call_oz (gn_sip)
        pop     hl
        cp      $80
        call    nc,z88_fgets_command
        cp      1
        jr      z,z88_fgets_abort
        cp      27                    ; ESC when GN_Sip returns special keys
        jr      z,z88_fgets_abort
        cp      13
        jr      z,z88_fgets_eol
        jr      z88_fgets_unknown

z88_fgets_command:
        push    hl
        push    bc
        call    processcmd
        pop     bc
        pop     hl
        ret

z88_fgets_abort:
        ld      (hl),0
        ld      hl,0
z88_fgets_out:
        pop     bc
        ret

z88_fgets_eol:
        push    hl
        ld      c,b
        ld      b,0
        add     hl,bc
        ld      (hl),0
        dec     hl
        ld      (hl),10
        pop     hl
        jr      z88_fgets_out

z88_fgets_unknown:
        pop     de
        ld      a,1
        call_oz (os_out)
        ld      a,'3'
        call_oz (os_out)
        ld      a,'@'
        call_oz (os_out)
        ld      a,e
        add     a,32
        call_oz (os_out)
        ld      a,d
        add     a,32
        call_oz (os_out)
        push    de
        ex      de,hl
        ld      hl,4
        add     hl,sp
        ld      b,(hl)
        ld      a,1
        jr      z88_fgets_loop
