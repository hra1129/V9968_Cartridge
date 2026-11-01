`timescale 1ps/1ps

module tb_geo3d_vdp_modes;
    reg clk = 0;
    always #5820 clk = ~clk;

    reg reset_n = 0;
    reg bus_valid = 0;
    reg [7:0] bus_wdata = 0;
    wire bus_ready;
    wire bus_write_done;
    reg ext_wr = 0;
    reg [5:0] ext_num = 0;
    reg [7:0] ext_data = 0;
    reg ext_span = 0;
    reg test_passed = 0;

    vdp u_vdp (
        .reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
        .bus_address(3'd1), .bus_ioreq(1'b1), .bus_write(1'b1),
        .bus_valid(bus_valid), .bus_ready(bus_ready), .bus_wdata(bus_wdata),
        .bus_rdata(), .bus_rdata_en(), .bus_write_done(bus_write_done), .int_n(),
        .vram_address(), .vram_write(), .vram_valid(), .vram_wdata(),
        .vram_wdata_mask(), .vram_rdata(32'd0), .vram_rdata_en(1'b0), .vram_refresh(),
        .display_hs(), .display_vs(), .display_en(), .display_r(), .display_g(), .display_b(),
        .force_highspeed(1'b1),
        .ext_cmd_wr(ext_wr), .ext_cmd_num(ext_num), .ext_cmd_data(ext_data),
        .ext_cmd_fill_span(ext_span), .ext_cmd_ce(),
        .button(2'd0), .pulse0(), .pulse1(), .pulse2(), .pulse3(),
        .pulse4(), .pulse5(), .pulse6(), .pulse7()
    );

    task automatic cpu_byte(input [7:0] data);
        integer timeout;
        begin
            timeout = 0;
            while (!bus_ready && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bus_ready) $fatal(1, "VDP bus did not become ready");
            @(negedge clk);
            bus_wdata = data;
            bus_valid = 1;
            @(negedge clk);
            bus_valid = 0;
            timeout = 0;
            while (!bus_write_done && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!bus_write_done) $fatal(1, "VDP bus write did not finish");
            @(negedge clk);
        end
    endtask

    task automatic cpu_register(input [5:0] number, input [7:0] data);
        begin
            cpu_byte(data);
            cpu_byte({2'b10, number});
        end
    endtask

    task automatic external_register(input [5:0] number, input [7:0] data, input bit span);
        begin
            @(negedge clk);
            ext_wr = 1;
            ext_num = number;
            ext_data = data;
            ext_span = span;
            @(negedge clk);
            ext_wr = 0;
            ext_span = 0;
        end
    endtask

    task automatic check_mode(
        input [7:0] r0, input [7:0] r25, input bit span,
        input bit expected_g7, input bit expected_fast
    );
        begin
            reset_n = 0;
            bus_valid = 0;
            ext_wr = 0;
            repeat (12) @(negedge clk);
            reset_n = 1;
            repeat (12) @(negedge clk);

            cpu_register(6'd0, r0);
            cpu_register(6'd1, 8'd0);
            cpu_register(6'd25, r25);
            repeat (12) @(negedge clk);
            if (u_vdp.w_screen_mode[6] !== expected_g7 ||
                u_vdp.reg_yjk_mode !== r25[3])
                $fatal(1, "Incorrect VDP mode decode: R0=%02x R25=%02x", r0, r25);

            external_register(6'd36, 8'd41, 0);
            external_register(6'd37, 8'd0, 0);
            external_register(6'd38, 8'd17, 0);
            external_register(6'd39, 8'd0, 0);
            external_register(6'd40, 8'd19, 0);
            external_register(6'd41, 8'd0, 0);
            external_register(6'd42, 8'd0, 0);
            external_register(6'd43, 8'd0, 0);
            external_register(6'd44, 8'ha9, 0);
            external_register(6'd45, 8'd0, 0);
            external_register(6'd46, 8'h70, span);
            if (u_vdp.u_command.ff_geo_hmmv !== expected_fast ||
                u_vdp.u_command.ff_command !== (expected_fast ? 4'hc : 4'h7))
                $fatal(1, "Incorrect VDP optimization: R0=%02x R25=%02x span=%0d", r0, r25, span);
            $display("PASS VDP mode decode R0=%02x R25=%02x span=%0d fast=%0d",
                     r0, r25, span, expected_fast);
        end
    endtask

    initial begin
        check_mode(8'h0e, 8'h00, 1, 1, 1);
        check_mode(8'h0e, 8'h10, 1, 1, 1);
        check_mode(8'h0e, 8'h08, 1, 1, 0);
        check_mode(8'h0e, 8'h18, 1, 1, 0);
        check_mode(8'h06, 8'h00, 1, 0, 0);
        check_mode(8'h0a, 8'h00, 1, 0, 0);
        check_mode(8'h0e, 8'h00, 0, 1, 0);
        test_passed = 1;
        $display("PASS VDP mode integration");
        $finish;
    end
endmodule
