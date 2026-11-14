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
        INCLUDE "mapsize.inc"
        PUBLIC  _plat_file_save
        PUBLIC  _plat_file_load
        PUBLIC  _plat_file_list
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
        defc    HRSAD = $A0
        defc    CITY_LEN = 31 + MAP_CELLS ; a city file's length: the header block and the map (96 x 96 or the build's MAP_W x MAP_H: mapsize.inc; at most a page)
        defc    LIST_MAX = 8
        defc    FILE_CODE = 19
        defc    NAME = 10
        defc    DIFA = 80               ; the header the DOS passes back: this far above the UIFA
        defc    LMPR_BASIC = l_dcal + 2 ; where the startup code kept the LMPR it was started with
        defc    FS_PAGE = 12            ; the spare page (the game's are 1 to 8 and the screen's 10 and 11) and the one above it
        defc    FS_WINDOW = $8000       ; where the file is, with FS_PAGE in
        defc    FS_STUB = $C000         ; and what the DOS call needs, in the page after
        defc    FS_SP = $C0F0
        defc    FS_LMPR_BASIC = $C0F2
        defc    FS_LMPR_OURS = $C0F3
        defc    FS_ARGA = $C0F4         ; what the hook gets in a (HRSAD: the drive)
        defc    FS_STACK = $C100        ; (32 bytes)
        defc    FS_UIFA = $C200         ; the UIFA (48 bytes) and, 80 above it, the DIFA the DOS makes
        defc    FS_CHUNK = 128
        defc    FS_SAVE = FS_WINDOW + $2000     ; (the spare page: the program's first 512 bytes while HRSAD has them)

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

        IFDEF   HAVE_SCENARIOS
; The scenarios' files (tools/convert_amiga_scenarios.py --sam): the power map, 16 bits for the length of the coded traffic map, that map padded to SCEN_RLE bytes, and the map, a fixed length.
        PUBLIC  _plat_scenario_read
        PUBLIC  _plat_scenario_peek
        defc    SCEN_RLE = 512
        defc    SCEN_MAP_AT = MMO_POWER_SIZE + 2 + SCEN_RLE
        defc    SCEN_LEN = SCEN_MAP_AT + MAP_CELLS

; uint8_t plat_scenario_read(const char *name, uint8_t *map) __smallc: the scenario file into the spare page, which keeps it (plat_scenario_peek reads the rest of it), and its map to `map`
; (in the game's data): 0, or 1 if there is no such file.  Nothing else may use the spare page (the file module's other calls do) until the last peek.
_plat_scenario_read:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; map
        inc     hl
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; name
        ld      (f_b),de
        ld      (f_name),bc
        ld      hl,SCEN_LEN
        ld      (f_alen),hl
        ld      hl,0
        ld      (f_blen),hl
        push    ix
        call    fs_setup
        call    ld_fetch
        ld      a,h
        or      l
        jr      nz,fs_exit
        ld      hl,FS_WINDOW + SCEN_MAP_AT
        ld      (fs_src),hl
        ld      hl,(f_b)
        ld      (fs_dst),hl
        ld      hl,MAP_CELLS
        ld      (fs_len),hl
        call    fs_get
        ld      hl,0
        jr      fs_exit

; void plat_scenario_peek(uint8_t *dst, uint16_t off, uint16_t len) __smallc: len bytes of the scenario file at `off`, to `dst` in the game's data
_plat_scenario_peek:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; len
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; off
        inc     hl
        ld      a,(hl)
        inc     hl
        ld      h,(hl)
        ld      l,a                     ; dst
        ld      (fs_dst),hl
        ld      (fs_len),bc
        ld      hl,FS_WINDOW
        add     hl,de
        ld      (fs_src),hl
        in      a,(HMPR)
        and     31
        ld      (fs_dpage),a
        jp      fs_get
        ENDIF

; uint8_t plat_file_list(char *names) __smallc: the CODE files of a city's length in the disk's directory (up to LIST_MAX, in the order they are
; kept), as names of 13 bytes, the blanks at the end cut and a NUL.  The directory is the 40 sectors of tracks 0 to 3 of drive 1, two 256
; byte entries each, read with HRSAD into the spare page; it stops at the second sector in a row that is empty (nothing is kept after
; that).  Returns how many; the names are collected in fs_buf and copied to the game's data at the end.
_plat_file_list:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (f_name),de             ; where the names go
        push    ix
        in      a,(HMPR)
        and     31
        ld      (fs_dpage),a
        call    fs_prepare
        xor     a
        ld      (fl_n),a
        ld      (fl_count),a
        ld      (fl_gap),a
fn_sector:
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      a,1
        ld      (FS_ARGA),a             ; drive 1
        ld      a,(fl_n)
        ld      d,0
fn_div: cp      10
        jr      c,fn_ts
        sub     10
        inc     d
        jr      fn_div
fn_ts:  inc     a
        ld      e,a                     ; d = the track, e = the sector
; HRSAD does not read into the page HMPR gives $8000, as HLOAD does: it works the page out of the address (the DOS, at $5EE2: $4000 is page 0, $8000 page 1, $C000 page 2), so the sector goes to
; the first 512 bytes of page 1, which are the start of the program (the vectors, the startup, l_dcal and the LMPR it keeps, the bottom of the stack).  Those are put away in the spare page
; (interrupts off, as the vector at $0038 is not there while the DOS has them), the sector is copied to the spare page, and they go back.
        di
        push    de
        ld      de,FS_SAVE
        call    fs_p1_out
        pop     de
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      hl,FS_WINDOW            ; (a destination in section C: page 1)
        ld      a,HRSAD
        call    fs_dos_noei
        push    hl
        ld      de,FS_WINDOW
        call    fs_p1_out               ; the sector, to the spare page
        ld      hl,FS_SAVE
        call    fs_p1_in                ; and the program's own bytes back
        ld      a,FS_PAGE
        out     (HMPR),a
        IFDEF   HAVE_SOUND
        ei                              ; (the sound's frame interrupt: the stub leaves them off)
        ENDIF
        pop     hl
        ld      a,h
        or      l
        jr      nz,fn_end
        xor     a
        ld      (fl_blank),a
        ld      hl,FS_WINDOW
        call    fn_entry
        ld      hl,FS_WINDOW + 256
        call    fn_entry
        ld      a,(fl_blank)
        cp      2
        ld      a,(fl_gap)
        jr      nz,fn_nogap
        inc     a
        cp      2
        jr      z,fn_end                ; two empty sectors: the end of the directory
        jr      fn_gap
fn_nogap:
        xor     a
fn_gap: ld      (fl_gap),a
        ld      a,(fl_count)
        cp      LIST_MAX
        jr      nc,fn_end
        ld      hl,fl_n
        inc     (hl)
        ld      a,(hl)
        cp      40
        jr      c,fn_sector
fn_end:
        ld      a,(fs_dpage)
        out     (HMPR),a
        ld      hl,fs_buf
        ld      de,(f_name)
        ld      bc,LIST_MAX * 13
        ldir
        ld      a,(fl_count)
        ld      l,a
        ld      h,0
        jp      fs_exit

; hl = a directory entry (in the spare page): a CODE file of a city's length is added to the list
fn_entry:
        ld      a,(hl)
        or      a
        jr      nz,fe_used
        ld      a,(fl_blank)
        inc     a
        ld      (fl_blank),a
        ret
fe_used:
        and     $3F
        cp      FILE_CODE
        ret     nz
        push    hl
        ld      de,239
        add     hl,de
        ld      a,(hl)                  ; the pages
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the length modulo 16 KB
        pop     hl
        or      a
        ret     nz
        push    hl
        ld      hl,CITY_LEN
        or      a
        sbc     hl,de
        pop     hl
        ret     nz
        ld      a,(fl_count)
        cp      LIST_MAX
        ret     nc
        ld      e,a                     ; de = fs_buf + 13 * count
        add     a,a
        add     a,e
        add     a,a
        add     a,a
        add     a,e
        ld      e,a
        ld      d,0
        push    hl
        ld      hl,fs_buf
        add     hl,de
        ex      de,hl
        pop     hl
        inc     hl                      ; the name
        ld      bc,NAME
        ldir
        xor     a
        ld      (de),a
fe_trim:
        dec     de
        ld      a,(de)
        cp      ' '
        jr      nz,fe_done
        xor     a
        ld      (de),a
        jr      fe_trim
fe_done:
        ld      hl,fl_count
        inc     (hl)
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
        call    ld_fetch
        ld      a,h
        or      l
        ret     nz                      ; (hl = 1: the map is as it was)
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

; The file whose length is fs_total, from the disk into the spare page: hl = 0, or 1 if it is not there (or is more than the page holds)
ld_fetch:
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
        ld      (FS_ARGA),a             ; (a hook that wants nothing in a gets what it always did)
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

; 512 bytes of page 1 ($8000 with it paged in) to (de) in the spare page, 64 at a time through fs_xfer (fs_buf has the names so far); HMPR is left at the spare page
fs_p1_out:
        ld      hl,$8000
        ld      b,8
fo_l:   push    bc
        push    de
        ld      a,1
        out     (HMPR),a
        ld      de,fs_xfer
        ld      bc,64
        ldir
        pop     de
        ld      a,FS_PAGE
        out     (HMPR),a
        push    hl
        ld      hl,fs_xfer
        ld      bc,64
        ldir
        pop     hl
        pop     bc
        djnz    fo_l
        ret

; 512 bytes from (hl) in the spare page to page 1 ($8000); HMPR is left at page 1
fs_p1_in:
        ld      de,$8000
        ld      b,8
fi_l:   push    bc
        push    de
        ld      a,FS_PAGE
        out     (HMPR),a
        ld      de,fs_xfer
        ld      bc,64
        ldir
        pop     de
        ld      a,1
        out     (HMPR),a
        push    hl
        ld      hl,fs_xfer
        ld      bc,64
        ldir
        pop     hl
        pop     bc
        djnz    fi_l
        ret

; fs_dos without the interrupts coming back on after it
fs_dos_noei:
        ld      (FS_STUB + fs_hook - fs_stub_src),a
        jp      FS_STUB

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
        ld      a,(FS_ARGA)
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
fl_n:    defb   0
fl_count: defb  0
fl_gap:  defb   0
fl_blank: defb  0
fs_buf:  defs   FS_CHUNK
fs_xfer: defs   64
