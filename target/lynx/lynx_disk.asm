;
;	Camputers Lynx: reading and writing the disk, in the shape of the other targets' asm_*_disk_regs
;
;	The floppy controller is a WD1793 at ports $50 (status) $51 (track) $52 (sector) $53 (data) for reading and $54 (command) $55 $56 $57 for writing;
;	port $58 selects the drive (bits 1-0), the side (bit 2) and the motor (bit 3, which is a 1 for the motor off).  The disk is single sided, 40 tracks of 10 sectors of 512 bytes,
;	the sectors numbered 1 to 10 (the layout of the .ldf images and of appmake's +cpmdisk -f lynx).  A sector is moved by polling the status for the
;	data request: a byte every 32 us, so interrupts are off for the length of a call (the game has them off but for the wait for a frame).
;
;	The file code works in sectors of 256 bytes, 16 to a track: they are laid on the disk's sectors in a line, two to each (a logical track is eight
;	sectors), and one sector is kept in SECBUF; a sector that is written whole is not read first.  The motor is stopped at the end of a call.
;
;	Entry: a = the mode (0 read, 1 write), e = drive, d = the logical track, c = the logical sector (1 to 16), b = the count, hl = buf.
;	Exit: hl = 0, or 1 on an error.  Uses all registers.

	MODULE	lynx_disk

	defc	TRIES = 3
	defc	SECBUF = $FA00		; 512 bytes above the doubling tables (the stack is under $FFF0 and does not get far down)

	SECTION	code_user
	PUBLIC	asm_lynx_disk_regs

asm_lynx_disk_regs:
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
	ld	hl,$FFFF
	ld	(l_curP),hl		; nothing in SECBUF
	xor	a
	ld	(l_dirty),a
	ld	(l_err),a
	ld	a,4
	ld	(l_efl),a		; (the head settling delay for the first sector only)
lg_loop:
	ld	a,(l_n)
	or	a
	jp	z,lg_done
	ld	hl,(l_L)
	ld	a,l
	and	1
	ld	(l_half),a
	srl	h
	rr	l			; hl = the physical sector
	ld	de,(l_curP)
	ld	a,h
	cp	d
	jr	nz,lg_load
	ld	a,l
	cp	e
	jr	z,lg_have
lg_load:
	push	hl
	call	lg_flush		; the sector that is in SECBUF, if it was written
	pop	hl
	ld	(l_curP),hl
	ld	a,(l_mode)
	or	a
	jr	z,lg_rd
	ld	a,(l_half)		; a write that fills both halves needs no read first
	or	a
	jr	nz,lg_rd
	ld	a,(l_n)
	cp	2
	jr	nc,lg_have
lg_rd:
	ld	hl,(l_curP)
	xor	a
	call	ph_io
	jr	z,lg_have
	ld	a,1
	ld	(l_err),a
	ld	hl,$FFFF
	ld	(l_curP),hl
	jr	lg_done
lg_have:
	ld	hl,SECBUF
	ld	a,(l_half)
	or	a
	jr	z,lg_h0
	inc	h			; the second half
lg_h0:
	ld	de,(l_buf)
	ld	bc,256
	ld	a,(l_mode)
	or	a
	jr	z,lg_copy
	ex	de,hl			; a write: the buffer to SECBUF
	ldir
	ld	a,1
	ld	(l_dirty),a
	jr	lg_next
lg_copy:
	ldir
lg_next:
	ld	hl,(l_buf)
	inc	h
	ld	(l_buf),hl
	ld	hl,(l_L)
	inc	hl
	ld	(l_L),hl
	ld	hl,l_n
	dec	(hl)
	jp	lg_loop
lg_done:
	ld	a,(l_err)
	or	a
	jr	nz,lg_off
	call	lg_flush
lg_off:
	ld	a,8
	out	($58),a			; the motor off (bit 3 set)
	ld	h,0
	ld	a,(l_err)
	ld	l,a
	ret

; the sector in SECBUF is written if it has been changed
lg_flush:
	ld	a,(l_dirty)
	or	a
	ret	z
	xor	a
	ld	(l_dirty),a
	ld	hl,(l_curP)
	ld	a,1
	call	ph_io
	ret	z
	ld	a,1
	ld	(l_err),a
	ret

; hl = a physical sector (0 to 399), a = 0 to read it to SECBUF or 1 to write it from there.  Z if all is well.
ph_io:
	ld	(l_pm),a
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
ph_dd:	inc	a
	ld	(l_sec),a		; 1 to 10
	ld	a,b
	ld	(l_trk),a
	ld	a,TRIES
	ld	(l_tries),a
ph_try:
	call	position
	jr	z,ph_go
	cp	2
	jp	z,ph_fail		; not ready: no disk, or no drive: not tried again
	jp	ph_retry
