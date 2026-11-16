;=====================================================================
; vdpcom.inc - common framework for V9968 hardware check tools
;
; - V9968 detection (MSX-NOTE procedure): unlock LockExtReg via
;   Port#4 = 00h first, read S#1 ID, if ID=2 write R#21=0 (V58=0)
;   and read again; ID=3 means V9968. Tries 98h, then 88h.
; - Saves VRAM 0000h-3FFFh (16 KB) at start and restores it, the
;   default palette and the control registers (from the BIOS work
;   area register saves) before returning to DOS.
; - Text screens use Text1 (40 cols) with the bundled 8x8 font
;   (font.inc, glyphs in bits 7..2). PNT = 0000h, PGT = 0800h.
;
; Build: zma <name>.asm <NAME>.COM   (run in this directory)
;=====================================================================

BDOS    := 0x0005
RGNSAV  := 0xF3DF           ; BIOS saves of R#0..R#27

;---------------------------------------------------------------------
; variables
;---------------------------------------------------------------------
vdp_base:   db  0           ; 98h or 88h
vdp_data:   db  0           ; base + 0 (VRAM data)
vdp_ctrl:   db  0           ; base + 1 (command / status)
vdp_pal:    db  0           ; base + 2 (palette)
vdp_reg:    db  0           ; base + 3 (indirect register)
vdp_ext:    db  0           ; base + 4 (Port#4)
text_x:     db  0
text_y:     db  0
text_w:     db  40          ; text width (40 or 80)
text_addr:  dw  0           ; VRAM cursor address in name table

;---------------------------------------------------------------------
; vc_detect - find the V9968. CY=1: found (vdp_* set). CY=0: none.
;---------------------------------------------------------------------
vc_detect:
        ld      a, 0x98
        call    vc_try_base
        ret     c
        ld      a, 0x88
        call    vc_try_base
        ret

vc_try_base:
        ld      [vdp_base], a
        ld      [vdp_data], a
        inc     a
        ld      [vdp_ctrl], a
        inc     a
        ld      [vdp_pal], a
        inc     a
        ld      [vdp_reg], a
        inc     a
        ld      [vdp_ext], a
        ;--- unlock extended registers via Port#4 (base+4): write 00h
        ;    (LockExtReg = 0). On real V9968 silicon the lock is 1 at
        ;    reset and R#20/R#21 writes are ignored while locked.
        ;    Writing 00h clears no interrupt flags. Harmless on
        ;    V9938/V9958 (port base+4 is undecoded there).
        ld      a, [vdp_ext]
        ld      c, a
        xor     a, a
        out     [c], a
        call    vc_read_id
        cp      a, 3
        jr      z, vc_found
        cp      a, 2
        jr      nz, vc_try_notfound
        ld      d, 0            ; R#21 = 0 (V58 = 0, extended mode)
        ld      e, 21
        call    vc_wvreg
        call    vc_read_id
        cp      a, 3
        jr      nz, vc_try_notfound
vc_found:
        scf
        ret
vc_try_notfound:
        or      a, a            ; clear carry
        ret

;---------------------------------------------------------------------
; vc_read_id - return S#1 ID field (bits 5..1) in A. R#15 restored.
;---------------------------------------------------------------------
vc_read_id:
        ld      d, 1
        ld      e, 15
        call    vc_wvreg
        ld      a, [vdp_ctrl]
        ld      c, a
        in      a, [c]
        push    af
        ld      d, 0
        ld      e, 15
        call    vc_wvreg
        pop     af
        srl     a
        and     a, 0x1F
        ret

;---------------------------------------------------------------------
; vc_wvreg - write VDP register: D = value, E = register number
;---------------------------------------------------------------------
vc_wvreg:
        push    bc
        ld      a, [vdp_ctrl]
        ld      c, a
        out     [c], d
        ld      a, e
        or      a, 0x80
        out     [c], a
        pop     bc
        ret

;---------------------------------------------------------------------
; vc_set_regs - HL -> table of (value, reg) pairs, reg = 0xFF ends
;---------------------------------------------------------------------
vc_set_regs:
        ld      d, [hl]
        inc     hl
        ld      e, [hl]
        inc     hl
        ld      a, e
        cp      a, 0xFF
        ret     z
        call    vc_wvreg
        jr      vc_set_regs

;---------------------------------------------------------------------
; vc_read_status - D = status register number -> A = value.
; R#15 is restored to 0. Preserves BC, DE, HL.
;---------------------------------------------------------------------
vc_read_status:
        push    bc
        push    de
        push    hl
        ld      e, 15
        call    vc_wvreg        ; D = number -> R#15
        ld      a, [vdp_ctrl]
        ld      c, a
        in      a, [c]
        push    af
        ld      d, 0
        ld      e, 15
        call    vc_wvreg
        pop     af
        pop     hl
        pop     de
        pop     bc
        ret

;---------------------------------------------------------------------
; VRAM address setup. A = R#14 value (address bits 16..14),
; HL = address bits 15..0.
;---------------------------------------------------------------------
vc_vaddr_w:
        push    bc
        push    af
        ld      d, a
        ld      e, 14
        call    vc_wvreg
        pop     af
        ld      a, [vdp_ctrl]
        ld      c, a
        out     [c], l
        ld      a, h
        and     a, 0x3F
        or      a, 0x40
        out     [c], a
        pop     bc
        ret

; NOTE (measured on openMSX V9968 fork + BlueMSX+, 2026-11-16):
; the read address is set with bit 6 = 0 (write-mode setup). With
; bit 6 = 1 (read-mode setup) the first byte read back is the stale
; read-buffer content and the stream comes back rotated by one;
; with bit 6 = 0 the buffer is primed and both single reads and
; streams return the exact bytes. (Probe: TRD/TRD2 in the project
; work folder.)
vc_vaddr_r:
        push    bc
        push    af
        ld      d, a
        ld      e, 14
        call    vc_wvreg
        pop     af
        ld      a, [vdp_ctrl]
        ld      c, a
        out     [c], l
        ld      a, h
        and     a, 0x3F
        out     [c], a
        pop     bc
        ret

;---------------------------------------------------------------------
; vc_vram_out - copy BC bytes from RAM (HL) to VRAM.
; DE = VRAM address bits 15..0, A = address bits 16..14.
;---------------------------------------------------------------------
vc_vram_out:
        push    hl
        push    bc
        ld      h, d
        ld      l, e
        call    vc_vaddr_w
        pop     bc
        pop     hl
        push    de
        ld      d, b
        ld      e, c            ; DE = byte count (C stays the port)
        ld      a, [vdp_data]
        ld      c, a
vc_vram_out_loop:
        ld      a, [hl]
        out     [c], a
        inc     hl
        dec     de
        ld      a, d
        or      a, e
        jr      nz, vc_vram_out_loop
        pop     de
        ret

;---------------------------------------------------------------------
; vc_vram_in - copy BC bytes from VRAM to RAM (HL).
; DE = VRAM address bits 15..0, A = address bits 16..14.
;---------------------------------------------------------------------
vc_vram_in:
        push    hl
        push    bc
        ld      h, d
        ld      l, e
        call    vc_vaddr_r
        pop     bc
        pop     hl
        push    de
        ld      d, b
        ld      e, c            ; DE = byte count (C stays the port)
        ld      a, [vdp_data]
        ld      c, a
vc_vram_in_loop:
        in      a, [c]
        ld      [hl], a
        inc     hl
        dec     de
        ld      a, d
        or      a, e
        jr      nz, vc_vram_in_loop
        pop     de
        ret

;---------------------------------------------------------------------
; vc_vram_fill - fill BC bytes at VRAM with value L.
; DE = VRAM address bits 15..0, A = address bits 16..14.
;---------------------------------------------------------------------
vc_vram_fill:
        push    hl
        push    bc
        ld      h, d
        ld      l, e
        call    vc_vaddr_w
        pop     bc
        pop     hl
        push    de
        ld      d, b
        ld      e, c            ; DE = byte count (C stays the port)
        ld      a, [vdp_data]
        ld      c, a
vc_vram_fill_loop:
        out     [c], l
        dec     de
        ld      a, d
        or      a, e
        jr      nz, vc_vram_fill_loop
        pop     de
        ret

;---------------------------------------------------------------------
; vc_vram_read1 - read one VRAM byte. HL = address (17 bit: use
; vc_vram_read1x with A = bits 16..14). Returns A = byte.
;---------------------------------------------------------------------
vc_vram_read1:                  ; HL = address bits 15..0, A = 16..14
        push    bc
        push    hl
        call    vc_vaddr_r
        pop     hl
        ld      a, [vdp_data]
        ld      c, a
        in      a, [c]
        pop     bc
        ret

;---------------------------------------------------------------------
; vc_set_palette - HL -> 32 bytes (16 entries x 2). Sets R#16 = 0
; first, palette pointer auto-increments.
;---------------------------------------------------------------------
vc_set_palette:
        push    bc
        ld      d, 0
        ld      e, 16
        call    vc_wvreg
        ld      a, [vdp_pal]
        ld      c, a
        ld      b, 32
vc_set_palette_loop:
        ld      a, [hl]
        out     [c], a
        inc     hl
        djnz    vc_set_palette_loop
        pop     bc
        ret

vc_pal_default:
        db      0x00, 0x00      ; 0  (0,0,0)
        db      0x00, 0x00      ; 1  (0,0,0)
        db      0x11, 0x06      ; 2  (1,6,1)
        db      0x33, 0x07      ; 3  (3,7,3)
        db      0x17, 0x01      ; 4  (1,1,7)
        db      0x27, 0x03      ; 5  (2,3,7)
        db      0x51, 0x01      ; 6  (5,1,1)
        db      0x27, 0x06      ; 7  (2,6,7)
        db      0x71, 0x01      ; 8  (7,1,1)
        db      0x73, 0x03      ; 9  (7,3,3)
        db      0x61, 0x06      ; 10 (6,6,1)
        db      0x64, 0x06      ; 11 (6,6,4)
        db      0x11, 0x04      ; 12 (1,4,1)
        db      0x66, 0x02      ; 13 (6,2,6)
        db      0x55, 0x05      ; 14 (5,5,5)
        db      0x77, 0x07      ; 15 (7,7,7)

;---------------------------------------------------------------------
; vc_save_vram / vc_restore_vram - VRAM 0000h-3FFFh <-> vram_save
;---------------------------------------------------------------------
vc_save_vram:
        ld      hl, vram_save
        ld      de, 0
        ld      a, 0
        ld      bc, 16384
        jp      vc_vram_in

vc_restore_vram:
        ld      hl, vram_save
        ld      de, 0
        ld      a, 0
        ld      bc, 16384
        jp      vc_vram_out

;---------------------------------------------------------------------
; vc_wait_frames - wait B frames (polls S#2 VS bit; S#0 untouched)
;---------------------------------------------------------------------
vc_wait_frames:
        push    bc
vc_wf_cycle:
        ld      d, 2
        call    vc_read_status
        bit     6, a
        jr      z, vc_wf_cycle          ; wait VS = 1
vc_wf_cycle2:
        ld      d, 2
        call    vc_read_status
        bit     6, a
        jr      nz, vc_wf_cycle2        ; wait VS = 0
        djnz    vc_wf_cycle
        pop     bc
        ret

;---------------------------------------------------------------------
; vc_wait_key - flush keyboard, then wait for one key (BDOS).
;---------------------------------------------------------------------
vc_wait_key:
        push    bc
        push    de
        push    hl
vc_wk_release:                  ; wait until no key is down
        call    vc_key_any
        jr      nz, vc_wk_release
vc_wk_press:                    ; wait until a key goes down
        call    vc_key_any
        jr      z, vc_wk_press
        pop     hl
        pop     de
        pop     bc
        ret

; vc_key_any - NZ if any key is pressed (rows 0-10), Z if none.
; Polls the keyboard matrix via PPI ports A9h/AAh directly. BDOS
; console input cannot be used here: with IE0=0 the BIOS keyboard
; scan (driven by the VBLANK interrupt) stops, so BDOS would wait
; forever. The matrix poll works in any interrupt state.
vc_key_any:
        ld      b, 11           ; rows 0..10
        ld      d, 0            ; row number
vc_ka_row:
        in      a, [0xAA]
        and     a, 0xF0         ; keep PPI control bits
        or      a, d
        out     [0xAA], a
        in      a, [0xA9]
        cp      a, 0xFF
        jr      nz, vc_ka_hit
        inc     d
        djnz    vc_ka_row
        xor     a, a            ; Z: no key down
        ret
vc_ka_hit:
        or      a, 1            ; NZ: a key is down
        ret

;---------------------------------------------------------------------
; Text1 screen support (PNT = 0000h, PGT = 0800h, 40 x 24)
; Call vc_text1_begin with D = R#7 value (FG/BG) before printing.
;---------------------------------------------------------------------
vc_text1_regs:
        db      0x00, 0               ; R#0  Text1 (M1 in R#1)
        db      0x50, 1               ; R#1  BL=1, M1=1
        db      0x00, 2               ; R#2  PNT = 0000h
        db      0x01, 4               ; R#4  PGT = 0800h
        db      0x0A, 8               ; R#8  VR=1, SPD=1 (sprites off)
        db      0x00, 9               ; R#9  LN=0
        db      0x00, 14              ; R#14
        db      0x00, 20              ; R#20 extensions off
        db      0x00, 21              ; R#21 V58=0
        db      0x00, 23              ; R#23 scroll 0
        db      0x00, 26              ; R#26
        db      0x00, 27              ; R#27
        db      0x00, 0xFF

vc_text1_begin:                 ; D = R#7 (FG high nibble / BG low)
        push    de
        ld      hl, vc_text1_regs
        call    vc_set_regs
        pop     de
        ld      e, 7
        call    vc_wvreg        ; D = R#7 value
        ; font -> PGT at 0800h + 20h*8 (glyphs are for codes 20h-5Fh,
        ; and the pattern slot of code C sits at PGT + C*8)
        ld      hl, font_data
        ld      de, 0x0900
        ld      a, 0
        ld      bc, 512
        call    vc_vram_out
        ; clear name table
        call    vc_text_cls
        ld      a, 0
        ld      [text_x], a
        ld      [text_y], a
        ld      a, 40
        ld      [text_w], a
        ld      hl, 0
        ld      [text_addr], hl
        ret

vc_text_cls:
        ld      de, 0
        ld      a, 0
        ld      bc, 960
        ld      l, 0x20
        jp      vc_vram_fill

;---------------------------------------------------------------------
; vc_locate - D = column, E = row (uses text_w for the stride)
;---------------------------------------------------------------------
vc_locate:
        ld      a, d
        ld      [text_x], a
        ld      a, e
        ld      [text_y], a
        ld      l, e
        ld      h, 0
        ld      a, [text_w]
        cp      a, 80
        jr      z, vc_loc_80
        add     hl, hl          ; y*2
        add     hl, hl          ; y*4
        add     hl, hl          ; y*8
        ld      e, l
        ld      d, h            ; DE = y*8
        add     hl, hl          ; y*16
        add     hl, hl          ; y*32
        add     hl, de          ; y*40
        jr      vc_loc_done
vc_loc_80:
        add     hl, hl          ; y*2
        add     hl, hl          ; y*4
        add     hl, hl          ; y*8
        add     hl, hl          ; y*16
        ld      e, l
        ld      d, h            ; DE = y*16
        add     hl, hl          ; y*32
        add     hl, hl          ; y*64
        add     hl, de          ; y*80
vc_loc_done:
        ld      a, [text_x]
        ld      e, a
        ld      d, 0
        add     hl, de
        ld      [text_addr], hl
        ret

;---------------------------------------------------------------------
; vc_putc - print A at the cursor, advance. Lowercase is folded to
; uppercase. 0x0A = newline.
;---------------------------------------------------------------------
vc_putc:
        push    bc
        push    de
        push    hl
        cp      a, 0x0A
        jr      z, vc_putc_nl
        cp      a, 0x61         ; fold a-z to A-Z
        jr      c, vc_putc_ok
        cp      a, 0x7B
        jr      nc, vc_putc_ok
        sub     a, 0x20
vc_putc_ok:
        push    af
        ld      hl, [text_addr]
        ld      a, 0
        call    vc_vaddr_w
        pop     af
        ld      b, a
        ld      a, [vdp_data]
        ld      c, a
        out     [c], b
        ld      hl, [text_addr]
        inc     hl
        ld      [text_addr], hl
        ld      a, [text_x]
        inc     a
        ld      [text_x], a
        ld      hl, text_w
        cp      a, [hl]
        jr      nz, vc_putc_done
        ; wrapped at line end: cursor already at next row start
        xor     a, a
        ld      [text_x], a
        ld      a, [text_y]
        inc     a
        ld      [text_y], a
        jr      vc_putc_done
vc_putc_nl:
        ld      a, [text_w]
        ld      hl, text_x
        sub     a, [hl]         ; remaining columns in this row
        ld      e, a
        ld      d, 0
        ld      hl, [text_addr]
        add     hl, de
        ld      [text_addr], hl
        xor     a, a
        ld      [text_x], a
        ld      a, [text_y]
        inc     a
        ld      [text_y], a
vc_putc_done:
        pop     hl
        pop     de
        pop     bc
        ret

;---------------------------------------------------------------------
; vc_puts - print 0-terminated string at HL
;---------------------------------------------------------------------
vc_puts:
        ld      a, [hl]
        or      a, a
        ret     z
        inc     hl
        push    hl
        call    vc_putc
        pop     hl
        jr      vc_puts

;---------------------------------------------------------------------
; vc_print_dec - print HL (0..65535) in decimal, no leading zeros
;---------------------------------------------------------------------
vc_print_dec:
        push    bc
        push    de
        push    hl
        xor     a, a
        ld      [vc_pd_flag], a
        ld      de, 10000
        call    vc_pd_digit
        ld      de, 1000
        call    vc_pd_digit
        ld      de, 100
        call    vc_pd_digit
        ld      de, 10
        call    vc_pd_digit
        ld      a, l
        add     a, 0x30
        call    vc_putc
        pop     hl
        pop     de
        pop     bc
        ret

; HL = remaining value, DE = power of ten; prints digit if the
; number has reached this magnitude (uses vc_pd_flag in RAM).
vc_pd_digit:
        ld      b, 0xFF         ; digit counter - 1
vc_pd_sub:
        inc     b
        or      a, a
        sbc     hl, de
        jr      nc, vc_pd_sub
        add     hl, de          ; restore (went negative once)
        ld      a, b
        or      a, a
        jr      nz, vc_pd_print
        ld      a, [vc_pd_flag]
        or      a, a
        ret     z               ; still leading zero: skip
vc_pd_print:
        ld      a, 1
        ld      [vc_pd_flag], a
        ld      a, b
        add     a, 0x30
        jp      vc_putc

vc_pd_flag: db  0

;---------------------------------------------------------------------
; vc_print_hex8 - print A as two hex digits
;---------------------------------------------------------------------
vc_print_hex8:
        push    af
        srl     a
        srl     a
        srl     a
        srl     a
        call    vc_ph_nib
        pop     af
        and     a, 0x0F
vc_ph_nib:
        add     a, 0x30
        cp      a, 0x3A
        jr      c, vc_ph_go
        add     a, 7
vc_ph_go:
        jp      vc_putc

;---------------------------------------------------------------------
; vc_restore_exit - restore palette, VRAM, registers; exit to DOS.
; Never returns.
;---------------------------------------------------------------------
vc_restore_exit:
        ld      d, 0            ; display off while restoring
        ld      e, 1
        call    vc_wvreg
        ld      d, 0            ; R#20 = 0
        ld      e, 20
        call    vc_wvreg
        ld      d, 0            ; R#21 = 0
        ld      e, 21
        call    vc_wvreg
        ld      hl, vc_pal_default
        call    vc_set_palette
        call    vc_restore_vram
        ; R#0..R#7 from the BIOS register saves (RGNSAV). These are
        ; the values the BIOS last programmed, i.e. the DOS text
        ; screen's mode/layout/colors on this machine.
        ld      hl, RGNSAV
        ld      e, 0
vc_re_loop:
        ld      d, [hl]
        call    vc_wvreg
        inc     hl
        inc     e
        ld      a, e
        cp      a, 8
        jr      nz, vc_re_loop
        ; R#8 and above are NOT reliably mirrored in the work area
        ; (bytes past RG7SAV are other variables), so restore the
        ; standard DOS text-screen values explicitly. In
        ; particular R#8 must come back with TP=0, or the DOS
        ; screen's color-0 pixels turn transparent.
        ld      hl, vc_re_tail
        call    vc_set_regs
        ld      d, 0            ; R#15 = 0, R#16 = 0, R#17 = 0
        ld      e, 15
        call    vc_wvreg
        ld      d, 0
        ld      e, 16
        call    vc_wvreg
        ld      d, 0
        ld      e, 17
        call    vc_wvreg
        ld      c, 0            ; BDOS terminate
        jp      BDOS

vc_re_tail:
        db      0x08, 8         ; R#8  VR=1, TP=0, SPD=0
        db      0x00, 9         ; R#9
        db      0x00, 10        ; R#10
        db      0x00, 11        ; R#11
        db      0x00, 12        ; R#12
        db      0x00, 13        ; R#13
        db      0x00, 19        ; R#19
        db      0x00, 20        ; R#20 (already 0, keep certain)
        db      0x00, 21        ; R#21
        db      0x00, 23        ; R#23
        db      0x00, 26        ; R#26
        db      0x00, 27        ; R#27
        db      0x00, 0xFF

;---------------------------------------------------------------------
; vc_notfound - print message on the DOS console and exit.
;---------------------------------------------------------------------
vc_notfound:
        ld      de, vc_nf_msg
        ld      c, 9
        call    BDOS
        ld      c, 0
        jp      BDOS

vc_nf_msg:
        db      "V9968 NOT FOUND.", 0x0D, 0x0A, "$"

        include "font.inc"

;---------------------------------------------------------------------
; 16 KB save buffer (must be the last item in the file)
;---------------------------------------------------------------------
vram_save:  SPACE 16384
