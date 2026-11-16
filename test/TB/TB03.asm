;=====================================================================
; TB03.COM - hesoten report B03: LFMM at the screen edge / NX
;
; Bugs (old RTL):
;   - v0.99.5 and earlier: a character crossing the right screen
;     edge made CE never drop; the command kept writing outside
;     the rectangle (wrapping around), and NX did not act as a
;     character count.
;   - v0.99.6: edge handling fixed, but the LFMM font reference
;     address missed the SCREEN 7+ / SP3=0 VRAM interleave.
;   - v0.99.7: interleave added to the font address generation.
; Font data format (manual 8.16): character-major - one character
; is 8 dots x NY rows, 1 byte per row, MSB first; the command
; draws one character's NY rows, then moves to the next. NX is a
; CHARACTER count.
;
; Setup: Graphic4 (SCREEN 5), page 0 filled with sentinel color 2
; (byte 22h). Font at VRAM 10000h: char0 = all 1s (draws FG=15),
; char1 = 00001111b (left half BG=4, right half FG), char2 = C3h.
; Cases (each: fill, run LFMM, view, then VRAM read-back checks):
;   1. DX=252, DY=24, NX=3, NY=16 - first character crosses the
;      right edge (dots 252-259). It must be clipped at dot 255,
;      the command must end (CE drops), and nothing may appear at
;      the left edge of the same rows or beyond NY rows.
;   2. DX=64, DY=80, NX=2, NY=16 - exactly 2 characters drawn
;      (NX is a character count): char0 and char1, no char2.
;   3. DX=128, DY=128, NX=3, NY=16 - control, fully on screen:
;      all 3 characters in order.
; G4 byte address = Y*128 + X/2. A byte is FFh when both dots are
; FG=15, 44h when both are BG=4, 22h = untouched sentinel.
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

        ;---------------- setup ----------------
        ld      hl, regs_b03
        call    vc_set_regs
        ld      hl, font3                 ; font -> VRAM 10000h
        ld      de, 0x0000
        ld      a, 4
        ld      bc, 48
        call    vc_vram_out

        ;---------------- case 1: right edge ----------------
        call    fill_sentinel
        ld      hl, 252
        ld      [lf_dx], hl
        ld      hl, 24
        ld      [lf_dy], hl
        ld      hl, 3
        ld      [lf_nx], hl
        ld      hl, 16
        ld      [lf_ny], hl
        call    lfmm_run
        call    vc_wait_key               ; view the scene
        xor     a, a
        ld      [chk_fail], a
        ld      de, 0x0C7E                ; row24 col126 = FF
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x0C7F                ; row24 col127 = FF
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x13FE                ; row39 col126 = FF
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x0C00                ; row24 col0 = sentinel
        ld      a, 0
        ld      l, 0x22
        call    check_byte
        ld      de, 0x0C03                ; row24 col3 = sentinel
        ld      a, 0
        ld      l, 0x22
        call    check_byte
        ld      de, 0x147E                ; row40 col126 = sentinel
        ld      a, 0
        ld      l, 0x22
        call    check_byte
        call    case_verdict
        ld      [v1], a

        ;---------------- case 2: NX = character count ----------------
        call    fill_sentinel
        ld      hl, 64
        ld      [lf_dx], hl
        ld      hl, 80
        ld      [lf_dy], hl
        ld      hl, 2
        ld      [lf_nx], hl
        ld      hl, 16
        ld      [lf_ny], hl
        call    lfmm_run
        call    vc_wait_key
        xor     a, a
        ld      [chk_fail], a
        ld      de, 0x2820                ; row80: char0 bytes
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x2823
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ; Graphic4: 1 char = 8 dots = 4 bytes (2 dots/byte).
        ; char1 pattern 0Fh -> bytes 44,44,FF,FF (BG half, FG half)
        ld      de, 0x2824                ; char1 left half = BG
        ld      a, 0
        ld      l, 0x44
        call    check_byte
        ld      de, 0x2825                ; char1 left half = BG
        ld      a, 0
        ld      l, 0x44
        call    check_byte
        ld      de, 0x2826                ; char1 right half = FG
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x2827                ; char1 right half = FG
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x2828                ; no 3rd character
        ld      a, 0
        ld      l, 0x22
        call    check_byte
        ld      de, 0x2F80 + 32           ; row95 col32 = FF
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x2F80 + 36           ; row95 col36 = BG (44)
        ld      a, 0
        ld      l, 0x44
        call    check_byte
        ld      de, 0x2F80 + 39           ; row95 col39 = FF
        ld      a, 0
        ld      l, 0xFF
        call    check_byte
        call    case_verdict
        ld      [v2], a

        ;---------------- case 3: control ----------------
        call    fill_sentinel
        ld      hl, 128
        ld      [lf_dx], hl
        ld      hl, 128
        ld      [lf_dy], hl
        ld      hl, 3
        ld      [lf_nx], hl
        ld      hl, 16
        ld      [lf_ny], hl
        call    lfmm_run
        call    vc_wait_key
        xor     a, a
        ld      [chk_fail], a
        ; addresses 4000h-47FFh: bits 16..14 = 1, so the R#14 value (A) is 1.
        ; char0 = bytes 4040-4043, char1 = 4044-4047 (44,44,FF,FF),
        ; char2 = 4048-404B (C3h -> FF,44,44,FF)
        ld      de, 0x4040                ; row128: char0 first byte
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x4043                ; char0 last byte
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x4044                ; char1 left = BG
        ld      a, 1
        ld      l, 0x44
        call    check_byte
        ld      de, 0x4045                ; char1 left = BG
        ld      a, 1
        ld      l, 0x44
        call    check_byte
        ld      de, 0x4046                ; char1 right = FG
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x4047                ; char1 right = FG
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x4048                ; char2: C3 -> F,4,4,F
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x4049
        ld      a, 1
        ld      l, 0x44
        call    check_byte
        ld      de, 0x404A
        ld      a, 1
        ld      l, 0x44
        call    check_byte
        ld      de, 0x404B
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        ld      de, 0x404C                ; after char2: sentinel
        ld      a, 1
        ld      l, 0x22
        call    check_byte
        ld      de, 0x4780 + 64           ; row143 col64 = FF
        ld      a, 1
        ld      l, 0xFF
        call    check_byte
        call    case_verdict
        ld      [v3], a

        ;---------------- results ----------------
        ld      d, 0xF4
        call    vc_text1_begin
        ld      hl, s_res1
        call    vc_puts
        ld      a, [v1]
        call    print_passng
        ld      hl, s_res2
        call    vc_puts
        ld      a, [v2]
        call    print_passng
        ld      hl, s_res3
        call    vc_puts
        ld      a, [v3]
        call    print_passng
        ld      hl, s_res_tail
        call    vc_puts
        call    vc_wait_key
        jp      vc_restore_exit

