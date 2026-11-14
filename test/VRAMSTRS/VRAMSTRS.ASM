; -----------------------------------------------------------------------------
;	VRAMSTRS.ASM -- VRAM CPU access stress test (MSX-DOS .COM)
;
;	Writes all 128 KB of VRAM by the CPU at full speed, reads it back and
;	compares every byte.  Each mismatch is re-read once by a single byte read:
;		W : re-read = wrong value  (the wrong value is stored in VRAM)
;		R : re-read = expected     (only the bulk read was wrong)
;		? : re-read = something else
;	Ten conditions (write method x read method x screen) run per round.
;		VRAMSTRS [rounds]     rounds = 1..255 (default 3), 0 = until ESC
;	ESC stops after the current condition.  The border colour shows the
;	condition being executed (1..10).
;	On a turboR the Z80 mode is used.
;
;	Assemble with zma:  zma VRAMSTRS.ASM VRAMSTRS.COM
; -----------------------------------------------------------------------------

BDOS		:= 0x0005
TPA_TOP		:= 0x0006
_TERM0		:= 0x00
_CONOUT		:= 0x02
_PUTS		:= 0x09

RDSLT		:= 0x000C
CALSLT		:= 0x001C
CHGMOD		:= 0x005F		; main ROM
CHGCPU		:= 0x0180		; main ROM (turboR)
GETCPU		:= 0x0183		; main ROM (turboR)
INIPLT		:= 0x0141		; sub ROM
EXPTBL_M1	:= 0xFCC0		; [FCC1h] = main ROM slot
EXBRSA_M1	:= 0xFAF7		; [FAF8h] = sub ROM slot
SCRMOD		:= 0xFCAF
BDRCLR		:= 0xF3EB
RG8SAV		:= 0xFFE7
RG9SAV		:= 0xFFE8

VDP_DATA	:= 0x98
VDP_CTRL	:= 0x99
VDP_IND		:= 0x9B
VDP_P4		:= 0x9C
PPI_B		:= 0xA9
PPI_C		:= 0xAA

BUF_E		:= 0x2000		; expected data of one 16 KB bank
BUF_R		:= 0x6000		; data read back from one bank
BUF_END_H	:= 0xA1			; TPA must reach A100h
COND_COUNT	:= 10
MAX_LOG		:= 16
LOG_SIZE	:= 11

		org		0x100

; -----------------------------------------------------------------------------
;	entry
; -----------------------------------------------------------------------------
entry_point::
		ld		de, msg_banner
		call	puts
		ld		a, [TPA_TOP + 1]
		cp		a, BUF_END_H
		jp		c, err_tpa
		call	parse_args

		di
		call	detect_vdp
		ei
		ld		a, [vdp_id]
		or		a, a
		jr		nz, vdp_ok
		ld		de, msg_v9938
		call	puts
		jp		exit_dos
vdp_ok:
		ld		a, [is_v9968]
		or		a, a
		ld		de, msg_v9958
		jr		z, print_kind
		ld		de, msg_v9968
print_kind:
		call	puts
		ld		de, msg_rounds
		call	puts
		ld		a, [rounds]
		or		a, a
		jr		nz, print_rounds_n
		ld		de, msg_endless
		call	puts
		jr		print_rounds_end
print_rounds_n:
		ld		l, a
		ld		h, 0
		call	put_dec
		call	put_crlf
print_rounds_end:
		ld		de, msg_running
		call	puts

		call	turbo_r_z80
		di
		call	vdp_init
round_loop:
		xor		a, a
		ld		[cond], a
cond_loop:
		call	run_cond
		call	check_esc
		jr		z, stopped_by_key
		ld		a, [cond]
		inc		a
		ld		[cond], a
		cp		a, COND_COUNT
		jr		c, cond_loop
		ld		hl, [round_done]
		inc		hl
		ld		[round_done], hl
		ld		a, [rounds]
		or		a, a
		jr		z, round_loop
		ld		b, a
		ld		a, [round_done]
		cp		a, b
		jr		c, round_loop
		jr		finish
