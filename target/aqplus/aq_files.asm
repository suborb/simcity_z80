; The files of the ESP32's current directory that are a city's size, for the file dialogues (plat_file_list: ui/platform.h), in assembler.
;
;     uint8_t plat_file_list(char *names) __smallc
;
; OPENDIR with an empty path (the current directory), then READDIR until it says no more (or LIST_MAX files have been found), then CLOSEDIR.
; READDIR answers: the result (0, or an error: ERR_EOF is $FC), the date (2 bytes), the time (2), the attributes (1: bit 0 is a directory), the
; size (4, least significant first) and the NUL terminated name.  A file is listed if it is not a directory, its size is CITY_LEN and its name
; fits an entry (NAMEMAX characters and a NUL: FILE_LIST_ENTRY in plat_config.h is 25).  Keeps IX.

        MODULE  aq_files
        SECTION code_user
        PUBLIC  _plat_file_list
        EXTERN  __esp_send_cmd
        EXTERN  __esp_send_byte
        EXTERN  __esp_read_byte

        defc    ESPCMD_OPENDIR = $16
        defc    ESPCMD_CLOSEDIR = $17
        defc    ESPCMD_READDIR = $18
        defc    ENTRY = 25
        defc    NAMEMAX = 24
        defc    LIST_MAX = 8
        defc    CITY_LEN = 31 + 96 * 96         ; the header block and the map (96 x 96 here)

_plat_file_list:
        ld      hl,2
        add     hl,sp
        ld      e,(hl)
        inc     hl
        ld      d,(hl)
        ld      (fl_dst),de
        xor     a
        ld      (fl_count),a
        ld      a,ESPCMD_OPENDIR
        call    __esp_send_cmd
        xor     a
        call    __esp_send_byte         ; the empty path
        call    __esp_read_byte
        ld      (fl_dir),a
        or      a
        jp      m,fl_done               ; (an error)
fl_next:
        ld      a,ESPCMD_READDIR
        call    __esp_send_cmd
        ld      a,(fl_dir)
        call    __esp_send_byte
        call    __esp_read_byte
        or      a
        jr      nz,fl_close             ; no more (or an error)
        ld      b,4                     ; the date and the time
fl_skip:
        call    __esp_read_byte
        djnz    fl_skip
        call    __esp_read_byte
        and     1
        ld      (fl_isdir),a
        call    __esp_read_byte
        ld      l,a
        call    __esp_read_byte
        ld      h,a                     ; hl = the size's low word
        call    __esp_read_byte
        ld      b,a
        call    __esp_read_byte
        or      b
        ld      (fl_high),a             ; the high word's bytes ORed: 0 if it is under 64 KB
        ld      de,(fl_dst)
        ld      c,0
fl_name:
        call    __esp_read_byte
        ld      (de),a
        or      a
        jr      z,fl_end
        inc     c
        ld      a,c
        cp      NAMEMAX + 1
        jr      nc,fl_long
        inc     de
        jr      fl_name
fl_long:                                ; too long for an entry: the rest of the name is read and it is not listed
        call    __esp_read_byte
        or      a
        jr      nz,fl_long
        jr      fl_next
fl_end:
        ld      a,(fl_isdir)
        ld      b,a
        ld      a,(fl_high)
        or      b
        jr      nz,fl_next
        ld      de,CITY_LEN
        or      a
        sbc     hl,de
        jr      nz,fl_next
        ld      hl,(fl_dst)             ; listed: the next entry
        ld      de,ENTRY
        add     hl,de
        ld      (fl_dst),hl
        ld      hl,fl_count
        inc     (hl)
        ld      a,(hl)
        cp      LIST_MAX
        jr      c,fl_next
fl_close:
        ld      a,ESPCMD_CLOSEDIR
        call    __esp_send_cmd
        ld      a,(fl_dir)
        call    __esp_send_byte
        call    __esp_read_byte
fl_done:
        ld      a,(fl_count)
        ld      l,a
        ld      h,0
        ret

        SECTION bss_user
fl_dst:   defw  0
fl_count: defb  0
fl_dir:   defb  0
fl_isdir: defb  0
fl_high:  defb  0
