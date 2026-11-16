;=====================================================================
; TB04.COM - LFMM fixes made after B03 (real-hardware check)
;
; Bugs (old RTL):
;   - v0.99.6: the LFMM font address missed the VRAM interleave
;     used in SCREEN 7/8 (G6/G7) with SP3=0. The font written by
;     the CPU at 10000h was read from the wrong place: the command
;     got the odd bytes of page 0 instead (here the sentinel 22h).
;     Fixed in v0.99.7.
;   - v0.99.8 and earlier: with DIY=1 a character that reached Y=0
;     kept drawing upwards, wrapped to the bottom of VRAM and wrote
;     there; the next character did not skip the font rows that
;     were not drawn. Fixed in v0.99.9: each character is clipped
;     at Y=0 and the next one starts at its own first font row.
;
; LFMM runs in the extended mode (V58=0), so VRAM is 256 KB and
; R#14 holds A17-A14. Font at VRAM 10000h, written by the CPU
; after the screen mode is set, so the CPU view (interleaved in
; SCREEN 7/8) is the reference. NX=3 characters, NY=16 rows,
; FG=R#44, BG=R#12. Page 0 (00000h-0FFFFh) and the bottom of VRAM
; (3F000h-3FFFFh) are filled with sentinel 22h before each case.
;
; Cases:
;   1. SCREEN 7, DX=64, DY=40, DIY=0 - font A via interleave.
;   2. SCREEN 8, DX=64, DY=40, DIY=0 - font A via interleave.
;   3. SCREEN 5, DX=64, DY=5, DIY=1 - font B, rows 0-5 visible
;      (Y=5..0), rows 6-15 above the screen must be skipped.
;   4. SCREEN 7, DX=64, DY=5, DIY=1 - same as 3 with interleave.
; Each case: CE must drop, the read-back bytes must match, and
; 3F000h-3FFFFh must still hold 22h (no wrap-around write).
;=====================================================================
        org     0x0100
start:
        call    vc_detect
        jp      nc, vc_notfound
        call    vc_save_vram
        ld      hl, vc_pal_default
        call    vc_set_palette

        ;---------------- intro ----------------
        ld      d, 0xF4
        call    vc_text1_begin
        ld      hl, s_intro1
        call    vc_puts
        ld      a, [vdp_base]
        call    vc_print_hex8
        ld      hl, s_intro2
        call    vc_puts
        call    vc_wait_key

        ;---------------- case 1: SCREEN 7 interleave ----------------
        ld      hl, regs_sc7
        ld      de, font_a
        call    setup_case
        ld      hl, 40
        ld      a, 0x0F                 ; FG
        ld      b, 0x04                 ; BG
        ld      c, 0x00                 ; ARG: DIY=0
        call    lfmm_run
        call    vc_wait_key
        ld      hl, chk_c1
        ld      de, rec1
        call    verify

        ;---------------- case 2: SCREEN 8 interleave ----------------
        ld      hl, regs_sc8
        ld      de, font_a
        call    setup_case
        ld      hl, 40
        ld      a, 0xFF                 ; FG
        ld      b, 0x44                 ; BG
        ld      c, 0x00
        call    lfmm_run
        call    vc_wait_key
        ld      hl, chk_c2
        ld      de, rec2
        call    verify

        ;---------------- case 3: SCREEN 5, DIY=1 top edge ----------------
        ld      hl, regs_sc5
        ld      de, font_b
        call    setup_case
        ld      hl, 5
        ld      a, 0x0F
        ld      b, 0x04
        ld      c, 0x08                 ; ARG: DIY=1
        call    lfmm_run
        call    vc_wait_key
        ld      hl, chk_c3
        ld      de, rec3
        call    verify

        ;---------------- case 4: SCREEN 7, DIY=1 top edge ----------------
        ld      hl, regs_sc7
        ld      de, font_b
        call    setup_case
        ld      hl, 5
        ld      a, 0x0F
        ld      b, 0x04
        ld      c, 0x08
        call    lfmm_run
        call    vc_wait_key
        ld      hl, chk_c4
        ld      de, rec4
        call    verify

        ;---------------- results ----------------
        ld      d, 0xF4
        call    vc_text1_begin
        ld      hl, s_res_title
        call    vc_puts
        ld      hl, s_case1
        ld      ix, rec1
        call    print_case
        ld      hl, s_case2
        ld      ix, rec2
        call    print_case
        ld      hl, s_case3
        ld      ix, rec3
        call    print_case
        ld      hl, s_case4
        ld      ix, rec4
        call    print_case
        ld      hl, s_res_tail
        call    vc_puts
        call    vc_wait_key
        jp      vc_restore_exit