stopped_by_key:
		ld		a, 1
		ld		[aborted], a
finish:
		call	restore_screen
		ei
		call	turbo_r_restore
		call	print_result
exit_dos:
		ld		c, _TERM0
		jp		BDOS

err_tpa:
		ld		de, msg_tpa
		call	puts
		jr		exit_dos

; -----------------------------------------------------------------------------
;	command line: rounds (decimal)
; -----------------------------------------------------------------------------
parse_args:
		ld		a, 3
		ld		[rounds], a
		ld		hl, 0x0080
		ld		b, [hl]
		inc		hl
		ld		c, 0
		xor		a, a
		ld		[arg_seen], a
parse_loop:
		ld		a, b
		or		a, a
		jr		z, parse_end
		dec		b
		ld		a, [hl]
		inc		hl
		sub		a, '0'
		cp		a, 10
		jr		nc, parse_nondigit
		ld		e, a
		ld		a, 1
		ld		[arg_seen], a
		ld		a, c
		cp		a, 26
		jr		nc, parse_over
		add		a, a
		ld		d, a
		add		a, a
		add		a, a
		add		a, d
		add		a, e
		jr		c, parse_over
		ld		c, a
		jr		parse_loop
parse_over:
		ld		c, 255
		jr		parse_loop
parse_nondigit:
		ld		a, [arg_seen]
		or		a, a
		jr		z, parse_loop
parse_end:
		ld		a, [arg_seen]
		or		a, a
		ret		z
		ld		a, c
		ld		[rounds], a
		ret

; -----------------------------------------------------------------------------
;	keyboard: Z = ESC pressed (PPI direct, works with DI)
; -----------------------------------------------------------------------------
check_esc:
		in		a, [PPI_C]
		and		a, 0xF0
		or		a, 7
		out		[PPI_C], a
		in		a, [PPI_B]
		and		a, 0x04
		ret

; -----------------------------------------------------------------------------
;	VDP helpers
; -----------------------------------------------------------------------------
;	A = value, B = register (keeps C, DE, HL)
wreg:
		out		[VDP_CTRL], a
		ld		a, b
		or		a, 0x80
		out		[VDP_CTRL], a
		ret

;	A = status register number -> A = value, R#15 back to 0
rstat:
		ld		b, 15
		call	wreg
		in		a, [VDP_CTRL]
		push	af
		xor		a, a
		ld		b, 15
		call	wreg
		pop		af
		ret

;	HL = { reg, value }... 0xFF   (keeps C)
reg_list:
		ld		b, [hl]
		inc		hl
		ld		a, b
		cp		a, 0xFF
		ret		z
		ld		a, [hl]
		inc		hl
		call	wreg
		jr		reg_list

;	VRAM address [bank] * 4000h + DE (DE < 4000h).  A = 0x00 read / 0x40 write
;	keeps DE, HL
set_addr_de:
		ld		c, a
		ld		a, [bank]
		out		[VDP_CTRL], a
		ld		a, 0x8E
		out		[VDP_CTRL], a
		ld		a, e
		out		[VDP_CTRL], a
		ld		a, d
		and		a, 0x3F
		or		a, c
		out		[VDP_CTRL], a
		ret

vdp_init:
		xor		a, a
		ld		b, 46
		call	wreg			; stop a command
		ld		a, [is_v9968]
		or		a, a
		jr		z, vdp_init_1
		xor		a, a
		out		[VDP_P4], a
		xor		a, a
		ld		b, 20
		call	wreg
		ld		a, 1
		ld		b, 21
		call	wreg
		ld		a, 0x80
		out		[VDP_P4], a
vdp_init_1:
		ld		hl, init_regs
		jr		reg_list

init_regs:
		db		1, 0x00			; display off, no interrupts
		db		0, 0x06
		db		8, 0x0A
		db		9, 0x80
		db		7, 0
		db		14, 0
		db		15, 0
		db		23, 0
		db		25, 0
		db		26, 0
		db		27, 0
		db		45, 0
		db		0xFF

