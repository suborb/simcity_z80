; The MSX-DOS 2 mapper side of the banks (engine_bank.inc): finds the mapper's support routines (extended BIOS), loads SIMCITY.UI and SIMCITY.SIM into two segments of
; their own, and switches page 2 between them.  The program's main() is here: it loads, maps the UI segment and runs the game (game_run, in the UI bank), and puts the segment
; that page 2 had back before it returns to DOS.  Resident: it is below $8000.
        MODULE  msx_bank
        SECTION code_user

        PUBLIC  _main, msx_bank_in, msx_bank_out, _msx_bye
        EXTERN  _game_run, __Exit

        defc    EXTBIO = $FFCA
        defc    HOKVLD = $FB20

; The mapper's jump table, copied from the extended BIOS's: 16 entries of 3 bytes
mb_jump:
mb_all_seg:     defs    3               ; allocate a segment (A = 0 user, B = 0 the primary mapper): A = the segment, carry set if none
                defs    3               ; free
                defs    3               ; read byte
                defs    3               ; write byte
                defs    3               ; call (cal_seg)
                defs    3               ; call (calls)
                defs    3               ; put_ph
                defs    3               ; get_ph
                defs    3               ; put_p0
                defs    3               ; get_p0
                defs    3               ; put_p1
                defs    3               ; get_p1
mb_put_p2:      defs    3               ; the segment in A into page 2
mb_get_p2:      defs    3               ; page 2's segment into A
                defs    3               ; put_p3 (a no-op)
                defs    3               ; get_p3
mb_jump_end:

mb_orig:        defb    0               ; the segment page 2 had when the program started
mb_have:        defb    0               ; the mapper is found
mb_seg_ui:      defb    0
mb_seg_sim:     defb    0

; The engine's entry points map its segment in and the UI's back; they keep every register.
msx_bank_in:
        push    af
        ld      a,(mb_seg_sim)
        call    mb_put_p2
        pop     af
        ret

msx_bank_out:
        push    af
        ld      a,(mb_seg_ui)
        call    mb_put_p2
        pop     af
        ret

mb_say:                                 ; DOS function 9 on de
        ld      c,9
        call    5
        ret

mb_msg_noext:   defm    "No extended BIOS: the banks need a mapper (MSX-DOS 2).", 13, 10, "$"
mb_msg_nomap:   defm    "No mapper found.", 13, 10, "$"
mb_msg_noseg:   defm    "No free segment for the banks.", 13, 10, "$"
mb_msg_nofile:  defm    "Cannot read SIMCITY.UI or SIMCITY.SIM.", 13, 10, "$"
mb_name_ui:     defm    "SIMCITY.UI", 0
mb_name_sim:    defm    "SIMCITY.SIM", 0
mb_name_hi:     defm    "SIMCITY.HI", 0

; Finds the mapper's routines: carry set (and a message said) if there is none
mb_find:
        ld      a,(HOKVLD)
        rrca
        ld      de,mb_msg_noext
        jr      nc,mb_err
        xor     a
        ld      de,$0401
        call    EXTBIO
        xor     a
        ld      de,$0402                ; the mapper support routines: A = the mapper's slot (0: none), HL = the table
        call    EXTBIO
        and     a
        ld      de,mb_msg_nomap
        jr      z,mb_err
        ld      de,mb_jump
        ld      bc,mb_jump_end - mb_jump
        ldir
        ld      a,1
        ld      (mb_have),a
        or      a
        ret
mb_err:
        call    mb_say
        scf
        ret

; Loads the file named by de into a new segment, mapped into page 2: a = the segment, carry set (and a message said) if it cannot
mb_load:
        push    de
        ld      b,0
        xor     a
        call    mb_all_seg
        pop     de
        ld      hl,mb_msg_noseg
        jr      c,mb_ld_err
        push    af                      ; the segment
        call    mb_put_p2
        ld      a,1                     ; DOS 2 open, read only
        ld      c,$43
        call    5
        and     a
        jr      nz,mb_ld_nofile
        push    bc                      ; b = the handle
        ld      de,$8000
        ld      hl,$4000
        ld      c,$48                   ; read
        call    5
        pop     bc                      ; (a partial read gives DOS 2's end of file error: not one to mind)
        ld      c,$45                   ; close
        call    5
        pop     af
        or      a
        ret
mb_ld_nofile:
        pop     af
        ld      hl,mb_msg_nofile
mb_ld_err:
        ex      de,hl
        call    mb_say
        scf
        ret

; Reads SIMCITY.HI to $C000, where the rest of the resident code is (no segment: page 3 is always there)
mb_load_hi:
        ld      de,mb_name_hi
        ld      a,1
        ld      c,$43
        call    5
        and     a
        jr      nz,mb_hi_err
        push    bc
        ld      de,$C000
        ld      hl,$1400                ; (the gate in the Makefile: at most this)
        ld      c,$48
        call    5
        pop     bc
        ld      c,$45
        call    5
        or      a
        ret
mb_hi_err:
        ld      de,mb_msg_nohi
        call    mb_say
        scf
        ret
mb_msg_nohi:    defm    "Cannot read SIMCITY.HI.", 13, 10, "$"

; main(): load both banks, run the game in the UI's, and give page 2 back
_main:
        call    mb_find
        jr      c,mb_end
        call    mb_get_p2
        ld      (mb_orig),a
        ld      de,mb_name_sim
        call    mb_load
        jr      c,mb_end
        ld      (mb_seg_sim),a
        ld      de,mb_name_ui
        call    mb_load
        jr      c,mb_end
        ld      (mb_seg_ui),a           ; (and it is the segment in page 2)
        call    mb_load_hi
        jr      c,mb_end
        call    _game_run
mb_end:
        call    mb_restore
        ld      hl,0
        ret

mb_restore:
        ld      a,(mb_have)
        or      a
        ret     z
        ld      a,(mb_orig)
        jp      mb_put_p2

; void msx_bye(void): back to DOS from anywhere (the game's error exits): page 2 as it was, then the C runtime's exit
_msx_bye:
        call    mb_restore
        jp      __Exit
