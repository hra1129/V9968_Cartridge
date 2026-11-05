; LMCMCHK - pinpoint LMCM checker for V9968 hardware investigation
; Writes known bytes to VRAM, runs targeted LMCM cases, logs TR behaviour
; and the actual values returned via S#7 to LMCMCHK.LOG (+ console).
; MSX-DOS 2 .COM, assembled with zma.

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
			; --- plant test bytes in VRAM ---
			ld		hl, 0x0000			; (0,0): pixels 1,2
			xor		a, a
			ld		e, 0x12
			call	vwr
			ld		hl, 2565			; (10,20): pixels 3,4
			xor		a, a
			ld		e, 0x34
			call	vwr
			ld		hl, 2566			; (12,20): pixels 5,6
			xor		a, a
			ld		e, 0x56
			call	vwr
			ld		hl, 2567			; (14,20): pixels 7,8
			xor		a, a
			ld		e, 0x78
			call	vwr
			ld		hl, 2568			; (16,20): pixels 9,A
			xor		a, a
			ld		e, 0x9A
			call	vwr
			ld		hl, 2569			; (18,20): pixels B,C
			xor		a, a
			ld		e, 0xBC
			call	vwr
			ld		hl, 0xFFFF			; (254,1023)=A (255,1023)=B, addr 0x1FFFF
			ld		a, 1
			ld		e, 0xAB
			call	vwr
			; --- run the case table ---
			ld		hl, case_table
			ld		b, NUM_CASES
case_loop:
			push	bc
			push	hl
			call	run_case
			pop		hl
			ld		de, 13
			add		hl, de
			pop		bc
			djnz	case_loop
			ld		hl, str_done
			call	emit_str
			; --- restore console regs, print, save log ---
			call	restore_text
			ei
			call	write_log_file
			ld		hl, [buf_ptr]
			ld		[hl], '$'
			ld		de, LOGBUF
			ld		c, _PUTS
			call	BDOS
			jp		0x0000

; ---------------------------------------------------------------------------
; run_case: HL -> 12-byte entry: id, sx.w, sy.w, nx.w, ny.w, expn, expptr.w
; ---------------------------------------------------------------------------
run_case::
			ld		a, [hl]
			ld		[cid], a
			inc		hl
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		[csx], de
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		[csy], de
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		[cnx], de
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		[cny], de
			ld		a, [hl]
			inc		hl
			ld		[cexpn], a
			ld		e, [hl]
			inc		hl
			ld		d, [hl]
			inc		hl
			ld		[cexpp], de
			ld		a, [hl]
			ld		[cproto], a
			; header: "CASEk SX=n SY=n NX=n NY=n VAL="
			ld		hl, str_case
			call	emit_str
			ld		a, [cid]
			call	emit_ch
			ld		hl, str_proto
			call	emit_str
			ld		a, [cproto]
			add		a, '0'
			call	emit_ch
			ld		hl, str_sx
			call	emit_str
			ld		hl, [csx]
			call	emit_dec
			ld		hl, str_sy
			call	emit_str
			ld		hl, [csy]
			call	emit_dec
			ld		hl, str_nx
			call	emit_str
			ld		hl, [cnx]
			call	emit_dec
			ld		hl, str_ny
			call	emit_str
			ld		hl, [cny]
			call	emit_dec
			ld		hl, str_val
			call	emit_str
			xor		a, a
			ld		[cbad], a
			ld		[cidx], a
			call	write_params
			ld		a, 0xA0
			ld		b, 46
			call	wreg
			ld		a, [cproto]
			cp		a, 2
			jr		nz, pix_loop
			; proto 2: conventional initialisation read of S#7
			ld		a, 7
			call	set_s15
			in		a, [0x99]
pix_loop:
			ld		a, [cproto]
			cp		a, 1
			jr		nz, pl_poll
			ld		a, [cidx]
			or		a, a
			jr		z, pl_poll
			call	delay_med
			jr		pl_read
pl_poll:
			call	poll_tr
			jr		c, tr_timeout
pl_read:
			ld		a, 7
			call	set_s15
			in		a, [0x99]
			ld		[pval], a
			ld		hl, [cexpp]
			ld		a, [cidx]
			ld		e, a
			ld		d, 0
			add		hl, de
			ld		a, [hl]			; expected
			ld		c, a
			ld		a, [pval]
			cp		a, c
			jr		z, val_ok
			ld		a, 1
			ld		[cbad], a
val_ok:
			ld		a, [cidx]
			or		a, a
			jr		z, no_comma
			ld		a, ','
			call	emit_ch
