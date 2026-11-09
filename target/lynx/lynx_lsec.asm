;
;	Camputers Lynx: the file code's sectors of 256 bytes, on z88dk's disk driver (lynx_disk_read, asm_lynx_disk_regs: sectors of 512 bytes)
;
;	The file code works in sectors of 256 bytes, 16 to a track: they are laid on the disk's 512 byte sectors in a line, two to each (a logical track is
;	eight sectors).  A run of logical sectors is a run of bytes, so the whole 512 byte sectors in the middle of it go straight to or from the buffer in one
;	call of the driver; a half sector at either end goes by way of SECBUF (a half that is written is read first).  The driver stops the motor at the end of each call.
;
;	Entry: a = the mode (0 read, 1 write), e = drive, d = the logical track, c = the logical sector (1 to 16), b = the count, hl = buf.
;	Exit: hl = 0, or 1 on an error.  Uses all registers.

	MODULE	lynx_lsec

	defc	SECBUF = $FA00		; 512 bytes above the doubling tables (the stack is under $FFF0 and does not get far down)

	SECTION	code_user
	PUBLIC	asm_lynx_lsec_regs
	EXTERN	asm_lynx_disk_regs

asm_lynx_lsec_regs:
	ld	(l_mode),a
	ld	a,e
	ld	(l_drive),a
	ld	(l_buf),hl
	ld	a,b
	ld	(l_n),a
	ld	l,d			; the logical sector number: track * 16 + sector - 1
	ld	h,0
	add	hl,hl
	add	hl,hl
	add	hl,hl
	add	hl,hl
	ld	a,c
	dec	a
	ld	e,a
	ld	d,0
	add	hl,de
	ld	(l_L),hl
lg_loop:
	ld	a,(l_n)
	or	a
	jp	z,lg_ok
	ld	hl,(l_L)
	bit	0,l
	jr	nz,lg_hi
	cp	2
	jr	c,lg_lo
	srl	a			; whole sectors: n / 2 of them, straight to the buffer
	ld	(l_m),a
	ld	b,a
	srl	h
	rr	l			; the physical sector
	ld	de,(l_buf)
	ld	a,(l_mode)
	call	phys
	jp	nz,lg_err
	ld	a,(l_m)
	add	a,a
	ld	e,a			; 2 * m: the logical sectors done (and the high byte of the buffer's advance, 512 * m bytes)
	ld	hl,(l_buf)
	ld	a,h
	add	a,e
	ld	h,a
	ld	(l_buf),hl
	ld	d,0
	ld	hl,(l_L)
	add	hl,de
	ld	(l_L),hl
	ld	a,(l_n)
	sub	e
	ld	(l_n),a
	jr	lg_loop
lg_lo:	xor	a
	jr	lg_one
lg_hi:	ld	a,1
lg_one:	ld	(l_half),a		; one logical sector, the half of a physical one
	srl	h
	rr	l
	ld	(l_P),hl
	ld	b,1
	ld	de,SECBUF
	xor	a
	call	phys			; (read it: a write changes only the half)
	jp	nz,lg_err
	ld	hl,SECBUF
	ld	a,(l_half)
	or	a
	jr	z,lg_h0
	inc	h
lg_h0:	ld	de,(l_buf)
	ld	bc,256
	ld	a,(l_mode)
	or	a
	jr	z,lg_cp
	ex	de,hl			; a write: the buffer to SECBUF, and the sector back
	ldir
	ld	hl,(l_P)
	ld	b,1
	ld	de,SECBUF
	ld	a,1
	call	phys
	jp	nz,lg_err
	jr	lg_adv
lg_cp:	ldir
lg_adv:	ld	hl,l_buf + 1
	inc	(hl)
	ld	hl,(l_L)
	inc	hl
	ld	(l_L),hl
	ld	hl,l_n
	dec	(hl)
	jp	lg_loop
lg_ok:	ld	hl,0
	ret
lg_err:	ld	hl,1
	ret

; a = the mode, hl = the physical sector (0 to 399), b = the count, de = the buffer.  Z if all is well.
phys:	ld	(l_pm),a
	ld	a,b
	ld	(l_pc),a
	ld	(l_pb),de
	ld	b,0			; the track: hl / 10
ph_d1:	ld	a,h
	or	a
	jr	nz,ph_sub
	ld	a,l
	cp	10
	jr	c,ph_dd
ph_sub:	ld	de,-10
	add	hl,de
	inc	b
	jr	ph_d1
ph_dd:	inc	a			; the sector, 1 to 10
	ld	c,a
	ld	d,b			; the track
	ld	a,(l_drive)
	ld	e,a
	ld	a,(l_pc)
	ld	b,a
	ld	hl,(l_pb)
	ld	a,(l_pm)
	call	asm_lynx_disk_regs
	ld	a,h
	or	l
	ret

l_mode:	defb	0
l_drive: defb	0
l_buf:	defw	0
l_n:	defb	0
l_L:	defw	0
l_m:	defb	0
l_half:	defb	0
l_P:	defw	0
l_pm:	defb	0
l_pc:	defb	0
l_pb:	defw	0
