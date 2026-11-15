; Included in the diagnostic build of VDPVIEW.ASM.

DIAG_P06	:= 5
DIAG_P11	:= 10

diag_run:
		call	diag_select
		ret		nz
		call	diag_release
		ret		nz
diag_trial:
		ld		a, [diag_count]
		add		a, 1
		daa
		ld		[diag_count], a
		ld		a, [diag_count + 1]
		adc		a, 0
		daa
		ld		[diag_count + 1], a
		call	diag_format_count
		xor		a, a
		ld		[diag_phase], a
		ld		a, [diag_first]
		ld		[cur], a
		call	run_page
		ld		a, [action]
		cp		a, ACT_QUIT
		ret		z
		call	diag_release
		ret		nz
		ld		a, 1
		ld		[diag_phase], a
		ld		a, [diag_first]
		inc		a
		ld		[cur], a
		call	run_page
		ld		a, [action]
		cp		a, ACT_QUIT
		ret		z
		call	diag_release
		ret		nz
		ld		hl, [diag_count]
		ld		[diag_completed], hl
		ld		a, h
		cp		a, 0x10
		jr		nz, diag_trial
		ld		a, l
		or		a, a
		jr		nz, diag_trial
		ld		a, 1
		ld		[diag_finished], a
		ret

diag_select:
		ld		c, 1
		call	BDOS
		cp		a, 0x1B
		jr		z, diag_cancel_select
		cp		a, 0x31
		jr		z, diag_select_11
		cp		a, 0x32
		jr		z, diag_select_06
		ld		de, diag_msg_select
		call	puts
		jr		diag_select
diag_select_11:
		ld		a, DIAG_P11
		jr		diag_selected
diag_select_06:
		ld		a, DIAG_P06
diag_selected:
		ld		[diag_first], a
		xor		a, a
		ret
diag_cancel_select:
		ld		a, 1
		ld		[diag_cancel], a
		or		a, a
		ret

; Like wait_release, but ESC can stop the test during the release interval.
diag_release:
		ld		de, 0x0800
diag_release_loop:
		call	get_key
		cp		a, ACT_QUIT
		jr		z, diag_release_cancel
		or		a, a
		jr		nz, diag_release
		dec		de
		ld		a, d
		or		a, e
		jr		nz, diag_release_loop
		xor		a, a
		ret
diag_release_cancel:
		ld		a, 1
		ld		[diag_cancel], a
		or		a, a
		ret

; Keep the keyboard polling and line-interrupt cleanup of the original pages.
diag_wait_action:
		ld		a, 1
		ld		[vv_ready], a
		push	de
		; An 8-bit LFSR varies the dwell without reading VDP status.
		ld		a, [diag_seed]
		srl		a
		jr		nc, diag_seed_ready
		xor		a, 0xB8
diag_seed_ready:
		ld		[diag_seed], a
		ld		e, a
		and		a, 7
		add		a, 4
		ld		d, a
diag_wait_loop:
		call	get_key
		cp		a, ACT_QUIT
		jr		z, diag_wait_cancel
		dec		de
		ld		a, d
		or		a, e
		jr		nz, diag_wait_loop
		ld		a, ACT_NEXT
		jr		diag_wait_done
diag_wait_cancel:
		ld		a, 1
		ld		[diag_cancel], a
		ld		a, ACT_QUIT
diag_wait_done:
		ld		[action], a
		xor		a, a
		ld		[vv_ready], a
		pop		de
		ret

diag_mark:
		ld		[diag_stage], a
		ld		b, 7
		jp		wreg