no_comma:
			ld		a, [pval]
			call	emit_hex
			ld		a, [cidx]
			inc		a
			ld		[cidx], a
			ld		hl, cexpn
			cp		a, [hl]
			jr		nc, pix_done
			jr		pix_loop
pix_done:
			; all pixels drained: wait for CE fall
			call	poll_ce
			jr		c, ce_timeout
			ld		hl, str_exp
			call	emit_str
			call	emit_exp_list
			ld		a, [cbad]
			or		a, a
			jr		nz, case_mismatch
			ld		hl, str_ok
			call	emit_str
			ret
case_mismatch:
			ld		hl, str_mismatch
			call	emit_str
			ret
tr_timeout:
			ld		hl, str_trto
			call	emit_str
			call	stop_cmd
			call	poll_ce
			ret
ce_timeout:
			ld		hl, str_exp
			call	emit_str
			call	emit_exp_list
			ld		hl, str_ceto
			call	emit_str
			call	stop_cmd
			ret

emit_exp_list:
			ld		hl, [cexpp]
			ld		a, [cexpn]
			ld		b, a
			xor		a, a
			ld		[cidx2], a
eel_loop:
			ld		a, [cidx2]
			or		a, a
			jr		z, eel_first
			push	bc
			ld		a, ','
			call	emit_ch
			pop		bc
eel_first:
			ld		a, [hl]
			inc		hl
			push	bc
			push	hl
			call	emit_hex
			pop		hl
			pop		bc
			ld		a, [cidx2]
			inc		a
			ld		[cidx2], a
			djnz	eel_loop
			ret

; ---------------------------------------------------------------------------
write_params::
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
			ld		a, [cnx]
			ld		b, 40
			call	wreg
			ld		a, [cnx + 1]
			ld		b, 41
			call	wreg
			ld		a, [cny]
			ld		b, 42
			call	wreg
			ld		a, [cny + 1]
			ld		b, 43
			call	wreg
			xor		a, a
			ld		b, 44
			call	wreg
			ld		b, 45
			call	wreg
			ret

stop_cmd::
			xor		a, a
			ld		b, 46
			jp		wreg