;	A = 0: SCREEN 5 display off / 1: SCREEN 5 display on / 2: SCREEN 8 display on
set_screen:
		ld		hl, scr_sc5
		cp		a, 2
		jr		nz, set_screen_1
		ld		hl, scr_sc8
set_screen_1:
		ld		c, 0x00
		or		a, a
		jr		z, set_screen_2
		ld		c, 0x40
set_screen_2:
		call	reg_list
		ld		a, c
		ld		b, 1
		jp		wreg

scr_sc5:
		db		0, 0x06, 2, 0x1F, 5, 0xEF, 11, 0x00, 6, 0x0F, 8, 0x08, 9, 0x80, 0xFF
scr_sc8:
		db		0, 0x0E, 2, 0x1F, 5, 0xF7, 11, 0x01, 6, 0x1E, 8, 0x08, 9, 0x80, 0xFF

; -----------------------------------------------------------------------------
;	conditions: write method, read method, screen, HMMV clear before writing
;		write 0: OTIR, 1: OUTI x16, 2: address set + OUTI x16 every 16 bytes
;		read  0: INIR, 1: INI x16
; -----------------------------------------------------------------------------
cond_table:
		db		0, 0, 0, 0
		db		1, 1, 0, 0
		db		2, 0, 0, 0
		db		0, 0, 1, 0
		db		1, 1, 1, 0
		db		2, 0, 1, 0
		db		0, 0, 2, 0
		db		1, 1, 2, 0
		db		0, 0, 0, 1
		db		1, 1, 1, 1

run_cond:
		ld		a, [cond]
		add		a, a
		add		a, a
		ld		e, a
		ld		d, 0
		ld		hl, cond_table
		add		hl, de
		ld		a, [hl]
		ld		[wmeth], a
		inc		hl
		ld		a, [hl]
		ld		[rmeth], a
		inc		hl
		ld		a, [hl]
		inc		hl
		push	hl
		call	set_screen
		pop		hl
		ld		a, [hl]
		ld		[clrmode], a
		ld		a, [cond]
		inc		a
		ld		b, 7
		call	wreg			; border = condition number
		call	gen_buf

		xor		a, a
		ld		[bank], a
run_cond_write:
		call	calc_off
		ld		a, [clrmode]
		or		a, a
		call	nz, hmmv_bank
		call	write_bank
		ld		a, [bank]
		inc		a
		ld		[bank], a
		cp		a, 8
		jr		c, run_cond_write

		xor		a, a
		ld		[bank], a
run_cond_read:
		call	calc_off
		call	read_bank
		call	compare_bank
		ld		a, [bank]
		inc		a
		ld		[bank], a
		cp		a, 8
		jr		c, run_cond_read
		ret

;	16 KB of xorshift data, seed from the round and the condition
gen_buf:
		ld		hl, [round_done]
		add		hl, hl
		add		hl, hl
		add		hl, hl
		add		hl, hl
		ld		a, [cond]
		or		a, l
		ld		l, a
		ld		de, 0x6D2B
		add		hl, de
		ld		a, h
		or		a, l
		jr		nz, gen_buf_1
		inc		hl
gen_buf_1:
		ld		de, BUF_E
		ld		bc, 0x4000
gen_loop:
		ld		a, h
		rra
		ld		a, l
		rra
		xor		a, h
		ld		h, a
		ld		a, l
		rra
		ld		a, h
		rra
		xor		a, l
		ld		l, a
		xor		a, h
		ld		h, a
		ld		[de], a
		inc		de
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, gen_loop
		ret

;	bank b gets BUF_E rotated by [off]: VRAM offset i = BUF_E[(i + off) & 3FFFh]
calc_off:
		ld		hl, 0
		ld		a, [bank]
		ld		de, 0x0510
		call	mul_add
		ld		a, [cond]
		ld		de, 0x0230
		call	mul_add
		ld		a, [round_done]
		ld		de, 0x0130
		call	mul_add
		ld		a, l
		and		a, 0xF0
		ld		l, a
		ld		a, h
		and		a, 0x3F
		ld		h, a
		ld		[off], hl
		ret