; Replaces wreg. Keeps a copy of every value written through wreg until a
; failure is captured, plus the last 16 writes in order.
diag_wreg:
		push	hl
		push	de
		push	bc
		ld		d, a
		ld		a, [diag_freeze]
		or		a, a
		jr		nz, diag_wreg_out
		ld		a, b
		and		a, 0x3F
		ld		c, a
		ld		b, 0
		ld		hl, diag_regs
		add		hl, bc
		ld		[hl], d
		ld		hl, diag_reg_valid
		add		hl, bc
		ld		[hl], 1
		pop		bc
		push	bc
		ld		a, [diag_hist_pos]
		ld		e, a
		ld		hl, diag_hist
		push	de
		ld		d, 0
		add		hl, de
		pop		de
		ld		[hl], b
		inc		hl
		ld		[hl], d
		ld		a, e
		add		a, 2
		and		a, 0x1F
		ld		[diag_hist_pos], a
diag_wreg_out:
		ld		a, d
		pop		bc
		pop		de
		pop		hl
		out		[VDP_CTRL], a
		ld		a, b
		or		a, 0x80
		out		[VDP_CTRL], a
		ret

; Both callers of wait_ce enter with HL just past the command bytes sent with
; OTIR from R#17 upwards to R#46.
diag_wait_ce:
		push	bc
		push	de
		push	hl
		ld		[diag_cmd_end], hl
		ld		hl, 6
		add		hl, sp
		ld		e, [hl]
		inc		hl
		ld		d, [hl]
		ld		[diag_cmd_ret], de
		call	diag_capture_cmd
		pop		hl
		ld		a, 2
		ld		b, 15
		call	wreg
		ld		bc, 0
		ld		d, 16
diag_ce_loop:
		in		a, [VDP_CTRL]
		rrca
		jr		nc, diag_ce_done
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, diag_ce_loop
		dec		d
		jr		nz, diag_ce_loop
		jp		diag_fail
diag_ce_done:
		pop		de
		pop		bc
		xor		a, a
		ld		b, 15
		jp		wreg

diag_capture_cmd:
		ld		a, [diag_reg_valid + 17]
		or		a, a
		ret		z
		ld		a, [diag_regs + 17]
		cp		a, 47				; also rejects R#17 bit 7 (no increment)
		ret		nc
		ld		[diag_cmd_first], a
		ld		c, a
		ld		a, 47
		sub		a, c
		ld		e, a
		ld		d, 0
		ld		hl, [diag_cmd_end]
		or		a, a
		sbc		hl, de
		ld		[diag_cmd_src], hl
		push	de
		push	de
		push	hl
		ld		b, 0
		ld		hl, diag_regs
		add		hl, bc
		ex		de, hl
		pop		hl
		pop		bc
		ldir
		ld		a, [diag_cmd_first]
		ld		c, a
		ld		b, 0
		ld		hl, diag_reg_valid
		add		hl, bc
		pop		bc
		ld		b, c
diag_capture_cmd_valid:
		ld		[hl], 1
		inc		hl
		djnz	diag_capture_cmd_valid
		ret

; CE stayed 1. Record the state first, then probe it, then show it as text.
diag_fail:
		di
		ld		a, 1
		ld		[diag_freeze], a
		; S#2 is still selected: raw reads before any further VDP write.
		ld		hl, diag_s2_now
		ld		b, 16
diag_fail_now:
		in		a, [VDP_CTRL]
		ld		[hl], a
		inc		hl
		djnz	diag_fail_now
		ld		bc, 0xFFFF
		ld		hl, 0x00FF			; H = OR, L = AND
		ld		ix, 0
diag_fail_acc:
		in		a, [VDP_CTRL]
		ld		e, a
		and		a, l
		ld		l, a
		ld		a, e
		or		a, h
		ld		h, a
		bit		0, e
		jr		nz, diag_fail_acc_ce
		inc		ix
diag_fail_acc_ce:
		dec		bc
		ld		a, b
		or		a, c
		jr		nz, diag_fail_acc
		ld		[diag_s2_acc], hl
		ld		[diag_s2_ce0], ix
		ld		a, 2
		ld		b, 15
		call	wreg
		ld		hl, diag_s2_sel
		ld		b, 8
