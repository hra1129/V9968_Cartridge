; LMCMPRB3 - 1x1 LMCM silent-completion discriminator for V9968 hardware.
; On the real FPGA cartridge a 1x1 LMCM ends with CE=0 / TR=0 and S#7 still
; holding the R#44 preload: either (a) the command never starts (CE never
; rises), or (b) it starts and terminates without parking in lmcm_next
; (CE rises and falls, TR never rises).  This program samples S#2 in a
; tight loop across the R#46 trigger write and logs, per run, the first
; sample index with CE=1 (CE@) and with TR=1 (TR@), the counts of samples
; with CE=1 (NCE) and TR=1 (NTR), and S#7 read once after sampling (S7).
; FFFF = never seen.  The openMSX model parks in lmcm_next, so there the
; expectation is CE@/TR@ small, NCE/NTR near the sample count, S7 = pixel.
; MSX-DOS 2 .COM, assembled with zma.

BDOS		:= 0x0005
_PUTS		:= 0x09
_CREATE		:= 0x44
_CLOSE		:= 0x45
_WRITE		:= 0x49

LOGBUF		:= 0x8000
SBUF		:= 0x5000		; 8192 status samples: 0x5000-0x6FFF
PHASE_A		:= 192			; pre-trigger baseline samples
PHASE_B		:= 8000			; post-trigger samples (500 blocks x 16)

			org		0x0100

start::
			di
			ld		hl, str_hdr
			call	emit_str
			ld		hl, str_hdr2
			call	emit_str
			call	vdp_init_g4
			; --- plant test bytes in VRAM (same as LMCMPRB) ---
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
			; --- C0: negative control, trigger = STOP, (10,20) 1x1 ---
			ld		a, '0'
			ld		[v_case], a
			ld		hl, 10
			ld		[v_sx], hl
			ld		hl, 20
			ld		[v_sy], hl
			ld		hl, 1
			ld		[v_nx], hl
			ld		[v_ny], hl
			xor		a, a
			ld		[v_cmd], a
			ld		[v_drain], a
			ld		a, 1
			call	do_reps
			; --- C1: 1x1 at (10,20), 8 reps ---
			ld		a, '1'
			ld		[v_case], a
			ld		a, 0xA0
			ld		[v_cmd], a
			ld		a, 8
			call	do_reps
			; --- C2: positive control, NX=2 at (10,20), 2 reps, drained ---
			ld		a, '2'
			ld		[v_case], a
			ld		hl, 2
			ld		[v_nx], hl
			ld		a, 1
			ld		[v_drain], a
			ld		a, 2
			call	do_reps
			; --- C3: 1x1 at (0,0), 4 reps ---
			ld		a, '3'
			ld		[v_case], a
			ld		hl, 0
			ld		[v_sx], hl
			ld		[v_sy], hl
			ld		hl, 1
			ld		[v_nx], hl
			xor		a, a
			ld		[v_drain], a
			ld		a, 4
			call	do_reps
			; --- done ---
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

; ---------------------------------------------------------------------------
; do_reps: A = repetition count; v_rep is set to '1'.. per repetition
; ---------------------------------------------------------------------------
do_reps::
			ld		[v_reps], a
			xor		a, a
			ld		[v_repi], a
dr_loop:
			ld		a, [v_repi]
			add		a, '1'
			ld		[v_rep], a
			call	sampled_run
			ld		hl, v_repi
			inc		[hl]
			ld		a, [v_reps]
			cp		a, [hl]
			jr		nz, dr_loop
			ret

; ---------------------------------------------------------------------------
; sampled_run: one sampled LMCM run for (v_sx, v_sy, v_nx, v_ny) with the
; trigger opcode in v_cmd.  Logs one line.  If v_drain != 0 (C2), the
; remaining pixel is drained normally before cleanup.
; ---------------------------------------------------------------------------
sampled_run::
			call	build_block
			; R#17 = 32 (AII=0: auto-increment), then 14 bytes to port #3
			ld		a, 32
			ld		b, 17
			call	wreg
			ld		hl, pblock
			ld		b, 14