; poll TR (S#2 bit7): CY set on timeout
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

; poll TR until it falls (after an S#7 read): CY set on timeout
poll_tr_fall::
			ld		a, 2
			call	set_s15
			ld		hl, 0x4000
pf_o:		ld		b, 32
pf_i:		in		a, [0x99]
			and		a, 0x80
			jr		z, pt_ok
			djnz	pf_i
			dec		hl
			ld		a, h
			or		a, l
			jr		nz, pf_o
			scf
			ret

delay_med::
			ld		hl, 0x3000
			jr		dl_loop

delay_long::
			ld		hl, 0xFFFF
dl_loop:
			dec		hl
			ld		a, h
			or		a, l
			jr		nz, dl_loop
			ret

; poll CE (S#2 bit0) until 0: CY set on timeout
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

; ---------------------------------------------------------------------------
; vwr: write byte E to VRAM address HL (A = address bit 16)
; ---------------------------------------------------------------------------
vwr::
			push	bc
			push	hl
			ld		c, a			; C = bit16
			ld		a, h
			rlca
			rlca
			and		a, 0x03			; addr[15:14]
			ld		b, a
			ld		a, c
			add		a, a
			add		a, a			; bit16 << 2
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

; ---------------------------------------------------------------------------
; low-level helpers
; ---------------------------------------------------------------------------
wreg::		; A = value, B = register number
			out		[0x99], a
			ld		a, b
			or		a, 0x80
			out		[0x99], a
			ret

set_s15::	; A = status register number
			ld		b, 15
			jp		wreg

write_reg_table:	; HL = (reg, value) pairs, C = pair count
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

; ---------------------------------------------------------------------------
; report buffer emitters (buffer at LOGBUF, pointer in buf_ptr)
; ---------------------------------------------------------------------------
emit_ch::
			push	hl
			ld		hl, [buf_ptr]
			ld		[hl], a
			inc		hl
			ld		[buf_ptr], hl
			pop		hl
			ret

emit_str::	; HL = zero-terminated string
			ld		a, [hl]
			inc		hl
			or		a, a
			ret		z
			push	hl
			call	emit_ch
			pop		hl
			jr		emit_str

emit_hex::	; A = byte -> two hex chars
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

emit_dec::	; HL = unsigned 16-bit -> decimal
			xor		a, a
			ld		[dflag], a
			ld		de, 1000
			call	emit_digit
			ld		de, 100
			call	emit_digit
			ld		de, 10
			call	emit_digit
			ld		a, l
			add		a, '0'
			jp		emit_ch
emit_digit:	; divide HL by DE (<=9), emit quotient digit, HL = remainder.
			; suppresses leading zeros via dflag (units digit always emitted
			; by the caller afterwards).
			ld		b, 0
ed_loop:
			ld		a, h
			cp		a, d
			jr		c, ed_lt
			jr		nz, ed_sub
			ld		a, l
			cp		a, e
			jr		c, ed_lt
ed_sub:
			or		a, a
			sbc		hl, de
			inc		b
			jr		ed_loop
ed_lt:
			ld		a, b
			or		a, a
			jr		nz, ed_emit
			ld		a, [dflag]
			or		a, a
			ret		z
			ld		a, b
ed_emit:
			ld		c, a
			ld		a, 1
			ld		[dflag], a
			ld		a, c
			add		a, '0'
			jp		emit_ch

; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; data
; ---------------------------------------------------------------------------
buf_ptr::	dw		LOGBUF
dflag::		db		0
log_hdl::	db		0
cid::		db		0
csx::		dw		0
csy::		dw		0
cnx::		dw		0
cny::		dw		0
cexpn::		db		0
cexpp::		dw		0
cidx::		db		0
cidx2::		db		0
cbad::		db		0
pval::		db		0
cproto::	db		0

log_name::	db		"LMCM2V.LOG", 0

str_hdr::	db		"LMCM2V.LOG", 0x0D, 0x0A, 0
str_done::	db		"DONE", 0x0D, 0x0A, 0
str_case::	db		"CASE", 0
str_sx::	db		" SX=", 0
str_sy::	db		" SY=", 0
str_nx::	db		" NX=", 0
str_ny::	db		" NY=", 0
str_val::	db		" VAL=", 0
str_proto::	db		" P=", 0
str_exp::	db		" EXP=", 0
str_ok::	db		" -> OK", 0x0D, 0x0A, 0
str_mismatch::	db		" -> MISMATCH", 0x0D, 0x0A, 0
str_trto::	db		"TIMEOUT", 0x0D, 0x0A, 0
str_ceto::	db		" -> CE TIMEOUT", 0x0D, 0x0A, 0

exp1::		db		0x01
exp2::		db		0x03
exp3::		db		0x03, 0x04
exp4::		db		0x0B
exp5::		db		0x0A, 0x0B
exp6::		db		0x03, 0x04, 0x05, 0x06
exp9::		db		0x0A, 0x0B, 0x00, 0x00

NUM_CASES	:= 9
case_table::
			db		'1'
			dw		0, 0, 1, 1
			db		1
			dw		exp1
			db		0
			db		'2'
			dw		10, 20, 1, 1
			db		1
			dw		exp2
			db		0
			db		'3'
			dw		10, 20, 2, 1
			db		2
			dw		exp3
			db		0
			db		'4'
			dw		255, 1023, 1, 1
			db		1
			dw		exp4
			db		0
			db		'5'
			dw		254, 1023, 2, 1
			db		2
			dw		exp5
			db		0
			db		'6'
			dw		10, 20, 4, 1
			db		4
			dw		exp6
			db		0
			db		'7'
			dw		10, 20, 4, 1
			db		4
			dw		exp6
			db		1
			db		'8'
			dw		10, 20, 4, 1
			db		4
			dw		exp6
			db		2
			db		'9'
			dw		254, 1023, 4, 1
			db		4
			dw		exp9
			db		0

; G4 mode, display ON
g4_regs::
			db		0, 0x06, 1, 0x42, 2, 0x00, 3, 0x00, 4, 0x00, 5, 0x00
			db		6, 0x00, 7, 0x00, 8, 0x08, 9, 0x80, 10, 0x00, 11, 0x00
			db		12, 0x00, 13, 0x00, 14, 0x00, 15, 0x00, 16, 0x00, 17, 0x00
			db		18, 0x00, 19, 0x00, 23, 0x00
g4_regs_end::

; FS-A1ST DOS console (SCREEN 1) baseline, captured 2026-11-04
text_regs::
			db		0, 0x00, 1, 0x60, 2, 0x06, 3, 0x80, 4, 0x00, 5, 0x36
			db		6, 0x00, 7, 0x07, 8, 0x08, 9, 0x00, 14, 0x00, 15, 0x00
text_regs_end::