ph_go:
	ld	a,(l_sec)
	out	($56),a
	ld	hl,SECBUF
	ld	a,(l_pm)
	or	a
	jr	nz,ph_wr
	ld	a,(l_efl)
	or	$80			; read sector
	out	($54),a
	ld	d,0
	ld	e,2			; 512 bytes: twice 256
ph_rb:	in	a,($50)
	bit	1,a			; data request?
	jr	nz,ph_rg
	rrca
	jr	c,ph_rb			; still busy
	jp	ph_retry		; ended without the data
ph_rg:	in	a,($53)
	ld	(hl),a
	inc	hl
	dec	d
	jr	nz,ph_rb
	dec	e
	jr	nz,ph_rb
	call	fdc_wait
	and	$1D			; lost data, CRC error, record not found, or never finished
	jp	nz,ph_retry
	jr	ph_ok
ph_wr:	ld	a,(l_efl)
	or	$A0			; write sector
	out	($54),a
	ld	d,0
	ld	e,2
ph_wb:	in	a,($50)
	bit	1,a
	jr	nz,ph_wg
	rrca
	jr	c,ph_wb
	jp	ph_retry
ph_wg:	ld	a,(hl)
	out	($57),a
	inc	hl
	dec	d
	jr	nz,ph_wb
	dec	e
	jr	nz,ph_wb
	call	fdc_wait
	and	$7D			; lost data, CRC, record not found, write fault, write protected, or never finished
	jp	nz,ph_retry
ph_ok:	xor	a
	ld	(l_efl),a
	ret				; Z
ph_retry:
	ld	a,(l_tries)
	or	a
	jr	z,ph_fail
	dec	a
	ld	(l_tries),a
	ld	a,$D0			; force interrupt: idle, then the heads are found again
	out	($54),a
	xor	a
	ld	(l_cyl1),a
	ld	a,4
	ld	(l_efl),a
	jp	ph_try
ph_fail:
	ld	a,$D0
	out	($54),a
	ld	a,1
	or	a
	ret				; NZ

; The drive selected with its motor on, and the heads on the track.  Z if all is well.  Uses all.
position:
	ld	a,(l_drive)
	and	1			; (bit 3 clear: the motor is on)
	out	($58),a
	ld	b,3			; (the motor takes a while to come up to speed)
ready0:	ld	hl,0
ready:	in	a,($50)
	rlca				; bit 7: not ready
	jr	nc,ready_ok
	dec	hl
	ld	a,h
	or	l
	jr	nz,ready
	djnz	ready0
	xor	a
	ld	(l_cyl1),a
	ld	a,2			; (never ready: no disk, or no drive)
	or	a
	ret			; NZ, and 2
ready_ok:
	ld	a,(l_trk)
	ld	d,a			; the track
	ld	a,(l_cyl1)
	or	a
	jr	nz,known
	ld	a,$0B			; restore, at the rate the Lynx's own boot sector uses
	out	($54),a
	call	fdc_wait
	and	$81			; not ready, or still busy
	jp	nz,failed
	ld	a,1
	ld	(l_cyl1),a		; (the track plus one: 0 is not known)
	ld	a,4
	ld	(l_efl),a
known:
	ld	a,(l_cyl1)
	dec	a
	cp	d
	jr	z,there
	ld	a,d
	out	($57),a			; the data register is where to go
	ld	a,$1B			; seek (no verify: the sector commands check the IDs)
	out	($54),a
	call	fdc_wait
	and	$99			; not ready, CRC error, record not found, still busy
	jp	nz,failed
	ld	a,d
	inc	a
	ld	(l_cyl1),a
	ld	a,4
	ld	(l_efl),a
there:
	xor	a
	ret
failed:
	xor	a
	ld	(l_cyl1),a		; (where the heads are is not known now)
	or	1
	ret

; Wait for the controller to finish its command (bounded: a seek across the disk takes about a second).  Exit: a = its status; bit 0
; is still set if it never did.  Keeps bc and de.
fdc_wait:
	push	bc
	push	de
	ld	b,24
	ld	de,0
wait_busy:
	in	a,($50)
	rrca
	jr	nc,wait_done
	dec	de
	ld	a,d
	or	e
	jr	nz,wait_busy
	djnz	wait_busy
wait_done:
	in	a,($50)
	pop	de
	pop	bc
	ret

l_mode:	defb	0
l_drive: defb	0
l_buf:	defw	0
l_n:	defb	0
l_L:	defw	0
l_curP:	defw	0
l_dirty: defb	0
l_err:	defb	0
l_half:	defb	0
l_pm:	defb	0
l_trk:	defb	0
l_sec:	defb	0
l_tries: defb	0
l_efl:	defb	0
l_cyl1:	defb	0			; the track the heads are on, plus one (0: not known)
