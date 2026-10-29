; Saving and loading a city on the Sharp X1's disk (plat_file_save, plat_file_load: see ui/platform.h), in assembler.
;
; A city is kept in one of SLOTS slots of SLOT_TRACKS tracks from track SLOT_TRACK0 (the program is below).  A slot's first
; sector has the header block, zero padded, with the mark "SC" in its last two bytes; the map's sectors follow.  The first 12
; bytes of the header are the file name, so a name finds its slot, and a save takes the slot that has the same name or else
; the first one without a mark.  The map is written before the header, so a slot is only marked once it is complete.  The sectors
; go through z88dk's asm_x1_disk_regs.
;
;     uint8_t plat_file_save(const char *name, const uint8_t *a, uint16_t alen, const uint8_t *b, uint16_t blen) __smallc
;     uint8_t plat_file_load(const char *name, uint8_t *a, uint16_t alen, uint8_t *b, uint16_t blen) __smallc
;
; save returns 0 or 1 (an error, a full disk, a block too long); load returns 0, 1 if there is no such file (or the header
; cannot be read), 2 if the map could not be read.  The name is 12 characters, blank after the first space.  Keeps IX.

        MODULE  plat_x1_files
        SECTION code_user
        PUBLIC  _plat_file_save
        PUBLIC  _plat_file_load
        EXTERN  asm_x1_disk_regs

        defc    SLOT_TRACK0 = 24
        defc    SLOT_TRACKS = 3
        defc    SLOTS = 8
        defc    KEY = 12
        defc    MAX_WHOLE = SLOT_TRACKS * 16 - 3        ; sectors of the map that fit (the header and the tail take two)

; The arguments (copied from the stack: this is called by the entries below, which are called from C)
fl_args:
        ld      hl,4
        add     hl,sp
        ld      de,f_blen
        ld      bc,10                   ; blen, b, alen, a, name
        ldir
        ret

_plat_file_save:
        call    fl_args
        ld      hl,(f_alen)
        ld      de,253
        or      a
        sbc     hl,de
        jp      nc,fl_fail1             ; alen > 252
        ld      a,(f_blen + 1)
        cp      MAX_WHOLE + 1
        jp      nc,fl_fail1
        call    fl_find
        ld      a,(f_found)
        cp      255
        jr      nz,sv_slot
        ld      a,(f_spare)
        cp      255
        jp      z,fl_fail1              ; the disk is full of other names
sv_slot:
        call    fl_track0
        ld      a,(f_blen + 1)          ; the whole sectors of the map
        or      a
        jr      z,sv_tail
        ld      b,a
        ld      c,2
        ld      hl,(f_b)
        ld      a,1
        call    fl_io
        jp      nz,fl_fail1
sv_tail:
        ld      a,(f_blen)
        or      a
        jr      z,sv_head
        call    fl_clear                ; the last part sector, zero padded
        ld      hl,(f_b)
        ld      a,(f_blen + 1)
        add     a,h
        ld      h,a                     ; b + 256 * whole
        ld      de,f_sector
        ld      a,(f_blen)
        ld      c,a
        ld      b,0
        ldir
        call    fl_tail
        ld      hl,f_sector
        ld      a,1
        call    fl_io1
        jp      nz,fl_fail1
sv_head:
        call    fl_clear                ; the header, and the mark
        ld      hl,(f_a)
        ld      de,f_sector
        ld      bc,(f_alen)
        ld      a,b
        or      c
        jr      z,sv_mark
        ldir
sv_mark:
        ld      a,'S'
        ld      (f_sector + 254),a
        ld      a,'C'
        ld      (f_sector + 255),a
        ld      a,(f_t0)
        ld      d,a
        ld      c,1
        ld      hl,f_sector
        ld      a,1
        call    fl_io1
        ld      hl,0
        ret     z
fl_fail1:
        ld      hl,1
        ret

_plat_file_load:
        call    fl_args
        call    fl_find
        ld      a,(f_found)
        cp      255
        jp      z,fl_fail1
        ld      hl,(f_alen)
        ld      de,253
        or      a
        sbc     hl,de
        jp      nc,fl_fail1
        call    fl_track0
        ld      b,1                     ; the header
        ld      c,1
        ld      hl,f_sector
        xor     a
        call    fl_io
        jp      nz,fl_fail1
        ld      hl,f_sector
        ld      de,(f_a)
        ld      bc,(f_alen)
        ld      a,b
        or      c
        jr      z,ld_map
        ldir
