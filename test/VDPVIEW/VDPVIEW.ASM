; -----------------------------------------------------------------------------
;	VDPVIEW.ASM -- V9958 / V9968 visual check pages (MSX-DOS .COM)
;
;	VDPVIEW.COM shows P01-P19; VDPINT.COM shows the line IRQ pages P20-P23.
;	Compare every page with the reference images in VDPVIEW.md.
;		SPACE / RETURN / RIGHT : next page (quit after the last page)
;		BS / LEFT              : previous page
;		ESC                    : quit
;	Pages for the V9968 only are skipped on a V9958.
;	On a turboR the Z80 mode is used while the pages are shown.
;
;	Use build.bat to build both variants and VDPDIAG.COM.
; -----------------------------------------------------------------------------

BDOS		:= 0x0005
TPA_TOP		:= 0x0006
_TERM0		:= 0x00
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
RG8SAV		:= 0xFFE7
RG9SAV		:= 0xFFE8

VDP_DATA	:= 0x98
VDP_CTRL	:= 0x99
VDP_PAL		:= 0x9A
VDP_IND		:= 0x9B
VDP_P4		:= 0x9C
PPI_B		:= 0xA9
PPI_C		:= 0xAA

ACT_NEXT	:= 1
ACT_PREV	:= 2
ACT_QUIT	:= 3

		org		0x100

		jp		entry_point
; fixed addresses for the automatic capture script (openMSX)
vv_page::	db		0			; 0103h: page index being shown
vv_ready::	db		0			; 0104h: 1 while waiting for a key
vv_sign::	db		"VDPV"		; 0105h

; -----------------------------------------------------------------------------
;	entry
; -----------------------------------------------------------------------------
entry_point::
		ld		de, msg_banner
		call	puts

		ld		hl, program_end
		ld		a, h
		add		a, 2			; 1 page margin for the stack
		ld		b, a
		ld		a, [TPA_TOP + 1]
		cp		a, b
		jr		nc, tpa_ok
		ld		de, msg_tpa
		call	puts
		jp		exit_dos
tpa_ok:
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
		call	turbo_r_z80
		call	wait_release

		xor		a, a
		ld		[cur], a
page_loop:
		call	run_page
		call	wait_release
		ld		a, [action]
		cp		a, ACT_QUIT
		jr		z, finish
		cp		a, ACT_PREV
		jr		z, page_prev
page_next:
		ld		a, [cur]
		inc		a
		ld		hl, page_count
		cp		a, [hl]
		jr		nc, finish
		ld		[cur], a
		call	page_skipped
		jr		nz, page_next
		jr		page_loop
page_prev:
		ld		a, [cur]
		or		a, a
		jr		z, page_loop
		dec		a
		ld		[cur], a
		call	page_skipped
		jr		nz, page_prev
		jr		page_loop

finish:
		call	restore_screen
		ei
		call	turbo_r_restore
		ld		de, msg_end
		call	puts
exit_dos:
		ld		c, _TERM0
		jp		BDOS

;	NZ = page [cur] is for the V9968 only and no V9968 is present
page_skipped:
		call	page_entry
		ld		a, [hl]
		and		a, 1
		ret		z
		ld		a, [is_v9968]
		xor		a, 1
		ret

;	HL = page_table + cur * 3
page_entry:
		ld		a, [cur]
		ld		l, a
		ld		h, 0
		ld		e, l
		ld		d, h
		add		hl, hl
		add		hl, de
		ld		de, page_table
		add		hl, de
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
;	keyboard (PPI direct, works with DI)
;	A = 0 none / ACT_NEXT / ACT_PREV / ACT_QUIT
; -----------------------------------------------------------------------------
get_key:
		in		a, [PPI_C]
		and		a, 0xF0
		or		a, 7
		out		[PPI_C], a
		in		a, [PPI_B]
		ld		c, a
		in		a, [PPI_C]
		and		a, 0xF0
		or		a, 8
		out		[PPI_C], a
		in		a, [PPI_B]
		ld		b, a
		ld		a, ACT_QUIT
		bit		2, c			; ESC
		ret		z
		ld		a, ACT_NEXT
		bit		7, c			; RETURN
		ret		z
		bit		0, b			; SPACE
		ret		z
		bit		7, b			; RIGHT
		ret		z
		ld		a, ACT_PREV
		bit		5, c			; BS
		ret		z
		bit		4, b			; LEFT
		ret		z
		xor		a, a
		ret

