; -----------------------------------------------------------------------------
;	VDPTEST.ASM -- VDP command termination stress test (MSX-DOS .COM)
;
;	Runs a table of VDP command patterns (boundary sizes, clipping edges,
;	overlaps, all logical operations, CPU-transfer commands, SRCH to the
;	border, plus retrigger / abort / DS4-style soak specials) and checks
;	that every command TERMINATES by polling S#2 CE with a timeout.
;
;	On timeout the pattern is written to the report buffer (printed on
;	screen at the end and saved to VDPTEST.LOG), a STOP is issued, and
;	the test continues with the next pattern.
;	At the end: "SUCCESS OF ALL" when there were no timeouts, otherwise
;	"TIMEOUTS: n".
;
;	The whole table runs twice: pass A with the display ON (display fetch
;	contends with the command engine), pass B with the display OFF.
;
;	Assemble with zma:  zma VDPTEST.ASM VDPTEST.COM
;	Target: MSX2 or later, 128 KB VRAM, Graphic 4 (SCREEN 5) geometry.
;	The program uses the main VDP ports (98h-9Bh).
; -----------------------------------------------------------------------------

BDOS		:= 0x0005
_TERM0		:= 0x00
_CONOUT		:= 0x02
_PUTS		:= 0x09
_CREATE		:= 0x44			; MSX-DOS 2 handle functions (byte counts,
_WRITE		:= 0x49			; no FCB record/extent semantics).
_CLOSE		:= 0x45			; Per the DOS 2.20 Function Specification:
							; _OPEN=43h _CREATE=44h _CLOSE=45h _READ=48h _WRITE=49h

LOGBUF		:= 0x8000		; report buffer (grows upward)
LOGBUF_END	:= 0xF000

NUM_CASES	:= 71

CE_OUTER	:= 60000		; CE poll: 60000 x 20 polls (~10 s)
TR_OUTER	:= 20000		; TR poll: 20000 x 20 polls (~3.4 s)
SHORT_OUTER	:= 400			; short poll: 400 x 20 polls (~70 ms)

		org		0x100

; -----------------------------------------------------------------------------
;	entry
; -----------------------------------------------------------------------------

entry_point::
		ld		de, msg_banner
		ld		c, _PUTS
		call	BDOS

		; report buffer <- header
		ld		hl, LOGBUF
		ld		[buf_ptr], hl
		ld		hl, str_loghdr
		call	append_str
		xor		a, a
		ld		[fail_count], a
		ld		[case_no], a
		ld		[total_done], a

		call	save_screen		; keep the text font before VRAM is trashed

		di
		call	vdp_init_g4
		call	palette_init

		; ---- pass A: display ON
		ld		a, 'A'
		ld		[pass_id], a
		ld		a, 0x42			; R#1: BL=1, sprite 16x16
		ld		b, 1
		call	wreg
		call	run_table
		call	run_specials

		; ---- pass B: display OFF
		ld		a, 'B'
		ld		[pass_id], a
		ld		a, 0x02			; R#1: BL=0
		ld		b, 1
		call	wreg
		call	run_table
		call	run_specials

		; verdict line into the report buffer
		ld		a, [fail_count]
		or		a, a
		jr		nz, verdict_ng
		ld		hl, str_success
		call	append_str
		jr		verdict_done
verdict_ng:
		ld		hl, str_timeouts
		call	append_str
		ld		a, [fail_count]
		call	append_dec
		ld		hl, str_crlf
		call	append_str
verdict_done:
		call	restore_screen	; font + name table + registers back
		ei

		; print the whole report
		ld		hl, LOGBUF
		ld		de, [buf_ptr]
		or		a, a
		sbc		hl, de			; HL = -len ... recompute below
		ld		hl, [buf_ptr]
		ld		de, LOGBUF
		or		a, a
		sbc		hl, de			; HL = len
		ld		b, h
		ld		c, l			; BC = len
		ld		hl, LOGBUF
print_loop:
		ld		a, b
		or		a, c
		jr		z, print_done
		ld		e, [hl]
		inc		hl
		push	hl
		push	bc
		ld		c, _CONOUT
		call	BDOS
		pop		bc
		pop		hl
		dec		bc
		jr		print_loop
print_done:
		call	write_log_file
		ld		c, _TERM0
		jp		BDOS