;---------------------------------------------------------------------
; setup_case - HL = register table, DE = font (48 bytes).
; Sets the mode first (the CPU view depends on it), then fills the
; sentinel areas and writes the font to VRAM 10000h.
;---------------------------------------------------------------------
setup_case:
        push    de
        call    vc_set_regs
        call    fill_sentinel
        pop     hl
        ld      de, 0x0000
        ld      a, 4                    ; 10000h
        ld      bc, 48
        call    vc_vram_out
        ret

;---------------------------------------------------------------------
; fill_sentinel - 00000h-0FFFFh and 3F000h-3FFFFh := 22h
;---------------------------------------------------------------------
fill_sentinel:
        xor     a, a
        ld      de, 0x0000
fs_loop:
        push    af
        push    de
        ld      bc, 16384
        ld      l, 0x22
        call    vc_vram_fill
        pop     de
        pop     af
        ld      hl, 0x4000
        add     hl, de
        ex      de, hl
        inc     a
        cp      a, 4
        jr      nz, fs_loop
        ld      a, 0x0F                 ; 3F000h
        ld      de, 0xF000
        ld      bc, 4096
        ld      l, 0x22
        call    vc_vram_fill
        ret

;---------------------------------------------------------------------
; lfmm_run - HL = DY, A = FG (R#44), B = BG (R#12), C = ARG (R#45).
; Font 10000h, DX=64, NX=3, NY=16, LOP=0. Polls S#2 CE with a
; timeout; on timeout issues STOP. [lf_ce_ok] = 1 if CE dropped.
;---------------------------------------------------------------------
lfmm_run:
        ld      [lf_dy], hl
        ld      [lf_fg], a
        ld      a, b
        ld      [lf_bg], a
        ld      a, c
        ld      [lf_arg], a
        ld      hl, regs_lfmm
        call    vc_set_regs
        ld      a, [lf_dy]
        ld      d, a
        ld      e, 38                   ; DY low
        call    vc_wvreg
        ld      a, [lf_dy + 1]
        ld      d, a
        ld      e, 39                   ; DY high
        call    vc_wvreg
        ld      a, [lf_fg]
        ld      d, a
        ld      e, 44                   ; FG color
        call    vc_wvreg
        ld      a, [lf_bg]
        ld      d, a
        ld      e, 12                   ; BG color
        call    vc_wvreg
        ld      a, [lf_arg]
        ld      d, a
        ld      e, 45                   ; ARG
        call    vc_wvreg
        ld      d, 0x10                 ; R#46 LFMM, LOP=0 -> GO
        ld      e, 46
        call    vc_wvreg
        ld      bc, 0x0100              ; settle: let CE assert
lf_settle:
        dec     bc
        ld      a, b
        or      a, c
        jr      nz, lf_settle
        ld      bc, 0x8000              ; CE poll timeout
lf_poll:
        ld      d, 2
        call    vc_read_status          ; S#2, bit0 = CE
        and     a, 1
        jr      z, lf_done
        dec     bc
        ld      a, b
        or      a, c
        jr      nz, lf_poll
        ld      d, 0                    ; timeout: STOP
        ld      e, 46
        call    vc_wvreg
        xor     a, a
        ld      [lf_ce_ok], a
        ret
lf_done:
        ld      a, 1
        ld      [lf_ce_ok], a
        ret

;---------------------------------------------------------------------
; verify - HL = check table, DE = 6-byte result record.
; Table entries: db R#14 value (A17-A14); dw address bits 15..0;
; db expected byte. 0xFF ends the table.
; Record: mask (bit0 CE timeout, bit1 data mismatch, bit2 write in
; 3F000h-3FFFFh), first mismatch R#14 value, address, got, expected.
;---------------------------------------------------------------------
verify:
        push    de
        ld      [vf_ptr], hl
        xor     a, a
        ld      [cr_mask], a
        ld      a, [lf_ce_ok]
        or      a, a
        jr      nz, vf_loop
        ld      a, 1
        ld      [cr_mask], a
vf_loop:
        ld      hl, [vf_ptr]
        ld      a, [hl]
        cp      a, 0xFF
        jr      z, vf_band
        ld      [vf_bank], a
        inc     hl
        ld      e, [hl]
        inc     hl
        ld      d, [hl]
        inc     hl
        ld      a, [hl]
        inc     hl
        ld      [vf_ptr], hl
        ld      [vf_exp], a
        ld      [vf_addr], de
        ex      de, hl
        ld      a, [vf_bank]
        call    vc_vram_read1
        ld      b, a
        ld      a, [vf_exp]
        cp      a, b
        jr      z, vf_loop
        ld      a, [cr_mask]
        bit     1, a
        jr      nz, vf_loop             ; keep the first mismatch
        or      a, 2
        ld      [cr_mask], a
        ld      a, [vf_bank]
        ld      [cr_bank], a
        ld      hl, [vf_addr]
        ld      [cr_addr], hl
        ld      a, b
        ld      [cr_got], a
        ld      a, [vf_exp]
        ld      [cr_exp], a
        jr      vf_loop
vf_band:
        ld      hl, scan_buf
        ld      de, 0xF000
        ld      a, 0x0F                 ; 3F000h
        ld      bc, 4096
        call    vc_vram_in
        ld      hl, scan_buf
        ld      bc, 4096
vf_band_loop:
        ld      a, [hl]
        cp      a, 0x22
        jr      nz, vf_band_ng
        inc     hl
        dec     bc
        ld      a, b
        or      a, c
        jr      nz, vf_band_loop
        jr      vf_store
vf_band_ng:
        ld      a, [cr_mask]
        or      a, 4
        ld      [cr_mask], a
vf_store:
        pop     de
        ld      hl, cr_mask
        ld      bc, 6
        ldir
        ret

;---------------------------------------------------------------------
; print_case - HL = label, IX = result record.
;---------------------------------------------------------------------
print_case:
        call    vc_puts
        ld      a, [ix + 0]
        or      a, a
        jr      nz, pc_ng
        ld      hl, s_pass
        jp      vc_puts
pc_ng:
        ld      hl, s_ng
        call    vc_puts
        bit     0, [ix + 0]
        jr      z, pc_data
        ld      hl, s_ce_ng
        call    vc_puts
pc_data:
        bit     1, [ix + 0]
        jr      z, pc_band
        ld      hl, s_data_ng
        call    vc_puts
        ld      a, [ix + 1]             ; A17-A14 -> A17-A16 digit
        rrca
        rrca
        and     a, 0x03
        add     a, '0'
        call    vc_putc
        ld      a, [ix + 3]
        call    vc_print_hex8
        ld      a, [ix + 2]
        call    vc_print_hex8
        ld      hl, s_data_got
        call    vc_puts
        ld      a, [ix + 4]
        call    vc_print_hex8
        ld      hl, s_data_exp
        call    vc_puts
        ld      a, [ix + 5]
        call    vc_print_hex8
        ld      a, 0x0A
        call    vc_putc
pc_band:
        bit     2, [ix + 0]
        ret     z
        ld      hl, s_band_ng
        jp      vc_puts

;---------------------------------------------------------------------
; work
;---------------------------------------------------------------------
lf_dy:      dw  0
lf_fg:      db  0
lf_bg:      db  0
lf_arg:     db  0
lf_ce_ok:   db  0
vf_ptr:     dw  0
vf_bank:    db  0
vf_addr:    dw  0
vf_exp:     db  0
cr_mask:    db  0               ; current record (6 bytes)
cr_bank:    db  0
cr_addr:    dw  0
cr_got:     db  0
cr_exp:     db  0
rec1:       db  0, 0, 0, 0, 0, 0
rec2:       db  0, 0, 0, 0, 0, 0
rec3:       db  0, 0, 0, 0, 0, 0
rec4:       db  0, 0, 0, 0, 0, 0

;---------------------------------------------------------------------
; fonts (character-major, 16 rows per character)
; font A: char0 = FFh, char1 = 0Fh, char2 = C3h (all rows)
; font B: rows 0-5 are drawn with DIY=1 from DY=5 (row r at Y=5-r);
;   char0 rows 0-4 = FFh, row 5 = F0h; char1 rows 0-5 = 0Fh;
;   char2 rows 0-5 = C3h; rows 6-15 (above the screen) = 18h.
;   If the hidden rows are not skipped, char1/char2 start with 18h.
;---------------------------------------------------------------------
font_a:
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        db      0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F
        db      0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F
        db      0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3
        db      0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3
font_b:
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xF0, 0x18, 0x18
        db      0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18
        db      0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x18, 0x18
        db      0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18
        db      0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0x18, 0x18
        db      0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18, 0x18

;---------------------------------------------------------------------
; check tables: db R#14 (addr >> 14), dw addr & FFFFh, db expected
; 4bpp: byte = 2 dots; FG=F, BG=4 -> FF / 44 / F4 / 4F. 8bpp: 1 dot.
;---------------------------------------------------------------------
; case 1: SCREEN 7 (256 bytes/line), DX=64 -> byte 32, Y=40..55
chk_c1:
        db 0
        dw 0x2820
        db 0xFF                 ; Y40 char0
        db 0
        dw 0x2823
        db 0xFF
        db 0
        dw 0x2824
        db 0x44                 ; char1 = 0Fh -> 44 44 FF FF
        db 0
        dw 0x2825
        db 0x44
        db 0
        dw 0x2826
        db 0xFF
        db 0
        dw 0x2827
        db 0xFF
        db 0
        dw 0x2828
        db 0xFF                 ; char2 = C3h -> FF 44 44 FF
        db 0
        dw 0x2829
        db 0x44
        db 0
        dw 0x282A
        db 0x44
        db 0
        dw 0x282B
        db 0xFF
        db 0
        dw 0x282C
        db 0x22                 ; after NX=3
        db 0
        dw 0x3720
        db 0xFF                 ; Y55 (last row) char0
        db 0
        dw 0x3726
        db 0xFF                 ; Y55 char1 right half
        db 0
        dw 0x3820
        db 0x22                 ; Y56 untouched
        db 0xFF

; case 2: SCREEN 8 (1 byte/dot), DX=64, Y=40..55, FG=FF, BG=44
chk_c2:
        db 0
        dw 0x2840
        db 0xFF                 ; char0
        db 0
        dw 0x2847
        db 0xFF
        db 0
        dw 0x2848
        db 0x44                 ; char1 = 0Fh: 4 x BG, 4 x FG
        db 0
        dw 0x284B
        db 0x44
        db 0
        dw 0x284C
        db 0xFF
        db 0
        dw 0x284F
        db 0xFF
        db 0
        dw 0x2850
        db 0xFF                 ; char2 = C3h: FG FG BG BG BG BG FG FG
        db 0
        dw 0x2851
        db 0xFF
        db 0
        dw 0x2852
        db 0x44
        db 0
        dw 0x2855
        db 0x44
        db 0
        dw 0x2856
        db 0xFF
        db 0
        dw 0x2857
        db 0xFF
        db 0
        dw 0x2858
        db 0x22                 ; after NX=3
        db 0
        dw 0x3740
        db 0xFF                 ; Y55 char0
        db 0
        dw 0x3840
        db 0x22                 ; Y56 untouched
        db 0xFF

; case 3: SCREEN 5 (128 bytes/line), DX=64 -> byte 32, DIY=1, DY=5
chk_c3:
        db 0
        dw 0x02A0
        db 0xFF                 ; Y5 = row0: char0 FF
        db 0
        dw 0x02A3
        db 0xFF
        db 0
        dw 0x02A4
        db 0x44                 ; Y5 char1 row0 = 0Fh
        db 0
        dw 0x02A5
        db 0x44
        db 0
        dw 0x02A6
        db 0xFF
        db 0
        dw 0x02A7
        db 0xFF
        db 0
        dw 0x02A8
        db 0xFF                 ; Y5 char2 row0 = C3h
        db 0
        dw 0x02A9
        db 0x44
        db 0
        dw 0x02AA
        db 0x44
        db 0
        dw 0x02AB
        db 0xFF
        db 0
        dw 0x02AC
        db 0x22                 ; after NX=3
        db 0
        dw 0x00A0
        db 0xFF                 ; Y1 = row4: char0 FF
        db 0
        dw 0x0020
        db 0xFF                 ; Y0 = row5: char0 F0h -> FF FF 44 44
        db 0
        dw 0x0021
        db 0xFF
        db 0
        dw 0x0022
        db 0x44
        db 0
        dw 0x0023
        db 0x44
        db 0
        dw 0x0024
        db 0x44                 ; Y0 char1 row5 = 0Fh
        db 0
        dw 0x0025
        db 0x44
        db 0
        dw 0x0026
        db 0xFF
        db 0
        dw 0x0027
        db 0xFF
        db 0
        dw 0x0028
        db 0xFF                 ; Y0 char2 row5 = C3h
        db 0
        dw 0x0029
        db 0x44
        db 0
        dw 0x002A
        db 0x44
        db 0
        dw 0x002B
        db 0xFF
        db 0
        dw 0x002C
        db 0x22
        db 0
        dw 0x0320
        db 0x22                 ; Y6 untouched
        db 0xFF

; case 4: SCREEN 7 (256 bytes/line), DX=64 -> byte 32, DIY=1, DY=5
chk_c4:
        db 0
        dw 0x0520
        db 0xFF                 ; Y5 = row0: char0 FF
        db 0
        dw 0x0523
        db 0xFF
        db 0
        dw 0x0524
        db 0x44                 ; Y5 char1 row0 = 0Fh
        db 0
        dw 0x0525
        db 0x44
        db 0
        dw 0x0526
        db 0xFF
        db 0
        dw 0x0527
        db 0xFF
        db 0
        dw 0x0528
        db 0xFF                 ; Y5 char2 row0 = C3h
        db 0
        dw 0x0529
        db 0x44
        db 0
        dw 0x052A
        db 0x44
        db 0
        dw 0x052B
        db 0xFF
        db 0
        dw 0x052C
        db 0x22                 ; after NX=3
        db 0
        dw 0x0120
        db 0xFF                 ; Y1 = row4: char0 FF
        db 0
        dw 0x0020
        db 0xFF                 ; Y0 = row5: char0 F0h -> FF FF 44 44
        db 0
        dw 0x0021
        db 0xFF
        db 0
        dw 0x0022
        db 0x44
        db 0
        dw 0x0023
        db 0x44
        db 0
        dw 0x0024
        db 0x44                 ; Y0 char1 row5 = 0Fh
        db 0
        dw 0x0025
        db 0x44
        db 0
        dw 0x0026
        db 0xFF
        db 0
        dw 0x0027
        db 0xFF
        db 0
        dw 0x0028
        db 0xFF                 ; Y0 char2 row5 = C3h
        db 0
        dw 0x0029
        db 0x44
        db 0
        dw 0x002A
        db 0x44
        db 0
        dw 0x002B
        db 0xFF
        db 0
        dw 0x002C
        db 0x22
        db 0
        dw 0x0620
        db 0x22                 ; Y6 untouched
        db 0xFF

;---------------------------------------------------------------------
; register tables
;---------------------------------------------------------------------
regs_sc5:
        db      0x06, 0         ; R#0  Graphic4 (SCREEN 5)
        db      0x40, 1         ; R#1  BL=1
        db      0x1F, 2         ; R#2  page 0
        db      0x04, 7         ; R#7  border = 4
        db      0x0A, 8         ; R#8  VR=1, SPD=1 (sprites off)
        db      0x00, 9         ; R#9  LN=0
        db      0x00, 14        ; R#14
        db      0x00, 20        ; R#20 (SP3=0)
        db      0x00, 21        ; R#21 V58=0 (extended mode)
        db      0x00, 23        ; R#23
        db      0x00, 25        ; R#25 YJK off
        db      0x00, 0xFF

regs_sc7:
        db      0x0A, 0         ; R#0  Graphic6 (SCREEN 7)
        db      0x40, 1
        db      0x1F, 2
        db      0x04, 7
        db      0x0A, 8
        db      0x00, 9
        db      0x00, 14
        db      0x00, 20
        db      0x00, 21
        db      0x00, 23
        db      0x00, 25
        db      0x00, 0xFF

regs_sc8:
        db      0x0E, 0         ; R#0  Graphic7 (SCREEN 8)
        db      0x40, 1
        db      0x1F, 2
        db      0x00, 7
        db      0x0A, 8
        db      0x00, 9
        db      0x00, 14
        db      0x00, 20
        db      0x00, 21
        db      0x00, 23
        db      0x00, 25
        db      0x00, 0xFF

regs_lfmm:
        db      0x00, 32        ; font A7-0
        db      0x00, 33        ; font A15-8
        db      0x01, 34        ; font A17-16 -> 10000h
        db      0x00, 35
        db      64, 36          ; DX = 64
        db      0x00, 37
        db      3, 40           ; NX = 3 characters
        db      0x00, 41
        db      16, 42          ; NY = 16 rows
        db      0x00, 43
        db      0x00, 0xFF

;---------------------------------------------------------------------
; strings (Text1, max 39 columns)
;---------------------------------------------------------------------
s_intro1:
        db      "TB04: LFMM AFTER B03", 0x0A, 0x0A
        db      "V9968 PORT: ", 0
s_intro2:
        db      "H", 0x0A, 0x0A
        db      "FONT AT VRAM 10000H, NX=3, NY=16.", 0x0A
        db      "BACKGROUND = SENTINEL 22H.", 0x0A, 0x0A
        db      " CASE 1: SC7 INTERLEAVE  DY=40", 0x0A
        db      " CASE 2: SC8 INTERLEAVE  DY=40", 0x0A
        db      " CASE 3: SC5 DIY=1 TOP   DY=5", 0x0A
        db      " CASE 4: SC7 DIY=1 TOP   DY=5", 0x0A, 0x0A
        db      "EACH CASE: VIEW, PRESS ANY KEY.", 0x0A
        db      "RESULTS (CE + VRAM READBACK +", 0x0A
        db      "3F000H-3FFFFH UNTOUCHED)", 0x0A
        db      "ARE SHOWN AT THE END.", 0x0A, 0x0A
        db      "PRESS ANY KEY", 0

s_res_title:
        db      "TB04 RESULTS (LFMM)", 0x0A, 0x0A, 0
s_case1:
        db      "CASE 1 SC7 FONT INTERLEAVE:", 0
s_case2:
        db      "CASE 2 SC8 FONT INTERLEAVE:", 0
s_case3:
        db      "CASE 3 SC5 DIY=1 TOP CLIP :", 0
s_case4:
        db      "CASE 4 SC7 DIY=1 TOP CLIP :", 0
s_pass:
        db      " PASS", 0x0A, 0
s_ng:
        db      " NG", 0x0A, 0
s_ce_ng:
        db      "  CE TIMEOUT (STOPPED)", 0x0A, 0
s_data_ng:
        db      "  VRAM ", 0
s_data_got:
        db      "H=", 0
s_data_exp:
        db      " EXP ", 0
s_band_ng:
        db      "  WRITE IN 3F000H-3FFFFH", 0x0A, 0
s_res_tail:
        db      0x0A
        db      "ALL PASS: THE V0.99.7 INTERLEAVE AND", 0x0A
        db      "V0.99.9 TOP CLIP FIXES ARE OK.", 0x0A, 0x0A
        db      "PRESS ANY KEY TO EXIT", 0

scan_buf:
        SPACE   4096

        include "vdpcom.inc"