wait_release:
		ld		de, 0x0800
wait_release_loop:
		call	get_key
		or		a, a
		jr		nz, wait_release
		dec		de
		ld		a, d
		or		a, e
		jr		nz, wait_release_loop
		ret

;	sets vv_ready while waiting, A = action
wait_action:
		ld		a, 1
		ld		[vv_ready], a
wait_action_loop:
		call	get_key
		or		a, a
		jr		z, wait_action_loop
		ld		[action], a
		xor		a, a
		ld		[vv_ready], a
		ret

; -----------------------------------------------------------------------------
;	VDP helpers
; -----------------------------------------------------------------------------
;	A = value, B = register
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

wait_ce:
		ld		a, 2
		ld		b, 15
		call	wreg
wait_ce_loop:
		in		a, [VDP_CTRL]
		rrca
		jr		c, wait_ce_loop
		xor		a, a
		ld		b, 15
		jp		wreg

;	HL = 11 bytes for R#36-R#46
vdp_cmd36:
		ld		a, 36
		ld		b, 17
		call	wreg
		ld		bc, 0x0B00 | VDP_IND
		otir
		jr		wait_ce

; -----------------------------------------------------------------------------
;	one page
; -----------------------------------------------------------------------------
run_page:
		ld		a, [cur]
		ld		[vv_page], a
		xor		a, a
		ld		[action], a
		call	page_prepare
		call	page_entry
		inc		hl
		ld		a, [hl]
		inc		hl
		ld		h, [hl]
		ld		l, a
interp_loop:
		ld		a, [hl]
		inc		hl
		cp		a, OPCODE_COUNT
		jr		nc, interp_broken
		push	hl
		add		a, a
		ld		e, a
		ld		d, 0
		ld		hl, op_table
		add		hl, de
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		ld		[op_jump + 1], de
		pop		hl
		call	op_jump
		ld		a, [action]
		or		a, a
		jr		z, interp_loop
		ret
interp_broken:
		ld		a, ACT_QUIT
		ld		[action], a
		ret

op_jump:
		jp		0

op_table:
		dw		op_end			; 00
		dw		op_reg			; 01
		dw		op_p4			; 02
		dw		op_pal			; 03
		dw		op_vram			; 04
		dw		op_show			; 05
		dw		op_line			; 06
		dw		op_poll			; 07
		dw		op_cmd			; 08
		if		EDGE_TEST
		dw		op_edge			; 09
OPCODE_COUNT	:= 10
		else
OPCODE_COUNT	:= 9
		endif

;	display off, all VRAM cleared, extension registers back to default
page_prepare:
		di
		xor		a, a
		ld		b, 1
		call	wreg			; display off, no interrupts
		xor		a, a
		ld		b, 46
		call	wreg
		ld		a, [is_v9968]
		or		a, a
		jr		z, page_prepare_1
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
page_prepare_1:
		ld		hl, prepare_regs
page_prepare_reg:
		ld		b, [hl]
		inc		hl
		ld		a, b
		cp		a, 0xFF
		jr		z, page_prepare_clear
		ld		a, [hl]
		inc		hl
		call	wreg
		jr		page_prepare_reg
page_prepare_clear:
		ld		hl, cmd_clear0
		call	vdp_cmd36
		ld		hl, cmd_clear1
		jp		vdp_cmd36

prepare_regs:
		db		0, 0x06			; GRAPHIC 4 for the clear
		db		8, 0x08
		db		9, 0x00
		db		15, 0
		db		19, 0
		db		23, 0
		db		25, 0
		db		26, 0
		db		27, 0
		db		45, 0
		db		0xFF

cmd_clear0:
		db		0, 0, 0, 0, 0, 1, 0, 2, 0, 0, 0xC0		; HMMV (0,0)-(255,511)
cmd_clear1:
		db		0, 0, 0, 2, 0, 1, 0, 2, 0, 0, 0xC0		; HMMV (0,512)-(255,1023)

