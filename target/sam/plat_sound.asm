; The SAM Coupe's sound clock (target/common/ay_hooks.asm, target/common/ay_sfx.asm with -DAY_SAA -DAY_ISR): the frame interrupt, 50 Hz,
; calls ay_tick.  z88dk's interrupt handler (sam allram crt0) pages the data in over the high window for the length of an interrupt and puts
; back what was paged, so one can come while the placer has the screen in; it calls the handlers in a chain, and this is one.
; snd_init (called by plat_init) puts it in the chain, once, and turns interrupts on.
        MODULE  plat_sound

        PUBLIC  ay_sync, snd_init
        EXTERN  ay_tick, asm_im1_install_isr

        SECTION code_user
ay_frames:      defb    0               ; frames, counted by the interrupt
ay_seen:        defb    0               ; the count ay_sync last saw
ay_isr_in:      defb    0               ; the interrupt is in the chain

; The interrupt: a tick of the sound (it may use af, bc, de, hl)
ay_isr:
        ld      hl,ay_frames
        inc     (hl)
        jp      ay_tick

; Z if a frame has gone by since the last call (the soundfx1's wait)
ay_sync:
        ld      a,(ay_frames)
        ld      hl,ay_seen
        ld      c,(hl)
        ld      (hl),a
        cp      c
        jr      nz,ay_frame
        or      1                       ; NZ
        ret
ay_frame:
        xor     a
        ret

; Put the interrupt in the chain (once), and enable interrupts
snd_init:
        ld      a,(ay_isr_in)
        or      a
        jr      nz,snd_on
        inc     a
        ld      (ay_isr_in),a
        ld      de,ay_isr
        call    asm_im1_install_isr
snd_on:
        ei
        ret
