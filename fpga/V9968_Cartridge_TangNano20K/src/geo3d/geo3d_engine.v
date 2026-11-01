// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Alex Moncks
// ============================================================================
// geo3d_engine.v  (phase 2)  -  geo3d v2.0
//
// v2.0 keeps every register and stream of v1.0.0 as it was (a v1.0.0
// program sends the same bytes and gets the same commands) and adds:
//   - 1023 vertices, edges and faces (v1.0.0: 255): the counts and the
//     write pointers have 10 bits, their high bits in 0x68-0x6E
//   - XCTRL (0x6F) bit0, the extended mode: the write pointers count on
//     their 10 bits and the edge and face streams carry 10-bit indices
//   - VFIRST, EFIRST, FFIRST: where the transform, edge and face phases of
//     a RUN start (reset: 0, as in v1.0.0)
//   - an ID at 0x49 (0x20; v1.0.0 reads 0xFF)
//   - the same pictures in less time: the painter's order from a heap (about
//     log2(n) steps a face, v1.0.0 scanned the n visible faces for each
//     one), a divider of two bits a clock for the spans, the 4 vertices of a
//     face read back to back
//
// Wireframe renderer that drives the V9968 command engine directly, so the
// Z80 only uploads the model once and then sends one matrix + RUN per frame.
//
//   Z80 ──(2 I/O ports)──> geo3d_engine ──(R#36..R#46 writes, CE)──> V9968
//
// Per RUN:
//   1. Transform phase: every vertex in vertex RAM goes through geo3d_core
//      (matrix, translation, perspective). Results go to the projected RAM.
//   2. Edge phase: for every edge (pair of vertex indices):
//        - edges touching a vertex behind the near plane or with a saturated
//          projection are skipped (counted in SKIPPED)
//        - edges trivially outside the screen are culled (counted in CULLED)
//        - otherwise the edge is clipped to [0,W) x [0,H) by midpoint
//          bisection (no divider) and emitted as a LINE command
//   3. The command issuer writes R#36..R#46 whenever the VDP is idle (CE=0),
//      while the clipper already prepares the next edge (1-deep pipeline).
//
// Z80 register window (index written on port SEL=0, data on port SEL=1):
//   0x00-0x23  geo3d_core configuration (M00..M22, TX,TY,TZ, F, CX, CY,
//              ZNEAR, W, H) little-endian words, auto-increment
//   0x24-0x29  immediate vertex (phase 1 mode, write of 0x29 computes one
//              vertex; index wraps back to 0x24)
//   0x30-0x36  immediate results SX, SY, Z, FLAGS (read, wraps at 0x36)
//   0x40 VADDR   vertex RAM write pointer (low byte; high bits: 0x68)
//   0x41 EADDR   edge RAM write pointer (low byte; high bits: 0x69)
//   0x42 NVERT   number of vertices to transform (low byte; high bits: 0x6A)
//   0x43 NEDGE   number of edges (low byte; high bits: 0x6B)
//   0x44 COLOR   LINE colour (R#44)
//   0x45 LOP     logical operation (low nibble of R#46)
//   0x46-0x47 YPAGE  added to every DY (page select), 11 bits
//   0x48 CTRL    write bit0=1: RUN, bit1: 0 = wireframe (edges), 1 = filled
//                faces, bit2: 1 = textured faces allowed (see below).
//                read: status (see below)
//   0x49 ID      read: 0x20 = geo3d v2.0 (v1.0.0: 0xFF)
//   0x4A-0x4B SKIPPED (read)  0x4C-0x4D DRAWN (read)  0x4E-0x4F CULLED (read)
//   0x50 VDATA   vertex stream: 6 bytes (VX,VY,VZ little-endian) per vertex,
//                stored at VADDR, VADDR auto-increments. Index does not move.
//   0x51 EDATA   edge stream: 2 bytes (index A, index B) per edge, stored at
//                EADDR, EADDR auto-increments. Index does not move.
//   0x52 FDATA   face stream: 11 bytes per face (I0, I1, I2, I3 vertex
//                indices, NX, NY, NZ model normal in Q2.14 little-endian,
//                BASE colour), stored at FADDR, FADDR auto-increments.
//   0x58 FADDR   face RAM write pointer (low byte; high bits: 0x6C)
//   0x59 NFACE   number of faces (low byte; high bits: 0x6D)
//   0x5A-0x5F LX, LY, LZ  light direction (towards the light) in camera
//                space, Q2.14 words
//   0x53 TDATA   texture-coordinate stream: 8 bytes per face (U0 V0 U1 V1
//                U2 V2 U3 V3, texels, unsigned), stored at TADDR, TADDR
//                auto-increments.
//   0x60-0x61 TEXX     texture origin X in VRAM (9 bits)
//   0x62-0x63 TEXY     texture origin Y in VRAM (13 bits, e.g. 512 = page 2)
//   0x64 TSTRIDE       rows between the pre-shaded copies of the texture
//   0x65 TADDR         texture-coordinate RAM write pointer (low byte; high
//                      bits: 0x6E)
//   v2.0:
//   0x54-0x55 VFIRST   first vertex of the transform phase (10 bits): a RUN
//                      transforms NVERT vertices from VFIRST on
//   0x56-0x57 FFIRST   first face of the face phase: NFACE faces from it on
//   0x66-0x67 EFIRST   first edge of the edge phase: NEDGE edges from it on
//                      (the three go around the end of their RAM, 1023 -> 0)
//   0x68 VADDR_H  0x69 EADDR_H  0x6A NVERT_H  0x6B NEDGE_H  0x6C FADDR_H
//   0x6D NFACE_H  0x6E TADDR_H   bits 9-8 of the register of the same name
//   0x6F XCTRL    read, bits 7-4: the address bits of the model RAMs (10:
//                 1024 entries each; the AW parameter of this module. A
//                 build with AW = 9 has 512 and counts in 9 bits: entry n
//                 and entry n + 512 are the same)
//                 bit0 = 1: extended mode.
//                 - the write pointers add 1 on their 10 bits. With bit0 = 0
//                   only their low byte counts and wraps at 256, as in
//                   v1.0.0 (the high bits stay as written)
//                 - EDATA takes 3 bytes an edge: A, B (low bytes), then the
//                   high bits (A in bits 1-0, B in bits 3-2)
//                 - FDATA takes 12 bytes a face: I0, I1, I2, I3 (low bytes),
//                   the high bits (I0 in bits 1-0, I1 in 3-2, I2 in 5-4, I3
//                   in 7-6), then NX, NY, NZ and BASE as in v1.0.0
//                 The vertex and texture-coordinate streams do not change.
//   Indices 0x40-0x4F, 0x54-0x57, 0x58-0x5F, 0x60-0x67 and 0x68-0x6F
//   auto-increment (wrap inside the block).
//   Writing the index (port SEL=0) resets the stream byte counters.
//
// Status (port SEL=0 read, no side effects):
//   bit0 RUN busy   bit1 transform phase   bit2 edge phase
//   bit3 core busy  bit7..4 immediate-mode outcodes
//
// Rules for the Z80 while RUN busy = 1:
//   - do not write VDP command registers R#32..R#46
//   - do not write geo3d configuration or model RAM
// Clearing the screen (HMMV) and page flipping stay with the Z80.
//
// Filled-face mode (CTRL bit1 = 1), per RUN after the transform phase:
//   a. LM = transpose(R) * L, the light in model space (9 multiplies)
//   b. per face: skip if a vertex is behind the near plane or saturated;
//      back-face cull by the sign of the projected area of I0, I1, I2
//      (visible when area > 0; screen y grows downwards, so a visible face
//      runs clockwise seen from outside with x right and y up, i.e.
//      cross(V1 - V0, V2 - V0) points outwards); shade level =
//      min(6, 7 * max(0, LM . N)), colour =
//      BASE + level; depth key = sum of the 4 camera-space Z
//   c. painter's order: farthest key first, ties by lower face number (the
//      visible faces are kept in a heap since v2.0: same order, less time)
//   d. each face (convex quad; triangles repeat a vertex) is filled row by
//      row: the span between the leftmost and rightmost edge crossing,
//      clipped to the screen, is sent as a horizontal LINE command. The V9968
//      may execute an opaque SCREEN 8 span using its HMMV write path.
//   Counters in this mode: SKIPPED = near faces, CULLED = back faces,
//   DRAWN = faces drawn.
//
// Textured faces (CTRL bit2 = 1 and bit7 of the face BASE colour set): each
// row is sent as a single-row LRMM instead of a LINE, so the V9968 copies the
// texels itself. Texture coordinates are interpolated along the edges (8.8
// fixed point, floor division) and the per-pixel source step VX, VY is
// (end - start) / width. The source row is offset by level * TSTRIDE, so the
// Z80 can store 7 pre-shaded copies of the texture and keep flat shading.
// LRMM needs the V9968 extended commands enabled (R#20 ECOM, PORT#4 unlock).
// SX has no fraction in LRMM, so each row starts on a whole texel.
//
// Limits: W <= 512, H <= 1024 (VDP coordinate range). Edges crossing the near
// plane are skipped (3D near-plane clipping is future work).
// ============================================================================
module geo3d_engine #(
    parameter AW = 10                         // address bits of the model RAMs: 2^AW entries
)(
    input  wire        clk,
    input  wire        rst,
    // Z80 side (strobes are one clock wide, already synchronised)
    input  wire        sel,
    input  wire        wr_stb,
    input  wire        rd_stb,
    input  wire [7:0]  din,
    output reg  [7:0]  dout,
    // V9968 command master port
    output reg         cmd_wr,
    output reg  [5:0]  cmd_num,
    output reg  [7:0]  cmd_data,
    output reg         cmd_fill_span,
    input  wire        cmd_ce,
    output wire        run_busy
);
    localparam [7:0] GEO3D_ID = 8'h20;        // index 0x49: v2.0
    wire [3:0] AW_BITS = AW;                  // read in XCTRL bits 7-4

    // ------------------------------------------------------------------ core
    wire [15:0] c_sx, c_sy, c_z;
    wire [7:0]  c_flags;
    wire        c_busy, c_done;

    reg         z_core_wr;
    reg  [4:0]  z_core_addr;
    reg  [15:0] z_core_data;
    reg         e_core_wr;
    reg  [4:0]  e_core_addr;
    reg  [15:0] e_core_data;

    wire        core_wr   = e_core_wr | z_core_wr;
    wire [4:0]  core_addr = e_core_wr ? e_core_addr : z_core_addr;
    wire [15:0] core_data = e_core_wr ? e_core_data : z_core_data;

    geo3d_core u_core (
        .clk(clk), .rst(rst),
        .wr_en(core_wr), .wr_addr(core_addr), .wr_data(core_data),
        .sx(c_sx), .sy(c_sy), .zout(c_z), .flags(c_flags),
        .busy(c_busy), .done_pulse(c_done)
    );

    // Shadow copies of W and H (the clipper needs them)
    reg signed [15:0] scr_w, scr_h;
    reg signed [16:0] scr_wm1, scr_hm1;       // W-1, H-1 (registered for timing)

    // ------------------------------------------------------------ model RAMs
    // 1024 entries each since v2.0 (v1.0.0: 256)
    reg [47:0] vmem [0:(1 << AW) - 1];     // VZ, VY, VX
    reg [19:0] emem [0:(1 << AW) - 1];     // B, A (10 bits each)
    reg [50:0] pmem [0:(1 << AW) - 1];     // Z, FLAGS (near, ovf x, ovf y), SY, SX

    reg        vwe;  reg [9:0] vwa;  reg [47:0] vwd;
    reg [9:0]  vra;  reg [47:0] vrd;
    reg        ewe;  reg [9:0] ewa;  reg [19:0] ewd;
    reg [9:0]  era;  reg [19:0] erd;
    reg        pwe;  reg [9:0] pwa;  reg [50:0] pwd;
    reg [9:0]  pra;  reg [50:0] prd;

    always @(posedge clk) begin
        if (vwe) vmem[vwa[AW-1:0]] <= vwd;
        vrd <= vmem[vra[AW-1:0]];
    end
    always @(posedge clk) begin
        if (ewe) emem[ewa[AW-1:0]] <= ewd;
        erd <= emem[era[AW-1:0]];
    end
    always @(posedge clk) begin
        if (pwe) pmem[pwa[AW-1:0]] <= pwd;
        prd <= pmem[pra[AW-1:0]];
    end

    reg [95:0] fmem [0:(1 << AW) - 1];     // BASE, NZ, NY, NX, I3, I2, I1, I0 (10 bits each)
    reg [30:0] smem [0:(1 << AW) - 1];     // visible faces, a heap: KEY(18), FACE(10), LEVEL(3)
    reg [63:0] tmem [0:(1 << AW) - 1];     // texture coords: V3 U3 V2 U2 V1 U1 V0 U0
    reg        twe;  reg [9:0] twa;  reg [63:0] twd;
    reg [9:0]  tra;  reg [63:0] trd;
    reg        fwe;  reg [9:0] fwa;  reg [95:0] fwd;
    reg [9:0]  fra;  reg [95:0] frd;
    reg        swe;  reg [9:0] swa;  reg [30:0] swd;
    reg [9:0]  sra;  reg [30:0] srd;

    always @(posedge clk) begin
        if (fwe) fmem[fwa[AW-1:0]] <= fwd;
        frd <= fmem[fra[AW-1:0]];
    end
    always @(posedge clk) begin
        if (swe) smem[swa[AW-1:0]] <= swd;
        srd <= smem[sra[AW-1:0]];
    end
    always @(posedge clk) begin
        if (twe) tmem[twa[AW-1:0]] <= twd;
        trd <= tmem[tra[AW-1:0]];
    end

    // ------------------------------------------------------ Z80 registers
    reg  [7:0]  widx, rptr, lo_latch;
    reg  [9:0]  vaddr_w, eaddr_w, nvert, nedge;
    reg  [9:0]  vfirst, efirst, ffirst;       // v2.0: where each phase starts
    reg         ext;                          // v2.0: XCTRL bit0, extended mode
    reg  [7:0]  color;
    reg  [3:0]  lop;
    reg  [10:0] ypage;
    reg  [39:0] vbuf;
    reg  [2:0]  vbc;
    reg  [15:0] ebuf;
    reg  [1:0]  ebc;
    reg         run_req;
    reg         ctrl_face, ctrl_tex;
    reg  [8:0]  texx;
    reg  [12:0] texy;
    reg  [7:0]  tstride;
    reg  [9:0]  taddr_w;
    reg  [55:0] tbuf;
    reg  [2:0]  tbc;
    reg  [9:0]  faddr_w, nface;
    reg  [87:0] fbuf;
    reg  [3:0]  fbc;
    reg signed [15:0] lreg [0:2];     // light LX, LY, LZ (Q2.14)
    reg signed [15:0] msh  [0:8];     // shadow of M00..M22 (Q2.14)
    integer     q;
    reg  [15:0] cnt_skip, cnt_draw, cnt_cull;

    // phase flags (driven by the engine FSM below)
    reg         ph_run, ph_xf, ph_edge;
    assign run_busy = ph_run;

    wire [7:0] status = {c_flags[7:4], c_busy, ph_edge, ph_xf, ph_run};

    function [7:0] next_idx;
        input [7:0] i;
        begin
            if (i[7:4] == 4'h4)      next_idx = {4'h4, i[3:0] + 4'd1};
            else if (i[7:2] == 6'b010101) next_idx = {6'b010101, i[1:0] + 2'd1};
            else if (i[7:3] == 5'b01011) next_idx = {5'b01011, i[2:0] + 3'd1};
            else if (i[7:3] == 5'b01100) next_idx = {5'b01100, i[2:0] + 3'd1};
            else if (i[7:3] == 5'b01101) next_idx = {5'b01101, i[2:0] + 3'd1};
            else if (i == 8'h29)     next_idx = 8'h24;
            else if (i < 8'h40)      next_idx = i + 8'd1;
            else                     next_idx = i;
        end
    endfunction

    // a write pointer after an entry: 10 bits in extended mode; otherwise
    // only the low byte counts, as in v1.0.0 (it wraps at 256)
    function [9:0] ptr_inc;
        input [9:0] p;
        input       e;
        begin
            ptr_inc = e ? p + 10'd1 : {p[9:8], p[7:0] + 8'd1};
        end
    endfunction

    // the stream words as the Z80 sent them, low byte first
    wire [87:0] fraw11 = {din, fbuf[87:8]};   // v1.0.0 face: 11 bytes
    wire [95:0] fraw12 = {din, fbuf};         // extended face: 12 bytes

    reg [7:0] rdata;
    always @(*) begin
        case (rptr)
            8'h30: rdata = c_sx[7:0];
            8'h31: rdata = c_sx[15:8];
            8'h32: rdata = c_sy[7:0];
            8'h33: rdata = c_sy[15:8];
            8'h34: rdata = c_z[7:0];
            8'h35: rdata = c_z[15:8];
            8'h36: rdata = c_flags;
            8'h40: rdata = vaddr_w[7:0];
            8'h41: rdata = eaddr_w[7:0];
            8'h42: rdata = nvert[7:0];
            8'h43: rdata = nedge[7:0];
            8'h44: rdata = color;
            8'h45: rdata = {4'd0, lop};
            8'h46: rdata = ypage[7:0];
            8'h47: rdata = {5'd0, ypage[10:8]};
            8'h48: rdata = status;
            8'h49: rdata = GEO3D_ID;
            8'h4A: rdata = cnt_skip[7:0];
            8'h4B: rdata = cnt_skip[15:8];
            8'h4C: rdata = cnt_draw[7:0];
            8'h4D: rdata = cnt_draw[15:8];
            8'h4E: rdata = cnt_cull[7:0];
            8'h4F: rdata = cnt_cull[15:8];
            8'h54: rdata = vfirst[7:0];
            8'h55: rdata = {6'd0, vfirst[9:8]};
            8'h56: rdata = ffirst[7:0];
            8'h57: rdata = {6'd0, ffirst[9:8]};
            8'h58: rdata = faddr_w[7:0];
            8'h59: rdata = nface[7:0];
            8'h65: rdata = taddr_w[7:0];
            8'h66: rdata = efirst[7:0];
            8'h67: rdata = {6'd0, efirst[9:8]};
            8'h68: rdata = {6'd0, vaddr_w[9:8]};
            8'h69: rdata = {6'd0, eaddr_w[9:8]};
            8'h6A: rdata = {6'd0, nvert[9:8]};
            8'h6B: rdata = {6'd0, nedge[9:8]};
            8'h6C: rdata = {6'd0, faddr_w[9:8]};
            8'h6D: rdata = {6'd0, nface[9:8]};
            8'h6E: rdata = {6'd0, taddr_w[9:8]};
            8'h6F: rdata = {AW_BITS, 3'd0, ext};
            default: rdata = 8'hFF;
        endcase
    end

    always @(posedge clk) begin
        if (rst) begin
            widx <= 8'h00; rptr <= 8'h30; lo_latch <= 8'h00;
            vaddr_w <= 10'd0; eaddr_w <= 10'd0; nvert <= 10'd0; nedge <= 10'd0;
            vfirst <= 10'd0; efirst <= 10'd0; ffirst <= 10'd0; ext <= 1'b0;
            color <= 8'd15; lop <= 4'd0; ypage <= 11'd0;
            vbc <= 3'd0; ebc <= 2'd0; run_req <= 1'b0;
            z_core_wr <= 1'b0; vwe <= 1'b0; ewe <= 1'b0;
            dout <= 8'hFF;
            scr_w <= 16'sd256; scr_h <= 16'sd212;
            scr_wm1 <= 17'sd255; scr_hm1 <= 17'sd211;
            ctrl_face <= 1'b0; faddr_w <= 10'd0; nface <= 10'd0; fbc <= 4'd0; fwe <= 1'b0;
            ctrl_tex <= 1'b0; texx <= 9'd0; texy <= 13'd512; tstride <= 8'd0;
            taddr_w <= 10'd0; tbc <= 3'd0; twe <= 1'b0;
            lreg[0] <= 16'sd0; lreg[1] <= 16'sd0; lreg[2] <= -16'sd16384;
            for (q = 0; q < 9; q = q + 1) msh[q] <= 16'sd0;
        end else begin
            z_core_wr <= 1'b0;
            vwe       <= 1'b0;
            ewe       <= 1'b0;
            fwe       <= 1'b0;
            twe       <= 1'b0;
            run_req   <= 1'b0;

            if (wr_stb) begin
                if (!sel) begin
                    widx <= din; rptr <= din; vbc <= 3'd0; ebc <= 2'd0; fbc <= 4'd0; tbc <= 3'd0;
                end else begin
                    if (widx < 8'h2A) begin
                        if (!widx[0]) lo_latch <= din;
                        else begin
                            z_core_wr   <= 1'b1;
                            z_core_addr <= widx[5:1];
                            z_core_data <= {din, lo_latch};
                            if (widx[5:1] == 5'd16) begin
                                scr_w   <= {din, lo_latch};
                                scr_wm1 <= $signed({din[7], din, lo_latch}) - 17'sd1;
                            end
                            if (widx[5:1] == 5'd17) begin
                                scr_h   <= {din, lo_latch};
                                scr_hm1 <= $signed({din[7], din, lo_latch}) - 17'sd1;
                            end
                            if (widx[5:1] == 5'd20) rptr  <= 8'h30;
                            if (widx[5:1] < 5'd9)   msh[widx[4:1]] <= {din, lo_latch};
                        end
                    end else begin
                        case (widx)
                            8'h40: vaddr_w[7:0] <= din;
                            8'h41: eaddr_w[7:0] <= din;
                            8'h42: nvert[7:0]   <= din;
                            8'h43: nedge[7:0]   <= din;
                            8'h44: color   <= din;
                            8'h45: lop     <= din[3:0];
                            8'h46: ypage[7:0]  <= din;
                            8'h47: ypage[10:8] <= din[2:0];
                            8'h48: begin run_req <= din[0]; ctrl_face <= din[1]; ctrl_tex <= din[2]; end
                            8'h50: begin
                                if (vbc == 3'd5) begin
                                    vwe <= 1'b1; vwa <= vaddr_w; vwd <= {din, vbuf};
                                    vaddr_w <= ptr_inc(vaddr_w, ext);
                                    vbc <= 3'd0;
                                end else begin
                                    vbuf <= {din, vbuf[39:8]};
                                    vbc  <= vbc + 3'd1;
                                end
                            end
                            // edge: A, B; extended: then a byte with the
                            // high bits (A in bits 1-0, B in bits 3-2)
                            8'h51: begin
                                if (ebc == (ext ? 2'd2 : 2'd1)) begin
                                    ewe <= 1'b1; ewa <= eaddr_w;
                                    ewd <= ext ? {din[3:2], ebuf[15:8], din[1:0], ebuf[7:0]}
                                               : {2'd0, din, 2'd0, ebuf[7:0]};
                                    eaddr_w <= ptr_inc(eaddr_w, ext);
                                    ebc <= 2'd0;
                                end else begin
                                    if (ebc == 2'd0) ebuf[7:0]  <= din;
                                    else             ebuf[15:8] <= din;
                                    ebc <= ebc + 2'd1;
                                end
                            end
                            // face: I0 I1 I2 I3, NX NY NZ, BASE; extended: a
                            // byte with the two high bits of each index
                            // (I0 in bits 1-0 ... I3 in bits 7-6) follows I3
                            8'h52: begin
                                if (fbc == (ext ? 4'd11 : 4'd10)) begin
                                    fwe <= 1'b1; fwa <= faddr_w;
                                    fwd <= ext ? {fraw12[95:40],
                                                  fraw12[39:38], fraw12[31:24], fraw12[37:36], fraw12[23:16],
                                                  fraw12[35:34], fraw12[15:8],  fraw12[33:32], fraw12[7:0]}
                                               : {fraw11[87:32],
                                                  2'd0, fraw11[31:24], 2'd0, fraw11[23:16],
                                                  2'd0, fraw11[15:8],  2'd0, fraw11[7:0]};
                                    faddr_w <= ptr_inc(faddr_w, ext);
                                    fbc <= 4'd0;
                                end else begin
                                    fbuf <= {din, fbuf[87:8]};
                                    fbc  <= fbc + 4'd1;
                                end
                            end
                            8'h53: begin
                                if (tbc == 3'd7) begin
                                    twe <= 1'b1; twa <= taddr_w; twd <= {din, tbuf};
                                    taddr_w <= ptr_inc(taddr_w, ext);
                                    tbc <= 3'd0;
                                end else begin
                                    tbuf <= {din, tbuf[55:8]};
                                    tbc  <= tbc + 3'd1;
                                end
                            end
                            8'h54: vfirst[7:0] <= din;
                            8'h55: vfirst[9:8] <= din[1:0];
                            8'h56: ffirst[7:0] <= din;
                            8'h57: ffirst[9:8] <= din[1:0];
                            8'h60: texx[7:0]   <= din;
                            8'h61: texx[8]     <= din[0];
                            8'h62: texy[7:0]   <= din;
                            8'h63: texy[12:8]  <= din[4:0];
                            8'h64: tstride     <= din;
                            8'h65: taddr_w[7:0] <= din;
                            8'h66: efirst[7:0] <= din;
                            8'h67: efirst[9:8] <= din[1:0];
                            8'h68: vaddr_w[9:8] <= din[1:0];
                            8'h69: eaddr_w[9:8] <= din[1:0];
                            8'h6A: nvert[9:8]   <= din[1:0];
                            8'h6B: nedge[9:8]   <= din[1:0];
                            8'h6C: faddr_w[9:8] <= din[1:0];
                            8'h6D: nface[9:8]   <= din[1:0];
                            8'h6E: taddr_w[9:8] <= din[1:0];
                            8'h6F: ext          <= din[0];
                            8'h58: faddr_w[7:0] <= din;
                            8'h59: nface[7:0]   <= din;
                            8'h5A, 8'h5C, 8'h5E: lo_latch <= din;
                            8'h5B: lreg[0] <= {din, lo_latch};
                            8'h5D: lreg[1] <= {din, lo_latch};
                            8'h5F: lreg[2] <= {din, lo_latch};
                            default: ;
                        endcase
                    end
                    widx <= next_idx(widx);
                end
            end

            if (rd_stb) begin
                if (!sel) dout <= status;
                else begin
                    dout <= rdata;
                    if (rptr == 8'h36)          rptr <= 8'h30;
                    else if (rptr[7:4] == 4'h4) rptr <= {4'h4, rptr[3:0] + 4'd1};
                    else if (rptr >= 8'h30 && rptr < 8'h36) rptr <= rptr + 8'd1;
                end
            end
        end
    end

    // --------------------------------------------------------- clip helpers
    function [3:0] ocode;
        input signed [16:0] x;
        input signed [16:0] y;
        input signed [15:0] w;
        input signed [15:0] h;
        begin
            ocode[0] = (x < 17'sd0);
            ocode[1] = (x >= $signed({w[15], w}));
            ocode[2] = (y < 17'sd0);
            ocode[3] = (y >= $signed({h[15], h}));
        end
    endfunction

    function signed [16:0] mid;
        input signed [16:0] a;
        input signed [16:0] b;
        reg   signed [17:0] s;
        begin
            s   = {a[16], a} + {b[16], b};
            mid = s[17:1];               // floor((a+b)/2)
        end
    endfunction

    // --------------------------------------------------------- engine FSM
    localparam R_IDLE  = 6'd0,
               T_ADDR  = 6'd1,  T_W1 = 6'd2,  T_W2 = 6'd3,
               T_WY    = 6'd4,  T_WZ = 6'd5,  T_WAIT = 6'd6,
               E_START = 6'd7,  E_ADDR = 6'd8, E_W1 = 6'd9, E_W2 = 6'd10,
               E_PA1   = 6'd11, E_PA2 = 6'd12, E_PB1 = 6'd13, E_PB2 = 6'd14,
               E_CLASS = 6'd15, E_SRCH = 6'd16, E_E1 = 6'd17, E_BIS = 6'd18,
               E_BISE  = 6'd19, E_E2 = 6'd20, E_BUILD = 6'd21, E_NEXT = 6'd22,
               R_DRAIN = 6'd23,
               // filled-face mode
               L_OP    = 6'd24, L_ACC = 6'd25,
               F_START = 6'd26, F_ADDR = 6'd27, F_W1 = 6'd28, F_W2 = 6'd29,
               F_CHK   = 6'd33, F_A1 = 6'd34, F_A2 = 6'd35,
               F_S1    = 6'd36, F_S2 = 6'd37, F_S3 = 6'd38, F_NEXT = 6'd39,
               D_START = 6'd40, D_FW2 = 6'd46, D_YR = 6'd47,
               // (30-32 and 41-45 were v1.0.0's vertex fetch and selection sort)
               D_ROW   = 6'd48, D_EDGE = 6'd49, D_EMUL = 6'd50, D_DIV = 6'd51,
               D_DIVE  = 6'd52, D_ENEXT = 6'd53, D_SPAN = 6'd54, D_YNEXT = 6'd55,
               D_NEXTR = 6'd56, D_YR0 = 6'd57, F_S4 = 6'd58,
               D_SPAN0 = 6'd59, D_DIVE2 = 6'd60, D_EDGE0 = 6'd61, F_A3 = 6'd62,
               // textured faces
               D_DQ    = 7'd64, D_XQ  = 7'd65, D_UQ  = 7'd66, D_VQ  = 7'd67,
               D_CAND  = 7'd68, D_T0  = 7'd69, D_T1  = 7'd70, D_T2  = 7'd71,
               D_T3    = 7'd72, D_T4  = 7'd73, D_T5  = 7'd74,
               // v2.0: the 4 projected vertices of a face, read back to back
               V_A1    = 7'd75, V_A2  = 7'd76, V_A3  = 7'd77, V_A4  = 7'd78,
               V_A5    = 7'd79,
               // v2.0: the heap of visible faces
               H_UP    = 7'd80, H_UP1 = 7'd81, H_UP2 = 7'd82,
               D_POP1  = 7'd83, D_POP2 = 7'd84, D_POP3 = 7'd85,
               H_DN    = 7'd86, H_DN1 = 7'd87, H_DN2 = 7'd88, H_DN3 = 7'd89;

    reg [6:0]  st;
    reg [9:0]  vi, ei;
    reg [9:0]  left;                          // entries left in the phase's loop
    reg [47:0] vtmp;
    reg [9:0]  ib;
    reg signed [16:0] ax_, ay_, bx_, by_;     // endpoints
    reg [2:0]  fa, fb;                        // near/ovf flags
    reg signed [16:0] px, py;                 // inside point
    reg signed [16:0] lox, loy, hix, hiy;     // search / bisection pair
    reg signed [16:0] e1x, e1y, e2x, e2y;
    reg [3:0]  it;
    reg        which;                         // 0 = E1, 1 = E2

    // issuer
    reg        hold_valid;
    reg [7:0]  hb [0:18];
    reg        hlrmm;                         // 0: LINE (11 regs), 1: LRMM (19 regs)
    reg        hfill;                         // untextured filled-face span
    reg [4:0]  ik;
    // LRMM register order: R#32..R#45, R#47..R#50, then R#46 (starts it)
    wire [5:0] lrmm_num = (ik < 5'd14) ? 6'd32 + {1'b0, ik} :
                          (ik < 5'd18) ? 6'd33 + {1'b0, ik} : 6'd46;
    reg        isend;
    reg [2:0]  guard;

    wire [3:0] ca = ocode(ax_, ay_, scr_w, scr_h);
    wire [3:0] cb = ocode(bx_, by_, scr_w, scr_h);

    wire signed [16:0] mx = mid(lox, hix);
    wire signed [16:0] my = mid(loy, hiy);
    wire [3:0] cm  = ocode(mx,  my,  scr_w, scr_h);
    wire [3:0] clo = ocode(lox, loy, scr_w, scr_h);
    wire [3:0] chi = ocode(hix, hiy, scr_w, scr_h);

    // LINE command fields from e1/e2
    wire signed [17:0] ldx = {e2x[16], e2x} - {e1x[16], e1x};
    wire signed [17:0] ldy = {e2y[16], e2y} - {e1y[16], e1y};
    wire [17:0] lax = ldx[17] ? -ldx : ldx;
    wire [17:0] lay = ldy[17] ? -ldy : ldy;
    wire        lmaj = (lay > lax);
    wire [10:0] lnx = lmaj ? lay[10:0] : lax[10:0];
    wire [10:0] lny = lmaj ? lax[10:0] : lay[10:0];
    wire [10:0] ldy_full = e1y[10:0] + ypage;
    wire [7:0]  larg = {4'd0, ldy[17], ldx[17], 1'b0, lmaj};

    // ---------------------------------------------------- face-mode datapath
    reg signed [17:0] ma, mb;                 // shared multiplier operands
    wire signed [35:0] mp = ma * mb;

    reg        fmode;                         // latched CTRL bit1 for this RUN
    reg [1:0]  li, lj;
    reg signed [35:0] lacc;
    reg signed [17:0] lm [0:2];               // light in model space

    reg [9:0]  fi, nvis;
    reg [95:0] fcur;
    reg        vret;                          // 0 = classify, 1 = draw
    reg signed [15:0] vx [0:3];
    reg signed [15:0] vy [0:3];
    reg signed [15:0] vz [0:3];
    reg [2:0]  vfl [0:3];
    reg signed [36:0] a1;
    reg signed [37:0] sacc;

    // The visible faces are kept as a heap in smem (v2.0): the root is the
    // next face to paint, the farthest one, the lower face number first when
    // two are as far. A face goes in when it is classified (H_UP*) and the
    // root comes out when its turn to be painted comes (D_POP*, H_DN*), so
    // the order is the one v1.0.0 found by scanning the whole list for every
    // face, in about log2(n) steps instead of n.
    reg [30:0] hent;                          // the entry looking for its place
    reg [30:0] hch;                           // the first child read
    reg [9:0]  hole;                          // where the place is being looked for
    reg [9:0]  hn;                            // entries in the heap
    reg [7:0]  dcol;

    // 1 when entry a is painted before entry b
    function hbefore;
        input [30:0] a;
        input [30:0] b;
        begin
            hbefore = ($signed(a[30:13]) > $signed(b[30:13])) ||
                      (a[30:13] == b[30:13] && a[12:3] < b[12:3]);
        end
    endfunction

    wire [9:0]  hparent = (hole - 10'd1) >> 1;
    wire [10:0] hc1     = {hole, 1'b1};                   // 2 * hole + 1
    wire [10:0] hc2     = {hole, 1'b1} + 11'd1;           // 2 * hole + 2
    wire        hsecond = (hc2 < {1'b0, hn}) && hbefore(srd, hch);
    wire [30:0] hbest   = hsecond ? srd : hch;            // the child painted first

    reg [10:0] yrow, ymax;
    reg [1:0]  ek;
    reg signed [19:0] xl, xr;
    reg signed [17:0] den;
    reg        dsgn;
    reg [17:0] drem;
    reg [17:0] dlow;
    reg [17:0] dq;
    reg [4:0]  dcnt;

    function signed [17:0] sat18s;
        input signed [35:0] x;
        begin
            if (x > 36'sd131071)       sat18s = 18'sd131071;
            else if (x < -36'sd131071) sat18s = -18'sd131071;
            else                       sat18s = x[17:0];
        end
    endfunction

    // matrix element M[3*li + lj] (row li, column lj)
    wire [3:0] midx = {2'd0, li} + {2'd0, li} + {2'd0, li} + {2'd0, lj};

    // shade level from the accumulated dot product
    wire signed [37:0] snext  = sacc + {{2{mp[35]}}, mp};
    wire signed [23:0] shade  = sacc[37:14];       // registered in F_S3
    wire signed [26:0] shade7 = {{3{shade[23]}}, shade} * 27'sd7;
    wire [2:0]  slevel = (shade <= 24'sd0) ? 3'd0 :
                         (shade7[26:14] >= 13'sd6) ? 3'd6 : shade7[16:14];

    // area terms from the projected vertices 0, 1, 2
    wire signed [16:0] adx1 = {vx[1][15], vx[1]} - {vx[0][15], vx[0]};
    wire signed [16:0] ady1 = {vy[1][15], vy[1]} - {vy[0][15], vy[0]};
    wire signed [16:0] adx2 = {vx[2][15], vx[2]} - {vx[0][15], vx[0]};
    wire signed [16:0] ady2 = {vy[2][15], vy[2]} - {vy[0][15], vy[0]};
    wire signed [36:0] area = a1 - {{1{mp[35]}}, mp};
    reg  signed [36:0] area_r;
    wire signed [17:0] zkey = {{2{vz[0][15]}}, vz[0]} + {{2{vz[1][15]}}, vz[1]}
                            + {{2{vz[2][15]}}, vz[2]} + {{2{vz[3][15]}}, vz[3]};

    // fill: current edge (ek -> ek+1) and y range
    wire [1:0]  ek1 = ek + 2'd1;
    reg  signed [16:0] eya, eyb, exa, exb;    // current edge, loaded in D_EDGE0
    reg  [7:0]  eua, eub, eva, evb;           // texture coords of the edge ends
    wire signed [16:0] ycur = $signed({6'd0, yrow});
    wire signed [16:0] ylo = (eya < eyb) ? eya : eyb;
    wire signed [16:0] yhi = (eya < eyb) ? eyb : eya;
    wire signed [16:0] fdy  = ycur - eya;       // 17-bit differences, then
    wire signed [16:0] fdx  = exb - exa;        // sign-extended with their
    wire signed [16:0] fden = eyb - eya;        // own MSB
    wire signed [19:0] exa20 = {{3{exa[16]}}, exa};
    wire signed [19:0] exb20 = {{3{exb[16]}}, exb};

    wire signed [16:0] vymin01 = (vy[0] < vy[1]) ? {vy[0][15], vy[0]} : {vy[1][15], vy[1]};
    wire signed [16:0] vymin23 = (vy[2] < vy[3]) ? {vy[2][15], vy[2]} : {vy[3][15], vy[3]};
    wire signed [16:0] vymax01 = (vy[0] > vy[1]) ? {vy[0][15], vy[0]} : {vy[1][15], vy[1]};
    wire signed [16:0] vymax23 = (vy[2] > vy[3]) ? {vy[2][15], vy[2]} : {vy[3][15], vy[3]};
    wire signed [16:0] fymin = (vymin01 < vymin23) ? vymin01 : vymin23;
    wire signed [16:0] fymax = (vymax01 > vymax23) ? vymax01 : vymax23;
    wire signed [16:0] hm1   = scr_hm1;
    wire signed [16:0] wm1   = scr_wm1;
    reg  signed [16:0] fymin_r, fymax_r;
    wire signed [16:0] cymin = (fymin_r < 17'sd0) ? 17'sd0 : fymin_r;
    wire signed [16:0] cymax = (fymax_r > hm1) ? hm1 : fymax_r;

    // division step: two quotient bits a clock (v2.0; v1.0.0 took one).
    // The remainder is below |den| <= 2^17 before the step, so with two more
    // bits it is below 4 |den|: it holds |den| 0, 1, 2 or 3 times.
    wire [17:0] dabs  = den[17] ? -den : den;
    wire [19:0] drem4 = {drem, dlow[17:16]};
    wire [19:0] dden1 = {2'd0, dabs};
    wire [19:0] dden2 = {1'd0, dabs, 1'd0};
    wire [19:0] dden3 = dden1 + dden2;
    wire        dge1  = (drem4 >= dden1);
    wire        dge2  = (drem4 >= dden2);
    wire        dge3  = (drem4 >= dden3);
    wire [1:0]  dqb   = dge3 ? 2'd3 : dge2 ? 2'd2 : dge1 ? 2'd1 : 2'd0;
    wire [19:0] dsub  = dge3 ? dden3 : dge2 ? dden2 : dge1 ? dden1 : 20'd0;
    wire [19:0] drest = drem4 - dsub;
    wire signed [19:0] dfq = dsgn ? ((drem != 18'd0) ? -$signed({2'b00, dq}) - 20'sd1
                                                    : -$signed({2'b00, dq}))
                                  : $signed({2'b00, dq});

    // span
    wire signed [19:0] wm1_20 = {{3{wm1[16]}}, wm1};
    wire signed [19:0] scl = (xl < 20'sd0) ? 20'sd0 : xl;
    wire signed [19:0] scr = (xr > wm1_20) ? wm1_20 : xr;
    reg  signed [19:0] scl_r, scr_r;    // registered span / crossing
    reg                span_ok;
    wire signed [19:0] snx = scr_r - scl_r;
    wire [10:0] sdy = yrow + ypage;

    // ------------------------------------------------ textured faces
    reg        ftex, dtex;                    // RUN allows textures / face is textured
    reg [2:0]  dlev;                          // shade level of the face
    reg [63:0] tcur;
    reg [6:0]  dret;                          // return state of the divider
    reg signed [19:0] qres;                   // floor quotient
    reg signed [19:0] cx;                     // span candidate: x, u, v (8.8)
    reg signed [19:0] cu, cv;
    reg        cand_n;                        // one more candidate (horizontal edge)
    reg signed [19:0] ul, ur, vl, vr;
    reg signed [15:0] du, dv;
    reg signed [35:0] us, vs;

    function [7:0] tu; input [63:0] t; input [1:0] k; tu = t[16 * k +: 8];     endfunction
    function [7:0] tv; input [63:0] t; input [1:0] k; tv = t[16 * k + 8 +: 8]; endfunction

    function signed [17:0] sat18w;            // 20-bit -> 18-bit signed, symmetric
        input signed [19:0] x;
        begin
            if (x > 20'sd131071)       sat18w = 18'sd131071;
            else if (x < -20'sd131071) sat18w = -18'sd131071;
            else                       sat18w = x[17:0];
        end
    endfunction

    function signed [15:0] sat16w;
        input signed [19:0] x;
        begin
            if (x > 20'sd32767)        sat16w = 16'sd32767;
            else if (x < -20'sd32767)  sat16w = -16'sd32767;
            else                       sat16w = x[15:0];
        end
    endfunction

    wire signed [16:0] fdu   = $signed({1'b0, eub, 8'd0}) - $signed({1'b0, eua, 8'd0});
    wire signed [16:0] fdv   = $signed({1'b0, evb, 8'd0}) - $signed({1'b0, eva, 8'd0});
    wire signed [17:0] tdu_n = {fdu[16], fdu};           // (ub - ua) * 256
    wire signed [19:0] eua20 = $signed({4'd0, eua, 8'd0});
    wire signed [19:0] eva20 = $signed({4'd0, eva, 8'd0});
    wire signed [19:0] eub20 = $signed({4'd0, eub, 8'd0});
    wire signed [19:0] evb20 = $signed({4'd0, evb, 8'd0});
    wire signed [35:0] us_s  = us >>> 8;
    wire signed [35:0] vs_s  = vs >>> 8;
    wire [10:0] lev_off = dlev * tstride;
    wire [11:0] lsx = {3'd0, texx} + us_s[11:0];
    wire [12:0] lsy = texy + {2'd0, lev_off} + vs_s[12:0];
    wire [10:0] lnxp = snx[10:0] + 11'd1;     // LRMM counts pixels

    integer k;

    always @(posedge clk) begin
        if (rst) begin
            st <= R_IDLE; ph_run <= 1'b0; ph_xf <= 1'b0; ph_edge <= 1'b0;
            e_core_wr <= 1'b0; pwe <= 1'b0; swe <= 1'b0; fmode <= 1'b0;
            hold_valid <= 1'b0; hfill <= 1'b0; isend <= 1'b0; guard <= 3'd0;
            cmd_wr <= 1'b0; cmd_num <= 6'd0; cmd_data <= 8'd0; cmd_fill_span <= 1'b0;
            cnt_skip <= 16'd0; cnt_draw <= 16'd0; cnt_cull <= 16'd0;
        end else begin
            e_core_wr <= 1'b0;
            pwe       <= 1'b0;
            swe       <= 1'b0;
            cmd_wr    <= 1'b0;
            if (guard != 3'd0) guard <= guard - 3'd1;

            // ------------------------------------------------ issuer
            if (!isend) begin
                if (hold_valid && !cmd_ce && guard == 3'd0) begin
                    isend <= 1'b1;
                    ik    <= 5'd0;
                end
            end else begin
                cmd_wr   <= 1'b1;
                cmd_num  <= hlrmm ? lrmm_num : 6'd36 + {1'b0, ik};
                cmd_data <= hb[ik];
                cmd_fill_span <= hfill;
                if (ik == (hlrmm ? 5'd18 : 5'd10)) begin
                    isend      <= 1'b0;
                    hold_valid <= 1'b0;
                    guard      <= 3'd4;
                end else begin
                    ik <= ik + 5'd1;
                end
            end

            // ------------------------------------------------ producer
            case (st)
                R_IDLE: begin
                    if (run_req) begin
                        ph_run   <= 1'b1;
                        fmode    <= ctrl_face;
                        ftex     <= ctrl_tex;
                        cnt_skip <= 16'd0; cnt_draw <= 16'd0; cnt_cull <= 16'd0;
                        vi <= vfirst; left <= nvert;
                        if (nvert == 10'd0) st <= ctrl_face ? L_OP : E_START;
                        else begin ph_xf <= 1'b1; st <= T_ADDR; end
                        li <= 2'd0; lj <= 2'd0; lacc <= 36'sd0;
                    end
                end

                // ------------------------- transform phase
                T_ADDR: begin vra <= vi; st <= T_W1; end
                T_W1:   st <= T_W2;
                T_W2: begin
                    vtmp <= vrd;
                    e_core_wr <= 1'b1; e_core_addr <= 5'd18; e_core_data <= vrd[15:0];
                    st <= T_WY;
                end
                T_WY: begin
                    e_core_wr <= 1'b1; e_core_addr <= 5'd19; e_core_data <= vtmp[31:16];
                    st <= T_WZ;
                end
                T_WZ: begin
                    e_core_wr <= 1'b1; e_core_addr <= 5'd20; e_core_data <= vtmp[47:32];
                    st <= T_WAIT;
                end
                T_WAIT: begin
                    if (c_done) begin
                        pwe <= 1'b1; pwa <= vi;
                        pwd <= {c_z, c_flags[2:0], c_sy, c_sx};
                        vi   <= vi + 10'd1;
                        left <= left - 10'd1;
                        if (left == 10'd1) st <= fmode ? L_OP : E_START;
                        else               st <= T_ADDR;
                    end
                end

                // ------------------------- edge phase
                E_START: begin
                    ph_xf <= 1'b0;
                    ei    <= efirst; left <= nedge;
                    if (nedge == 10'd0) st <= R_DRAIN;
                    else begin ph_edge <= 1'b1; st <= E_ADDR; end
                end
                E_ADDR: begin era <= ei; st <= E_W1; end
                E_W1:   st <= E_W2;
                E_W2: begin
                    pra <= erd[9:0];
                    ib  <= erd[19:10];
                    st  <= E_PA1;
                end
                E_PA1:  st <= E_PA2;
                E_PA2: begin
                    ax_ <= {prd[15], prd[15:0]};
                    ay_ <= {prd[31], prd[31:16]};
                    fa  <= prd[34:32];
                    pra <= ib;
                    st  <= E_PB1;
                end
                E_PB1:  st <= E_PB2;
                E_PB2: begin
                    bx_ <= {prd[15], prd[15:0]};
                    by_ <= {prd[31], prd[31:16]};
                    fb  <= prd[34:32];
                    st  <= E_CLASS;
                end
                E_CLASS: begin
                    if (fa != 3'd0 || fb != 3'd0) begin
                        cnt_skip <= cnt_skip + 16'd1;
                        st <= E_NEXT;
                    end else if ((ca & cb) != 4'd0) begin
                        cnt_cull <= cnt_cull + 16'd1;
                        st <= E_NEXT;
                    end else if (ca == 4'd0) begin
                        px <= ax_; py <= ay_; st <= E_E1;
                    end else if (cb == 4'd0) begin
                        px <= bx_; py <= by_; st <= E_E1;
                    end else begin
                        lox <= ax_; loy <= ay_; hix <= bx_; hiy <= by_;
                        it  <= 4'd0;
                        st  <= E_SRCH;
                    end
                end
                E_SRCH: begin
                    if (cm == 4'd0) begin
                        px <= mx; py <= my; st <= E_E1;
                    end else if ((clo & cm) != 4'd0) begin
                        lox <= mx; loy <= my;
                        it  <= it + 4'd1;
                        if (it == 4'd15) begin cnt_skip <= cnt_skip + 16'd1; st <= E_NEXT; end
                    end else if ((cm & chi) != 4'd0) begin
                        hix <= mx; hiy <= my;
                        it  <= it + 4'd1;
                        if (it == 4'd15) begin cnt_skip <= cnt_skip + 16'd1; st <= E_NEXT; end
                    end else begin
                        cnt_skip <= cnt_skip + 16'd1;
                        st <= E_NEXT;
                    end
                end
                E_E1: begin
                    if (ca == 4'd0) begin
                        e1x <= ax_; e1y <= ay_; st <= E_E2;
                    end else begin
                        lox <= px; loy <= py; hix <= ax_; hiy <= ay_;   // lo = inside
                        it <= 4'd0; which <= 1'b0; st <= E_BIS;
                    end
                end
                E_E2: begin
                    if (cb == 4'd0) begin
                        e2x <= bx_; e2y <= by_; st <= E_BUILD;
                    end else begin
                        lox <= px; loy <= py; hix <= bx_; hiy <= by_;
                        it <= 4'd0; which <= 1'b1; st <= E_BIS;
                    end
                end
                E_BIS: begin
                    if (cm == 4'd0) begin lox <= mx; loy <= my; end
                    else            begin hix <= mx; hiy <= my; end
                    it <= it + 4'd1;
                    if (it == 4'd15) st <= E_BISE;
                end
                E_BISE: begin
                    if (!which) begin e1x <= lox; e1y <= loy; st <= E_E2; end
                    else        begin e2x <= lox; e2y <= loy; st <= E_BUILD; end
                end
                E_BUILD: begin
                    if (!hold_valid) begin
                        hb[0]  <= e1x[7:0];
                        hb[1]  <= {7'd0, e1x[8]};
                        hb[2]  <= ldy_full[7:0];
                        hb[3]  <= {5'd0, ldy_full[10:8]};
                        hb[4]  <= lnx[7:0];
                        hb[5]  <= {5'd0, lnx[10:8]};
                        hb[6]  <= lny[7:0];
                        hb[7]  <= {5'd0, lny[10:8]};
                        hb[8]  <= color;
                        hb[9]  <= larg;
                        hb[10] <= {4'h7, lop};
                        hlrmm  <= 1'b0;
                        hfill  <= 1'b0;
                        hold_valid <= 1'b1;
                        cnt_draw   <= cnt_draw + 16'd1;
                        st <= E_NEXT;
                    end
                end
                E_NEXT: begin
                    ei   <= ei + 10'd1;
                    left <= left - 10'd1;
                    if (left == 10'd1) st <= R_DRAIN;
                    else               st <= E_ADDR;
                end

                // ============================== filled-face mode
                // a. LM[j] = sum_i M[i][j] * L[i]  (transpose(R) * L)
                L_OP: begin
                    ph_xf <= 1'b0;
                    ma <= {{2{msh[midx][15]}}, msh[midx]};
                    mb <= {{2{lreg[li][15]}}, lreg[li]};
                    st <= L_ACC;
                end
                L_ACC: begin
                    if (li == 2'd2) begin
                        lm[lj] <= sat18s((lacc + mp) >>> 14);
                        lacc   <= 36'sd0;
                        li     <= 2'd0;
                        lj     <= lj + 2'd1;
                        st     <= (lj == 2'd2) ? F_START : L_OP;
                    end else begin
                        lacc <= lacc + mp;
                        li   <= li + 2'd1;
                        st   <= L_OP;
                    end
                end

                // b. classify every face
                F_START: begin
                    ph_edge <= 1'b1;
                    fi <= ffirst; left <= nface; nvis <= 10'd0;
                    st <= (nface == 10'd0) ? R_DRAIN : F_ADDR;
                end
                F_ADDR: begin fra <= fi; st <= F_W1; end
                F_W1:   st <= F_W2;
                F_W2: begin
                    fcur <= frd; vret <= 1'b0;
                    pra  <= frd[9:0];
                    st   <= V_A1;
                end
                // the 4 projected vertices of fcur, read back to back (v2.0).
                // The state that comes here has already given the address
                // of the first one.
                V_A1: begin
                    pra <= fcur[19:10];
                    st  <= V_A2;
                end
                V_A2: begin
                    vx[0] <= prd[15:0]; vy[0] <= prd[31:16]; vfl[0] <= prd[34:32]; vz[0] <= prd[50:35];
                    pra   <= fcur[29:20];
                    st    <= V_A3;
                end
                V_A3: begin
                    vx[1] <= prd[15:0]; vy[1] <= prd[31:16]; vfl[1] <= prd[34:32]; vz[1] <= prd[50:35];
                    pra   <= fcur[39:30];
                    st    <= V_A4;
                end
                V_A4: begin
                    vx[2] <= prd[15:0]; vy[2] <= prd[31:16]; vfl[2] <= prd[34:32]; vz[2] <= prd[50:35];
                    st    <= V_A5;
                end
                V_A5: begin
                    vx[3] <= prd[15:0]; vy[3] <= prd[31:16]; vfl[3] <= prd[34:32]; vz[3] <= prd[50:35];
                    st    <= vret ? D_YR0 : F_CHK;
                end
                F_CHK: begin
                    if (vfl[0] != 3'd0 || vfl[1] != 3'd0 || vfl[2] != 3'd0 || vfl[3] != 3'd0) begin
                        cnt_skip <= cnt_skip + 16'd1;
                        st <= F_NEXT;
                    end else begin
                        ma <= {adx1[16], adx1}; mb <= {ady2[16], ady2};
                        st <= F_A1;
                    end
                end
                F_A1: begin
                    a1 <= {{1{mp[35]}}, mp};
                    ma <= {ady1[16], ady1}; mb <= {adx2[16], adx2};
                    st <= F_A2;
                end
                F_A2: begin
                    area_r <= area;
                    st <= F_A3;
                end
                F_A3: begin
                    if (area_r <= 37'sd0) begin
                        cnt_cull <= cnt_cull + 16'd1;
                        st <= F_NEXT;
                    end else begin
                        sacc <= 38'sd0;
                        ma <= lm[0]; mb <= {{2{fcur[55]}}, fcur[55:40]};
                        st <= F_S1;
                    end
                end
                F_S1: begin
                    sacc <= snext;
                    ma <= lm[1]; mb <= {{2{fcur[71]}}, fcur[71:56]};
                    st <= F_S2;
                end
                F_S2: begin
                    sacc <= snext;
                    ma <= lm[2]; mb <= {{2{fcur[87]}}, fcur[87:72]};
                    st <= F_S3;
                end
                F_S3: begin
                    sacc <= snext;
                    st   <= F_S4;
                end
                // the visible face goes into the heap: from the first free
                // place up, for as long as it is painted before its parent
                F_S4: begin
                    hent <= {zkey, fi, slevel};
                    hole <= nvis;
                    nvis <= nvis + 10'd1;
                    st   <= H_UP;
                end
                H_UP: begin
                    if (hole == 10'd0) begin
                        swe <= 1'b1; swa <= 10'd0; swd <= hent;
                        st  <= F_NEXT;
                    end else begin
                        sra <= hparent;
                        st  <= H_UP1;
                    end
                end
                H_UP1:  st <= H_UP2;
                H_UP2: begin
                    swe <= 1'b1; swa <= hole;
                    if (hbefore(hent, srd)) begin
                        swd  <= srd;                // the parent comes down
                        hole <= hparent;
                        st   <= H_UP;
                    end else begin
                        swd <= hent;
                        st  <= F_NEXT;
                    end
                end
                F_NEXT: begin
                    fi   <= fi + 10'd1;
                    left <= left - 10'd1;
                    if (left == 10'd1) st <= D_START;
                    else               st <= F_ADDR;
                end

                // c. painter's order: the root of the heap is the next
                // farthest face. It comes out, the last entry takes its
                // place and goes down for as long as a child is painted
                // before it.
                D_START: begin
                    hn  <= nvis;
                    sra <= 10'd0;
                    st  <= (nvis == 10'd0) ? R_DRAIN : D_POP1;
                end
                D_POP1: begin
                    sra <= hn - 10'd1;
                    st  <= D_POP2;
                end
                D_POP2: begin                       // srd: the root
                    dlev <= srd[2:0];
                    fra  <= srd[12:3]; tra <= srd[12:3];
                    hn   <= hn - 10'd1;
                    hole <= 10'd0;
                    st   <= D_POP3;
                end
                D_POP3: begin                       // srd: the last entry
                    hent <= srd;
                    st   <= H_DN;
                end
                H_DN: begin
                    if (hn == 10'd0) begin
                        st <= D_FW2;                // that was the last face
                    end else if (hc1 >= {1'b0, hn}) begin
                        swe <= 1'b1; swa <= hole; swd <= hent;
                        st  <= D_FW2;               // no children: its place
                    end else begin
                        sra <= hc1[9:0];
                        st  <= H_DN1;
                    end
                end
                H_DN1: begin
                    sra <= hc2[9:0];
                    st  <= H_DN2;
                end
                H_DN2: begin
                    hch <= srd;                     // the first child
                    st  <= H_DN3;
                end
                H_DN3: begin                        // srd: the second child
                    swe <= 1'b1; swa <= hole;
                    if (hbefore(hbest, hent)) begin
                        swd  <= hbest;              // the child comes up
                        hole <= hsecond ? hc2[9:0] : hc1[9:0];
                        st   <= H_DN;
                    end else begin
                        swd <= hent;
                        st  <= D_FW2;
                    end
                end
                D_FW2: begin
                    fcur <= frd; tcur <= trd; vret <= 1'b1;
                    dtex <= ftex & frd[95];
                    dcol <= frd[95:88] + {5'd0, dlev};   // BASE + level (v2.0: not kept in the heap)
                    pra  <= frd[9:0];
                    st   <= V_A1;
                end


                // d. fill the face row by row
                D_YR0: begin
                    fymin_r <= fymin; fymax_r <= fymax;
                    st <= D_YR;
                end
                D_YR: begin
                    if (cymin > cymax) st <= D_NEXTR;
                    else begin
                        yrow <= cymin[10:0]; ymax <= cymax[10:0];
                        st <= D_ROW;
                    end
                end
                D_ROW: begin
                    xl <= 20'sh7FFFF; xr <= -20'sh80000; ek <= 2'd0;
                    st <= D_EDGE0;
                end
                D_EDGE0: begin
                    eya <= {vy[ek][15],  vy[ek]};
                    eyb <= {vy[ek1][15], vy[ek1]};
                    exa <= {vx[ek][15],  vx[ek]};
                    exb <= {vx[ek1][15], vx[ek1]};
                    eua <= tu(tcur, ek);  eub <= tu(tcur, ek1);
                    eva <= tv(tcur, ek);  evb <= tv(tcur, ek1);
                    st  <= D_EDGE;
                end
                D_EDGE: begin
                    if (eya == eyb) begin
                        // horizontal edge on this row: both ends are candidates
                        if (ycur == eya) begin
                            cx <= exa20; cu <= eua20; cv <= eva20; cand_n <= 1'b1;
                            st <= D_CAND;
                        end else begin
                            st <= D_ENEXT;
                        end
                    end else if (ycur >= ylo && ycur <= yhi) begin
                        ma   <= {fdy[16],  fdy};
                        mb   <= {fdx[16],  fdx};
                        den  <= {fden[16], fden};
                        dret <= D_XQ;
                        st   <= D_EMUL;
                    end else begin
                        st <= D_ENEXT;
                    end
                end
                D_EMUL: begin
                    dsgn <= mp[35] ^ den[17];
                    drem <= (mp[35] ? -mp : mp) >>> 18;
                    dlow <= (mp[35] ? -mp : mp);
                    dq   <= 18'd0;
                    dcnt <= 5'd8;
                    st   <= D_DIV;
                end
                D_DIV: begin
                    drem <= drest[17:0];
                    dq   <= {dq[15:0], dqb};
                    dlow <= {dlow[15:0], 2'b00};
                    dcnt <= dcnt - 5'd1;
                    if (dcnt == 5'd0) st <= D_DQ;
                end
                D_DQ: begin
                    qres <= dfq;
                    st   <= dret;
                end
                D_XQ: begin
                    cx <= exa20 + qres;
                    cu <= 20'sd0; cv <= 20'sd0; cand_n <= 1'b0;
                    if (dtex) begin
                        ma   <= tdu_n;
                        mb   <= {fdy[16], fdy};
                        dret <= D_UQ;
                        st   <= D_EMUL;
                    end else begin
                        st <= D_CAND;
                    end
                end
                D_UQ: begin
                    cu   <= eua20 + qres;
                    ma   <= {fdv[16], fdv};
                    mb   <= {fdy[16], fdy};
                    dret <= D_VQ;
                    st   <= D_EMUL;
                end
                D_VQ: begin
                    cv <= eva20 + qres;
                    st <= D_CAND;
                end
                D_CAND: begin
                    if (cx < xl) begin xl <= cx; ul <= cu; vl <= cv; end
                    if (cx > xr) begin xr <= cx; ur <= cu; vr <= cv; end
                    if (cand_n) begin
                        cx <= exb20; cu <= eub20; cv <= evb20; cand_n <= 1'b0;
                    end else begin
                        st <= D_ENEXT;
                    end
                end
                D_ENEXT: begin
                    ek <= ek + 2'd1;
                    st <= (ek == 2'd3) ? D_SPAN0 : D_EDGE0;
                end
                D_SPAN0: begin
                    scl_r   <= scl;
                    scr_r   <= scr;
                    span_ok <= (xl <= xr) && (scl <= scr);
                    st <= dtex ? D_T0 : D_SPAN;
                end
                // texture step and start for this span
                D_T0: begin
                    if (!span_ok) st <= D_SPAN;
                    else if (xr == xl) begin
                        du <= 16'sd0; dv <= 16'sd0; st <= D_T3;
                    end else begin
                        ma   <= sat18w(ur - ul);
                        mb   <= 18'sd1;
                        den  <= sat18w(xr - xl);
                        dret <= D_T1;
                        st   <= D_EMUL;
                    end
                end
                D_T1: begin
                    du   <= sat16w(qres);
                    ma   <= sat18w(vr - vl);
                    dret <= D_T2;
                    st   <= D_EMUL;
                end
                D_T2: begin
                    dv <= sat16w(qres);
                    st <= D_T3;
                end
                D_T3: begin
                    ma <= sat18w(scl_r - xl);
                    mb <= {{2{du[15]}}, du};
                    st <= D_T4;
                end
                D_T4: begin
                    us <= {{16{ul[19]}}, ul} + mp;
                    mb <= {{2{dv[15]}}, dv};
                    st <= D_T5;
                end
                D_T5: begin
                    vs <= {{16{vl[19]}}, vl} + mp;
                    st <= D_SPAN;
                end
                D_SPAN: begin
                    if (!span_ok) st <= D_YNEXT;
                    else if (!hold_valid && dtex) begin
                        hb[0]  <= lsx[7:0];
                        hb[1]  <= {4'd0, lsx[11:8]};
                        hb[2]  <= lsy[7:0];
                        hb[3]  <= {3'd0, lsy[12:8]};
                        hb[4]  <= scl_r[7:0];
                        hb[5]  <= {7'd0, scl_r[8]};
                        hb[6]  <= sdy[7:0];
                        hb[7]  <= {5'd0, sdy[10:8]};
                        hb[8]  <= lnxp[7:0];
                        hb[9]  <= {5'd0, lnxp[10:8]};
                        hb[10] <= 8'd1;
                        hb[11] <= 8'd0;
                        hb[12] <= dcol;
                        hb[13] <= 8'd0;
                        hb[14] <= du[7:0];
                        hb[15] <= du[15:8];
                        hb[16] <= dv[7:0];
                        hb[17] <= dv[15:8];
                        hb[18] <= {4'h3, lop};
                        hlrmm  <= 1'b1;
                        hfill  <= 1'b0;
                        hold_valid <= 1'b1;
                        st <= D_YNEXT;
                    end
                    else if (!hold_valid) begin
                        hlrmm  <= 1'b0;
                        hfill  <= 1'b1;
                        hb[0]  <= scl_r[7:0];
                        hb[1]  <= {7'd0, scl_r[8]};
                        hb[2]  <= sdy[7:0];
                        hb[3]  <= {5'd0, sdy[10:8]};
                        hb[4]  <= snx[7:0];
                        hb[5]  <= {5'd0, snx[10:8]};
                        hb[6]  <= 8'd0;
                        hb[7]  <= 8'd0;
                        hb[8]  <= dcol;
                        hb[9]  <= 8'd0;
                        hb[10] <= {4'h7, lop};
                        hold_valid <= 1'b1;
                        st <= D_YNEXT;
                    end
                end
                D_YNEXT: begin
                    if (yrow == ymax) st <= D_NEXTR;
                    else begin yrow <= yrow + 11'd1; st <= D_ROW; end
                end
                D_NEXTR: begin
                    cnt_draw <= cnt_draw + 16'd1;
                    sra <= 10'd0;                   // the heap's new root
                    st  <= (hn == 10'd0) ? R_DRAIN : D_POP1;
                end

                R_DRAIN: begin
                    ph_edge <= 1'b0;
                    if (!hold_valid && !isend && guard == 3'd0 && !cmd_ce) begin
                        ph_run <= 1'b0;
                        st <= R_IDLE;
                    end
                end
                default: st <= R_IDLE;
            endcase
        end
    end

endmodule