mul_add:
		or		a, a
		ret		z
		ld		b, a
mul_add_loop:
		add		hl, de
		djnz	mul_add_loop
		ret

;	-> HL = BUF_E + off, BC = 4000h - off, DE = off
seg1_args:
		ld		hl, [off]
		ex		de, hl
		ld		hl, 0x4000
		or		a, a
		sbc		hl, de
		ld		b, h
		ld		c, l
		ld		hl, BUF_E
		add		hl, de
		ret

;	BC = BC / 16
div16:
		srl		b
		rr		c
		srl		b
		rr		c
		srl		b
		rr		c
		srl		b
		rr		c
		ret

; --- HMMV (SCREEN 5 coordinates) fills the bank with 00h -----------------------
hmmv_bank:
		ld		a, 36
		ld		b, 17
		call	wreg
		ld		a, [bank]
		ld		e, a
		and		a, 1
		rrca
		ld		d, a			; DY low = (bank & 1) * 128
		ld		a, e
		srl		a
		ld		e, a			; DY high = bank / 2
		ld		c, VDP_IND
		xor		a, a
		out		[c], a			; R#36 DX
		out		[c], a			; R#37
		out		[c], d			; R#38 DY
		out		[c], e			; R#39
		out		[c], a			; R#40 NX = 256
		inc		a
		out		[c], a			; R#41
		ld		a, 0x80
		out		[c], a			; R#42 NY = 128
		xor		a, a
		out		[c], a			; R#43
		out		[c], a			; R#44 CLR = 00h
		out		[c], a			; R#45 ARG
		ld		a, 0xC0
		out		[c], a			; R#46 HMMV
		ld		a, 2
		ld		b, 15
		call	wreg
hmmv_wait:
		in		a, [VDP_CTRL]
		rrca
		jr		c, hmmv_wait
		xor		a, a
		ld		b, 15
		jp		wreg

; --- write one bank -------------------------------------------------------------
write_bank:
		ld		a, [wmeth]
		cp		a, 2
		jr		z, write_bank_addr
		ld		de, 0
		ld		a, 0x40
		call	set_addr_de
		call	seg1_args
		call	wseg
		ld		hl, BUF_E
		ld		bc, [off]

;	HL = source, BC = bytes (multiple of 16)
wseg:
		ld		a, b
		or		a, c
		ret		z
		ld		a, [wmeth]
		or		a, a
		jr		nz, wseg_outi
		ld		d, b
		ld		e, c
		ld		c, VDP_DATA
wseg_otir_loop:
		ld		a, d
		or		a, a
		jr		z, wseg_otir_last
		ld		b, 0
		otir
		dec		d
		jr		wseg_otir_loop
wseg_otir_last:
		ld		a, e
		or		a, a
		ret		z
		ld		b, a
		otir
		ret
wseg_outi:
		call	div16
		ld		d, b
		ld		e, c
		ld		c, VDP_DATA
wseg_outi_loop:
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		dec		de
		ld		a, d
		or		a, e
		jr		nz, wseg_outi_loop
		ret

;	the VRAM address is set again before every 16 bytes
write_bank_addr:
		call	seg1_args
		ld		de, 0
		call	waseg
		ld		hl, BUF_E
		ld		bc, [off]

;	HL = source, DE = VRAM offset, BC = bytes (multiple of 16)
waseg:
		ld		a, b
		or		a, c
		ret		z
		call	div16
waseg_loop:
		push	bc
		ld		a, 0x40
		call	set_addr_de
		ld		c, VDP_DATA
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		outi
		ex		de, hl
		ld		bc, 16
		add		hl, bc
		ex		de, hl
		pop		bc
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, waseg_loop
		ret

; --- read one bank into BUF_R ---------------------------------------------------
read_bank:
		ld		de, 0
		xor		a, a
		call	set_addr_de
		ld		hl, BUF_R
		ld		c, VDP_DATA
		ld		a, [rmeth]
		or		a, a
		jr		nz, read_bank_ini
		ld		d, 64