diag_fail_sel:
		in		a, [VDP_CTRL]
		ld		[hl], a
		inc		hl
		djnz	diag_fail_sel
		ld		hl, diag_status
		ld		c, 0
diag_fail_stat:
		ld		a, c
		push	bc
		push	hl
		call	rstat
		pop		hl
		pop		bc
		ld		[hl], a
		inc		hl
		inc		c
		ld		a, c
		cp		a, 16
		jr		nz, diag_fail_stat
		in		a, [VDP_P4]
		ld		[diag_p4], a
		ld		hl, [0x0038]
		ld		[diag_v38], hl
		ld		a, [0x003A]
		ld		[diag_v38 + 2], a
		; The border colour shows the step if the CPU stops here.
		ld		a, 0x0C
		ld		b, 7
		call	wreg
		xor		a, a
		ld		b, 46
		call	wreg				; STOP
		call	diag_poll_ce
		ld		[diag_stop_poll], hl
		ld		[diag_stop_s2], a
		ld		a, 0x0E
		ld		b, 7
		call	wreg
		call	diag_scan_vram
		ld		a, 0x0F
		ld		b, 7
		call	wreg
		ld		a, 36
		ld		b, 17
		call	wreg
		ld		hl, diag_cmd_retry
		ld		bc, 0x0B00 | VDP_IND
		otir
		call	diag_poll_ce
		ld		[diag_retry_poll], hl
		ld		[diag_retry_s2], a
		ld		a, 7
		ld		b, 14
		call	wreg
		ld		a, 0x80
		out		[VDP_CTRL], a
		ld		a, 0x3F
		out		[VDP_CTRL], a		; read 1FF80h = (0,1023)
		nop
		nop
		in		a, [VDP_DATA]
		ld		[diag_retry_vram], a
		ld		hl, [0x0039]
		ld		de, line_isr
		or		a, a
		sbc		hl, de
		jr		nz, diag_fail_text
		ld		hl, [saved_38]
		ld		[0x0038], hl
		ld		a, [saved_38 + 2]
		ld		[0x003A], a
diag_fail_text:
		call	restore_screen
		ei
		call	turbo_r_restore
		call	diag_build
		call	diag_show
		call	diag_save
		jp		exit_dos

;	HL = reads before CE=0 (FFFFh = still 1), A = last S#2, R#15 back to 0
diag_poll_ce:
		ld		a, 2
		ld		b, 15
		call	wreg
		ld		hl, 0
diag_poll_ce_loop:
		in		a, [VDP_CTRL]
		ld		e, a
		rrca
		jr		nc, diag_poll_ce_done
		inc		hl
		ld		a, h
		and		a, l
		inc		a
		jr		nz, diag_poll_ce_loop
diag_poll_ce_done:
		push	de
		xor		a, a
		ld		b, 15
		call	wreg
		pop		de
		ld		a, e
		ret

; For each 64KB half: first and last non-zero byte address and their count.
; HMMV of the first clear writes 00000h-0FFFFh in address order.
diag_scan_vram:
		ld		hl, diag_vram_res
		ld		b, 18
diag_scan_init:
		ld		[hl], 0xFF
		inc		hl
		djnz	diag_scan_init
		xor		a, a
		ld		[diag_vram_res + 6], a
		ld		[diag_vram_res + 7], a
		ld		[diag_vram_res + 8], a
		ld		[diag_vram_res + 15], a
		ld		[diag_vram_res + 16], a
		ld		[diag_vram_res + 17], a
		ld		[diag_scan_block], a
diag_scan_block_loop:
		ld		a, [diag_scan_block]
		ld		b, 14
		call	wreg
		xor		a, a
		out		[VDP_CTRL], a
		out		[VDP_CTRL], a
		ld		de, 0
diag_scan_byte:
		in		a, [VDP_DATA]
		or		a, a
		call	nz, diag_scan_hit
		inc		de
		ld		a, d
		cp		a, 0x40
		jr		nz, diag_scan_byte
		ld		a, [diag_scan_block]
		inc		a
		ld		[diag_scan_block], a
		cp		a, 8
		jr		nz, diag_scan_block_loop
		ret