; --- op codes (HL = script pointer) -------------------------------------------
op_end:
		ld		a, ACT_QUIT
		ld		[action], a
		ret

op_reg:
		ld		b, [hl]
		inc		hl
		ld		a, [hl]
		inc		hl
		jp		wreg

op_p4:
		ld		a, [hl]
		inc		hl
		out		[VDP_P4], a
		ret

op_pal:
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		inc		hl
		push	hl
		xor		a, a
		ld		b, 16
		call	wreg
		pop		hl
op_pal_loop:
		ld		a, d
		or		a, e
		ret		z
		ld		a, [hl]
		inc		hl
		out		[VDP_PAL], a
		dec		de
		jr		op_pal_loop

op_vram:
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		inc		hl
		ld		a, [hl]
		inc		hl
		add		a, a
		add		a, a
		ld		b, a
		ld		a, d
		rlca
		rlca
		and		a, 0x03
		or		a, b
		out		[VDP_CTRL], a
		ld		a, 0x8E
		out		[VDP_CTRL], a
		ld		a, e
		out		[VDP_CTRL], a
		ld		a, d
		and		a, 0x3F
		or		a, 0x40
		out		[VDP_CTRL], a
op_vram_loop:
		ld		a, [hl]
		inc		hl
		or		a, a
		ret		z
		cp		a, 0x80
		jr		c, op_vram_literal
		cp		a, 0xFF
		jr		z, op_vram_long
		sub		a, 0x7D
		ld		c, a
		ld		b, 0
		jr		op_vram_fill
op_vram_long:
		ld		c, [hl]
		inc		hl
		ld		b, [hl]
		inc		hl
op_vram_fill:
		ld		a, [hl]
		inc		hl
op_vram_fill_loop:
		out		[VDP_DATA], a
		dec		bc
		ld		d, a
		ld		a, b
		or		a, c
		ld		a, d
		jr		nz, op_vram_fill_loop
		jr		op_vram_loop
op_vram_literal:
		ld		b, a
		ld		c, VDP_DATA
		otir
		jr		op_vram_loop

op_cmd:
		ld		a, 32
		ld		b, 17
		call	wreg
		ld		bc, 0x0F00 | VDP_IND
		otir
		push	hl
		call	wait_ce
		pop		hl
		ret

op_show:
		di
		jp		wait_action

;	r0, start_r19, entries {n, n bytes (value, reg|80h), next_r19, wrap}
op_line:
		ld		a, [hl]
		inc		hl
		ld		[line_r0], a
		ld		a, [hl]
		inc		hl
		ld		[lstart], hl
		ld		[lptr], hl
		ld		b, 19
		call	wreg
		ld		hl, [0x0038]
		ld		[saved_38], hl
		ld		a, [0x003A]
		ld		[saved_38 + 2], a
		ld		a, 0xC3
		ld		[0x0038], a
		ld		hl, line_isr
		ld		[0x0039], hl
		ld		a, 1
		ld		b, 15
		call	wreg			; S#1 stays selected while the page is shown
		in		a, [VDP_CTRL]
		ld		a, [line_r0]
		ld		b, 0
		call	wreg			; IE1 = 1
		ei
		call	wait_action
		di
		ld		a, [line_r0]
		and		a, 0xEF
		ld		b, 0
		call	wreg
		in		a, [VDP_CTRL]
		xor		a, a
		ld		b, 15
		call	wreg
		ld		hl, [saved_38]
		ld		[0x0038], hl
		ld		a, [saved_38 + 2]
		ld		[0x003A], a
		ret

line_isr:
		push	af
		push	bc
		push	hl
		in		a, [VDP_CTRL]	; S#1, clears FH
		rrca
		jr		nc, line_isr_end
		ld		hl, [lptr]
		ld		b, [hl]
		inc		hl
		ld		c, VDP_CTRL
		ld		a, b
		or		a, a
		jr		z, line_isr_r19
		otir
line_isr_r19:
		ld		a, [hl]
		inc		hl
		out		[VDP_CTRL], a
		ld		a, 0x80 | 19
		out		[VDP_CTRL], a
		ld		a, [hl]
		inc		hl
		or		a, a
		jr		z, line_isr_store
		ld		hl, [lstart]
