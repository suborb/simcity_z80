; Saving and loading a city as a SAMDOS file (plat_file_save, plat_file_load: see ui/platform.h), through the DOS's hook codes
; (the SAM technical manual, "SAMDOS Interfacing"): a CODE file of the header block followed by the map, in place (the engine leaves
; room for the header block before the map: LEVELMAP_ROOM), written
; with HSAVE (an older file of the name is erased first, with HERAZ) and read with HGTHD (which says whether it is there and how long
; it is) and HLOAD.  SAMDOS names are 10 characters (FILE_NAME_MAX in plat_config.h keeps the player to that), and a longer one is cut.
;
;     uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen) __smallc
;     uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen) __smallc
;
; save returns 0 or 1; load returns 0, 1 if nothing was read (no such file, no DOS, a file of the wrong length) or 2 if the map is partly overwritten.
; Keeps IX.
;
; A hook is called with `rst 8; defb code`, which needs the ROM at $0000 and the system variables at $4000 (the LMPR that BASIC
; started the program with), so the program, which is in the low 32 KB, is paged out for the time it takes: the call is made from
; a copy of fs_stub_src in the data (above $8000, which the DOS leaves alone), with a stack of its own there.  The ROM would take the
; call for an error if bit 0 of DOSCNT ($5BC3) were set, so that is cleared; and the DOS returns through DOSER ($5BC0), which holds the
; address of fs_after for the time.  The UIFA and the data are above $8000 too, so that the DOS can see them; the data are in one
; 16 KB page (the Makefile checks), for the DOS to take the page and offset of the UIFA.

        MODULE  plat_sam_files
        SECTION code_user
        PUBLIC  _plat_file_save
        PUBLIC  _plat_file_load
        EXTERN  l_dcal
        EXTERN  mp_screen

        defc    LMPR = 250
        defc    HMPR = 251
        defc    DOSER = $5BC0
        defc    DOSCNT = $5BC3
        defc    HGTHD = $81
        defc    HLOAD = $82
        defc    HSAVE = $84
        defc    HERAZ = $A6
        defc    FILE_CODE = 19
        defc    NAME = 10
        defc    FS_ROOM = 64            ; the room before the map for the header block (the Makefile: -Ca-DLEVELMAP_ROOM=64)
        defc    DIFA = 80               ; the header the DOS passes back: this far above the UIFA
        defc    LMPR_BASIC = l_dcal + 2 ; where the startup code kept the LMPR it was started with

; The arguments (copied from the stack at the entry points, below)
_plat_file_save:
        ld      hl,2
        add     hl,sp
        ld      de,f_blen
        ld      bc,10                   ; blen, b, alen, a, name
        ldir
        push    ix
        call    sv_body
        push    hl
        call    mp_screen               ; (the ROM resets the palette)
        pop     hl
        pop     ix
        ret

_plat_file_load:
        ld      hl,2
        add     hl,sp
        ld      de,f_blen
        ld      bc,10
        ldir
        push    ix
        call    ld_body
        push    hl
        call    mp_screen
        pop     hl
        pop     ix
        ret

sv_body:
        call    fs_room
        jp      nz,fl_fail1             ; (a header block that does not fit before the map)
        call    fs_hdrpos               ; the header block goes in front of the map, and the two are the file
        ex      de,hl
        ld      hl,(f_a)
        ld      bc,(f_alen)
        ld      a,b
        or      c
        jr      z,sv_copied
        ldir
sv_copied:
        call    fs_prepare
        ld      a,HERAZ                 ; (an older file of the name goes: it is not an error if there was none)
        call    fs_dos_ix
        call    fs_mkuifa
        ld      a,HSAVE
        call    fs_dos_ix
        ld      a,h
        or      l
        jr      nz,fl_fail1
        ld      hl,0
        ret
fl_fail1:
        ld      hl,1
        ret

ld_body:
        call    fs_room
        jr      nz,fl_fail1
        call    fs_prepare
        ld      a,HGTHD                 ; (the DOS finds the file here: HLOAD goes on from it)
        call    fs_dos_ix
        ld      a,h
        or      l
        jr      nz,fl_fail1
        call    fs_total
        ex      de,hl                   ; de = the length
        ld      c,0                     ; the pages: none
        call    fs_hdrpos               ; where it goes: the header block's place, then the map
        ld      ix,fs_uifa
        ld      a,HLOAD
        call    fs_dos
        ld      a,h
        or      l
        jr      nz,ld_broken
        call    fs_hdrpos               ; the header block out of its place
        ld      de,(f_a)
        ld      bc,(f_alen)
        ld      a,b
        or      c
        jr      z,ld_ok
        ldir
ld_ok:
        ld      hl,0
        ret
ld_broken:
        ld      hl,2                    ; (the map is partly overwritten)
        ret