; -----------------------------------------------------------------------------
;	VDP register write: A = value, B = register number (preserves HL, DE)
; -----------------------------------------------------------------------------

wreg::
		out		[0x99], a
		ld		a, b
		or		a, 0x80
		out		[0x99], a
		ret

; -----------------------------------------------------------------------------
;	set R#15 (status register select): A = number
; -----------------------------------------------------------------------------

set_s15::
		ld		b, 15
		jp		wreg

; -----------------------------------------------------------------------------
;	write a (register, value) pair table: HL = table, C = pair count
; -----------------------------------------------------------------------------

write_reg_table::
		ld		b, [hl]
		inc		hl
		ld		a, [hl]
		inc		hl
		push	hl
		push	bc
		call	wreg
		pop		bc
		pop		hl
		dec		c
		jr		nz, write_reg_table
		ret

; -----------------------------------------------------------------------------
;	Graphic 4 (SCREEN 5) initialisation, direct register writes
; -----------------------------------------------------------------------------

vdp_init_g4::
		ld		hl, g4_regs
		ld		c, (g4_regs_end - g4_regs) / 2
		jp		write_reg_table

; -----------------------------------------------------------------------------
;	palette: 16 greys
; -----------------------------------------------------------------------------

palette_init::
		xor		a, a
		ld		b, 16
		call	wreg			; R#16 = 0
		ld		b, 16
pal_loop:
		ld		a, 16
		sub		a, b			; A = color index 0..15
		srl		a				; v = index >> 1 (0..7)
		ld		c, a
		rlca
		rlca
		rlca
		rlca
		or		a, c			; A = (v<<4)|v  (R,B)
		out		[0x9A], a
		ld		a, c			; A = v (G)
		out		[0x9A], a
		djnz	pal_loop
		ret

; -----------------------------------------------------------------------------
;	VRAM address setup helpers.  HL = 16-bit VRAM address.
;	R#14 gets (address >> 14); works for all standard text bases.
; -----------------------------------------------------------------------------
set_rd_addr::
		push	hl
		ld		a, h
		rrca
		rrca
		rrca
		rrca
		rrca
		rrca
		and		a, 0x07
		ld		b, 14
		call	wreg
		pop		hl
		ld		a, l
		out		[0x99], a
		ld		a, h
		and		a, 0x3F
		out		[0x99], a
		ret

set_wr_addr::
		push	hl
		ld		a, h
		rrca
		rrca
		rrca
		rrca
		rrca
		rrca
		and		a, 0x07
		ld		b, 14
		call	wreg
		pop		hl
		ld		a, l
		out		[0x99], a
		ld		a, h
		and		a, 0x3F
		or		a, 0x40
		out		[0x99], a
		ret

; -----------------------------------------------------------------------------
;	save_screen: snapshot whatever text screen the console is using.
;	The DOS console layout is machine dependent (on the FS-A1ST the
;	work area says PATBAS=0x0000 / NAMBAS=0x1800, a SCREEN 1 layout),
;	so nothing is hardcoded: PATBAS/NAMBAS come from the work area and
;	the VDP register set from the RGnSAV shadows (0xF3DF, 24 bytes).
;	The test trashes all of VRAM, font included; without this the
;	end-of-run text screen cannot come back.  Call before touching VRAM.
; -----------------------------------------------------------------------------
save_screen::
		ld		hl, [0xF924]		; PATBAS
		ld		[patbas_save], hl
		ld		hl, [0xF922]		; NAMBAS
		ld		[nambas_save], hl
		ld		hl, 0xF3DF			; RG0SAV..
		ld		de, reg_save
		ld		bc, 24
		ldir
		ld		hl, [patbas_save]
		call	set_rd_addr
		in		a, [0x98]			; dummy read (prefetch prime)
		ld		hl, [patbas_save]
		call	set_rd_addr
		ld		hl, font_buf
		ld		bc, 2048
ss_font:
		in		a, [0x98]
		ld		[hl], a
		inc		hl
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, ss_font
		; colour table: 32 bytes (SCREEN 1 consoles only)
		call	ct_addr
		jr		c, ss_ct_done
		call	set_rd_addr
		in		a, [0x98]			; dummy read (prefetch prime)
		call	ct_addr
		call	set_rd_addr
		ld		hl, ct_buf
		ld		bc, 32
