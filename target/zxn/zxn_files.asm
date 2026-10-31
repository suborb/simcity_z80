; The files of the current directory that are a city's size, for the file dialogues (plat_file_list: ui/platform.h), in assembler.
;
;     uint8_t plat_file_list(char *names) __smallc
;
; z88dk's esxDOS routines (opendir, readdir, close) use IX, which the compiled code keeps its frame in, so this is in assembler, which keeps IX
; (and reloads its own frame pointer after each call).  What esxDOS is given is in the upper RAM: the stack, and zxn_scratch (scenarios.c) for the
; path (the program's strings are below $4000, which the DivMMC pages out).  The directory entry is the attributes, the NUL terminated name, the date and time (4 bytes) and the size (4).
; Returns 255 if the directory cannot be opened (the game then asks for a name).  A file that is not a directory and is CITY_LEN long is listed, as a name of 13 bytes (the 8.3 names are at most 12 characters).

        MODULE  zxn_files
        SECTION code_user
        PUBLIC  _plat_file_list
        EXTERN  asm_esx_f_opendir
        EXTERN  asm_esx_f_readdir
        EXTERN  asm_esx_f_closedir
        EXTERN  asm_esx_f_getcwd
        EXTERN  _zxn_scratch

        defc    ENTRY = 13
        defc    LIST_MAX = 8
        defc    CITY_LEN = 31 + MAP_W * MAP_H   ; the header block and the map
        defc    DIRENT = 22                     ; the entry: attributes, a name of 12 and its NUL, 8 bytes
        defc    F_PATH = 22                     ; the frame: the entry, the path ".", the handle, the count, where the next name goes
        defc    F_HANDLE = 24
        defc    F_COUNT = 25
        defc    F_DST = 26
        defc    FRAME = 28

_plat_file_list:
        push    ix
        ld      hl,4
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; the names
        ld      hl,-FRAME
        add     hl,sp
        ld      sp,hl
        call    fl_ix
        ld      (ix+F_DST),e
        ld      (ix+F_DST+1),d
        ld      (ix+F_COUNT),0
        ld      (ix+F_PATH),'.'
        ld      (ix+F_PATH+1),0
        ld      hl,_zxn_scratch
        call    asm_esx_f_getcwd        ; the directory's path (NextZXOS wants one: "." is not taken) ...
        call    fl_ix
        ld      a,h
        or      l
        ld      hl,_zxn_scratch
        jr      z,fl_open
        push    ix                      ; ... or ".", if it could not say
        pop     hl
        ld      de,F_PATH
        add     hl,de
fl_open:
        call    asm_esx_f_opendir
        call    fl_ix
        ld      a,l
        inc     a
        jr      nz,fl_opened
        ld      (ix+F_COUNT),255        ; it did not open: 255 says the directory cannot be listed
        jr      fl_out
fl_opened:
        dec     a
        ld      (ix+F_HANDLE),a
fl_next:
        ld      a,(ix+F_HANDLE)
        push    ix
        pop     hl
        call    asm_esx_f_readdir
        call    fl_ix
        ld      a,l
        cp      1
        jr      nz,fl_close             ; no more (or an error)
        bit     4,(ix+0)
        jr      nz,fl_next              ; a directory
        push    ix
        pop     hl
        inc     hl
        push    hl                      ; the name
        xor     a
        ld      bc,DIRENT
        cpir                            ; hl is after its NUL: the date and time, then the size
        ld      de,4
        add     hl,de
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        inc     hl
        ld      a,(hl)
        inc     hl
        or      (hl)
        jr      nz,fl_skip
        ld      hl,CITY_LEN
        or      a
        sbc     hl,de
        jr      nz,fl_skip
        pop     hl
        ld      e,(ix+F_DST)
        ld      d,(ix+F_DST+1)
fl_copy:
        ld      a,(hl)
        ld      (de),a
        inc     hl
        inc     de
        or      a
        jr      nz,fl_copy
        ld      l,(ix+F_DST)
        ld      h,(ix+F_DST+1)
        ld      de,ENTRY
        add     hl,de
        ld      (ix+F_DST),l
        ld      (ix+F_DST+1),h
        inc     (ix+F_COUNT)
        ld      a,(ix+F_COUNT)
        cp      LIST_MAX
        jr      c,fl_next
        jr      fl_close
fl_skip:
        pop     hl
        jr      fl_next
fl_close:
        ld      l,(ix+F_HANDLE)
        call    asm_esx_f_closedir
        call    fl_ix
fl_out:
        ld      l,(ix+F_COUNT)
        ld      h,0
        ld      de,FRAME
        ex      de,hl
        add     hl,sp
        ld      sp,hl
        ex      de,hl
        pop     ix
        ret

fl_ix:                                  ; ix = the frame (sp, less the return address)
        ld      ix,2
        add     ix,sp
        ret