; The file is the header block and then the map, in the map's own place: the room before it (LEVELMAP_ROOM, in the engine's buffers).
; fs_room: z if the header block fits the room.
fs_room:
        ld      hl,FS_ROOM
        ld      de,(f_alen)
        or      a
        sbc     hl,de
        sbc     a,a                     ; (carry: it is longer: nz)
        ret

; hl = where the header block goes: the map's address less its length
fs_hdrpos:
        ld      hl,(f_b)
        ld      de,(f_alen)
        or      a
        sbc     hl,de
        ret

; hl = the file's length: the header block and the map
fs_total:
        ld      hl,(f_alen)
        ld      de,(f_blen)
        add     hl,de
        ret

; The stub is copied to where the DOS leaves it alone, the two LMPR values are noted, and the UIFA is made.
fs_prepare:
        ld      hl,fs_stub_src
        ld      de,fs_stub
        ld      bc,fs_stub_end - fs_stub_src
        ldir
        ld      a,(LMPR_BASIC)
        ld      (fs_lmpr_basic),a
        in      a,(LMPR)
        ld      (fs_lmpr_ours),a
        ; fall into fs_mkuifa

; The UIFA for the name: a CODE file the length of the header block and the map, its 10 character name padded with spaces.
fs_mkuifa:
        ld      hl,fs_uifa
        ld      de,fs_uifa + 1
        ld      bc,127
        ld      (hl),0
        ldir                            ; the UIFA and the room for the DIFA
        ld      a,FILE_CODE
        ld      (fs_uifa),a
        ld      hl,(f_name)
        ld      de,fs_uifa + 1
        ld      b,NAME + 4              ; the name's 14 bytes
        ld      c,0                     ; 1 once the name has ended
mk_name:
        ld      a,' '
        bit     0,c
        jr      nz,mk_store
        ld      a,b
        cp      5
        jr      c,mk_end                ; (the name's own 10 characters are done)
        ld      a,(hl)
        or      a
        jr      z,mk_end
        inc     hl
        jr      mk_store
mk_end:
        ld      c,1
        ld      a,' '
mk_store:
        ld      (de),a
        inc     de
        djnz    mk_name
        in      a,(HMPR)
        and     31
        call    fs_hdrpos               ; where the file "starts": the header block's page and offset (the DOS pages by 16 KB: the
        bit     6,h                     ; data's section C is the first page, D the next, and an offset is $8000-$BFFF)
        jr      z,mk_sec
        inc     a
        ld      de,$4000
        or      a
        sbc     hl,de
mk_sec:
        ld      (fs_uifa + 31),a
        ld      (fs_uifa + 32),hl
        call    fs_total
        ld      (fs_uifa + 35),hl       ; (under 16 KB: no whole pages)
        ld      a,$FF
        ld      (fs_uifa + 37),a        ; no execution address
        ret

; Hook a (de, bc, hl as the hook wants them) with ix = the UIFA.  Returns hl = the error number, 0 if there was none.
fs_dos_ix:
        ld      ix,fs_uifa
fs_dos:
        ld      (fs_stub + fs_hook - fs_stub_src),a
        IFDEF   HAVE_SOUND
        call    fs_stub
        ei                              ; (the sound's frame interrupt: the stub leaves them off)
        ret
        ELSE
        jp      fs_stub
        ENDIF

; The stub.  It is copied to fs_stub and must not depend on where it is: it gets to its variables by their addresses.
fs_stub_src:
        di
        ld      (fs_sp),sp
        ld      sp,fs_stack + 32
        ld      a,(fs_lmpr_basic)
        out     (LMPR),a                ; the ROM and the system variables are back
        push    hl                      ; (HLOAD takes its address in hl)
        ld      hl,DOSCNT
        res     0,(hl)                  ; (set, the ROM takes the RST 8 for an error report)
        ld      hl,fs_stub + fs_after - fs_stub_src
        ld      (DOSER),hl              ; "return from DOS": the ROM jumps here when the hook has run, a = 0 or the error
        pop     hl
        rst     8
fs_hook:
        defb    0
fs_after:
        ld      hl,0
        ld      (DOSER),hl
        ld      l,a                     ; the error (hl was 0)
        ld      a,(fs_lmpr_ours)
        out     (LMPR),a                ; and the program is back
        ld      sp,(fs_sp)
        di
        ret
fs_stub_end:

        SECTION bss_user
fs_stub: defs   fs_stub_end - fs_stub_src
fs_sp:   defw   0
fs_lmpr_basic: defb 0
fs_lmpr_ours:  defb 0
fs_stack: defs  32
fs_uifa: defs   128                     ; the UIFA (48 bytes) and, 80 above it, the DIFA the DOS makes
f_blen:  defw   0                       ; the arguments, in this order
f_b:     defw   0
f_alen:  defw   0
f_a:     defw   0
f_name:  defw   0