;	DE = offset in the 16KB block -> entry {first[3], last[3], count[3]}
diag_scan_hit:
		push	hl
		push	bc
		ld		a, [diag_scan_block]
		ld		c, a
		and		a, 3
		rrca
		rrca
		or		a, d
		ld		b, a				; A15-A8
		srl		c
		srl		c					; A16
		ld		hl, diag_vram_res
		ld		a, c
		or		a, a
		jr		z, diag_scan_hit_entry
		push	de
		ld		de, 9
		add		hl, de
		pop		de
diag_scan_hit_entry:
		inc		hl
		inc		hl
		ld		a, [hl]
		dec		hl
		dec		hl
		inc		a
		jr		nz, diag_scan_hit_last
		ld		[hl], e
		inc		hl
		ld		[hl], b
		inc		hl
		ld		[hl], c
		dec		hl
		dec		hl
diag_scan_hit_last:
		inc		hl
		inc		hl
		inc		hl
		ld		[hl], e
		inc		hl
		ld		[hl], b
		inc		hl
		ld		[hl], c
		inc		hl
		inc		[hl]
		jr		nz, diag_scan_hit_end
		inc		hl
		inc		[hl]
		jr		nz, diag_scan_hit_end
		inc		hl
		inc		[hl]
diag_scan_hit_end:
		pop		bc
		pop		hl
		ret

; --- report text ---------------------------------------------------------------
diag_putc:
		push	hl
		ld		hl, [diag_buf_ptr]
		ld		[hl], a
		inc		hl
		ld		[diag_buf_ptr], hl
		pop		hl
		ret

;	text follows the call, terminated by 0
diag_text:
		ex		[sp], hl
		call	diag_puts0
		ex		[sp], hl
		ret

diag_puts0:
		ld		a, [hl]
		inc		hl
		or		a, a
		ret		z
		call	diag_putc
		jr		diag_puts0

diag_crlf:
		ld		a, 0x0D
		call	diag_putc
		ld		a, 0x0A
		jr		diag_putc

diag_hex16:
		ld		a, h
		call	diag_hex8
		ld		a, l
diag_hex8:
		push	af
		rrca
		rrca
		rrca
		rrca
		call	diag_nibble
		pop		af
diag_nibble:
		and		a, 0x0F
		add		a, 0x90
		daa
		adc		a, 0x40
		daa
		jr		diag_putc

;	HL = bytes, B = count
diag_hex_list:
		ld		a, 0x20
		call	diag_putc
		ld		a, [hl]
		inc		hl
		call	diag_hex8
		djnz	diag_hex_list
		ret

;	A = 0-99
diag_dec2:
		push	bc
		ld		c, 0x30
diag_dec2_tens:
		cp		a, 10
		jr		c, diag_dec2_out
		sub		a, 10
		inc		c
		jr		diag_dec2_tens
diag_dec2_out:
		push	af
		ld		a, c
		call	diag_putc
		pop		af
		add		a, 0x30
		pop		bc
		jr		diag_putc

;	HL = {low, middle, high}; high = FFh means none
diag_addr24:
		inc		hl
		inc		hl
		ld		a, [hl]
		cp		a, 0xFF
		jr		nz, diag_addr24_valid
		call	diag_text
		db		"-----", 0
		inc		hl
		ret
diag_addr24_valid:
		call	diag_nibble
		dec		hl
		ld		a, [hl]
		call	diag_hex8
		dec		hl
		ld		a, [hl]
		call	diag_hex8
		inc		hl
		inc		hl
		inc		hl
		ret

