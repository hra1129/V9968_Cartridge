;=====================================================================
; T06.COM - hesoten report item 06: text / multicolor color 0 and TP
;
; Real V9958 behaviour (hesoten report 06, hardware measured):
;   - Text1/Text2 foreground color 0 is transparent regardless of
;     TP: the glyph is drawn in the character's own background
;     color (R#7 for normal characters, R#12 for blink characters),
;     so it vanishes. Background color 0 stays palette color 0.
;   - Multicolor color 0 is transparent regardless of TP: the
;     border color (R#7 low nibble) shows.
; Old V9968 RTL (up to v0.99.5):
;   - Text color 0 was palette color 0 regardless of TP.
;   - Multicolor color 0 followed TP (TP=1 showed palette color 0).
; Fixed in v0.99.6 (vdp_timing_control_screen_mode.v,
; vdp_color_palette.v). This program makes the difference visible:
; palette entry 0 is set to MAGENTA, so any leaked color 0 is
; unmistakable. All scenes are visual checks (the composed display
; cannot be read back by the CPU).
;
; Scenes (press any key to advance):
;   1 Text1 FG=0 TP=0   2 Text1 FG=0 TP=1   3 Text2 blink FG=0
;   4 Multicolor TP=0   5 Multicolor TP=1 (same screen, TP flipped)
;=====================================================================
        org     0x0100
start:
        call    vc_detect
        jp      nc, vc_notfound
        call    vc_save_vram
        ld      hl, pal_t06
        call    vc_set_palette

        ;---------------- intro page (Text1, FG15/BG4) ----------------
        ld      d, 0xF4
        call    vc_text1_begin
        ld      hl, s_title
        call    vc_puts
        ld      hl, s_port
        call    vc_puts
        ld      a, [vdp_base]
        call    vc_print_hex8
        ld      hl, s_intro
        call    vc_puts
        call    vc_wait_key

        ;---------------- scene 1: Text1 FG=0, TP=0 ----------------
        ld      d, 0x04                 ; R#7: FG=0, BG=4
        call    vc_text1_begin          ; R#8 = 0x0A (TP=0)
        call    fill_test_text
        call    vc_wait_key

        ;---------------- scene 2: Text1 FG=0, TP=1 ----------------
        ld      d, 0x04
        call    vc_text1_begin
        ld      d, 0x2A                 ; R#8: TP=1, VR=1, SPD=1
        ld      e, 8
        call    vc_wvreg
        call    fill_test_text
        call    vc_wait_key

        ;---------------- scene 3: Text2 blink ----------------
        call    setup_text2
        call    vc_wait_key

        ;---------------- scene 4: Multicolor TP=0 ----------------
        ld      hl, regs_mc
        call    vc_set_regs
        ld      hl, mc_colors
        ld      de, 0x0800
        ld      a, 0
        ld      bc, 24
        call    vc_vram_out
        call    mc_build_pnt
        call    vc_wait_key

        ;---------------- scene 5: same screen, TP=1 ----------------
        ld      d, 0x2A                 ; R#8: TP=1, VR=1, SPD=1
        ld      e, 8
        call    vc_wvreg
        call    vc_wait_key

        ;---------------- summary page ----------------
        ld      d, 0xF4
        call    vc_text1_begin
        ld      hl, s_summary
        call    vc_puts
        call    vc_wait_key
        jp      vc_restore_exit

;---------------------------------------------------------------------
; fill the Text1 screen with the test line (FG color under test)
;---------------------------------------------------------------------
fill_test_text:
        xor     a, a
        ld      [ft_row], a
ft_loop:
        ld      d, 0
        ld      a, [ft_row]
        ld      e, a
        call    vc_locate
        ld      hl, s_testline
        call    vc_puts
        ld      a, [ft_row]
        inc     a
        ld      [ft_row], a
        cp      a, 24
        jr      nz, ft_loop
        ret
ft_row: db      0

;---------------------------------------------------------------------
; Text2 scene: labels + control rows in R#7 colors, rows 10-17 are
; blink characters filled with '#'. R#12 FG=0 / BG=11, R#13 = 0x0A
; (R#7 phase length 0, so blink characters always show R#12 colors).
;---------------------------------------------------------------------
setup_text2:
        ld      hl, regs_t2
        call    vc_set_regs
        ld      hl, font_data
        ld      de, 0x0900              ; PGT 0800h + 20h*8 (codes 20h-)
        ld      a, 0
        ld      bc, 512
        call    vc_vram_out
        ld      de, 0                   ; name table clear (1920)
        ld      a, 0
        ld      bc, 1920
        ld      l, 0x20
        call    vc_vram_fill
        ld      de, 0x1000              ; blink table clear (240)
        ld      a, 0
        ld      bc, 240
        ld      l, 0x00
        call    vc_vram_fill
        ld      de, 0x1000 + 100        ; rows 10-17 blink on
        ld      a, 0
        ld      bc, 80
        ld      l, 0xFF
        call    vc_vram_fill
        ld      a, 80
        ld      [text_w], a
        xor     a, a
        ld      [text_x], a
        ld      [text_y], a
        ld      hl, 0
        ld      [text_addr], hl
        ld      hl, s_t2
        call    vc_puts
        ; rows 10-17: 640 '#' characters (auto wrap)
        ld      d, 0
        ld      e, 10
        call    vc_locate
        ld      bc, 640
t2_hash_loop:
        ld      a, 0x23                 ; '#'
        call    vc_putc
        dec     bc
        ld      a, b
        or      a, c
        jr      nz, t2_hash_loop
        ld      d, 0
        ld      e, 19
        call    vc_locate
        ld      hl, s_t2b
        call    vc_puts
        ret

;---------------------------------------------------------------------
; Multicolor name table: rows 0-15: left half pattern 0 (color 0),
; right half pattern 1 (color 15). Rows 16-23: pattern 2 (color 8).
;---------------------------------------------------------------------
mc_build_pnt:
        xor     a, a
        ld      [mc_row], a
mc_row_loop:
        ld      a, [mc_row]
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl                  ; row * 32
        ld      a, 0
        call    vc_vaddr_w
        ld      a, [vdp_data]
        ld      c, a
        xor     a, a
        ld      [mc_col], a
mc_col_loop:
        ld      a, [mc_row]
        cp      a, 16
        jr      nc, mc_val2
        ld      a, [mc_col]
        cp      a, 16
        jr      c, mc_val0
        ld      l, 1
        jr      mc_out
mc_val2:
        ld      l, 2
        jr      mc_out
mc_val0:
        ld      l, 0
mc_out:
        out     [c], l
        ld      a, [mc_col]
        inc     a
        ld      [mc_col], a
        cp      a, 32
        jr      nz, mc_col_loop
        ld      a, [mc_row]
        inc     a
        ld      [mc_row], a
        cp      a, 24
        jr      nz, mc_row_loop
        ret
mc_row: db      0
mc_col: db      0

;---------------------------------------------------------------------
; data
;---------------------------------------------------------------------
pal_t06:
        db      0x77, 0x00      ; 0  MAGENTA (7,0,7) - leak detector
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

regs_t2:
        db      0x04, 0         ; R#0  Text2 (M4)
        db      0x50, 1         ; R#1  BL=1, M1=1
        db      0x00, 2         ; R#2  PNT = 0000h
        db      0x40, 3         ; R#3  blink table = 1000h
        db      0x01, 4         ; R#4  PGT = 0800h
        db      0xF4, 7         ; R#7  FG=15, BG=4
        db      0x0A, 8         ; R#8  VR=1, SPD=1
        db      0x00, 9         ; R#9
        db      0x00, 10        ; R#10 blink table high
        db      0x0B, 12        ; R#12 blink FG=0, BG=11
        db      0x0A, 13        ; R#13 R#7 phase 0, blink phase 10
        db      0x00, 14        ; R#14
        db      0x00, 20        ; R#20
        db      0x00, 21        ; R#21 V58=0
        db      0x00, 23        ; R#23
        db      0x00, 0xFF

regs_mc:
        db      0x00, 0         ; R#0  Multicolor (M2 in R#1)
        db      0x48, 1         ; R#1  BL=1, M2=1
        db      0x00, 2         ; R#2  PNT = 0000h
        db      0x01, 4         ; R#4  color data = 0800h
        db      0x0A, 7         ; R#7  border = 10 (olive)
        db      0x0A, 8         ; R#8  VR=1, SPD=1, TP=0
        db      0x00, 9         ; R#9
        db      0x00, 14        ; R#14
        db      0x00, 20        ; R#20
        db      0x00, 21        ; R#21 V58=0
        db      0x00, 23        ; R#23
        db      0x00, 0xFF

mc_colors:                      ; Multicolor pattern color data
        db      0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ; pat0: color 0
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF  ; pat1: color 15
        db      0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88, 0x88  ; pat2: color 8

s_title:
        db      "T06: COLOR 0 AND TP (ITEM 06)", 0x0A, 0x0A
        db      "V9968 PORT: ", 0
s_port: db      0               ; (hex printed between the two)
s_intro:
        db      "H", 0x0A, 0x0A
        db      "PALETTE 0 = MAGENTA IN THIS TEST.", 0x0A
        db      "IF COLOR 0 SHOWS, YOU SEE MAGENTA.", 0x0A, 0x0A
        db      "SCENE 1: TEXT1 FG=0 TP=0", 0x0A
        db      "  PASS: ALL DARK BLUE, NO LETTERS", 0x0A
        db      "  NG  : MAGENTA LETTERS", 0x0A
        db      "SCENE 2: TEXT1 FG=0 TP=1", 0x0A
        db      "  PASS: SAME AS SCENE 1", 0x0A
        db      "SCENE 3: TEXT2 BLINK R12 FG=0", 0x0A
        db      "  PASS: BLINK ROWS PLAIN YELLOW", 0x0A
        db      "  NG  : MAGENTA MARKS", 0x0A
        db      "SCENE 4: MULTICOLOR TP=0", 0x0A
        db      "  PASS: LEFT HALF = BORDER OLIVE", 0x0A
        db      "SCENE 5: MULTICOLOR TP=1", 0x0A
        db      "  PASS: IDENTICAL TO SCENE 4", 0x0A
        db      "  NG  : LEFT HALF MAGENTA", 0x0A, 0x0A
        db      "PRESS ANY KEY", 0

s_testline:
        db      "COLOR 0 TEST 0123456789 ABCDEFGHIJKLM", 0

s_t2:
        db      "TEXT2 BLINK TEST (ITEM 06)", 0x0A, 0x0A
        db      "NORMAL ROWS USE R7: FG=15 BG=4 (ALWAYS VISIBLE)", 0x0A
        db      "CONTROL TEXT 0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ", 0x0A, 0x0A
        db      "ROWS 10-17 BLINK WITH R12: FG=0 BG=11", 0x0A
        db      "PASS: THEY ARE PLAIN LIGHT-YELLOW BANDS", 0x0A
        db      "NG  : MAGENTA # MARKS ON YELLOW", 0

s_t2b:
        db      "THE MARKS IN ROWS 10-17 ARE # CHARACTERS.", 0x0A
        db      "WITH FG=0 THEY MUST VANISH INTO THE BG COLOR.", 0

s_summary:
        db      "T06 SUMMARY", 0x0A, 0x0A
        db      "ITEM 06 IS OK IF ALL OF THESE HELD:", 0x0A
        db      " 1. TEXT1 FG=0 (TP=0 AND TP=1):", 0x0A
        db      "    NO LETTERS WERE VISIBLE.", 0x0A
        db      " 2. TEXT2 BLINK ROWS (R12 FG=0):", 0x0A
        db      "    PLAIN YELLOW, NO MAGENTA.", 0x0A
        db      " 3. MULTICOLOR TP=1:", 0x0A
        db      "    LEFT HALF STAYED BORDER OLIVE,", 0x0A
        db      "    IDENTICAL TO TP=0.", 0x0A, 0x0A
        db      "IF ANY SCENE SHOWED MAGENTA WHERE", 0x0A
        db      "COLOR 0 WAS USED, ITEM 06 IS NG.", 0x0A, 0x0A
        db      "PRESS ANY KEY TO EXIT", 0

        include "vdpcom.inc"