read_bank_inir:
		ld		b, 0
		inir
		dec		d
		jr		nz, read_bank_inir
		ret
read_bank_ini:
		ld		de, 1024
read_bank_ini_loop:
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		ini
		dec		de
		ld		a, d
		or		a, e
		jr		nz, read_bank_ini_loop
		ret

; --- compare BUF_R with the rotated BUF_E ----------------------------------------
compare_bank:
		call	seg1_args
		ld		de, BUF_R
		call	cmp_seg
		ld		hl, BUF_E
		ld		bc, [off]

;	HL = expected, DE = read, BC = bytes
cmp_seg:
		ld		a, b
		or		a, c
		ret		z
cmp_loop:
		ld		a, [de]
		inc		de
		cpi
		jr		nz, cmp_mis
		jp		pe, cmp_loop
		ret
cmp_mis:
		push	hl
		push	de
		push	bc
		dec		hl
		dec		de
		call	record_error
		pop		bc
		pop		de
		pop		hl
		ld		a, b
		or		a, c
		jr		nz, cmp_loop
		ret

;	HL = expected pointer, DE = read pointer
record_error:
		ld		a, [de]
		ld		[e_got], a
		ld		a, [hl]
		ld		[e_exp], a
		push	de
		ld		de, BUF_E
		or		a, a
		sbc		hl, de			; HL = index in BUF_E
		push	hl
		dec		hl
		call	exp_at
		ld		[e_prev], a
		pop		hl
		inc		hl
		call	exp_at
		ld		[e_next], a
		pop		hl
		ld		de, BUF_R
		or		a, a
		sbc		hl, de
		ld		[e_off], hl
		ex		de, hl
		xor		a, a
		call	set_addr_de		; single byte re-read
		ld		b, 8
record_wait:
		djnz	record_wait
		in		a, [VDP_DATA]
		ld		[e_re], a
		ld		b, a
		ld		c, 'R'
		ld		hl, 2
		ld		a, [e_exp]
		cp		a, b
		jr		z, record_kind
		ld		c, 'W'
		ld		hl, 0
		ld		a, [e_got]
		cp		a, b
		jr		z, record_kind
		ld		c, '?'
		ld		hl, 4
record_kind:
		ld		a, [cond]
		ld		e, a
		add		a, a
		add		a, e
		add		a, a
		ld		e, a
		ld		d, 0
		add		hl, de
		ld		de, cnt_table
		add		hl, de
		call	inc_sat
		ld		hl, total_err
		call	inc_sat
		ld		a, [log_count]
		cp		a, MAX_LOG
		ret		nc
		inc		a
		ld		[log_count], a
		ld		hl, [log_ptr]
		ld		[hl], c
		inc		hl
		ld		a, [cond]
		ld		[hl], a
		inc		hl
		ld		a, [round_done]
		ld		[hl], a
		inc		hl
		ld		a, [bank]
		ld		[hl], a
		inc		hl
		ld		de, [e_off]
		ld		[hl], e
		inc		hl
		ld		[hl], d
		inc		hl
		ld		a, [e_exp]
		ld		[hl], a
		inc		hl
		ld		a, [e_got]
		ld		[hl], a
		inc		hl
		ld		a, [e_re]
		ld		[hl], a
		inc		hl
		ld		a, [e_prev]
		ld		[hl], a
		inc		hl
		ld		a, [e_next]
		ld		[hl], a
		inc		hl
		ld		[log_ptr], hl
		ret

;	HL = index (wraps) -> A = BUF_E[HL & 3FFFh]
exp_at:
		ld		a, h
		and		a, 0x3F
		add		a, BUF_E >> 8
		ld		h, a
		ld		a, [hl]
		ret

;	HL = word pointer, saturating increment (keeps C)
inc_sat:
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		inc		de
		ld		a, d
		or		a, e
		ret		z
		ld		[hl], d
		dec		hl
		ld		[hl], e
		ret