ld_map:
        ld      a,(f_blen + 1)
        or      a
        jr      z,ld_tail
        ld      b,a
        ld      c,2
        ld      hl,(f_b)
        xor     a
        call    fl_io
        jp      nz,fl_fail2
ld_tail:
        ld      a,(f_blen)
        or      a
        jr      z,ld_ok
        call    fl_tail
        ld      hl,f_sector
        xor     a
        call    fl_io1
        jp      nz,fl_fail2
        ld      hl,f_sector
        ld      de,(f_b)
        ld      a,(f_blen + 1)
        add     a,d
        ld      d,a
        ld      a,(f_blen)
        ld      c,a
        ld      b,0
        ldir
ld_ok:
        ld      hl,0
        ret
fl_fail2:
        ld      hl,2
        ret

; The disk: a = the mode (0 read, 1 write), c = the first sector, hl = the buffer; b = the sectors and the track f_t0 (fl_io), or one sector
; of the track d (fl_io1).  Nz if the unit reported an error.
fl_io:
        push    af
        ld      a,(f_t0)
        ld      d,a
        pop     af
        jr      fl_rw
fl_io1:
        ld      b,1
fl_rw:
        ld      e,0                     ; drive 0
        call    asm_x1_disk_regs
        ld      a,h
        or      l
        ret

; f_t0 = the track of slot f_found (or f_spare if there is none with the name)
fl_track0:
        ld      a,(f_found)
        cp      255
        jr      nz,t0_have
        ld      a,(f_spare)
t0_have:
        call    fl_slot_track
        ld      (f_t0),a
        ret

; a = the track of slot a
fl_slot_track:
        ld      b,a
        add     a,a
        add     a,b
        add     a,SLOT_TRACK0
        ret

; d = the track and c = the sector of the map's last, part sector: the sector after the map's whole ones (the header is first)
fl_tail:
        ld      a,(f_blen + 1)
        inc     a
        ld      c,a
        rrca
        rrca
        rrca
        rrca
        and     15
        ld      hl,f_t0
        add     a,(hl)
        ld      d,a
        ld      a,c
        and     15
        inc     a
        ld      c,a
        ret

fl_clear:
        ld      hl,f_sector
        ld      de,f_sector + 1
        ld      bc,255
        ld      (hl),0
        ldir
        ret

; f_key = the name (12 characters, blank after the first space) of the string in hl
fl_key:
        ld      de,f_key
        ld      b,KEY
        ld      c,0                     ; 1 once a space has been stored
key_next:
        ld      a,' '
        bit     0,c
        jr      nz,key_store
        ld      a,(hl)
        or      a
        jr      nz,key_char
        ld      a,' '
key_char:
        cp      ' '
        jr      nz,key_store
        ld      c,1
key_store:
        ld      (de),a
        inc     hl
        inc     de
        djnz    key_next
        ret

; f_found = the slot whose header has the name (255 if none), f_spare = the first slot without a mark (255 if none)
fl_find:
        ld      hl,(f_name)
        call    fl_key
        ld      a,255
        ld      (f_found),a
        ld      (f_spare),a
        xor     a
fd_next:
        ld      (f_s),a
        call    fl_slot_track
        ld      d,a
        ld      c,1
        ld      hl,f_sector
        xor     a
        call    fl_io1
        jr      nz,fd_skip              ; a track that cannot be read is not a slot
        ld      a,(f_sector + 254)
        cp      'S'
        jr      nz,fd_unmarked
        ld      a,(f_sector + 255)
        cp      'C'
        jr      nz,fd_unmarked
        ld      a,(f_found)
        cp      255
        jr      nz,fd_skip
        ld      hl,f_sector
        ld      de,f_key
        ld      b,KEY
fd_cmp:
        ld      a,(de)
        cp      (hl)
        jr      nz,fd_skip
        inc     hl
        inc     de
        djnz    fd_cmp
        ld      a,(f_s)
        ld      (f_found),a
        jr      fd_skip
fd_unmarked:
        ld      a,(f_spare)
        cp      255
        jr      nz,fd_skip
        ld      a,(f_s)
        ld      (f_spare),a
fd_skip:
        ld      a,(f_s)
        inc     a
        cp      SLOTS
        jr      nz,fd_next
        ret

        SECTION bss_user
f_blen: defw    0                       ; the arguments, in this order (fl_args)
f_b:    defw    0
f_alen: defw    0
f_a:    defw    0
f_name: defw    0
f_key:  defs    KEY
f_found: defb   0
f_spare: defb   0
f_s:    defb    0
f_t0:   defb    0
f_sector: defs  256