sr_blk:		ld		a, [hl]
			inc		hl
			out		[0x9B], a
			djnz	sr_blk
			; select S#2 and take the Phase A baseline samples
			ld		a, 2
			call	set_s15
			ld		hl, SBUF
			ld		b, PHASE_A
sr_pa:		in		a, [0x99]
			ld		[hl], a
			inc		hl
			djnz	sr_pa
			; trigger: single direct write of R#46
			ld		a, [v_cmd]
			ld		b, 46
			call	wreg
			; Phase B: tight sampling
			call	sample_b
			call	analyze
			; read S#7 once, then S#2 once
			ld		a, 7
			call	set_s15
			in		a, [0x99]
			ld		[v_s7], a
			ld		a, 2
			call	set_s15
			in		a, [0x99]
			ld		[v_s2], a
			call	emit_log_line
			; C2: drain the second pixel normally
			ld		a, [v_drain]
			or		a, a
			jr		z, sr_cleanup
			call	poll_tr
			jr		c, sr_cleanup
			ld		a, 7
			call	set_s15
			in		a, [0x99]
sr_cleanup:
			call	stop_cmd
			call	poll_ce
			ld		a, 7
			call	set_s15
			in		a, [0x99]
			ret

; ---------------------------------------------------------------------------
; sample_b: 8000 tight samples of S#2 into SBUF+PHASE_A.
; Per sample: in + store + inc only (~24 T-states, ~6.7 us at 3.58 MHz).
; Unrolled x16 per counter check (500 blocks).
; ---------------------------------------------------------------------------
sample_b::
			ld		hl, SBUF + PHASE_A
			ld		bc, PHASE_B / 16
sb_loop:
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			in		a, [0x99]
			ld		[hl], a
			inc		hl
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, sb_loop
			ret

; ---------------------------------------------------------------------------
; analyze: scan the Phase-B samples (index 0 = first post-trigger sample).
; v_fce/v_ftr = first index with CE=1 / TR=1 (0xFFFF if never),
; v_cntce/v_cnttr = counts.
; ---------------------------------------------------------------------------
analyze::
			ld		hl, 0xFFFF
			ld		[v_fce], hl
			ld		[v_ftr], hl
			ld		hl, 0
			ld		[v_cntce], hl
			ld		[v_cnttr], hl
			xor		a, a
			ld		[v_fce_f], a
			ld		[v_ftr_f], a
			ld		hl, SBUF + PHASE_A
			ld		bc, PHASE_B
			ld		de, 0
an_loop:
			ld		a, [hl]
			inc		hl
			ld		[v_smp], a
			and		a, 0x01
			jr		z, an_tr
			push	hl
			ld		hl, [v_cntce]
			inc		hl
			ld		[v_cntce], hl
			pop		hl
			ld		a, [v_fce_f]
			or		a, a
			jr		nz, an_tr
			ld		a, 1
			ld		[v_fce_f], a
			ld		[v_fce], de
an_tr:
			ld		a, [v_smp]
			and		a, 0x80
			jr		z, an_next
			push	hl
			ld		hl, [v_cnttr]
			inc		hl
			ld		[v_cnttr], hl
			pop		hl
			ld		a, [v_ftr_f]
			or		a, a
			jr		nz, an_next
			ld		a, 1
			ld		[v_ftr_f], a
			ld		[v_ftr], de
an_next:
			inc		de
			dec		bc
			ld		a, b
			or		a, c
			jr		nz, an_loop
			ret

; ---------------------------------------------------------------------------
; build_block: pblock[14] = R#32..R#45 image (SX,SY,DX=0,DY=0,NX,NY,R#44=0,ARG=0)
; ---------------------------------------------------------------------------
build_block::
			ld		hl, pblock
			ld		a, [v_sx]
			ld		[hl], a
			inc		hl
			ld		a, [v_sx + 1]
			ld		[hl], a
			inc		hl
			ld		a, [v_sy]
			ld		[hl], a
			inc		hl
			ld		a, [v_sy + 1]
			ld		[hl], a
			inc		hl
			xor		a, a
			ld		[hl], a			; DX lo
			inc		hl
			ld		[hl], a			; DX hi
			inc		hl
			ld		[hl], a			; DY lo
			inc		hl
			ld		[hl], a			; DY hi
			inc		hl
			ld		a, [v_nx]
			ld		[hl], a
			inc		hl
			ld		a, [v_nx + 1]
			ld		[hl], a
			inc		hl
			ld		a, [v_ny]
			ld		[hl], a
			inc		hl
			ld		a, [v_ny + 1]
			ld		[hl], a
			inc		hl
			xor		a, a
			ld		[hl], a			; R#44 = 0 (preload)
			inc		hl
			ld		[hl], a			; R#45 ARG = 0
			ret