diag_vram_line:
		call	diag_text
		db		" F", 0
		call	diag_addr24
		call	diag_text
		db		" L", 0
		call	diag_addr24
		call	diag_text
		db		" N", 0
		inc		hl
		inc		hl
		ld		a, [hl]
		call	diag_hex8
		dec		hl
		ld		a, [hl]
		call	diag_hex8
		dec		hl
		ld		a, [hl]
		call	diag_hex8
		jp		diag_crlf

diag_build:
		ld		hl, diag_buf
		ld		[diag_buf_ptr], hl
		call	diag_text
		db		0x0D, 0x0A, "VDPDIAG CE TIMEOUT", 0x0D, 0x0A
		db		"TRIAL ", 0
		ld		a, [diag_count + 1]
		call	diag_hex8
		ld		a, [diag_count]
		call	diag_hex8
		call	diag_text
		db		" PHASE ", 0
		ld		a, [diag_phase]
		add		a, 0x41
		call	diag_putc
		call	diag_text
		db		" P", 0
		ld		a, [cur]
		inc		a
		call	diag_dec2
		call	diag_text
		db		0x0D, 0x0A, "STAGE ", 0
		ld		a, [diag_stage]
		call	diag_hex8
		call	diag_text
		db		" CALLER ", 0
		ld		hl, [diag_cmd_ret]
		call	diag_hex16
		call	diag_text
		db		0x0D, 0x0A, "CMD R#", 0
		ld		a, [diag_cmd_first]
		call	diag_dec2
		call	diag_text
		db		"-46 SRC ", 0
		ld		hl, [diag_cmd_src]
		call	diag_hex16
		call	diag_text
		db		0x0D, 0x0A, "S2: ", 0
		ld		hl, diag_s2_now
		ld		b, 8
		call	diag_hex_list
		call	diag_text
		db		0x0D, 0x0A, "    ", 0
		ld		b, 8
		call	diag_hex_list
		call	diag_text
		db		0x0D, 0x0A, "S2 AND ", 0
		ld		a, [diag_s2_acc]
		call	diag_hex8
		call	diag_text
		db		" OR ", 0
		ld		a, [diag_s2_acc + 1]
		call	diag_hex8
		call	diag_text
		db		" CE0 ", 0
		ld		hl, [diag_s2_ce0]
		call	diag_hex16
		call	diag_text
		db		0x0D, 0x0A, "S2R:", 0
		ld		hl, diag_s2_sel
		ld		b, 8
		call	diag_hex_list
		call	diag_text
		db		0x0D, 0x0A, "S00:", 0
		ld		hl, diag_status
		ld		b, 8
		call	diag_hex_list
		call	diag_text
		db		0x0D, 0x0A, "S08:", 0
		ld		b, 8
		call	diag_hex_list
		call	diag_text
		db		0x0D, 0x0A, "P4 ", 0
		ld		a, [diag_p4]
		call	diag_hex8
		call	diag_text
		db		" V9968 ", 0
		ld		a, [is_v9968]
		call	diag_hex8
		call	diag_text
		db		" ID ", 0
		ld		a, [vdp_id]
		call	diag_hex8
		call	diag_text
		db		0x0D, 0x0A, "INT38", 0
		ld		hl, diag_v38
		ld		b, 3
		call	diag_hex_list
		call	diag_text
		db		0x0D, 0x0A, "STOP CE0 AFTER ", 0
		ld		hl, [diag_stop_poll]
		call	diag_hex16
		call	diag_text
		db		" S2 ", 0
		ld		a, [diag_stop_s2]
		call	diag_hex8
		call	diag_text
		db		0x0D, 0x0A, "VRAM0", 0
		ld		hl, diag_vram_res
		call	diag_vram_line
		call	diag_text
		db		"VRAM1", 0
		ld		hl, diag_vram_res + 9
		call	diag_vram_line
		call	diag_text
		db		"RETRY ", 0
		ld		hl, [diag_retry_poll]
		call	diag_hex16
		call	diag_text
		db		" S2 ", 0
		ld		a, [diag_retry_s2]
		call	diag_hex8
		call	diag_text
		db		" VRAM ", 0
		ld		a, [diag_retry_vram]
		call	diag_hex8
		call	diag_crlf
		ld		c, 0