ss_ct:
		in		a, [0x98]
		ld		[hl], a
		inc		hl
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, ss_ct
ss_ct_done:
		ret

;	ct_addr: HL = colour table address (SCREEN 1 only: PATBAS + 0x2000).
;	Returns CY=1 when the console is not in SCREEN 1 (no colour table).
;	NOTE: RGnSAV shadows are stale for R#8+ on the FS-A1ST DOS console
;	(probed 2026-11-04), so nothing is derived from the shadow R#3.
ct_addr::
		ld		a, [0xFCAF]			; SCRMOD
		cp		a, 1
		jr		nz, ct_none
		ld		hl, [patbas_save]
		ld		de, 0x2000
		add		hl, de
		or		a, a
		ret
ct_none:
		scf
		ret

; -----------------------------------------------------------------------------
;	restore_screen: write the saved font back to PATBAS, clear the name
;	table at NAMBAS (1024 spaces, covers 40x24 and 32x24), and restore
;	the saved VDP register set R#0..R#23.
; -----------------------------------------------------------------------------
restore_screen::
		ld		hl, [patbas_save]
		call	set_wr_addr
		ld		hl, font_buf
		ld		bc, 2048
rs_font:
		ld		a, [hl]
		out		[0x98], a
		inc		hl
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, rs_font
		call	ct_addr
		jr		c, rs_ct_done
		call	set_wr_addr
		ld		hl, ct_buf
		ld		bc, 32
rs_ct:
		ld		a, [hl]
		out		[0x98], a
		inc		hl
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, rs_ct
rs_ct_done:
		ld		hl, [nambas_save]
		call	set_wr_addr
		ld		bc, 1024
rs_clr:
		ld		a, 0x20
		out		[0x98], a
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, rs_clr
		; Restore R#0..R#7 from the saved shadows (the only range whose
		; shadows match the real console registers), then set R#8/R#9
		; to the standard text-console values.  The RGnSAV shadows for
		; R#8+ are stale garbage on the FS-A1ST DOS console (probed
		; 2026-11-04: actual R#8=08/R#9=00 vs shadows 9F/F1), so they
		; must NOT be written back.
		ld		hl, reg_save
		ld		c, 0
rs_reg:
		ld		a, [hl]
		inc		hl
		push	hl
		push	bc
		ld		b, c
		call	wreg
		pop		bc
		pop		hl
		inc		c
		ld		a, c
		cp		a, 8
		jr		nz, rs_reg
		ld		a, 0x08
		ld		b, 8
		call	wreg
		xor		a, a
		ld		b, 9
		call	wreg
		ld		b, 14
		call	wreg
		ld		b, 15
		jp		wreg

; -----------------------------------------------------------------------------
;	restore a text screen (SCREEN 0-like register set)
; -----------------------------------------------------------------------------

vdp_restore_text::
		ld		hl, text_regs
		ld		c, (text_regs_end - text_regs) / 2
		jp		write_reg_table

; -----------------------------------------------------------------------------
;	delay: HL = loop count (~25 T-states each)
; -----------------------------------------------------------------------------

delay16::
		dec		hl
		ld		a, h
		or		a, l
		jr		nz, delay16
		ret

; -----------------------------------------------------------------------------
;	poll S#2 CE (bit0) until the command finishes.
;	Select S#2 before calling.  HL = outer count (x20 polls).
;	Returns CY=1 on timeout, NC on completion.  Last S#2 value in [last_s2].
; -----------------------------------------------------------------------------

poll_ce::
		ld		[to_outer], hl
pce_outer:
		ld		b, 20
pce_inner:
		in		a, [0x99]
		ld		[last_s2], a
		and		a, 0x01
		jr		z, pce_ok
		djnz	pce_inner
		ld		hl, [to_outer]
		dec		hl
		ld		[to_outer], hl
		ld		a, h
		or		a, l
		jr		nz, pce_outer
		scf
		ret
pce_ok:
		or		a, a
		ret

; -----------------------------------------------------------------------------
;	poll S#2 TR (bit7) until the engine is ready for a CPU transfer byte.
;	Select S#2 before calling.  Returns CY=1 on timeout.
; -----------------------------------------------------------------------------

