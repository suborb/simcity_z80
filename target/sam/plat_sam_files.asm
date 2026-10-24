; Saving and loading a city as a SAMDOS file (plat_file_save, plat_file_load: see ui/platform.h), through the DOS's hook codes
; (the SAM technical manual, "SAMDOS Interfacing"): a CODE file of the header block followed by the map, written with HSAVE (an older file of
; the name is erased first, with HERAZ) and read with HGTHD (which says whether it is there) and HLOAD.  SAMDOS names are 10 characters
; (FILE_NAME_MAX in plat_config.h keeps the player to that), and a longer one is cut.
;
;     uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen) __smallc
;     uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen) __smallc
;
; save returns 0 or 1; load returns 0, or 1 if nothing was read (no such file, no DOS).  The map is only changed by a load that worked.  Keeps IX.
;
; HLOAD (and HSAVE) take the file's place in memory as a destination between $8000 and $BFFF, in the page that HMPR gives that window, so the
; game's data (which is in two pages, and the map in the second) cannot be where the DOS works.  The file is made, or read, in a spare page
; (FS_PAGE) paged in at $8000, a piece at a time from, or to, the game's data through a buffer in low memory.  The page above it, which is
; at $C000 then, holds what the call needs: the stub, its stack, its variables and the UIFA.
;
; A hook is called with `rst 8; defb code`, which needs the ROM at $0000 and the system variables at $4000 (the LMPR that BASIC
; started the program with), so the program, which is in the low 32 KB, is paged out for the time it takes: the call is made from
; a copy of fs_stub_src in the page above the spare one, with a stack of its own there.  The ROM would take the call for an error if
; bit 0 of DOSCNT ($5BC3) were set, so that is cleared; and the DOS returns through DOSER ($5BC0), which holds the address of fs_after for
; the time.  The DOS takes the page and offset of the UIFA's file from its fields.

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
        defc    DIFA = 80               ; the header the DOS passes back: this far above the UIFA
        defc    LMPR_BASIC = l_dcal + 2 ; where the startup code kept the LMPR it was started with
        defc    FS_PAGE = 12            ; the spare page (the game's are 1 to 6 and the screen's 8 and 9) and the one above it
        defc    FS_WINDOW = $8000       ; where the file is, with FS_PAGE in
        defc    FS_STUB = $C000         ; and what the DOS call needs, in the page after
        defc    FS_SP = $C0F0
        defc    FS_LMPR_BASIC = $C0F2
        defc    FS_LMPR_OURS = $C0F3
        defc    FS_STACK = $C100        ; (32 bytes)
        defc    FS_UIFA = $C200         ; the UIFA (48 bytes) and, 80 above it, the DIFA the DOS makes
        defc    FS_CHUNK = 128

; The arguments (copied from the stack at the entry points, below)
_plat_file_save:
        ld      hl,2
        add     hl,sp
        ld      de,f_blen
        ld      bc,10                   ; blen, b, alen, a, name
        ldir
        push    ix
        call    fs_setup
        call    sv_body
        jr      fs_exit

_plat_file_load:
        ld      hl,2
        add     hl,sp
        ld      de,f_blen
        ld      bc,10
        ldir
        push    ix
        call    fs_setup
        call    ld_body
fs_exit:
        push    hl
        ld      a,(fs_dpage)            ; the game's data back at $8000
        out     (HMPR),a
        call    mp_screen               ; (the ROM resets the palette)
        pop     hl
        pop     ix
        ret

; Note the page the game's data is in, and copy the name (it is in the data, which will not be there) to fs_name, padded with spaces
fs_setup:
        in      a,(HMPR)
        and     31
        ld      (fs_dpage),a
        ld      hl,(f_name)
        ld      de,fs_name
        ld      b,NAME
fa_name:
        ld      a,(hl)
        or      a
        jr      z,fa_pad
        ld      (de),a
        inc     hl
        inc     de
        djnz    fa_name
        ret
fa_pad:
        ld      a,' '
fa_padl:
        ld      (de),a
        inc     de
        djnz    fa_padl
        ret

sv_body:
        call    fs_total
        ld      a,h
        cp      $40
        jr      nc,fl_fail1             ; (more than the spare page holds)
        ld      hl,(f_a)                ; the header block, then the map, into the spare page
        ld      (fs_src),hl
        ld      hl,FS_WINDOW
        ld      (fs_dst),hl
        ld      hl,(f_alen)
        ld      (fs_len),hl
        call    fs_put
        ld      hl,(f_b)
        ld      (fs_src),hl
        ld      hl,(f_blen)
        ld      (fs_len),hl
        call    fs_put
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
        call    fs_total
        ld      a,h
        cp      $40
        jr      nc,fl_fail1
        call    fs_prepare
        ld      a,HGTHD                 ; (the DOS finds the file here: HLOAD goes on from it)
        call    fs_dos_ix
        ld      a,h
        or      l
        jr      nz,fl_fail1
        call    fs_total
        ex      de,hl                   ; de = the length
        ld      hl,FS_WINDOW            ; where it goes
        ld      c,0                     ; the pages: none
        ld      ix,FS_UIFA
        ld      a,HLOAD
        call    fs_dos
        ld      a,h
        or      l
        jr      nz,fl_fail1             ; (the map is as it was: the file went to the spare page)
        ld      hl,FS_WINDOW            ; the header block, then the map, out of the spare page
        ld      (fs_src),hl
        ld      hl,(f_a)
        ld      (fs_dst),hl
        ld      hl,(f_alen)
        ld      (fs_len),hl
        call    fs_get
        ld      hl,(f_b)
        ld      (fs_dst),hl
        ld      hl,(f_blen)
        ld      (fs_len),hl
        call    fs_get
        ld      hl,0
        ret