diag_build_reg_line:
		ld		a, 0x52
		call	diag_putc
		ld		a, c
		call	diag_dec2
		ld		a, 0x3A
		call	diag_putc
		ld		b, 8
diag_build_reg:
		push	bc
		ld		b, 0
		ld		hl, diag_reg_valid
		add		hl, bc
		ld		a, [hl]
		or		a, a
		jr		nz, diag_build_reg_valid
		call	diag_text
		db		" --", 0
		jr		diag_build_reg_next
diag_build_reg_valid:
		ld		hl, diag_regs
		add		hl, bc
		ld		b, 1
		call	diag_hex_list
diag_build_reg_next:
		pop		bc
		inc		c
		djnz	diag_build_reg
		call	diag_crlf
		ld		a, c
		cp		a, 64
		jr		nz, diag_build_reg_line
		call	diag_text
		db		"WREG OLD->NEW REG=VAL", 0x0D, 0x0A, 0
		ld		a, [diag_hist_pos]
		ld		c, a
		ld		b, 16
		ld		d, 0
diag_build_hist:
		push	bc
		ld		b, 0
		ld		hl, diag_hist
		add		hl, bc
		ld		a, [hl]
		cp		a, 0xFF
		jr		z, diag_build_hist_next
		ld		a, 0x20
		call	diag_putc
		ld		a, [hl]
		inc		hl
		call	diag_dec2
		ld		a, 0x3D
		call	diag_putc
		ld		a, [hl]
		call	diag_hex8
		inc		d
		ld		a, d
		cp		a, 4
		jr		nz, diag_build_hist_next
		ld		d, 0
		call	diag_crlf
diag_build_hist_next:
		pop		bc
		ld		a, c
		add		a, 2
		and		a, 0x1F
		ld		c, a
		djnz	diag_build_hist
		ld		a, d
		or		a, a
		call	nz, diag_crlf
		call	diag_text
		db		"LINE LPTR ", 0
		ld		hl, [lptr]
		call	diag_hex16
		call	diag_text
		db		" LSTART ", 0
		ld		hl, [lstart]
		call	diag_hex16
		jp		diag_crlf

;	DOS console output with a pause every 22 lines
diag_show:
		ld		c, 0x06
		ld		e, 0xFF
		call	BDOS
		or		a, a
		jr		nz, diag_show
		ld		hl, diag_buf
		ld		d, 0
diag_show_loop:
		ld		bc, [diag_buf_ptr]
		ld		a, l
		cp		a, c
		jr		nz, diag_show_char
		ld		a, h
		cp		a, b
		ret		z
diag_show_char:
		ld		a, [hl]
		inc		hl
		push	hl
		push	de
		ld		e, a
		ld		c, 0x02
		call	BDOS
		pop		de
		pop		hl
		dec		hl
		ld		a, [hl]
		inc		hl
		cp		a, 0x0A
		jr		nz, diag_show_loop
		inc		d
		ld		a, d
		cp		a, 22
		jr		nz, diag_show_loop
		ld		d, 0
		push	hl
		push	de
		ld		de, diag_msg_more
		call	puts
		ld		c, 0x08
		call	BDOS
		ld		de, diag_msg_crlf
		call	puts
		pop		de
		pop		hl
		jr		diag_show_loop

;	The same text to VDPDIAG.LOG in the current drive (FCB, DOS1 compatible).
diag_save:
		ld		de, diag_buf
diag_save_pad:
		ld		hl, [diag_buf_ptr]
		ld		a, l
		sub		a, e
		and		a, 0x7F
		jr		z, diag_save_padded
		ld		[hl], 0x1A
		inc		hl
		ld		[diag_buf_ptr], hl
		jr		diag_save_pad
diag_save_padded:
		ld		hl, diag_fcb + 12
		ld		b, 37 - 12