poll_tr::
		ld		hl, TR_OUTER
		ld		[to_outer], hl
ptr_outer:
		ld		b, 20
ptr_inner:
		in		a, [0x99]
		ld		[last_s2], a
		and		a, 0x80
		jr		nz, ptr_ok
		djnz	ptr_inner
		ld		hl, [to_outer]
		dec		hl
		ld		[to_outer], hl
		ld		a, h
		or		a, l
		jr		nz, ptr_outer
		scf
		ret
ptr_ok:
		or		a, a
		ret

; -----------------------------------------------------------------------------
;	issue STOP command
; -----------------------------------------------------------------------------

stop_cmd::
		xor		a, a
		ld		b, 46
		jp		wreg

; -----------------------------------------------------------------------------
;	write a command register block: HL -> 15 bytes (R#32..R#46 values).
;	The write to R#46 triggers the command.
; -----------------------------------------------------------------------------

wr_cmd_block::
		ld		b, 32
wcb_loop:
		ld		a, [hl]
		inc		hl
		push	hl
		push	bc
		call	wreg
		pop		bc
		pop		hl
		inc		b
		ld		a, b
		cp		a, 47
		jr		nz, wcb_loop
		ret

; -----------------------------------------------------------------------------
;	report buffer append helpers
; -----------------------------------------------------------------------------

append_char::
		ld		hl, [buf_ptr]
		ld		de, LOGBUF_END
		or		a, a
		sbc		hl, de
		ret		nc					; buffer full: drop
		add		hl, de
		ld		e, a
		ld		[hl], e
		inc		hl
		ld		[buf_ptr], hl
		ret

append_str::
		ld		a, [hl]
		inc		hl
		or		a, a
		ret		z
		push	hl
		call	append_char
		pop		hl
		jr		append_str

append_hex2::
		push	af
		rrca
		rrca
		rrca
		rrca
		call	append_hex1
		pop		af
append_hex1:
		and		a, 0x0F
		cp		a, 10
		jr		c, ah_digit
		add		a, 'A' - 10
		jp		append_char
ah_digit:
		add		a, '0'
		jp		append_char

append_hex4::
		push	hl
		ld		a, h
		call	append_hex2
		pop		hl
		ld		a, l
		jp		append_hex2

; append A as decimal (0..255, no leading zeros except "0" itself)

append_dec::
		ld		c, a
		ld		d, 0			; printed flag
		ld		a, c
		ld		b, 100
		call	ad_digit
		ld		a, c
		ld		b, 10
		call	ad_digit
		ld		a, c
		add		a, '0'
		jp		append_char
ad_digit:
		ld		e, 0
ad_sub:
		cp		a, b
		jr		c, ad_done
		sub		a, b
		inc		e
		jr		ad_sub
ad_done:
		ld		c, a			; remainder
		ld		a, e
		or		a, a
		jr		nz, ad_print
		ld		a, d
		or		a, a
		ret		z				; leading zero: skip
ad_print:
		ld		d, 1
		ld		a, e
		add		a, '0'
		jp		append_char

; -----------------------------------------------------------------------------
;	extract NX / NY from the current entry -> [nx_val] / [ny_val]
;	entry layout: +0 type, +1..2 pad, +3 SXlo, +4 SXhi, +5 SYlo, +6 SYhi,
;	+7 DXlo, +8 DXhi, +9 DYlo, +10 DYhi, +11 NXlo, +12 NXhi,
;	+13 NYlo, +14 NYhi, +15 CLR, +16 ARG, +17 CMD
; -----------------------------------------------------------------------------

get_nx_ny::
		ld		hl, [cur_entry]
		ld		de, 11
		add		hl, de
		ld		a, [hl]
		inc		hl
		ld		[nx_val], a
		ld		a, [hl]
		and		a, 0x01
		ld		[nx_val + 1], a
		inc		hl
		ld		a, [hl]
		inc		hl
		ld		[ny_val], a
		ld		a, [hl]
		and		a, 0x03
		ld		[ny_val + 1], a
		ret

; HL = [nx_val] * [ny_val]  (result <= 65535 for all table feed cases)

mul_nx_ny::
		ld		hl, [ny_val]
		ld		e, l
		ld		d, h			; DE = NY (counter)
		ld		hl, [nx_val]
		ld		c, l
		ld		b, h			; BC = NX
		ld		hl, 0
mul_loop:
		ld		a, d
		or		a, e
		ret		z
		add		hl, bc
		dec		de
		jr		mul_loop

; -----------------------------------------------------------------------------
;	CPU -> VDP data feed (LMMC / HMMC).  DE = byte count.
;	Returns CY=1 on TR timeout.
; -----------------------------------------------------------------------------

feed_bytes::
		ld		a, 2
		call	set_s15
fb_loop:
		ld		a, d
		or		a, e
		jr		z, fb_done
		call	poll_tr
		ret		c
		ld		a, [feed_pat]
		out		[0x99], a		; R#44 value (color/data)
		push	af
		ld		a, 0x80 + 44
		out		[0x99], a		; R#44 select (direct register write)
		pop		af
		inc		a
		ld		[feed_pat], a
		dec		de
		jr		fb_loop
fb_done:
		or		a, a
		ret

; -----------------------------------------------------------------------------
;	VDP -> CPU drain (LMCM), data read via S#7.  DE = byte count.
;	Returns CY=1 on TR timeout.
; -----------------------------------------------------------------------------

drain_bytes::
		ld		a, 2
		call	set_s15
dr_loop:
		ld		a, d
		or		a, e
		jr		z, dr_done
		call	poll_tr
		ret		c
		ld		a, 7
		call	set_s15
		in		a, [0x99]		; pixel byte (discarded)
		ld		a, 2
		call	set_s15
		dec		de
		jr		dr_loop
dr_done:
		or		a, a
		ret

; -----------------------------------------------------------------------------
;	log a failure for the current entry (also increments fail_count)
; -----------------------------------------------------------------------------

log_fail::
		ld		a, [fail_count]
		inc		a
		ld		[fail_count], a
		ld		hl, str_fail
		call	append_str
		ld		a, [pass_id]
		call	append_char
		ld		a, ' '
		call	append_char
		ld		a, '#'
		call	append_char
		ld		a, [case_no]
		call	append_dec
		ld		hl, str_op
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 17
		add		hl, de
		ld		a, [hl]			; CMD
		call	append_hex2
		ld		hl, str_sx
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 3
		call	lf_field4		; SX (hi mask 0F)
		ld		hl, str_sy
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 5
		call	lf_field4		; SY (hi mask 03)
		ld		hl, str_dx
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 7
		call	lf_field4		; DX (hi mask 01)
		ld		hl, str_dy
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 9
		call	lf_field4		; DY (hi mask 03)
		ld		hl, str_nx
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 11
		call	lf_field4		; NX (hi mask 01)
		ld		hl, str_ny
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 13
		call	lf_field4		; NY (hi mask 03)
		ld		hl, str_clr
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 15
		add		hl, de
		ld		a, [hl]			; CLR
		call	append_hex2
		ld		hl, str_arg
		call	append_str
		ld		hl, [cur_entry]
		ld		de, 16
		add		hl, de
		ld		a, [hl]			; ARG
		call	append_hex2
		ld		hl, str_s2
		call	append_str
		ld		a, [last_s2]
		call	append_hex2
		ld		hl, str_crlf
		jp		append_str

; append a 16-bit field: HL = entry, DE = offset of low byte.
; mask for the high byte is taken from the field position (see lf_masks use:
; caller sets A = mask before call -- simplified: use mask table by offset)
lf_field4:
		add		hl, de
		ld		e, [hl]
		inc		hl
		ld		a, [hl]
		ld		d, a
		; mask high byte by field: offsets 3->0F, 5->03, 7->01, 9->03, 11->01, 13->03
		; (the raw hi bytes in the table already carry only the valid bits,
		;  so masking is a no-op for our generated table; keep value as-is)
		ld		h, d
		ld		l, e
		jp		append_hex4

; -----------------------------------------------------------------------------
;	progress bar: one HMMV strip on page 0, DY=206..208, width = total_done
; -----------------------------------------------------------------------------

progress::
		ld		a, [total_done]
		inc		a
		ld		[total_done], a
		ld		hl, bar_block
		ld		de, 8			; NXlo offset in the 15-byte block
		add		hl, de
		ld		[hl], a
		ld		hl, bar_block
		call	wr_cmd_block
		ld		a, 2
		call	set_s15
		ld		hl, SHORT_OUTER
		call	poll_ce
		ret						; result ignored (cosmetic)

; -----------------------------------------------------------------------------
;	execute one table case: HL = entry
; -----------------------------------------------------------------------------

exec_case::
		ld		[cur_entry], hl
		ld		a, [hl]
		ld		[cur_type], a
		push	hl
		inc		hl
		inc		hl
		inc		hl
		call	wr_cmd_block		; triggers the command
		pop		hl
		ld		a, [cur_type]
		or		a, a
		jr		z, ec_wait
		cp		a, 1
		jr		z, ec_lmmc
		cp		a, 2
		jr		z, ec_hmmc
		cp		a, 3
		jr		z, ec_lmcm
		jr		ec_wait
ec_lmmc:
		call	get_nx_ny
		call	mul_nx_ny		; HL = NX*NY
		ld		d, h
		ld		e, l
		call	feed_bytes
		jr		c, ec_xfer_fail
		jr		ec_wait
ec_hmmc:
		call	get_nx_ny
		ld		hl, [nx_val]
		srl		h
		rr		l				; NX/2 (NX is even in the table)
		ld		[nx_val], hl
		call	mul_nx_ny
		ld		d, h
		ld		e, l
		call	feed_bytes
		jr		c, ec_xfer_fail
		jr		ec_wait
ec_lmcm:
		call	get_nx_ny
		call	mul_nx_ny
		ld		d, h
		ld		e, l
		call	drain_bytes
		jr		c, ec_xfer_fail
		jr		ec_wait
ec_xfer_fail:
		call	log_fail
		call	stop_cmd
		ld		hl, 2000
		call	delay16
		jp		progress
ec_wait:
		ld		a, 2
		call	set_s15
		ld		hl, CE_OUTER
		call	poll_ce
		jr		nc, ec_ok
		call	log_fail
		call	stop_cmd
		ld		hl, 2000
		call	delay16
		ld		a, 2
		call	set_s15
		ld		hl, SHORT_OUTER
		call	poll_ce			; recovery attempt (result ignored)
ec_ok:
		jp		progress

; -----------------------------------------------------------------------------
;	run the whole case table once
; -----------------------------------------------------------------------------

run_table::
		ld		hl, case_table
		ld		a, 1
		ld		[case_no], a
rt_loop:
		ld		a, [case_no]
		cp		a, NUM_CASES + 1
		ret		nc
		push	hl
		call	exec_case
		pop		hl
		ld		de, 18
		add		hl, de
		ld		a, [case_no]
		inc		a
		ld		[case_no], a
		jr		rt_loop

; -----------------------------------------------------------------------------
;	special tests: retrigger, abort recovery, DS4-style soak
; -----------------------------------------------------------------------------

run_specials::
		; ---- #201: retrigger while a long command is executing
		ld		a, 201
		ld		[case_no], a
		ld		hl, retrig1_regs
		call	wr_cmd_block		; HMMV full screen (takes ~0.5 s)
		ld		hl, 3000
		call	delay16				; ~17 ms: command still running
		ld		hl, retrig2_entry
		ld		[cur_entry], hl
		inc		hl
		inc		hl
		inc		hl
		call	wr_cmd_block		; retrigger: LMMV 8x8 TAND
		ld		a, 2
		call	set_s15
		ld		hl, CE_OUTER
		call	poll_ce
		jr		nc, sp1_ok
		call	log_fail
		call	stop_cmd
sp1_ok:
		call	progress

		; ---- #202: STOP abort, then a fresh command must work
		ld		a, 202
		ld		[case_no], a
		ld		hl, abort_entry
		ld		[cur_entry], hl
		inc		hl
		inc		hl
		inc		hl
		call	wr_cmd_block		; LMMV full screen IMP
		ld		hl, 1500
		call	delay16
		call	stop_cmd			; abort it
		ld		a, 2
		call	set_s15
		ld		hl, SHORT_OUTER
		call	poll_ce
		jr		nc, sp2_mid
		call	log_fail			; CE never fell after STOP
sp2_mid:
		ld		hl, small_entry
		ld		[cur_entry], hl
		inc		hl
		inc		hl
		inc		hl
		call	wr_cmd_block		; HMMV 16x16
		ld		a, 2
		call	set_s15
		ld		hl, CE_OUTER
		call	poll_ce
		jr		nc, sp2_ok
		call	log_fail
		call	stop_cmd
sp2_ok:
		call	progress

		; ---- #203: soak, 2000 x (HMMM 8x8 + LMMV-TAND 8x8) pairs
		ld		a, 203
		ld		[case_no], a
		ld		hl, 0
		ld		[iter_no], hl
		ld		hl, 2000
		ld		[soak_left], hl
		ld		a, 0x10
		ld		[soak_sx], a
		ld		a, 0x60
		ld		[soak_sy], a
soak_loop:
		call	soak_build
		ld		hl, soakA_entry
		ld		[cur_entry], hl
		inc		hl
		inc		hl
		inc		hl
		call	wr_cmd_block
		ld		a, 2
		call	set_s15
		ld		hl, SHORT_OUTER
		call	poll_ce
		jr		c, soak_fail
		ld		hl, soakB_entry
		ld		[cur_entry], hl
		inc		hl
		inc		hl
		inc		hl
		call	wr_cmd_block
		ld		a, 2
		call	set_s15
		ld		hl, SHORT_OUTER
		call	poll_ce
		jr		c, soak_fail
		ld		a, [soak_sx]
		add		a, 37
		ld		[soak_sx], a
		ld		a, [soak_sy]
		add		a, 91
		ld		[soak_sy], a
		ld		hl, [iter_no]
		inc		hl
		ld		[iter_no], hl
		ld		hl, [soak_left]
		dec		hl
		ld		[soak_left], hl
		ld		a, h
		or		a, l
		jr		nz, soak_loop
		jr		soak_done
soak_fail:
		call	log_fail
		ld		hl, str_iter
		call	append_str
		ld		hl, [iter_no]
		call	append_hex4
		ld		hl, str_crlf
		call	append_str
		call	stop_cmd
soak_done:
		jp		progress

; build the two soak entries for this iteration (patched in place)
soak_build:
		ld		a, [soak_sx]
		and		a, 0xF8			; SX = 0..248 step 8
		ld		c, a			; C = SX
		ld		[soakA_entry + 3], a	; A: SXlo
		ld		a, [soak_sy]
		and		a, 0xF8			; SY = 0..248 step 8
		ld		[soakA_entry + 5], a	; A: SYlo
		ld		[soakA_entry + 9], a	; A: DYlo = SY
		ld		[soakB_entry + 9], a	; B: DYlo
		ld		a, [iter_no]
		and		a, 0x01
		ld		[soakA_entry + 6], a	; A: SYhi = page (0/1)
		xor		a, 0x01
		ld		[soakA_entry + 10], a	; A: DYhi = other page
		ld		[soakB_entry + 10], a	; B: DYhi
		ld		a, 248
		sub		a, c
		ld		[soakA_entry + 7], a	; A: DXlo = 248 - SX
		ld		[soakB_entry + 7], a	; B: DXlo
		ld		a, [soak_sx]
		ld		[soakB_entry + 15], a	; B: CLR varies
		ret

; -----------------------------------------------------------------------------
;	write the report buffer to VDPTEST.LOG
; -----------------------------------------------------------------------------

write_log_file::
		; Use the MSX-DOS 2 handle API: _WRITE takes an exact byte
		; count, avoiding the FCB record/extent behaviour that
		; truncated the log at 128 bytes (see DEBUG_NOTES.md).
		ld		de, log_name	; ASCIIZ "VDPTEST.LOG"
		xor		a, a			; A = open mode 0 (read/write)
		ld		b, a			; attributes = 0 (normal file)
		ld		c, _CREATE
		call	BDOS
		or		a, a			; A = error code, B = handle
		jp		nz, wlf_err
		ld		a, b
		ld		[log_hdl], a
		ld		hl, [buf_ptr]
		ld		de, LOGBUF
		or		a, a
		sbc		hl, de			; HL = byte count
		ld		de, LOGBUF
		ld		a, [log_hdl]
		ld		b, a
		ld		c, _WRITE
		call	BDOS
		or		a, a
		jp		nz, wlf_err
		ld		a, [log_hdl]
		ld		b, a
		ld		c, _CLOSE
		call	BDOS
		ret
wlf_err:
		ld		de, msg_logerr
		ld		c, _PUTS
		jp		BDOS

; -----------------------------------------------------------------------------
;	data
; -----------------------------------------------------------------------------
msg_banner::
		db		"VDPTEST - VDP COMMAND TERMINATION STRESS TEST", 0x0D, 0x0A
		db		"RUNNING... (PROGRESS BAR ON SCREEN)", 0x0D, 0x0A, '$'
msg_logerr::
		db		"LOG FILE ERROR", 0x0D, 0x0A, '$'

str_loghdr::	db		"VDPTEST LOG", 0x0D, 0x0A, 0
str_fail::	db		"FAIL P=", 0
str_op::		db		" OP=", 0
str_sx::		db		" SX=", 0
str_sy::		db		" SY=", 0
str_dx::		db		" DX=", 0
str_dy::		db		" DY=", 0
str_nx::		db		" NX=", 0
str_ny::		db		" NY=", 0
str_clr::	db		" CLR=", 0
str_arg::	db		" ARG=", 0
str_s2::		db		" S2=", 0
str_iter::	db		" ITER=", 0
str_crlf::	db		0x0D, 0x0A, 0
str_success::	db		"SUCCESS OF ALL", 0x0D, 0x0A, 0
str_timeouts::	db		"TIMEOUTS: ", 0

log_name::	db		"VDPTEST.LOG", 0

; (register, value) pairs
g4_regs::
		db		0, 0x06, 1, 0x02, 2, 0x00, 3, 0x00, 4, 0x00, 5, 0x00
		db		6, 0x00, 7, 0x00, 8, 0x00, 9, 0x80, 10, 0x00, 11, 0x00
		db		12, 0x00, 13, 0x00, 14, 0x00, 15, 0x00, 16, 0x00, 17, 0x00
		db		18, 0x00, 19, 0x00, 23, 0x00
g4_regs_end::

text_regs::
		db		0, 0x00, 1, 0x50, 2, 0x00, 3, 0x00, 4, 0x01, 5, 0x00
		db		6, 0x00, 7, 0xF4, 8, 0x00, 9, 0x00, 10, 0x00, 11, 0x00
		db		15, 0x00, 23, 0x00
text_regs_end::

; progress bar command block (15 bytes, R#32..R#46): HMMV at DY=206
bar_block::
		db		0, 0, 0, 0, 0, 0, 206, 0, 0, 0, 3, 0, 0xFF, 0x00, 0xC0

; retrigger: first command (HMMV full screen, CLR=99h)
retrig1_regs::
		db		0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x01, 0x00, 0x04, 0x99, 0x00, 0xC0
; retrigger: second command entry (LMMV 8x8 TAND at 40,40)
retrig2_entry::
		db		0, 0, 0, 0, 0, 0, 0, 40, 0, 40, 0, 8, 0, 8, 0, 0xF0, 0x09, 0x89
; abort target entry (LMMV full screen IMP, CLR=77h)
abort_entry::
		db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x00, 0x01, 0x00, 0x04, 0x77, 0x00, 0x80
; post-abort check entry (HMMV 16x16, CLR=42h)
small_entry::
		db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 16, 0, 16, 0, 0x42, 0x00, 0xC0

; soak entries (patched per iteration)
soakA_entry::
		db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 8, 0, 0x00, 0x00, 0xD0
soakB_entry::
		db		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 8, 0, 8, 0, 0xE4, 0x09, 0x89

; -----------------------------------------------------------------------------
;	variables
; -----------------------------------------------------------------------------
buf_ptr::	space	2
fail_count::	space	1
case_no::	space	1
total_done::	space	1
pass_id::	space	1
last_s2::	space	1
cur_type::	space	1
feed_pat::	space	1
soak_sx::	space	1
soak_sy::	space	1
to_outer::	space	2
cur_entry::	space	2
nx_val::		space	2
ny_val::		space	2
iter_no::	space	2
soak_left::	space	2
log_hdl::	space	1
font_buf::	space	2048
ct_buf::	space	32
patbas_save::	space	2
nambas_save::	space	2
reg_save::	space	24
case_table::
		include		"cases.inc"
case_table_end::