line_isr_store:
		ld		[lptr], hl
line_isr_end:
		pop		hl
		pop		bc
		pop		af
		ei
		ret

		if		EDGE_TEST
; One fixed R#19 per case: frame IRQs measure delivery without rearming a
; missed line IRQ. Setup is excluded by two warm-up frames.
op_edge:
		ld		a, [hl]
		inc		hl
		ld		[edge_lines], a
		ld		a, [hl]
		inc		hl
		ld		[edge_ilns], a
		ld		[edge_panel], hl
		ld		hl, [0x0038]
		ld		[saved_38], hl
		ld		a, [0x003A]
		ld		[saved_38 + 2], a
		ld		a, 0xC3
		ld		[0x0038], a
		ld		hl, edge_isr
		ld		[0x0039], hl
		ld		a, [edge_ilns]
		or		a, a
		jr		z, edge_init
		xor		a, a
		out		[VDP_P4], a
		ld		b, 21
		call	wreg
		ld		a, 4
		ld		b, 20
		call	wreg
		ld		a, 0x80
		out		[VDP_P4], a
edge_init:
		xor		a, a
		ld		[edge_failed], a
		ld		[edge_case], a
		ld		[edge_offset], a
		ld		[edge_r23], a
		ld		a, 1
		ld		[vv_ready], a
edge_setup:
		di
		ld		a, 0x06
		ld		b, 0
		call	wreg
		ld		a, 0x40
		ld		b, 1
		call	wreg
		call	edge_panel_address
		call	edge_erase_panel
		ld		a, [edge_case]
		cp		a, 8
		jr		c, edge_set_y
		cp		a, 17
		jr		nc, edge_border_y
		ld		b, a
		ld		a, [edge_lines]
		add		a, b
		sub		a, 13			; (last visible line - 4) + (case - 8)
		jr		edge_set_y
edge_border_y:
		sub		a, 17
		ld		e, a
		ld		d, 0
		ld		a, [edge_lines]
		cp		a, 212
		jr		nz, edge_border_table
		ld		a, e
		add		a, 3
		ld		e, a
edge_border_table:
		ld		hl, edge_border_lines
		add		hl, de
		ld		a, [hl]
edge_set_y:
		ld		[edge_y], a
		ld		a, [edge_offset]
		ld		e, a
		ld		d, 0
		ld		hl, edge_offsets
		add		hl, de
		ld		a, [hl]
		ld		[edge_r23], a
		ld		b, 23
		call	wreg
		ld		a, [edge_ilns]
		or		a, a
		ld		a, [edge_y]
		jr		nz, edge_set_r19
		ld		b, a
		ld		a, [edge_r23]
		add		a, b
edge_set_r19:
		ld		[edge_r19], a
		ld		b, 19
		call	wreg
		call	edge_panel_address
		call	edge_write_panel
		call	edge_write_values
		xor		a, a
		ld		[edge_phase], a
		ld		[edge_done], a
		ld		[edge_sample], a
		ld		hl, 0
		ld		[edge_hits], hl
		call	rstat
		ld		a, 1
		call	rstat
		ld		a, 4
		ld		b, 7
		call	wreg
		ld		a, 0x16
		ld		b, 0
		call	wreg
		ld		a, 0x60
		ld		b, 1
		call	wreg
		ei
edge_wait:
		call	get_key
		or		a, a
		jr		nz, edge_exit
		ld		a, [edge_failed]
		or		a, a
		jr		nz, edge_wait
		ld		a, [edge_sample]
		or		a, a
		call	nz, edge_sample_window
		ld		a, [edge_done]
		or		a, a
		jr		z, edge_wait
		ld		a, [edge_case]
		inc		a
		cp		a, 20
		jr		c, edge_next_case
		xor		a, a
		ld		[edge_case], a
		ld		a, [edge_offset]
		inc		a
		cp		a, 5
		jr		c, edge_next_offset
		xor		a, a
edge_next_offset:
		ld		[edge_offset], a
		jp		edge_setup