;---------------------------------------------------------------------
; case_verdict - A = 1 if CE dropped AND all read-back checks held.
;---------------------------------------------------------------------
case_verdict:
        ld      a, [lf_ce_ok]
        or      a, a
        jr      z, cv_ng
        ld      a, [chk_fail]
        or      a, a
        jr      nz, cv_ng
        ld      a, 1
        ret
cv_ng:
        xor     a, a
        ret

;---------------------------------------------------------------------
; print_passng - A = 1 -> " PASS", else " NG". Plus newline.
;---------------------------------------------------------------------
print_passng:
        or      a, a
        jr      z, pp_ng
        ld      hl, s_pass
        jr      pp_out
pp_ng:
        ld      hl, s_ng
pp_out:
        call    vc_puts
        ret

;---------------------------------------------------------------------
; fill_sentinel - page 0 := 22h (two 16KB-block chunks).
;---------------------------------------------------------------------
fill_sentinel:
        ld      de, 0x0000
        ld      a, 0
        ld      bc, 16384
        ld      l, 0x22
        call    vc_vram_fill
        ld      de, 0x4000
        ld      a, 1
        ld      bc, 10752
        ld      l, 0x22
        call    vc_vram_fill
        ret

;---------------------------------------------------------------------
; check_byte - DE = VRAM address (low 16), A = R#14 value,
; L = expected byte. Sets chk_fail on mismatch.
;---------------------------------------------------------------------
check_byte:
        push    hl              ; L = expected byte
        ex      de, hl          ; vc_vram_read1 takes HL = address
        call    vc_vram_read1
        pop     hl
        cp      a, l
        ret     z
        ld      a, 1
        ld      [chk_fail], a
        ret

