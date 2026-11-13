; Samsung SPC-1500: the cassette, with the IPL ROM's own tape routines (the ones its "C: cassette system" uses): the machine's format, one copy of each block (a leader, the
; bytes each as a one bit and eight, the count of one bits as two bytes, an end bit).
;
;     uint8_t spc1500_tape(uint8_t cmd, void *buf, uint16_t len) __smallc
;
; cmd 0 loads a header block (128 bytes) and 1 a data block of len bytes to buf; 2 saves a header block and 3 a data block.  It returns 0 if it was done and 1 if it failed or
; was stopped (the player's Shift and Break together).  The ROM waits for the deck to run (the player presses PLAY, or RECORD and PLAY, and it says so on its own screen: the text
; layer, which the graphics priority hides; mp_hw_reset puts the screen back).
;
; The IPL ROM is at $0000-$7FFF while it is paged in (I/O port $1D00), which hides the game, whose code and data are there too.  So what talks to the ROM is a little routine that
; is copied to rc_buf, in the uninitialised data above $8000, each time; the buffers it works on are up there too.  It calls the ROM's routines as the ROM's own entries do, past their
; EXX and, for the saves, past the ROM's messages: $23D2 counts the one bits, $2335 waits for the deck, $246C writes the leader and $2161 the block; $2195 and $21B0 load a header
; and a data block.  The ROM's routines leave the interrupts on: they are turned off again.

        MODULE  plat_files
        SECTION code_user
        PUBLIC  _spc1500_tape
        EXTERN  mp_hw_reset

_spc1500_tape:
        ld      hl,2
        add     hl,sp
        ld      c,(hl)
        inc     hl
        ld      b,(hl)                  ; len
        ld      (rc_bc),bc
        inc     hl
        ld      e,(hl)
        inc     hl
        ld      d,(hl)                  ; buf
        ld      (rc_hl),de
        inc     hl
        ld      a,(hl)                  ; cmd
        ld      (rc_cmd),a
        ld      hl,rc_start             ; the routine to its home above $8000
        ld      de,rc_buf
        ld      bc,rc_end - rc_start
        ldir
        push    ix
        call    rc_buf
        pop     ix
        call    mp_hw_reset
        ld      a,(rc_res)
        ld      l,a
        ld      h,0
        ret

; The routine that runs from rc_buf (so: no absolute addresses of its own, other than rc_buf's)
rc_start:
        di
        ld      a,$F2                   ; the 8255's port C as plat_init has it: the ROM keeps a copy, and merges it into what it writes for the tape
        ld      ($F88E),a
        ld      bc,$1D00                ; ROM select
        out     (c),a
        call    rc_buf + rc_body - rc_start
        di
        ld      bc,$1E00                ; RAM select
        out     (c),a
        ld      a,0
        rla                             ; the carry the ROM's routine left: 1 if it failed
        ld      (rc_res),a
        ret
rc_body:
        ld      hl,(rc_hl)
        ld      bc,(rc_bc)
        ld      a,(rc_cmd)
        cp      2
        jr      nc,rc_save
        or      a
        jp      z,$2195                 ; load a header block
        jp      $21B0                   ; load a data block
rc_save:
        sub     2
        ld      e,$CC                   ; the ROM's marks: $CC a header block (a longer leader), $53 a data block
        jr      z,rc_s1
        ld      e,$53
rc_s1:
        push    de
        push    bc
        push    hl
        call    $23D2                   ; the count of one bits, the checksum
        call    $2335                   ; wait for the deck
        jp      c,$220A                 ; (stopped)
        call    $246C                   ; the leader
        call    $2161                   ; the block, and the checksum
        jp      $220A                   ; the deck off, the registers back, EI, RET
rc_end:

        SECTION bss_user
rc_hl:  defw    0
rc_bc:  defw    0
rc_cmd: defb    0
rc_res: defb    0
rc_buf: defs    rc_end - rc_start