edge_next_case:
		ld		[edge_case], a
		jp		edge_setup
edge_exit:
		ld		[action], a
		di
		xor		a, a
		ld		[vv_ready], a
		ld		a, 0x06
		ld		b, 0
		call	wreg
		ld		a, 0x40
		ld		b, 1
		call	wreg
		ld		a, 1
		call	rstat
		xor		a, a
		call	rstat
		ld		hl, [saved_38]
		ld		[0x0038], hl
		ld		a, [saved_38 + 2]
		ld		[0x003A], a
		ret

; At 60 Hz on a 3.58 MHz Z80, sample after all tested bottom-border lines
; and before the next top-border line. Leave IRQs enabled during the delay.
edge_sample_window:
		ld		c, 4
edge_sample_outer:
		ld		b, 150
edge_sample_delay:
		djnz	edge_sample_delay
		dec		c
		jr		nz, edge_sample_outer
edge_sample_lock:
		di
		ld		a, [edge_sample]
		ld		b, a
		xor		a, a
		ld		[edge_sample], a
		ld		a, b
		cp		a, 2
		jr		z, edge_reset_hits
		ld		hl, [edge_hits]
		ld		a, h
		or		a, a
		jr		nz, edge_miss
		ld		a, l
		cp		a, 64
		jr		nz, edge_miss
		ld		a, [edge_failed]
		or		a, a
		jr		nz, edge_sample_end
		ld		a, 1
		ld		[edge_done], a
		jr		edge_sample_end
edge_miss:
		ld		a, 1
		ld		[edge_failed], a
		ld		a, 8
		ld		b, 7
		call	wreg
		call	edge_write_count
		jr		edge_sample_end
edge_reset_hits:
		ld		hl, 0
		ld		[edge_hits], hl
edge_sample_end:
		ei
		ret

edge_isr:
		push	af
		push	bc
		push	hl
		ld		a, 1
		call	rstat
		and		a, 1
		ld		[edge_fh], a
		jr		z, edge_read_frame
		ld		hl, [edge_hits]
		inc		hl
		ld		[edge_hits], hl
edge_read_frame:
		xor		a, a
		call	rstat
		bit		7, a
		jr		z, edge_line_colour
		ld		a, [edge_phase]
		inc		a
		ld		[edge_phase], a
		cp		a, 2
		jr		z, edge_request_sample
		cp		a, 66
		jr		nz, edge_frame_colour
edge_request_sample:
		ld		[edge_sample], a
edge_frame_colour:
		ld		a, 4
		ld		b, 7
		call	wreg
edge_line_colour:
		ld		a, [edge_fh]
		or		a, a
		jr		z, edge_failure_colour
		ld		a, 2
		ld		b, 7
		call	wreg
edge_failure_colour:
		ld		a, [edge_failed]
		or		a, a
		jr		z, edge_isr_end
		ld		a, 8
		ld		b, 7
		call	wreg
edge_isr_end:
		pop		hl
		pop		bc
		pop		af
		ei
		ret

; The panel follows the R#23 ring, so its labels stay at screen Y=80.
edge_panel_address:
		ld		a, [edge_r23]
		add		a, 80
		ld		h, a
		ld		l, 0
		srl		h
		rr		l
		ld		de, 32
		add		hl, de
		ld		[edge_addr], hl
		ret

; BC = CPU-view write address, preserved.
edge_vram_address:
		ld		a, b
		rlca
		rlca
		and		a, 3
		out		[VDP_CTRL], a
		ld		a, 0x8E
		out		[VDP_CTRL], a
		ld		a, c
		out		[VDP_CTRL], a
		ld		a, b
		and		a, 0x3F
		or		a, 0x40
		out		[VDP_CTRL], a
		ret

edge_erase_panel:
		ld		bc, [edge_addr]
		ld		d, 14
edge_erase_row:
		call	edge_vram_address
		ld		e, 64
		ld		a, 0x11
edge_erase_byte:
		out		[VDP_DATA], a
		dec		e
		jr		nz, edge_erase_byte
		call	edge_next_row
		dec		d
		jr		nz, edge_erase_row
		ret