diag_save_clear:
		ld		[hl], 0
		inc		hl
		djnz	diag_save_clear
		ld		de, diag_fcb
		ld		c, 0x16
		call	BDOS
		or		a, a
		jr		nz, diag_save_error
		ld		hl, diag_buf
diag_save_record:
		push	hl
		ex		de, hl
		ld		c, 0x1A
		call	BDOS
		ld		de, diag_fcb
		ld		c, 0x15
		call	BDOS
		pop		hl
		or		a, a
		jr		nz, diag_save_close_error
		ld		de, 128
		add		hl, de
		ld		de, [diag_buf_ptr]
		ld		a, l
		cp		a, e
		jr		nz, diag_save_record
		ld		a, h
		cp		a, d
		jr		nz, diag_save_record
		ld		de, diag_fcb
		ld		c, 0x10
		call	BDOS
		or		a, a
		jr		nz, diag_save_error
		ld		de, diag_msg_saved
		jp		puts
diag_save_close_error:
		ld		de, diag_fcb
		ld		c, 0x10
		call	BDOS
diag_save_error:
		ld		de, diag_msg_save_error
		jp		puts

; Packed BCD count to glyph indices, with leading zeroes.
diag_format_count:
		ld		a, [diag_count + 1]
		rrca
		rrca
		rrca
		rrca
		and		a, 0x0F
		ld		[diag_digits + 1], a
		ld		a, [diag_count + 1]
		and		a, 0x0F
		ld		[diag_digits + 2], a
		ld		a, [diag_count]
		rrca
		rrca
		rrca
		rrca
		and		a, 0x0F
		ld		[diag_digits + 3], a
		ld		a, [diag_count]
		and		a, 0x0F
		ld		[diag_digits + 4], a
		ret

; Draw A/B and the current trial number at x=16, y=0 in SCREEN 5 or 8.
diag_draw:
		push	af
		push	bc
		push	de
		push	hl
		ld		a, [diag_phase]
		add		a, 10
		ld		[diag_digits], a
		add		a, 6			; glyph A/B -> visible stage 16/17
		ld		[diag_stage], a
		xor		a, a
		ld		b, 14
		call	wreg
		ld		a, [cur]
		cp		a, DIAG_P06
		ld		hl, 0x0008
		jr		nz, diag_draw_address
		ld		hl, 0x0010
diag_draw_address:
		ld		[diag_vram_addr], hl
		xor		a, a
		ld		[diag_row], a
diag_draw_row:
		ld		hl, [diag_vram_addr]
		ld		a, l
		out		[VDP_CTRL], a
		ld		a, h
		or		a, 0x40
		out		[VDP_CTRL], a
		ld		hl, diag_digits
		ld		b, 5
diag_draw_char:
		ld		a, [hl]
		inc		hl
		push	hl
		push	bc
		add		a, a
		add		a, a
		add		a, a
		ld		e, a
		ld		a, [diag_row]
		add		a, e
		ld		e, a
		ld		d, 0
		ld		hl, diag_font
		add		hl, de
		ld		e, [hl]
		ld		a, [cur]
		cp		a, DIAG_P06
		jr		z, diag_draw_sc8
		ld		c, 3
diag_draw_sc5_pair:
		sla		e
		ld		a, 0x10
		jr		nc, diag_draw_sc5_high
		ld		a, 0xF0
diag_draw_sc5_high:
		sla		e
		jr		nc, diag_draw_sc5_low
		or		a, 0x0F
		jr		diag_draw_sc5_out
diag_draw_sc5_low:
		or		a, 0x01
diag_draw_sc5_out:
		out		[VDP_DATA], a
		dec		c
		jr		nz, diag_draw_sc5_pair
		jr		diag_draw_next_char
diag_draw_sc8:
		ld		c, 6
diag_draw_sc8_pixel:
		sla		e
		sbc		a, a
		out		[VDP_DATA], a
		dec		c
		jr		nz, diag_draw_sc8_pixel
