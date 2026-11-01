// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Alex Moncks
// ============================================================================
// geo3d_bus.v
// Adapter between the cartridge's msx_slot bus (bus_valid / bus_ready /
// bus_rdata_en, 8-port block at 88h or 98h) and geo3d_engine.
//
// The slot decodes an 8-port block; the V9968 uses offsets 0-4. geo3d takes:
//   offset PORT_INDEX (default 5): index write / status read   (8Dh or 9Dh)
//   offset PORT_DATA  (default 7): data read / write           (8Fh or 9Fh)
// Offset 6 (8Eh) is left alone on purpose: 8Eh is used by the MegaRAM.
//
// Clocks: the slot bus and the V9968 run on clk (85.9 MHz). The engine runs
// on clk_eng = clk / 2 (42.95 MHz), which doubles its timing margin. Both
// must come from the same PLL with aligned rising edges: on the cartridge
// clk = clk85m (u_pll2 CLKOUT) and clk_eng = clk42g (u_pll2 CLKOUTD, the
// PLL's own divide-by-2), not HRA!'s clk42m (Gowin_CLKDIV, which Gowin's
// timing model places 3-4 ns away from the PLL outputs). The SDC declares
// clk42g as clk14m x 3 with 0.5 ns of uncertainty on the crossings (see
// geo3d/integration/apply_geo3d_patch.py). Crossings use toggles:
//   bus -> engine : request toggle, one engine-clock strobe per access
//   engine -> bus : acknowledge toggle when read data is ready
//   engine -> VDP : one toggle per command-register write, with its data and
//                   filled-span tag, turned back into a single clk pulse
//   VDP -> engine : CE is a level, sampled directly (related clocks)
// ============================================================================
module geo3d_bus #(
    parameter [2:0] PORT_INDEX = 3'd5,
    parameter [2:0] PORT_DATA  = 3'd7
)(
    input  wire       clk,            // 85.9 MHz: slot bus and VDP
    input  wire       clk_eng,        // 42.95 MHz: geo3d engine (clk / 2)
    input  wire       reset_n,
    // from msx_slot (clk domain)
    input  wire [2:0] bus_address,
    input  wire       bus_ioreq,
    input  wire       bus_write,
    input  wire       bus_valid,
    input  wire [7:0] bus_wdata,
    output wire       hit,            // this access belongs to geo3d
    output wire       bus_ready,
    output wire [7:0] bus_rdata,
    output reg        bus_rdata_en,
    // to the V9968 command engine (clk domain)
    output reg        cmd_wr,
    output reg  [5:0] cmd_num,
    output reg  [7:0] cmd_data,
    output reg        cmd_fill_span,
    input  wire       cmd_ce,
    output wire       run_busy
);
    assign hit = (bus_address == PORT_INDEX) || (bus_address == PORT_DATA);

    // ------------------------------------------------ bus side (clk)
    reg        req_t, busy_f, is_rd;
    reg        a_sel, a_wr;
    reg  [7:0] a_data;
    reg        ack_s1, ack_seen;
    wire       ack_t;
    wire [7:0] eng_dout;

    assign bus_ready = ~busy_f;
    wire acc = bus_valid & bus_ioreq & hit & ~busy_f;

    always @(posedge clk) begin
        if (!reset_n) begin
            req_t <= 1'b0; busy_f <= 1'b0; is_rd <= 1'b0;
            ack_s1 <= 1'b0; ack_seen <= 1'b0; bus_rdata_en <= 1'b0;
        end else begin
            bus_rdata_en <= 1'b0;
            ack_s1 <= ack_t;
            if (acc) begin
                a_sel  <= (bus_address == PORT_DATA);
                a_wr   <= bus_write;
                a_data <= bus_wdata;
                req_t  <= ~req_t;
                busy_f <= 1'b1;
                is_rd  <= ~bus_write;
            end else if (busy_f && ack_s1 != ack_seen) begin
                ack_seen     <= ack_s1;
                busy_f       <= 1'b0;
                bus_rdata_en <= is_rd;
            end
        end
    end
    assign bus_rdata = eng_dout;

    // clk -> clk_eng crossing for the hold check.
    // clk_eng rising edges coincide with clk rising edges, so a direct
    // rising-edge crossing has zero hold relation and fails the 0.5ns hold
    // uncertainty on short routes. req_t/a_sel/a_wr/a_data are therefore
    // re-launched on the falling edge of clk (hold relation: half a clk).
    // clk_eng edges only fall on clk rising edges, so the clk_eng edge that
    // detects the request is the same as before; each crossing is a single
    // FF-to-FF hop, which fits the half-period setup relation.
    // Keep these copies so synthesis does not merge or remove them.
    reg        req_t_n  /* synthesis syn_preserve = 1 */;
    reg        a_sel_n  /* synthesis syn_preserve = 1 */;
    reg        a_wr_n   /* synthesis syn_preserve = 1 */;
    reg  [7:0] a_data_n /* synthesis syn_preserve = 1 */;
    always @(negedge clk) begin
        req_t_n  <= req_t;
        a_sel_n  <= a_sel;
        a_wr_n   <= a_wr;
        a_data_n <= a_data;
    end

    // ------------------------------------------------ engine side (clk_eng)
    reg        req_seen, ack_r;
    reg        e_wr, e_rd;
    reg        e_sel;
    reg  [7:0] e_din;
    reg        ce_s;
    wire       e_cmd_wr;
    wire [5:0] e_cmd_num;
    wire [7:0] e_cmd_data;
    wire       e_cmd_fill_span;
    reg        cmd_t;
    reg  [5:0] cmd_num_e;
    reg  [7:0] cmd_data_e;
    reg        cmd_fill_span_e;

    // v2.0: the engine side resets from its own flop. The slot's reset_n then
    // reaches one clk_eng register instead of every register of the engine
    // (a clk -> clk_eng path with a fanout of hundreds, which took routing
    // from the VDP). The engine leaves reset one engine clock later.
    reg        rst_e;
    always @(posedge clk_eng) rst_e <= ~reset_n;

    always @(posedge clk_eng) begin
        if (rst_e) begin
            req_seen <= 1'b0; ack_r <= 1'b0; e_wr <= 1'b0; e_rd <= 1'b0;
            cmd_t <= 1'b0; ce_s <= 1'b0;
        end else begin
            e_wr <= 1'b0; e_rd <= 1'b0;
            ce_s <= cmd_ce;
            if (req_t_n != req_seen) begin
                req_seen <= req_t_n;
                e_wr <= a_wr_n;
                e_rd <= ~a_wr_n;
                // the engine sees sel/din together with the strobe, as before
                e_sel <= a_sel_n;
                e_din <= a_data_n;
            end
            // acknowledge one engine clock after the strobe (dout is then valid)
            if (e_wr | e_rd) ack_r <= ~ack_r;
            if (e_cmd_wr) begin
                cmd_t      <= ~cmd_t;
                cmd_num_e  <= e_cmd_num;
                cmd_data_e <= e_cmd_data;
                cmd_fill_span_e <= e_cmd_fill_span;
            end
        end
    end
    assign ack_t = ack_r;

    geo3d_engine u_engine (
        .clk(clk_eng), .rst(rst_e),
        .sel(e_sel), .wr_stb(e_wr), .rd_stb(e_rd), .din(e_din), .dout(eng_dout),
        .cmd_wr(e_cmd_wr), .cmd_num(e_cmd_num), .cmd_data(e_cmd_data),
        .cmd_fill_span(e_cmd_fill_span), .cmd_ce(ce_s),
        .run_busy(run_busy)
    );

    // ------------------------------------------------ command writes back to clk
    reg cmd_seen;
    always @(posedge clk) begin
        if (!reset_n) begin
            cmd_seen <= 1'b0; cmd_wr <= 1'b0; cmd_fill_span <= 1'b0;
        end else begin
            cmd_wr <= 1'b0;
            if (cmd_t != cmd_seen) begin
                cmd_seen <= cmd_t;
                cmd_wr   <= 1'b1;
                cmd_num  <= cmd_num_e;
                cmd_data <= cmd_data_e;
                cmd_fill_span <= cmd_fill_span_e;
            end
        end
    end
endmodule
