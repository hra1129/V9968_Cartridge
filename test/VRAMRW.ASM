; VRAMRW - isolate VRAM access paths: CPU port write -> CPU port readback,
; then single-pixel LMCM readback of the same addresses. No LMCM streaming.
; MSX-DOS 2 .COM, zma.

BDOS		:= 0x0005
_PUTS		:= 0x09
_CREATE		:= 0x44
_CLOSE		:= 0x45
_WRITE		:= 0x49

LOGBUF		:= 0x8000

			org		0x0100

start::
			di
			ld		hl, str_hdr
			call	emit_str
			call	vdp_init_g4
			; plant: (0,0)=12 @(0,0) / (10,20)=34 @2565 / (254,1023)=AB @0x1FFFF
			ld		hl, 0x0000
			xor		a, a
			ld		e, 0x12
			call	vwr
			ld		hl, 2565
			xor		a, a
			ld		e, 0x34
			call	vwr
			ld		hl, 0xFFFF
			ld		a, 1
			ld		e, 0xAB
			call	vwr
			; --- CPU port readback ---
			ld		hl, str_rb
			call	emit_str
			ld		hl, 0x0000
			xor		a, a
			call	vrd
			call	emit_hex_sp
			ld		hl, 2565
			xor		a, a
			call	vrd
			call	emit_hex_sp
			ld		hl, 0xFFFF
			ld		a, 1
			call	vrd
			call	emit_hex_sp
			ld		hl, str_crlf
			call	emit_str
			; --- LMCM 1x1 readbacks ---
			ld		hl, str_lm
			call	emit_str
			ld		de, 0				; SX=0 SY=0
			ld		bc, 0
			call	lmcm1
			call	emit_hex_sp
			ld		de, 10				; SX=10 SY=20
			ld		bc, 20
			call	lmcm1
			call	emit_hex_sp
			ld		de, 255				; SX=255 SY=1023
			ld		bc, 1023
			call	lmcm1
			call	emit_hex_sp
			ld		hl, str_crlf
			call	emit_str
			ld		hl, str_done
			call	emit_str
			call	restore_text
			ei
			call	write_log_file
			ld		hl, [buf_ptr]
			ld		[hl], '$'
			ld		de, LOGBUF
			ld		c, _PUTS
			call	BDOS
			jp		0x0000

; lmcm1: LMCM 1x1 at SX=DE, SY=BC -> A = pixel value or 0xEE on TR timeout
lmcm1::
			ld		[csx], de
			ld		[csy], bc
			call	write_params_lm
			ld		a, 0xA0
			ld		b, 46
			call	wreg
			call	poll_tr
			jr		c, lm_to
			ld		a, 7
			call	set_s15
			in		a, [0x99]
			push	af
			call	poll_ce
			pop		af
			ret
lm_to:
			call	stop_cmd
			call	poll_ce
			ld		a, 0xEE
			ret

write_params_lm::
			ld		a, [csx]
			ld		b, 32
			call	wreg
			ld		a, [csx + 1]
			ld		b, 33
			call	wreg
			ld		a, [csy]
			ld		b, 34
			call	wreg
			ld		a, [csy + 1]
			ld		b, 35
			call	wreg
			xor		a, a
			ld		b, 36
			call	wreg
			ld		b, 37
			call	wreg
			ld		b, 38
			call	wreg
			ld		b, 39
			call	wreg
			ld		a, 1
			ld		b, 40
			call	wreg
			xor		a, a
			ld		b, 41
			call	wreg
			ld		a, 1
			ld		b, 42
			call	wreg
			xor		a, a
			ld		b, 43
			call	wreg
			ld		b, 44
			call	wreg
			ld		b, 45
			call	wreg
			ret

stop_cmd::
			xor		a, a
			ld		b, 46
			jp		wreg

poll_tr::
			ld		a, 2
			call	set_s15
			ld		hl, 0x4000
pt_o:		ld		b, 32
pt_i:		in		a, [0x99]
			and		a, 0x80
			jr		nz, pt_ok
			djnz	pt_i
			dec		hl
			ld		a, h
			or		a, l
			jr		nz, pt_o
			scf
			ret
pt_ok:		xor		a, a
			ret

poll_ce::
			ld		a, 2
			call	set_s15
			ld		hl, 0x4000
pc_o:		ld		b, 32
pc_i:		in		a, [0x99]
			and		a, 0x01
			jr		z, pt_ok
			djnz	pc_i
			dec		hl
			ld		a, h
			or		a, l
			jr		nz, pc_o
			scf
			ret