; -----------------------------------------------------------------------------
;	VDP detection (DI)
; -----------------------------------------------------------------------------
detect_vdp:
		ld		a, 1
		call	rstat
		rrca
		and		a, 0x1F
		ld		[vdp_id], a
		xor		a, a
		ld		[is_v9968], a
		ld		a, [vdp_id]
		or		a, a
		ret		z
		; Port#4 of the V9968 reads {lock, 0000, CI, LI, FI}; nothing there reads FFh
		in		a, [VDP_P4]
		and		a, 0x78
		ret		nz
		xor		a, a
		out		[VDP_P4], a		; unlock R#20/R#21
		in		a, [VDP_P4]
		and		a, 0x80
		jr		nz, detect_relock
		xor		a, a
		ld		b, 21
		call	wreg			; V58 = 0
		ld		a, 1
		call	rstat
		rrca
		and		a, 0x1F
		cp		a, 3
		jr		nz, detect_restore
		ld		a, 1
		ld		[is_v9968], a
detect_restore:
		xor		a, a
		ld		b, 20
		call	wreg
		ld		a, 1
		ld		b, 21
		call	wreg			; V58 = 1
detect_relock:
		ld		a, 0x80
		out		[VDP_P4], a
		ret

; -----------------------------------------------------------------------------
;	turboR: Z80 mode while running
; -----------------------------------------------------------------------------
turbo_r_z80:
		xor		a, a
		ld		[is_turbo_r], a
		ld		a, [EXPTBL_M1 + 1]
		ld		hl, 0x002D
		call	RDSLT
		ei
		cp		a, 3
		ret		c
		ld		a, 1
		ld		[is_turbo_r], a
		ld		iy, [EXPTBL_M1]
		ld		ix, GETCPU
		call	CALSLT
		ld		[saved_cpu], a
		ld		a, 0x80
		ld		iy, [EXPTBL_M1]
		ld		ix, CHGCPU
		call	CALSLT
		ei
		ret

turbo_r_restore:
		ld		a, [is_turbo_r]
		or		a, a
		ret		z
		ld		a, [saved_cpu]
		or		a, 0x80
		ld		iy, [EXPTBL_M1]
		ld		ix, CHGCPU
		call	CALSLT
		ei
		ret

; -----------------------------------------------------------------------------
;	back to the DOS text screen
; -----------------------------------------------------------------------------
restore_screen:
		di
		xor		a, a
		ld		b, 46
		call	wreg
		ld		a, [is_v9968]
		or		a, a
		jr		z, restore_common
		xor		a, a
		out		[VDP_P4], a
		xor		a, a
		ld		b, 20
		call	wreg
		ld		a, 1
		ld		b, 21
		call	wreg
		ld		a, 0x80
		out		[VDP_P4], a
restore_common:
		ld		hl, restore_regs
		call	reg_list
		ld		a, [RG8SAV]
		ld		b, 8
		call	wreg
		ld		a, [RG9SAV]
		ld		b, 9
		call	wreg
		ld		a, [BDRCLR]
		ld		b, 7
		call	wreg
		; CHGMOD rebuilds the text screen (tables, font, registers)
		ld		a, [SCRMOD]
		ld		iy, [EXPTBL_M1]
		ld		ix, CHGMOD
		call	CALSLT
		di
		; the palette table in VRAM was overwritten
		ld		iy, [EXBRSA_M1]
		ld		ix, INIPLT
		call	CALSLT
		ret

restore_regs:
		db		25, 0, 26, 0, 27, 0, 23, 0, 45, 0, 15, 0, 0xFF

; -----------------------------------------------------------------------------
;	report
; -----------------------------------------------------------------------------
print_result:
		ld		de, msg_done
		call	puts
		ld		hl, [round_done]
		call	put_dec
		ld		a, [aborted]
		or		a, a
		jr		z, print_result_1
		ld		de, msg_aborted
		call	puts
print_result_1:
		call	put_crlf
		ld		de, msg_table
		call	puts
		xor		a, a
		ld		[pcond], a
		ld		hl, cnt_table
		ld		[pptr], hl