diag_draw_next_char:
		pop		bc
		pop		hl
		djnz	diag_draw_char
		ld		hl, [diag_vram_addr]
		ld		a, [cur]
		cp		a, DIAG_P06
		ld		de, 0x0080
		jr		nz, diag_draw_next_row
		ld		de, 0x0100
diag_draw_next_row:
		add		hl, de
		ld		[diag_vram_addr], hl
		ld		a, [diag_row]
		inc		a
		ld		[diag_row], a
		cp		a, 7
		jr		nz, diag_draw_row
		pop		hl
		pop		de
		pop		bc
		pop		af
		ret

diag_report:
		ld		hl, [diag_completed]
		ld		[diag_count], hl
		call	diag_format_count
		ld		hl, diag_digits + 1
		ld		de, diag_result_digits
		ld		b, 4
diag_report_digits:
		ld		a, [hl]
		add		a, 0x30
		ld		[de], a
		inc		hl
		inc		de
		djnz	diag_report_digits
		ld		de, diag_msg_complete
		ld		a, [diag_finished]
		or		a, a
		jr		nz, diag_report_result
		ld		de, diag_msg_stopped
		ld		a, [diag_cancel]
		or		a, a
		jr		nz, diag_report_result
		ld		de, diag_msg_error
diag_report_result:
		call	puts
		ld		de, diag_msg_count
		jp		puts

diag_msg_select:
		db		0x0D, 0x0A, "Select 1 or 2 (ESC quits): $"
diag_msg_complete:
		db		0x0D, 0x0A, "VDPDIAG COMPLETE: $"
diag_msg_stopped:
		db		0x0D, 0x0A, "VDPDIAG STOPPED: $"
diag_msg_error:
		db		0x0D, 0x0A, "VDPDIAG ERROR (unexpected page end): $"
diag_msg_count:
diag_result_digits:
		db		"0000/1000 transitions", 0x0D, 0x0A, "$"

diag_msg_more:
		db		"-- HIT ANY KEY --$"
diag_msg_crlf:
		db		0x0D, 0x0A, "$"
diag_msg_saved:
		db		"Saved to VDPDIAG.LOG", 0x0D, 0x0A, "$"
diag_msg_save_error:
		db		"VDPDIAG.LOG write failed", 0x0D, 0x0A, "$"

diag_first:		db		0
diag_phase:		db		0
diag_stage:		db		0
diag_seed:		db		0xA5
diag_cancel:		db		0
diag_finished:	db		0
diag_count:		dw		0
diag_completed:	dw		0
diag_digits:		db		10, 0, 0, 0, 0
diag_vram_addr:	dw		0
diag_row:		db		0
diag_freeze:		db		0
diag_regs:		space	64
diag_reg_valid:	space	64
diag_hist:		db		0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0
				db		0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0, 0xFF, 0
diag_hist_pos:	db		0
diag_cmd_end:		dw		0
diag_cmd_src:		dw		0
diag_cmd_ret:		dw		0
diag_cmd_first:	db		0
diag_s2_now:		space	16
diag_s2_acc:		dw		0
diag_s2_ce0:		dw		0
diag_s2_sel:		space	8
diag_status:		space	16
diag_p4:			db		0
diag_v38:		db		0, 0, 0
diag_stop_poll:	dw		0
diag_stop_s2:		db		0
diag_scan_block:	db		0
diag_vram_res:	space	18
diag_retry_poll:	dw		0
diag_retry_s2:	db		0
diag_retry_vram:	db		0
diag_buf_ptr:		dw		0
; HMMV 1 byte 5Ah at (0,1023) to check that a new command completes.
diag_cmd_retry:
		db		0, 0, 0xFF, 0x03, 2, 0, 1, 0, 0x5A, 0, 0xC0
diag_fcb:
		db		0, "VDPDIAG LOG"
		space	25
diag_buf:		space	2048