;---------------------------------------------------------------------
; lfmm_run - run LFMM with [lf_dx],[lf_dy],[lf_nx],[lf_ny] and the
; fixed font address 10000h, FG=15 (R#44), BG=4 (R#12), ARG=0.
; Polls S#2 CE with a timeout; on timeout issues STOP.
; [lf_ce_ok] = 1 if CE dropped, 0 on timeout.
;---------------------------------------------------------------------
lfmm_run:
        ld      d, 0                    ; R#32 font A7-0
        ld      e, 32
        call    vc_wvreg
        ld      d, 0                    ; R#33 font A15-8
        ld      e, 33
        call    vc_wvreg
        ld      d, 1                    ; R#34 font A17-16 -> 10000h
        ld      e, 34
        call    vc_wvreg
        ld      d, 0                    ; R#35 unused = 0
        ld      e, 35
        call    vc_wvreg
        ld      a, [lf_dx]
        ld      d, a
        ld      e, 36                   ; DX low
        call    vc_wvreg
        ld      a, [lf_dx + 1]
        ld      d, a
        ld      e, 37                   ; DX high
        call    vc_wvreg
        ld      a, [lf_dy]
        ld      d, a
        ld      e, 38                   ; DY low
        call    vc_wvreg
        ld      a, [lf_dy + 1]
        ld      d, a
        ld      e, 39                   ; DY high
        call    vc_wvreg
        ld      a, [lf_nx]
        ld      d, a
        ld      e, 40                   ; NX low
        call    vc_wvreg
        ld      a, [lf_nx + 1]
        ld      d, a
        ld      e, 41                   ; NX high
        call    vc_wvreg
        ld      a, [lf_ny]
        ld      d, a
        ld      e, 42                   ; NY low
        call    vc_wvreg
        ld      a, [lf_ny + 1]
        ld      d, a
        ld      e, 43                   ; NY high
        call    vc_wvreg
        ld      d, 15                   ; R#44 FG color
        ld      e, 44
        call    vc_wvreg
        ld      d, 4                    ; R#12 BG color
        ld      e, 12
        call    vc_wvreg
        ld      d, 0                    ; R#45 ARG = 0
        ld      e, 45
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

lf_dx:  dw      0
lf_dy:  dw      0
lf_nx:  dw      0
lf_ny:  dw      0
lf_ce_ok: db    0
chk_fail: db    0
v1:     db      0
v2:     db      0
v3:     db      0

;---------------------------------------------------------------------
; font: char0 = FFh x16, char1 = 0Fh x16, char2 = C3h x16
;---------------------------------------------------------------------
font3:
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF
        db      0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F
        db      0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F, 0x0F
        db      0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3
        db      0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3

regs_b03:
        db      0x06, 0         ; R#0  Graphic4 (SCREEN 5)
        db      0x40, 1         ; R#1  BL=1
        db      0x1F, 2         ; R#2  page 0 at 00000h
        db      0x04, 7         ; R#7  border = 4
        db      0x0A, 8         ; R#8  VR=1, SPD=1 (sprites off)
        db      0x00, 9         ; R#9  LN=0
        db      0x00, 14        ; R#14
        db      0x00, 20        ; R#20
        db      0x00, 21        ; R#21 V58=0 (extended mode)
        db      0x00, 23        ; R#23
        db      0x00, 0xFF

;---------------------------------------------------------------------
; strings
;---------------------------------------------------------------------
s_intro1:
        db      "TB03: LFMM EDGE AND NX (B03)", 0x0A, 0x0A
        db      "V9968 PORT: ", 0
s_intro2:
        db      "H", 0x0A, 0x0A
        db      "GRAPHIC4. BACKGROUND = COLOR 2.", 0x0A
        db      "FONT: 3 CHARS AT VRAM 10000H.", 0x0A, 0x0A
        db      " CASE 1: DX=252 NX=3 (CROSSES EDGE)", 0x0A
        db      " CASE 2: DX=64  NX=2", 0x0A
        db      " CASE 3: DX=128 NX=3 (CONTROL)", 0x0A, 0x0A
        db      "EACH CASE: VIEW, PRESS ANY KEY.", 0x0A
        db      "RESULTS (CE + VRAM READBACK)", 0x0A
        db      "ARE SHOWN AT THE END.", 0x0A, 0x0A
        db      "PRESS ANY KEY", 0

s_res1:
        db      "B03 RESULTS (LFMM)", 0x0A, 0x0A
        db      "CASE 1 RIGHT EDGE CLIP :", 0
s_res2:
        db      0x0A, "CASE 2 NX = CHAR COUNT :", 0
s_res3:
        db      0x0A, "CASE 3 NORMAL DRAWING  :", 0
s_pass:
        db      " PASS", 0
s_ng:
        db      " NG", 0
s_res_tail:
        db      0x0A, 0x0A
        db      "CE (COMMAND END) WAS CHECKED IN", 0x0A
        db      "EACH CASE; VRAM WAS READ BACK.", 0x0A, 0x0A
        db      "ITEM B03 IS OK IF ALL ARE PASS.", 0x0A, 0x0A
        db      "PRESS ANY KEY TO EXIT", 0

        include "vdpcom.inc"