edge_write_panel:
		ld		hl, [edge_panel]
		ld		bc, [edge_addr]
		ld		d, 14
edge_panel_row:
		call	edge_vram_address
		ld		e, 64
edge_panel_byte:
		ld		a, [hl]
		inc		hl
		out		[VDP_DATA], a
		dec		e
		jr		nz, edge_panel_byte
		call	edge_next_row
		dec		d
		jr		nz, edge_panel_row
		ret

edge_next_row:
		ld		a, c
		add		a, 128
		ld		c, a
		ret		nc
		inc		b
		ret

edge_write_values:
		ld		hl, [edge_addr]
		ld		de, 7 * 128 + 6
		add		hl, de
		ld		[edge_addr], hl
		ld		hl, edge_y
		ld		d, 3
edge_value:
		ld		a, [hl]
		push	hl
		push	de
		push	af
		rrca
		rrca
		rrca
		rrca
		call	edge_hex_digit
		ld		hl, [edge_addr]
		inc		hl
		inc		hl
		inc		hl
		ld		[edge_addr], hl
		pop		af
		call	edge_hex_digit
		ld		hl, [edge_addr]
		ld		de, 18
		add		hl, de
		ld		[edge_addr], hl
		pop		de
		pop		hl
		inc		hl
		dec		d
		jr		nz, edge_value
		ret

; Show the first failed sample as four hexadecimal digits.
edge_write_count:
		call	edge_panel_address
		ld		hl, [edge_addr]
		ld		de, 39
		add		hl, de
		ld		[edge_addr], hl
		ld		a, [edge_hits + 1]
		call	edge_count_byte
		ld		a, [edge_hits]
		call	edge_count_byte
		ret

edge_count_byte:
		push	af
		rrca
		rrca
		rrca
		rrca
		call	edge_hex_digit
		call	edge_count_next
		pop		af
		call	edge_hex_digit
edge_count_next:
		ld		hl, [edge_addr]
		inc		hl
		inc		hl
		inc		hl
		ld		[edge_addr], hl
		ret

edge_hex_digit:
		and		a, 15
		ld		l, a
		ld		h, 0
		add		hl, hl
		add		hl, hl
		ld		e, a
		ld		d, 0
		add		hl, de
		add		hl, hl
		add		hl, hl
		add		hl, de			; 21 bytes per digit
		ld		de, edge_hex_font
		add		hl, de
		ld		bc, [edge_addr]
		ld		d, 7
edge_digit_row:
		call	edge_vram_address
		ld		e, 3
edge_digit_byte:
		ld		a, [hl]
		inc		hl
		out		[VDP_DATA], a
		dec		e
		jr		nz, edge_digit_byte
		call	edge_next_row
		dec		d
		jr		nz, edge_digit_row
		ret

edge_offsets:
		db		0, 1, 64, 200, 255
edge_border_lines:
		db		208, 216, 223		; 192 lines: NTSC frame ends before screen Y=230
		db		223, 230, 234		; 212 lines
		endif

;	{n, pairs} at VR rise, {n, pairs} at VR fall, count, {hr, n, pairs} ...
op_poll:
		ld		[poll_rise], hl
		call	skip_pairs
		ld		[poll_fall], hl
		call	skip_pairs
		ld		a, [hl]
		inc		hl
		ld		[poll_count], a
		ld		[poll_ent], hl
		ld		a, 2
		ld		b, 15
		call	wreg
		ld		a, 1
		ld		[vv_ready], a
poll_frame:
		in		a, [VDP_CTRL]
		and		a, 0x40
		jr		z, poll_frame
		ld		hl, [poll_rise]
		call	out_pairs
poll_vr_fall:
		in		a, [VDP_CTRL]
		and		a, 0x40
		jr		nz, poll_vr_fall
		ld		hl, [poll_fall]
		call	out_pairs
		ld		hl, [poll_ent]
		ld		a, [poll_count]
		ld		d, a
poll_entry:
		ld		a, d
		or		a, a
		jr		z, poll_key
		ld		e, [hl]
		inc		hl
poll_hr_low:
		in		a, [VDP_CTRL]
		and		a, 0x20
		jr		nz, poll_hr_low