print_cond_loop:
		ld		a, [pcond]
		inc		a
		ld		l, a
		ld		h, 0
		cp		a, 10
		jr		nc, print_cond_no
		ld		e, ' '
		call	putc
print_cond_no:
		call	put_dec
		ld		e, ' '
		call	putc
		ld		a, [pcond]
		add		a, a
		ld		e, a
		ld		d, 0
		ld		hl, cond_names
		add		hl, de
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		call	puts
		ld		b, 3
print_cnt_loop:
		push	bc
		ld		hl, [pptr]
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		inc		hl
		ld		[pptr], hl
		ex		de, hl
		call	put_cnt
		pop		bc
		djnz	print_cnt_loop
		call	put_crlf
		ld		a, [pcond]
		inc		a
		ld		[pcond], a
		cp		a, COND_COUNT
		jr		c, print_cond_loop

		ld		hl, [total_err]
		ld		a, h
		or		a, l
		jr		nz, print_errors
		ld		de, msg_success
		jp		puts
print_errors:
		ld		de, msg_errors
		call	puts
		ld		hl, [total_err]
		call	put_dec
		call	put_crlf
		ld		de, msg_log_head
		call	puts
		ld		ix, log_area
		ld		a, [log_count]
		ld		b, a
print_log_loop:
		push	bc
		ld		e, [ix + 0]
		call	putc
		ld		a, [ix + 1]
		inc		a
		ld		l, a
		ld		h, 0
		cp		a, 10
		jr		nc, print_log_cond
		ld		e, ' '
		call	putc
print_log_cond:
		call	put_sp_dec
		call	put_sp
		ld		a, [ix + 2]
		call	put_hex8
		call	put_sp
		; address: bank * 4000h + offset
		ld		a, [ix + 3]
		rrca
		rrca
		and		a, 0x01
		call	put_nib
		ld		a, [ix + 3]
		rrca
		rrca
		and		a, 0xC0
		or		a, [ix + 5]
		call	put_hex8
		ld		a, [ix + 4]
		call	put_hex8
		call	put_sp
		ld		a, [ix + 6]
		call	put_hex8_sp
		ld		a, [ix + 7]
		call	put_hex8_sp
		ld		a, [ix + 6]
		xor		a, [ix + 7]
		call	put_hex8_sp
		ld		a, [ix + 8]
		call	put_hex8_sp
		ld		a, [ix + 9]
		call	put_hex8_sp
		ld		a, [ix + 10]
		call	put_hex8
		call	put_crlf
		ld		de, LOG_SIZE
		add		ix, de
		pop		bc
		djnz	print_log_loop
		ld		hl, [total_err]
		ld		a, [log_count]
		ld		e, a
		ld		d, 0
		or		a, a
		sbc		hl, de
		ret		z
		ld		de, msg_more
		jp		puts

put_sp_dec:
		call	put_sp
		jp		put_dec

put_sp:
		ld		e, ' '
		jp		putc

put_hex8_sp:
		call	put_hex8
		jr		put_sp

put_hex8:
		push	af
		rrca
		rrca
		rrca
		rrca
		call	put_nib
		pop		af
put_nib:
		and		a, 0x0F
		add		a, '0'
		cp		a, '9' + 1
		jr		c, put_nib_1
		add		a, 7
put_nib_1:
		ld		e, a
		jp		putc

puts:
		ld		c, _PUTS
		jp		BDOS

;	E = character (keeps BC, HL, IX)
putc:
		push	hl
		push	bc
		push	ix
		ld		c, _CONOUT
		call	BDOS
		pop		ix
		pop		bc
		pop		hl
		ret

put_crlf:
		ld		de, msg_crlf
		jp		puts

;	HL = count, " dddd" (shown as 9999 when larger)
put_cnt:
		ld		de, 10000
		or		a, a
		sbc		hl, de
		add		hl, de
		jr		c, put_cnt_1
		ld		hl, 9999
put_cnt_1:
		ld		e, ' '
		call	putc
		ld		a, ' '
		ld		[pad], a
		ld		b, 0
		jr		put_dec_1000
