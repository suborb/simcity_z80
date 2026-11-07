; plat_file_save / plat_file_load / plat_file_list over the pack model: save a city under a name, clear the buffers, load it back, list, load a missing name.
        SECTION code_user
        org     $2000
start:  ld      sp,$7000
        ; the data: a = 100 bytes at $8000, b = 9000 bytes at $9000
        ld      hl,$8000
        ld      b,100
        ld      a,3
f1:     ld      (hl),a
        inc     hl
        add     a,7
        djnz    f1
        ld      hl,$9000
        ld      de,9000
        ld      a,5
f2:     ld      (hl),a
        inc     hl
        add     a,11
        dec     de
        ld      c,a
        ld      a,d
        or      e
        ld      a,c
        jr      nz,f2
        ld      hl,key1
        ld      de,$8000
        ld      bc,12
        ldir
        ; save "MYCITY"
        ld      hl,name1
        push    hl
        ld      hl,$8000
        push    hl
        ld      hl,100
        push    hl
        ld      hl,$9000
        push    hl
        ld      hl,9000
        push    hl
        call    _plat_file_save
        ld      ($7F00),hl
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ; and a second city, "OTHER", with a shorter map
        ld      hl,key2
        ld      de,$8000
        ld      bc,12
        ldir
        ld      hl,name2
        push    hl
        ld      hl,$8000
        push    hl
        ld      hl,50
        push    hl
        ld      hl,$9000
        push    hl
        ld      hl,300
        push    hl
        call    _plat_file_save
        ld      ($7F02),hl
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ; load "MYCITY" into $C000 / $D000
        ld      hl,name1
        push    hl
        ld      hl,$C000
        push    hl
        ld      hl,100
        push    hl
        ld      hl,$D000
        push    hl
        ld      hl,9000
        push    hl
        call    _plat_file_load
        ld      ($7F04),hl
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ; a name that is not there
        ld      hl,name3
        push    hl
        ld      hl,$C000
        push    hl
        ld      hl,100
        push    hl
        ld      hl,$D000
        push    hl
        ld      hl,9000
        push    hl
        call    _plat_file_load
        ld      ($7F06),hl
        ld      hl,10
        add     hl,sp
        ld      sp,hl
        ; the list
        ld      hl,$7800
        push    hl
        call    _plat_file_list
        pop     de
        ld      ($7F08),hl
        ld      a,1
        ld      bc,$00FE
        out     (c),a
done:   jp      done
key1:   defm    "MYCITY      "
key2:   defm    "OTHER       "
name1:  defm    "MYCITY",0
name2:  defm    "OTHER",0
name3:  defm    "NOPE",0
        EXTERN  _plat_file_save, _plat_file_load, _plat_file_list