poll_hr_high:
		in		a, [VDP_CTRL]
		and		a, 0x20
		jr		z, poll_hr_high
		dec		e
		jr		nz, poll_hr_low
		call	out_pairs
		dec		d
		jr		poll_entry
poll_key:
		call	get_key
		or		a, a
		jr		z, poll_frame
		ld		[action], a
		xor		a, a
		ld		[vv_ready], a
		xor		a, a
		ld		b, 15
		jp		wreg

skip_pairs:
		ld		e, [hl]
		inc		hl
		ld		d, 0
		add		hl, de
		ret

out_pairs:
		ld		b, [hl]
		inc		hl
		ld		a, b
		or		a, a
		ret		z
		ld		c, VDP_CTRL
		otir
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
		in		a, [VDP_P4]
		and		a, 0x78
		ret		nz
		xor		a, a
		out		[VDP_P4], a
		in		a, [VDP_P4]
		and		a, 0x80
		jr		nz, detect_relock
		xor		a, a
		ld		b, 21
		call	wreg
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
		call	wreg
detect_relock:
		ld		a, 0x80
		out		[VDP_P4], a
		ret

; -----------------------------------------------------------------------------
;	back to the DOS text screen
; -----------------------------------------------------------------------------
restore_screen:
		di
		xor		a, a
		ld		b, 1
		call	wreg
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
restore_reg:
		ld		b, [hl]
		inc		hl
		ld		a, b
		cp		a, 0xFF
		jr		z, restore_bios
		ld		a, [hl]
		inc		hl
		call	wreg
		jr		restore_reg
restore_bios:
		ld		a, [RG8SAV]
		ld		b, 8
		call	wreg
		ld		a, [RG9SAV]
		ld		b, 9
		call	wreg
		ld		a, [SCRMOD]
		ld		iy, [EXPTBL_M1]
		ld		ix, CHGMOD
		call	CALSLT
		di
		ld		iy, [EXBRSA_M1]
		ld		ix, INIPLT
		call	CALSLT
		ret

restore_regs:
		db		0, 0
		db		15, 0
		db		19, 0
		db		23, 0
		db		25, 0
		db		26, 0
		db		27, 0
		db		45, 0
		db		0xFF

puts:
		ld		c, _PUTS
		jp		BDOS

; -----------------------------------------------------------------------------
;	messages
; -----------------------------------------------------------------------------
msg_banner:
		if		EDGE_TEST
		db		"VDPINT - VDP line IRQ check", 0x0D, 0x0A
		else
		db		"VDPVIEW - VDP visual check", 0x0D, 0x0A
		endif
		db		"SPACE/RET/RIGHT:next  BS/LEFT:back  ESC:quit", 0x0D, 0x0A, "$"
msg_v9938:
		db		"V9938 detected. V9958 or V9968 is required.", 0x0D, 0x0A, "$"
msg_end:
		if		EDGE_TEST
		db		"VDPINT END", 0x0D, 0x0A, "$"
		else
		db		"VDPVIEW END", 0x0D, 0x0A, "$"
		endif
msg_tpa:
		db		"Not enough TPA.", 0x0D, 0x0A, "$"

; -----------------------------------------------------------------------------
;	work area
; -----------------------------------------------------------------------------
cur::		db		0
action::	db		0
vdp_id::	db		0
is_v9968::	db		0
is_turbo_r::	db		0
saved_cpu::	db		0
line_r0::	db		0
lstart::	dw		0
lptr::		dw		0
saved_38::	db		0, 0, 0
poll_rise::	dw		0
poll_fall::	dw		0
poll_ent::	dw		0
poll_count::	db		0
		if		EDGE_TEST
edge_lines::	db		0
edge_ilns::	db		0
edge_panel::	dw		0
edge_y::	db		0
edge_r23::	db		0
edge_r19::	db		0
edge_case::	db		0
edge_offset::	db		0
edge_phase::	db		0
edge_hits::	dw		0
edge_failed::	db		0
edge_done::	db		0
edge_sample::	db		0
edge_fh::	db		0
edge_addr::	dw		0
		include	"VDPINT.INC"
		else
		include	"VDPVIEW.INC"
		endif
program_end::