;	HL = value (decimal, no leading zeros)
put_dec:
		xor		a, a
		ld		[pad], a
		ld		b, 0
		ld		de, 10000
		call	put_dec_digit
put_dec_1000:
		ld		de, 1000
		call	put_dec_digit
		ld		de, 100
		call	put_dec_digit
		ld		de, 10
		call	put_dec_digit
		ld		b, 1
		ld		de, 1
put_dec_digit:
		ld		a, '0' - 1
put_dec_sub:
		inc		a
		or		a, a
		sbc		hl, de
		jr		nc, put_dec_sub
		add		hl, de
		cp		a, '0'
		jr		nz, put_dec_out
		inc		b
		dec		b
		jr		nz, put_dec_out
		ld		a, [pad]
		or		a, a
		ret		z
put_dec_char:
		push	de
		ld		e, a
		call	putc
		pop		de
		ret
put_dec_out:
		ld		b, 1
		jr		put_dec_char

; -----------------------------------------------------------------------------
;	messages
; -----------------------------------------------------------------------------
msg_banner:
		db		"VRAMSTRS: VRAM stress test", 0x0D, 0x0A
		db		"VRAMSTRS [rounds] 0=until ESC", 0x0D, 0x0A, "$"
msg_v9938:
		db		"V9958 or V9968 is required.", 0x0D, 0x0A, "$"
msg_v9958:
		db		"VDP: V9958", 0x0D, 0x0A, "$"
msg_v9968:
		db		"VDP: V9968", 0x0D, 0x0A, "$"
msg_rounds:
		db		"ROUNDS: $"
msg_endless:
		db		"UNTIL ESC", 0x0D, 0x0A, "$"
msg_running:
		db		"Running... ESC = stop", 0x0D, 0x0A, "$"
msg_tpa:
		db		"Not enough memory.", 0x0D, 0x0A, "$"
msg_done:
		db		"ROUNDS DONE: $"
msg_aborted:
		db		" (ESC)$"
msg_table:
		db		"NO WRT  RD   SCR    W    R    ?", 0x0D, 0x0A, "$"
msg_success:
		db		"SUCCESS OF ALL", 0x0D, 0x0A, "$"
msg_errors:
		db		"ERRORS: $"
msg_log_head:
		db		"T NO RD ADDR  EX GT XR RE PV NX", 0x0D, 0x0A, "$"
msg_more:
		db		"(first 16 errors only)", 0x0D, 0x0A, "$"
msg_crlf:
		db		0x0D, 0x0A, "$"

cond_names:
		dw		cn1, cn2, cn3, cn4, cn5, cn6, cn7, cn8, cn9, cn10
cn1:	db		"OTIR INIR OFF$"
cn2:	db		"OUTI INI  OFF$"
cn3:	db		"ADDR INIR OFF$"
cn4:	db		"OTIR INIR SC5$"
cn5:	db		"OUTI INI  SC5$"
cn6:	db		"ADDR INIR SC5$"
cn7:	db		"OTIR INIR SC8$"
cn8:	db		"OUTI INI  SC8$"
cn9:	db		"HMMV OTIR OFF$"
cn10:	db		"HMMV OUTI SC5$"

; -----------------------------------------------------------------------------
;	work area
; -----------------------------------------------------------------------------
rounds::	db		0
arg_seen::	db		0
aborted::	db		0
round_done::	dw		0
cond::		db		0
bank::		db		0
off::		dw		0
wmeth::		db		0
rmeth::		db		0
clrmode::	db		0
vdp_id::	db		0
is_v9968::	db		0
is_turbo_r::	db		0
saved_cpu::	db		0
e_off::		dw		0
e_exp::		db		0
e_got::		db		0
e_re::		db		0
e_prev::	db		0
e_next::	db		0
total_err::	dw		0
cnt_table::	space	COND_COUNT * 6
log_count::	db		0
log_ptr::	dw		log_area
pcond::		db		0
pptr::		dw		0
pad::		db		0
log_area::	space	MAX_LOG * LOG_SIZE
program_end::