; vwr: write byte E to VRAM addr HL (A = addr bit16)
vwr::
			push	bc
			push	hl
			ld		c, a
			ld		a, h
			rlca
			rlca
			and		a, 0x03
			ld		b, a
			ld		a, c
			add		a, a
			add		a, a
			or		a, b
			ld		b, 14
			call	wreg
			pop		hl
			ld		a, l
			out		[0x99], a
			ld		a, h
			and		a, 0x3F
			or		a, 0x40
			out		[0x99], a
			ld		a, e
			out		[0x98], a
			pop		bc
			ret

; vrd: read VRAM addr HL (A = addr bit16) -> A = byte (double-set + dummy read)
vrd::
			push	bc
			push	hl
			ld		c, a
			ld		a, h
			rlca
			rlca
			and		a, 0x03
			ld		b, a
			ld		a, c
			add		a, a
			add		a, a
			or		a, b
			ld		b, 14
			call	wreg
			pop		hl
			push	hl
			ld		a, l
			out		[0x99], a
			ld		a, h
			and		a, 0x3F
			out		[0x99], a
			in		a, [0x98]			; prefetch dummy
			pop		hl
			ld		a, l
			out		[0x99], a
			ld		a, h
			and		a, 0x3F
			out		[0x99], a
			in		a, [0x98]
			pop		bc
			ret

wreg::
			out		[0x99], a
			ld		a, b
			or		a, 0x80
			out		[0x99], a
			ret

set_s15::
			ld		b, 15
			jp		wreg

write_reg_table:
			ld		a, [hl]
			inc		hl
			ld		b, a
			ld		a, [hl]
			inc		hl
			push	bc
			push	hl
			call	wreg
			pop		hl
			pop		bc
			dec		c
			jr		nz, write_reg_table
			ret

vdp_init_g4::
			ld		hl, g4_regs
			ld		c, (g4_regs_end - g4_regs) / 2
			jp		write_reg_table

restore_text::
			ld		hl, text_regs
			ld		c, (text_regs_end - text_regs) / 2
			jp		write_reg_table

emit_ch::
			push	hl
			ld		hl, [buf_ptr]
			ld		[hl], a
			inc		hl
			ld		[buf_ptr], hl
			pop		hl
			ret

emit_str::
			ld		a, [hl]
			inc		hl
			or		a, a
			ret		z
			push	hl
			call	emit_ch
			pop		hl
			jr		emit_str

emit_hex_sp::
			call	emit_hex
			ld		a, ' '
			jp		emit_ch

emit_hex::
			push	af
			rrca
			rrca
			rrca
			rrca
			call	emit_nib
			pop		af
			jp		emit_nib
emit_nib:
			and		a, 0x0F
			cp		a, 10
			jr		c, en_num
			add		a, 'A' - 10
			jp		emit_ch
en_num:
			add		a, '0'
			jp		emit_ch

write_log_file::
			ld		de, log_name
			xor		a, a
			ld		b, a
			ld		c, _CREATE
			call	BDOS
			or		a, a
			jr		nz, wlf_err
			ld		a, b
			ld		[log_hdl], a
			ld		hl, [buf_ptr]
			ld		de, LOGBUF
			or		a, a
			sbc		hl, de
			ld		de, LOGBUF
			ld		a, [log_hdl]
			ld		b, a
			ld		c, _WRITE
			call	BDOS
			or		a, a
			jr		nz, wlf_err
			ld		a, [log_hdl]
			ld		b, a
			ld		c, _CLOSE
			call	BDOS
			ret
wlf_err:
			ret

buf_ptr::	dw		LOGBUF
log_hdl::	db		0
csx::		dw		0
csy::		dw		0

log_name::	db		"VRAMRW.LOG", 0
str_hdr::	db		"VRAMRW LOG", 0x0D, 0x0A, 0
str_rb::	db		"CPU-READBACK (00,2565,1FFFF): ", 0
str_lm::	db		"LMCM1 (0,0)/(10,20)/(255,1023): ", 0
str_crlf::	db		0x0D, 0x0A, 0
str_done::	db		"DONE", 0x0D, 0x0A, 0

g4_regs::
			db		0, 0x06, 1, 0x42, 2, 0x00, 3, 0x00, 4, 0x00, 5, 0x00
			db		6, 0x00, 7, 0x00, 8, 0x00, 9, 0x80, 10, 0x00, 11, 0x00
			db		12, 0x00, 13, 0x00, 14, 0x00, 15, 0x00, 16, 0x00, 17, 0x00
			db		18, 0x00, 19, 0x00, 23, 0x00
g4_regs_end::

text_regs::
			db		0, 0x00, 1, 0x60, 2, 0x06, 3, 0x80, 4, 0x00, 5, 0x36
			db		6, 0x00, 7, 0x07, 8, 0x08, 9, 0x00, 14, 0x00, 15, 0x00
text_regs_end::
