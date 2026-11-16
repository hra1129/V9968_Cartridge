;=====================================================================
; TB02.COM - hesoten report B02: false sprite collision with S16
;
; Bug (old RTL, up to v0.99.5): with S16=1 (R#20 bit7) in sprite
; mode 1/2, plane selection stopped only when 16 planes had been
; selected. On a line with fewer than 16 sprites, the attribute
; scan wrapped after plane 31 and selected plane 0 a second time,
; so plane 0 collided with itself and S#0's C bit was set every
; frame (in SCREEN 8 a ghost sprite also appeared).
; Fixed in v0.99.6 (vdp_sprite_select_visible_planes.v): with S16,
; selection also stops when all 32 planes have been scanned
; (ff_plane_count[5]).
;
; Cases (S16=1 throughout, 8x8 sprites, solid pattern):
;   1. Mode 1 (SCREEN 1): plane 0 alone at the top, planes 1-16
;      and 17-31 on two lower rows, nothing overlapping, and NO
;      terminator entry in the attribute table.
;      -> C must be 0. Old RTL: C = 1 (plane 0 selected twice).
;   2. Mode 1: planes 0/1 overlapped, terminator at plane 2.
;      -> C must be 1.
;   3. Mode 2 (SCREEN 5): same layout as case 1. -> C must be 0.
;   4. Mode 2: overlapped. -> C must be 1, and the collision
;      coordinates (S#3-S#6) must read X=104, Y=80.
; Each scene is shown until a key is pressed. Stale flags from the
; previous scene are discarded (S#0/S#5 read) after 1 display-off
; frame; S#0 is then read 2 frames after display on. Verdicts are
; summarised on the final text screen.
;=====================================================================
        org     0x0100
start:
        call    vc_detect
        jp      nc, vc_notfound
        call    vc_save_vram

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

        ;---------------- mode 1 ----------------
        call    setup_g1
        ld      hl, sat_m1_a
        ld      de, 0x1B00
        ld      a, 0
        call    run_case
        ld      [res1], a
        call    vc_wait_key
        ld      hl, sat_m1_b
        ld      de, 0x1B00
        ld      a, 0
        call    run_case
        ld      [res2], a
        call    vc_wait_key

        ;---------------- mode 2 ----------------
        call    setup_g4
        ld      hl, sat_m2_a
        ld      de, 0x7600
        ld      a, 1
        call    run_case
        ld      [res3], a
        call    vc_wait_key
        ld      hl, sat_m2_b
        ld      de, 0x7600
        ld      a, 1
        call    run_case
        ld      [res4], a
        ; collision coordinates (mode 2, case 4)
        ld      d, 3
        call    vc_read_status
        ld      [col_xl], a
        ld      d, 4
        call    vc_read_status
        ld      [col_xh], a
        ld      d, 5
        call    vc_read_status
        ld      [col_yl], a
        ld      d, 6
        call    vc_read_status
        ld      [col_yh], a
        call    vc_wait_key

        ;---------------- results ----------------
        ld      d, 0xF4
        call    vc_text1_begin
        ld      hl, s_res_title
        call    vc_puts
        ; case 1: expect C=0
        ld      hl, s_case1
        call    vc_puts
        ld      a, [res1]
        ld      e, 0
        call    print_verdict
        ; case 2: expect C=1
        ld      hl, s_case2
        call    vc_puts
        ld      a, [res2]
        ld      e, 1
        call    print_verdict
        ; case 3: expect C=0
        ld      hl, s_case3
        call    vc_puts
        ld      a, [res3]
        ld      e, 0
        call    print_verdict
        ; case 4: expect C=1
        ld      hl, s_case4
        call    vc_puts
        ld      a, [res4]
        ld      e, 1
        call    print_verdict
        ; coordinates: X = ((S#4&1)<<8 | S#3) - 12, Y likewise - 8
        ld      hl, s_coord
        call    vc_puts
        ld      a, [col_xh]
        and     a, 1
        ld      h, a
        ld      a, [col_xl]
        ld      l, a
        ld      de, 12
        or      a, a
        sbc     hl, de
        call    vc_print_dec
        ld      hl, s_coord2
        call    vc_puts
        ld      a, [col_yh]
        and     a, 1
        ld      h, a
        ld      a, [col_yl]
        ld      l, a
        ld      de, 8
        or      a, a
        sbc     hl, de
        call    vc_print_dec
        ld      hl, s_res_tail
        call    vc_puts
        call    vc_wait_key
        jp      vc_restore_exit

;---------------------------------------------------------------------
; run_case - HL = SAT data (128 bytes), DE/A = SAT VRAM address.
; Turns display off, waits 1 frame, discards stale flags (S#0/S#5),
; writes SAT, turns display on, waits 2 frames, returns S#0 in A.
;---------------------------------------------------------------------
run_case:
        push    hl
        push    de
        push    af
        ld      d, 0x00                 ; R#1: display off
        ld      e, 1
        call    vc_wvreg
        ; Discard flags latched by the previous scene (it stays on
        ; screen during vc_wait_key and nothing reads S#0 meanwhile).
        ; Clear them only after a full display-off frame, so no flag
        ; from this case can be discarded.
        ld      b, 1
        call    vc_wait_frames
        ld      d, 0
        call    vc_read_status          ; S#0 (discard)
        ld      d, 5
        call    vc_read_status          ; S#5 (clear coordinates)
        pop     af
        pop     de
        pop     hl
        ld      bc, 128
        call    vc_vram_out
        ld      d, 0x40                 ; R#1: display on
        ld      e, 1
        call    vc_wvreg
        ; S#0 is not read until the verdict, so C accumulates over
        ; every frame displayed in this case.
        ld      b, 2
        call    vc_wait_frames
        ld      d, 0
        call    vc_read_status          ; S#0
        ret

;---------------------------------------------------------------------
; print_verdict - A = S#0 value, E = expected C bit (0/1).
; Prints " S#0=XX PASS" or " S#0=XX NG" plus newline.
;---------------------------------------------------------------------
print_verdict:
        push    af
        ld      hl, s_s0
        call    vc_puts
        pop     af
        push    af
        call    vc_print_hex8
        pop     af
        and     a, 0x20                 ; C bit
        jr      z, pv_c0
        ld      a, 1
        jr      pv_cmp
pv_c0:
        xor     a, a
pv_cmp:
        cp      a, e
        jr      z, pv_pass
        ld      hl, s_ng
        jr      pv_out
pv_pass:
        ld      hl, s_pass
pv_out:
        call    vc_puts
        ret

;---------------------------------------------------------------------
; Graphic1 (sprite mode 1) setup. Tables: PNT 1800h, CT 2800h,
; PGT 2000h, SAT 1B00h, SPGT 3000h. Background pattern 0 (blank),
; sprite pattern 0 = solid. S16=1 via regs table (R#20 = 80h).
;---------------------------------------------------------------------
setup_g1:
        ld      hl, regs_g1
        call    vc_set_regs
        ld      de, 0x1800              ; PNT: all pattern 0
        ld      a, 0
        ld      bc, 768
        ld      l, 0x00
        call    vc_vram_fill
        ld      de, 0x2000              ; PGT: all zero (blank)
        ld      a, 0
        ld      bc, 2048
        ld      l, 0x00
        call    vc_vram_fill
        ld      de, 0x2800              ; CT: FG=4 BG=4
        ld      a, 0
        ld      bc, 32
        ld      l, 0x44
        call    vc_vram_fill
        ld      de, 0x3000              ; SPGT: all zero...
        ld      a, 0
        ld      bc, 2048
        ld      l, 0x00
        call    vc_vram_fill
        ld      hl, spr_solid           ; ...pattern 0 = solid
        ld      de, 0x3000
        ld      a, 0
        ld      bc, 8
        call    vc_vram_out
        ret

;---------------------------------------------------------------------
; Graphic4 (sprite mode 2) setup. Page 0 filled with color 4,
; SAT 7600h, color table 7400h, SPGT 8000h pattern 0 = solid.
; Color table: plane 0 = 15, planes 1-16 = 11, planes 17-31 = 8.
;---------------------------------------------------------------------
setup_g4:
        ld      hl, regs_g4
        call    vc_set_regs
        ld      de, 0x0000              ; page 0 fill, block 0
        ld      a, 0
        ld      bc, 16384
        ld      l, 0x44
        call    vc_vram_fill
        ld      de, 0x4000              ; page 0 fill, block 1
        ld      a, 1
        ld      bc, 10752
        ld      l, 0x44
        call    vc_vram_fill
        ld      hl, spr_solid           ; SPGT pattern 0 = solid
        ld      de, 0x8000
        ld      a, 2
        ld      bc, 8
        call    vc_vram_out
        ; color table at 7400h: 32 planes x 16 bytes
        ld      hl, 0x7400
        ld      a, 1
        call    vc_vaddr_w
        ld      a, [vdp_data]
        ld      c, a
        xor     a, a
        ld      [cg_plane], a
cg_plane_loop:
        ld      a, [cg_plane]
        or      a, a
        jr      z, cg_c15
        cp      a, 17
        jr      c, cg_c11
        ld      l, 8
        jr      cg_fill16
cg_c15:
        ld      l, 15
        jr      cg_fill16
cg_c11:
        ld      l, 11
cg_fill16:
        ld      b, 16
cg_byte_loop:
        out     [c], l
        djnz    cg_byte_loop
        ld      a, [cg_plane]
        inc     a
        ld      [cg_plane], a
        cp      a, 32
        jr      nz, cg_plane_loop
        ret
cg_plane: db    0

spr_solid:
        db      0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF

;---------------------------------------------------------------------
; register tables (R#1 = 0: display off; run_case turns it on)
;---------------------------------------------------------------------
regs_g1:
        db      0x00, 0         ; R#0  Graphic1
        db      0x00, 1         ; R#1  BL=0 (SI=0, MAG=0)
        db      0x06, 2         ; R#2  PNT = 1800h
        db      0xA0, 3         ; R#3  CT = 2800h
        db      0x04, 4         ; R#4  PGT = 2000h
        db      0x36, 5         ; R#5  SAT = 1B00h
        db      0x06, 6         ; R#6  SPGT = 3000h
        db      0x44, 7         ; R#7  backdrop = 4
        db      0x08, 8         ; R#8  VR=1, TP=0
        db      0x00, 9         ; R#9  LN=0
        db      0x00, 10        ; R#10
        db      0x00, 11        ; R#11
        db      0x00, 14        ; R#14
        db      0x80, 20        ; R#20 S16=1
        db      0x00, 21        ; R#21 V58=0
        db      0x00, 23        ; R#23
        db      0x00, 0xFF

regs_g4:
        db      0x06, 0         ; R#0  Graphic4 (SCREEN 5)
        db      0x00, 1         ; R#1  BL=0
        db      0x1F, 2         ; R#2  page 0 at 00000h
        db      0xEC, 5         ; R#5  SAT = 7600h
        db      0x10, 6         ; R#6  SPGT = 8000h
        db      0x04, 7         ; R#7  border = 4
        db      0x08, 8         ; R#8  VR=1, TP=0
        db      0x00, 9         ; R#9  LN=0
        db      0x00, 11        ; R#11
        db      0x00, 14        ; R#14
        db      0x80, 20        ; R#20 S16=1
        db      0x00, 21        ; R#21 V58=0
        db      0x00, 23        ; R#23
        db      0x00, 0xFF

;---------------------------------------------------------------------
; SAT data. Mode 1 entry: Y, X, pattern, color. Mode 2: Y, X,
; pattern, unused. Y = top line - 1.
; Case A layout: plane 0 at (100, 40); planes 1-16 at Y=99,
; X = 0,16,...,240; planes 17-31 at Y=119, X = 8,24,...,232.
;---------------------------------------------------------------------
sat_m1_a:
        db      39, 100, 0, 15
        db      99, 0, 0, 11
        db      99, 16, 0, 11
        db      99, 32, 0, 11
        db      99, 48, 0, 11
        db      99, 64, 0, 11
        db      99, 80, 0, 11
        db      99, 96, 0, 11
        db      99, 112, 0, 11
        db      99, 128, 0, 11
        db      99, 144, 0, 11
        db      99, 160, 0, 11
        db      99, 176, 0, 11
        db      99, 192, 0, 11
        db      99, 208, 0, 11
        db      99, 224, 0, 11
        db      99, 240, 0, 11
        db      119, 8, 0, 8
        db      119, 24, 0, 8
        db      119, 40, 0, 8
        db      119, 56, 0, 8
        db      119, 72, 0, 8
        db      119, 88, 0, 8
        db      119, 104, 0, 8
        db      119, 120, 0, 8
        db      119, 136, 0, 8
        db      119, 152, 0, 8
        db      119, 168, 0, 8
        db      119, 184, 0, 8
        db      119, 200, 0, 8
        db      119, 216, 0, 8
        db      119, 232, 0, 8

sat_m1_b:
        db      79, 100, 0, 15
        db      79, 104, 0, 11
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0
        db      208, 0, 0, 0

sat_m2_a:
        db      39, 100, 0, 0
        db      99, 0, 0, 0
        db      99, 16, 0, 0
        db      99, 32, 0, 0
        db      99, 48, 0, 0
        db      99, 64, 0, 0
        db      99, 80, 0, 0
        db      99, 96, 0, 0
        db      99, 112, 0, 0
        db      99, 128, 0, 0
        db      99, 144, 0, 0
        db      99, 160, 0, 0
        db      99, 176, 0, 0
        db      99, 192, 0, 0
        db      99, 208, 0, 0
        db      99, 224, 0, 0
        db      99, 240, 0, 0
        db      119, 8, 0, 0
        db      119, 24, 0, 0
        db      119, 40, 0, 0
        db      119, 56, 0, 0
        db      119, 72, 0, 0
        db      119, 88, 0, 0
        db      119, 104, 0, 0
        db      119, 120, 0, 0
        db      119, 136, 0, 0
        db      119, 152, 0, 0
        db      119, 168, 0, 0
        db      119, 184, 0, 0
        db      119, 200, 0, 0
        db      119, 216, 0, 0
        db      119, 232, 0, 0

sat_m2_b:
        db      79, 100, 0, 0
        db      79, 104, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0
        db      216, 0, 0, 0

res1:   db      0
res2:   db      0
res3:   db      0
res4:   db      0
col_xl: db      0
col_xh: db      0
col_yl: db      0
col_yh: db      0

;---------------------------------------------------------------------
; strings
;---------------------------------------------------------------------
s_intro1:
        db      "TB02: S16 FALSE COLLISION (B02)", 0x0A, 0x0A
        db      "V9968 PORT: ", 0
s_intro2:
        db      "H", 0x0A, 0x0A
        db      "S16=1 (R20 BIT7). 4 CASES:", 0x0A
        db      " 1. MODE1, 32 SPRITES, NO OVERLAP", 0x0A
        db      " 2. MODE1, 2 SPRITES OVERLAPPED", 0x0A
        db      " 3. MODE2, 32 SPRITES, NO OVERLAP", 0x0A
        db      " 4. MODE2, 2 SPRITES OVERLAPPED", 0x0A, 0x0A
        db      "CASES 1/3: OLD RTL SETS COLLISION", 0x0A
        db      "(PLANE 0 GETS SELECTED TWICE).", 0x0A
        db      "CASES 2/4 MUST SET COLLISION.", 0x0A, 0x0A
        db      "WATCH EACH SCENE, PRESS ANY KEY.", 0x0A
        db      "RESULTS ARE SHOWN AT THE END.", 0x0A, 0x0A
        db      "PRESS ANY KEY", 0

s_res_title:
        db      "B02 RESULTS (S16=1)", 0x0A, 0x0A, 0
s_case1:
        db      "CASE 1 MODE1 NO OVERLAP: C=0", 0
s_case2:
        db      0x0A, "CASE 2 MODE1 OVERLAP   : C=1", 0
s_case3:
        db      0x0A, "CASE 3 MODE2 NO OVERLAP: C=0", 0
s_case4:
        db      0x0A, "CASE 4 MODE2 OVERLAP   : C=1", 0
s_s0:
        db      " S#0=", 0
s_pass:
        db      " PASS", 0x0A, 0
s_ng:
        db      " NG", 0x0A, 0
s_coord:
        db      0x0A, "CASE 4 HIT POSITION: X=", 0
s_coord2:
        db      " Y=", 0
s_res_tail:
        db      0x0A, "(EXPECTED: X=104 Y=80)", 0x0A, 0x0A
        db      "ITEM B02 IS OK IF ALL 4 ARE PASS.", 0x0A, 0x0A
        db      "PRESS ANY KEY TO EXIT", 0

        include "vdpcom.inc"