; hl = the file's length: the header block and the map
fs_total:
        ld      hl,(f_alen)
        ld      de,(f_blen)
        add     hl,de
        ret

; fs_len bytes from fs_src (in the game's data) to fs_dst (in the spare page): fs_src and fs_dst go on from where they end.
fs_put:
        ld      bc,(fs_len)
        ld      a,b
        or      c
        ret     z
        ld      a,b
        or      a
        jr      nz,fp_full
        ld      a,c
        cp      FS_CHUNK + 1
        jr      c,fp_n
fp_full:
        ld      a,FS_CHUNK
fp_n:   ld      c,a                     ; bc = this piece
        ld      b,0
        ld      hl,(fs_len)
        or      a
        sbc     hl,bc
        ld      (fs_len),hl
        ld      a,(fs_dpage)
        out     (HMPR),a
        ld      hl,(fs_src)
        ld      de,fs_buf
        push    bc
        ldir
        ld      (fs_src),hl
        pop     bc
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      hl,fs_buf
        ld      de,(fs_dst)
        ldir
        ld      (fs_dst),de
        jr      fs_put

; fs_len bytes from fs_src (in the spare page) to fs_dst (in the game's data)
fs_get:
        ld      bc,(fs_len)
        ld      a,b
        or      c
        ret     z
        ld      a,b
        or      a
        jr      nz,fg_full
        ld      a,c
        cp      FS_CHUNK + 1
        jr      c,fg_n
fg_full:
        ld      a,FS_CHUNK
fg_n:   ld      c,a
        ld      b,0
        ld      hl,(fs_len)
        or      a
        sbc     hl,bc
        ld      (fs_len),hl
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      hl,(fs_src)
        ld      de,fs_buf
        push    bc
        ldir
        ld      (fs_src),hl
        pop     bc
        ld      a,(fs_dpage)
        out     (HMPR),a
        ld      hl,fs_buf
        ld      de,(fs_dst)
        ldir
        ld      (fs_dst),de
        jr      fs_get

; The stub is copied to the page after the spare one, the two LMPR values are noted, and the UIFA is made.  (The spare page is in.)
fs_prepare:
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      hl,fs_stub_src
        ld      de,FS_STUB
        ld      bc,fs_stub_end - fs_stub_src
        ldir
        ld      a,(LMPR_BASIC)
        ld      (FS_LMPR_BASIC),a
        in      a,(LMPR)
        ld      (FS_LMPR_OURS),a
        ; fall into fs_mkuifa

; The UIFA for the name: a CODE file the length of the header block and the map, its 10 character name padded with spaces, in the spare page.
fs_mkuifa:
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      hl,FS_UIFA
        ld      de,FS_UIFA + 1
        ld      bc,127
        ld      (hl),0
        ldir                            ; the UIFA and the room for the DIFA
        ld      a,FILE_CODE
        ld      (FS_UIFA),a
        ld      hl,fs_name
        ld      de,FS_UIFA + 1
        ld      bc,NAME
        ldir
        ld      a,' '
        ld      b,4                     ; (the name's 14 bytes)
mk_pad:
        ld      (de),a
        inc     de
        djnz    mk_pad
        ld      a,FS_PAGE
        ld      (FS_UIFA + 31),a        ; where the file "starts": the page and the offset in $8000 to $BFFF
        ld      hl,FS_WINDOW
        ld      (FS_UIFA + 32),hl
        call    fs_total
        ld      (FS_UIFA + 35),hl       ; (under 16 KB: no whole pages)
        ld      a,$FF
        ld      (FS_UIFA + 37),a        ; no execution address
        ret

; Hook a (de, bc, hl as the hook wants them) with ix = the UIFA.  Returns hl = the error number, 0 if there was none.
fs_dos_ix:
        ld      ix,FS_UIFA
fs_dos:
        ld      (FS_STUB + fs_hook - fs_stub_src),a
        IFDEF   HAVE_SOUND
        call    FS_STUB
        ei                              ; (the sound's frame interrupt: the stub leaves them off)
        ret
        ELSE
        jp      FS_STUB
        ENDIF

; The stub.  It is copied to FS_STUB and must not depend on where it is: it gets to its variables by their addresses.
fs_stub_src:
        di
        ld      (FS_SP),sp
        ld      sp,FS_STACK + 32
        ld      a,(FS_LMPR_BASIC)
        out     (LMPR),a                ; the ROM and the system variables are back
        push    hl                      ; (HLOAD takes its address in hl)
        ld      hl,DOSCNT
        res     0,(hl)                  ; (set, the ROM takes the RST 8 for an error report)
        ld      hl,FS_STUB + fs_after - fs_stub_src
        ld      (DOSER),hl              ; "return from DOS": the ROM jumps here when the hook has run, a = 0 or the error
        pop     hl
        rst     8
fs_hook:
        defb    0
fs_after:
        ld      hl,0
        ld      (DOSER),hl
        ld      l,a                     ; the error (hl was 0)
        ld      a,(FS_LMPR_OURS)
        out     (LMPR),a                ; and the program is back
        ld      sp,(FS_SP)
        di
        ret
fs_stub_end:

; (in low memory, where they are kept while the data's page is out)
f_blen:  defw   0                       ; the arguments, in this order
f_b:     defw   0
f_alen:  defw   0
f_a:     defw   0
f_name:  defw   0
fs_name: defs   NAME
fs_dpage: defb  0
fs_src:  defw   0
fs_dst:  defw   0
fs_len:  defw   0
fs_buf:  defs   FS_CHUNK