; ---------------------------------------------------------------------------
; emit_log_line: "C<c> R<r> CE@<hex4> TR@<hex4> NCE=<hex4> NTR=<hex4> S7=<hex2>"
; ---------------------------------------------------------------------------
emit_log_line::
			ld		a, 'C'
			call	emit_ch
			ld		a, [v_case]
			call	emit_ch
			ld		a, ' '
			call	emit_ch
			ld		a, 'R'
			call	emit_ch
			ld		a, [v_rep]
			call	emit_ch
			ld		hl, str_ceat
			call	emit_str
			ld		hl, [v_fce]
			call	emit_hex16
			ld		hl, str_trat
			call	emit_str
			ld		hl, [v_ftr]
			call	emit_hex16
			ld		hl, str_nce
			call	emit_str
			ld		hl, [v_cntce]
			call	emit_hex16
			ld		hl, str_ntr
			call	emit_str
			ld		hl, [v_cnttr]
			call	emit_hex16
			ld		hl, str_s7e
			call	emit_str
			ld		a, [v_s7]
			call	emit_hex
			ld		hl, str_crlf
			jp		emit_str

emit_hex16::	; HL = value -> four hex chars
			ld		a, h
			call	emit_hex
			ld		a, l
			jp		emit_hex

; ---------------------------------------------------------------------------
; helpers reused from LMCMPRB
; ---------------------------------------------------------------------------
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
log_hdl::	db		0
v_case::	db		0
v_rep::		db		0
v_repi::	db		0
v_reps::	db		0
v_cmd::		db		0
v_drain::	db		0
v_sx::		dw		0
v_sy::		dw		0
v_nx::		dw		0
v_ny::		dw		0
v_smp::		db		0
v_s7::		db		0
v_s2::		db		0
v_fce_f::	db		0
v_ftr_f::	db		0
v_fce::		dw		0
v_ftr::		dw		0
v_cntce::	dw		0
v_cnttr::	dw		0
pblock::	space	14

log_name::	db		"LMCMPRB3.LOG", 0

str_hdr::	db		"LMCMPRB3 LOG", 0x0D, 0x0A, 0
str_hdr2::	db		"CE@/TR@=FIRST SAMPLE WITH CE/TR (FFFF=NEVER) NCE/NTR=SAMPLE COUNTS S7=S#7 AFTER SAMPLING", 0x0D, 0x0A, 0
str_done::	db		"DONE", 0x0D, 0x0A, 0
str_ceat::	db		" CE@", 0
str_trat::	db		" TR@", 0
str_nce::	db		" NCE=", 0
str_ntr::	db		" NTR=", 0
str_s7e::	db		" S7=", 0
str_crlf::	db		0x0D, 0x0A, 0

; G4 mode, display ON
g4_regs::
			db		0, 0x06, 1, 0x42, 2, 0x00, 3, 0x00, 4, 0x00, 5, 0x00
			db		6, 0x00, 7, 0x00, 8, 0x00, 9, 0x80, 10, 0x00, 11, 0x00
			db		12, 0x00, 13, 0x00, 14, 0x00, 15, 0x00, 16, 0x00, 17, 0x00
			db		18, 0x00, 19, 0x00, 23, 0x00
g4_regs_end::

; FS-A1ST DOS console (SCREEN 1) baseline, captured 2026-11-04
text_regs::
			db		0, 0x00, 1, 0x60, 2, 0x06, 3, 0x80, 4, 0x00, 5, 0x36
			db		6, 0x00, 7, 0x07, 8, 0x08, 9, 0x00, 14, 0x00, 15, 0x00
text_regs_end::
