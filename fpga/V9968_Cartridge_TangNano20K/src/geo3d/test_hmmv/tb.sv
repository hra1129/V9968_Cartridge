`timescale 1ns/1ps

module tb_geo3d_hmmv;
    localparam [9:0] SCREEN5 = 10'h008;
    localparam [9:0] SCREEN6 = 10'h010;
    localparam [9:0] SCREEN7 = 10'h020;
    localparam [9:0] SCREEN8 = 10'h040;

    reg clk = 0;
    reg clk_eng = 0;
    always #5.82 clk = ~clk;
    always @(posedge clk) clk_eng <= ~clk_eng;

    reg reset_n = 0;
    reg [9:0] screen_mode = SCREEN8;
    reg yjk_mode = 0;
    reg initial_yjk = 0;
    reg switch_yjk = 0;
    reg interleave = 0;
    reg high_speed = 1;
    reg vram256k = 0;
    reg ext_mode = 0;
    reg memory_stalls = 0;
    reg manual_mode = 1;
    reg manual_wr = 0;
    reg [5:0] manual_num = 0;
    reg [7:0] manual_data = 0;
    reg manual_span = 0;
    reg [2:0] bus_address = 0;
    reg bus_ioreq = 0;
    reg bus_write = 0;
    reg bus_valid = 0;
    reg [7:0] bus_wdata = 0;
    wire geo_ready, geo_wr, geo_span, geo_busy;
    wire [5:0] geo_num;
    wire [7:0] geo_data;
    wire command_execute, border_detect, transfer_ready;
    wire [7:0] status_color;
    wire [8:0] border_position;
    wire [17:0] cache_address;
    wire cache_valid, cache_ready, cache_write, cache_rdata_en;
    wire [7:0] cache_wdata, cache_rdata;
    wire cache_flush_start, cache_flush_end;
    wire [17:0] memory_address;
    wire memory_valid, memory_write;
    wire [31:0] memory_wdata;
    wire [3:0] memory_wdata_mask;
    wire [31:0] memory_rdata;
    wire memory_rdata_en;
    reg test_passed = 0;

    wire register_write = manual_mode ? manual_wr : geo_wr;
    wire [5:0] register_num = manual_mode ? manual_num : geo_num;
    wire [7:0] register_data = manual_mode ? manual_data : geo_data;
    wire register_span = manual_mode ? manual_span : (geo_wr && geo_span);

    geo3d_bus u_geo (
        .clk(clk), .clk_eng(clk_eng), .reset_n(reset_n),
        .bus_address(bus_address), .bus_ioreq(bus_ioreq),
        .bus_write(bus_write), .bus_valid(bus_valid), .bus_wdata(bus_wdata),
        .hit(), .bus_ready(geo_ready), .bus_rdata(), .bus_rdata_en(),
        .cmd_wr(geo_wr), .cmd_num(geo_num), .cmd_data(geo_data),
        .cmd_fill_span(geo_span), .cmd_ce(command_execute), .run_busy(geo_busy)
    );

    vdp_command u_command (
        .reset_n(reset_n), .clk(clk),
        .cache_vram_address(cache_address), .cache_vram_valid(cache_valid),
        .cache_vram_ready(cache_ready), .cache_vram_write(cache_write),
        .cache_vram_wdata(cache_wdata), .cache_vram_rdata(cache_rdata),
        .cache_vram_rdata_en(cache_rdata_en),
        .cache_flush_start(cache_flush_start), .cache_flush_end(cache_flush_end),
        .register_write(register_write), .register_num(register_num),
        .register_data(register_data), .register_fill_span(register_span),
        .clear_border_detect(1'b0), .read_color(1'b0),
        .status_command_execute(command_execute), .status_border_detect(border_detect),
        .status_transfer_ready(transfer_ready), .status_color(status_color),
        .status_border_position(border_position),
        .screen_mode(screen_mode), .reg_yjk_mode(yjk_mode), .vram_interleave(interleave),
        .reg_text_back_color(8'd0), .reg_command_enable(1'b0),
        .reg_command_high_speed_mode(high_speed), .reg_ext_command_mode(ext_mode),
        .reg_vram256k_mode(vram256k), .vram_access_mask(), .intr_command_end()
    );

    integer cycles = 0;
    wire memory_ready = !memory_stalls || (cycles % 23 < 11);
    vdp_command_cache u_cache (
        .reset_n(reset_n), .clk(clk), .start(1'b0),
        .cache_vram_address(cache_address), .cache_vram_valid(cache_valid),
        .cache_vram_ready(cache_ready), .cache_vram_write(cache_write),
        .cache_vram_wdata(cache_wdata), .cache_vram_rdata(cache_rdata),
        .cache_vram_rdata_en(cache_rdata_en),
        .cache_flush_start(cache_flush_start), .cache_flush_end(cache_flush_end),
        .cpu_vram_address(18'd0), .cpu_vram_valid(1'b0), .cpu_vram_ready(),
        .cpu_vram_write(1'b0), .cpu_vram_wdata(8'd0),
        .cpu_vram_rdata(), .cpu_vram_rdata_en(),
        .command_vram_address(memory_address), .command_vram_valid(memory_valid),
        .command_vram_ready(memory_ready), .command_vram_write(memory_write),
        .command_vram_wdata(memory_wdata), .command_vram_wdata_mask(memory_wdata_mask),
        .command_vram_rdata(memory_rdata), .command_vram_rdata_en(memory_rdata_en)
    );

    reg [31:0] memory [0:65535];
    reg [31:0] reference [0:65535];
    reg [31:0] read_pipe [0:7];
    reg [7:0] read_valid = 0;
    integer stage;
    integer pixel_writes = 0;
    integer fallbacks = 0;
    integer geo_flat_commands = 0;
    integer geo_wire_commands = 0;
    integer geo_texture_commands = 0;
    integer geo_fast_starts = 0;
    integer geo_line_starts = 0;
    integer geo_texture_starts = 0;
    assign memory_rdata = read_pipe[7];
    assign memory_rdata_en = read_valid[7];

    always @(posedge clk) begin
        if (!reset_n) begin
            cycles <= 0;
            read_valid <= 0;
            pixel_writes <= 0;
            fallbacks <= 0;
            geo_flat_commands <= 0;
            geo_wire_commands <= 0;
            geo_texture_commands <= 0;
            geo_fast_starts <= 0;
            geo_line_starts <= 0;
            geo_texture_starts <= 0;
        end else begin
            cycles <= cycles + 1;
            read_valid <= {read_valid[6:0], memory_valid && memory_ready && !memory_write};
            if (memory_valid && memory_ready && !memory_write)
                read_pipe[0] <= memory[memory_address[17:2]];
            for (stage = 1; stage < 8; stage = stage + 1)
                read_pipe[stage] <= read_pipe[stage-1];
            if (memory_valid && memory_ready && memory_write) begin
                if (!memory_wdata_mask[0]) memory[memory_address[17:2]][7:0] <= memory_wdata[7:0];
                if (!memory_wdata_mask[1]) memory[memory_address[17:2]][15:8] <= memory_wdata[15:8];
                if (!memory_wdata_mask[2]) memory[memory_address[17:2]][23:16] <= memory_wdata[23:16];
                if (!memory_wdata_mask[3]) memory[memory_address[17:2]][31:24] <= memory_wdata[31:24];
            end
            if (cache_valid && cache_ready && cache_write) pixel_writes <= pixel_writes + 1;
            if (u_command.w_geo_hmmv_fallback) fallbacks <= fallbacks + 1;
            if (!manual_mode && geo_wr && geo_num == 6'd46) begin
                if (geo_span) begin
                    if (geo_data[7:4] !== 4'h7) $fatal(1, "Flat span tag on non-LINE command");
                    geo_flat_commands <= geo_flat_commands + 1;
                end else if (geo_data[7:4] == 4'h7) begin
                    geo_wire_commands <= geo_wire_commands + 1;
                end else if (geo_data[7:4] == 4'h3) begin
                    geo_texture_commands <= geo_texture_commands + 1;
                end else begin
                    $fatal(1, "Unexpected Geo3D command %02h", geo_data);
                end
            end
            if (!manual_mode && u_command.ff_start) begin
                if (u_command.ff_geo_hmmv && u_command.ff_command == 4'hc)
                    geo_fast_starts <= geo_fast_starts + 1;
                else if (u_command.ff_command == 4'h7)
                    geo_line_starts <= geo_line_starts + 1;
                else if (u_command.ff_command == 4'h3)
                    geo_texture_starts <= geo_texture_starts + 1;
                else
                    $fatal(1, "Unexpected VDP command %h", u_command.ff_command);
            end
        end
    end

    task automatic reset_case(
        input [9:0] mode, input bit il, input bit hs,
        input bit v256, input bit ext, input bit stalls
    );
        integer i;
        begin
            @(negedge clk);
            reset_n = 0;
            manual_mode = 1;
            manual_wr = 0;
            manual_span = 0;
            bus_ioreq = 0;
            bus_valid = 0;
            screen_mode = mode;
            yjk_mode = initial_yjk;
            interleave = il;
            high_speed = hs;
            vram256k = v256;
            ext_mode = ext;
            memory_stalls = stalls;
            repeat (8) @(negedge clk);
            for (i = 0; i < 65536; i = i + 1)
                memory[i] = 32'h44332211 ^ (i * 32'h01020408);
            reset_n = 1;
            repeat (12) @(negedge clk);
        end
    endtask

    task automatic write_reg(input [5:0] number, input [7:0] data, input bit span);
        begin
            @(negedge clk);
            manual_wr = 1;
            manual_num = number;
            manual_data = data;
            manual_span = span;
            @(negedge clk);
            manual_wr = 0;
            manual_span = 0;
        end
    endtask

    task automatic wait_command_end;
        integer timeout;
        begin
            timeout = 0;
            while (!command_execute && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!command_execute) $fatal(1, "Command did not start");
            timeout = 0;
            while (command_execute && timeout < 300000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (command_execute) $fatal(1, "Command did not finish");
            repeat (4) @(negedge clk);
        end
    endtask

    task automatic run_line(
        input integer x, input integer pixels, input integer y,
        input [7:0] color, input [3:0] lop, input [7:0] arg,
        input [10:0] ny, input bit span,
        input integer change_after, input [9:0] new_mode,
        output bit used_fast, output integer elapsed
    );
        reg [10:0] nx;
        integer start_cycle, timeout;
        begin
            nx = pixels - 1;
            write_reg(6'd36, x[7:0], 0);
            write_reg(6'd37, {7'd0, x[8]}, 0);
            write_reg(6'd38, y[7:0], 0);
            write_reg(6'd39, {5'd0, y[10:8]}, 0);
            write_reg(6'd40, nx[7:0], 0);
            write_reg(6'd41, {5'd0, nx[10:8]}, 0);
            write_reg(6'd42, ny[7:0], 0);
            write_reg(6'd43, {5'd0, ny[10:8]}, 0);
            write_reg(6'd44, color, 0);
            write_reg(6'd45, arg, 0);
            if (change_after == -1) begin
                @(negedge clk);
                if (switch_yjk) yjk_mode = 1;
                else screen_mode = new_mode;
                repeat (4) @(negedge clk);
            end
            write_reg(6'd46, {4'h7, lop}, span);
            if (u_command.ff_geo_hmmv !== 1'b0 && u_command.ff_geo_hmmv !== 1'b1)
                $fatal(1, "Unknown fast-fill state");
            used_fast = u_command.ff_geo_hmmv;
            if (used_fast) begin
                if (u_command.ff_command !== 4'hc ||
                    u_command.reg_nx !== pixels[10:0] || u_command.reg_ny !== 11'd1)
                    $fatal(1, "Incorrect HMMV command parameters");
            end else if (u_command.ff_command !== 4'h7) begin
                $fatal(1, "Expected the original LINE command");
            end
            start_cycle = cycles;
            if (change_after == -2) screen_mode = new_mode;
            if (change_after > 0) begin
                timeout = 0;
                while (pixel_writes < change_after && timeout < 300000) begin
                    @(negedge clk);
                    timeout = timeout + 1;
                end
                if (pixel_writes < change_after) $fatal(1, "Mode-change point not reached");
                if (switch_yjk) yjk_mode = 1;
                else screen_mode = new_mode;
            end
            wait_command_end();
            elapsed = cycles - start_cycle;
        end
    endtask

    task automatic compare_line(
        input [9:0] mode, input bit il, input bit hs, input bit v256,
        input bit stalls, input integer x, input integer pixels, input integer y,
        input [7:0] color, input [3:0] lop, input [7:0] arg, input [10:0] ny,
        input integer change_after, input [9:0] new_mode,
        input bit expect_fast, input bit expect_fallback
    );
        integer i, base_cycles, fast_cycles;
        bit used_fast;
        reg [10:0] expected_nx, expected_ny, expected_dy;
        reg [8:0] expected_dx, expected_border_position;
        reg [3:0] expected_command;
        reg expected_border, expected_transfer;
        reg [7:0] expected_color;
        begin
            reset_case(mode, il, hs, v256, arg[7], stalls);
            run_line(x, pixels, y, color, lop, arg, ny, 0, change_after, new_mode, used_fast, base_cycles);
            if (used_fast) $fatal(1, "CPU LINE was unexpectedly optimized");
            expected_nx = u_command.reg_nx;
            expected_ny = u_command.reg_ny;
            expected_dy = u_command.ff_dy;
            expected_dx = u_command.reg_dx;
            expected_command = u_command.ff_command;
            expected_border = border_detect;
            expected_transfer = transfer_ready;
            expected_color = status_color;
            expected_border_position = border_position;
            for (i = 0; i < 65536; i = i + 1) reference[i] = memory[i];

            reset_case(mode, il, hs, v256, arg[7], stalls);
            run_line(x, pixels, y, color, lop, arg, ny, 1, change_after, new_mode, used_fast, fast_cycles);
            if (used_fast !== expect_fast)
                $fatal(1, "Wrong optimization choice mode=%h x=%0d LOP=%h arg=%h NY=%0d",
                       mode, x, lop, arg, ny);
            if ((fallbacks != 0) !== expect_fallback)
                $fatal(1, "Unexpected mode-change fallback count %0d", fallbacks);
            for (i = 0; i < 65536; i = i + 1)
                if (memory[i] !== reference[i])
                    $fatal(1, "VRAM mismatch at word %0d mode=%h x=%0d pixels=%0d LOP=%h",
                           i, mode, x, pixels, lop);
            if (u_command.reg_nx !== expected_nx || u_command.reg_ny !== expected_ny ||
                u_command.ff_dy !== expected_dy || u_command.reg_dx !== expected_dx ||
                u_command.ff_command !== expected_command ||
                border_detect !== expected_border || transfer_ready !== expected_transfer ||
                status_color !== expected_color || border_position !== expected_border_position)
                $fatal(1, "Post-command LINE parameters or status differ");
            if (expect_fast && change_after == 0 && fast_cycles >= base_cycles)
                $fatal(1, "HMMV was not faster: LINE=%0d HMMV=%0d", base_cycles, fast_cycles);
            $display("PASS mode=%03h il=%0d HS=%0d x=%0d pixels=%0d LOP=%h fast=%0d fallback=%0d LINE=%0d optimized=%0d",
                     mode, il, hs, x, pixels, lop, used_fast, fallbacks, base_cycles, fast_cycles);
        end
    endtask

    task automatic test_native_hmmv(input bit span);
        begin
            reset_case(SCREEN8, 0, 1, 0, 0, 0);
            write_reg(6'd36, 8'd10, 0);
            write_reg(6'd37, 8'd0, 0);
            write_reg(6'd38, 8'd17, 0);
            write_reg(6'd39, 8'd0, 0);
            write_reg(6'd40, 8'd10, 0);
            write_reg(6'd41, 8'd0, 0);
            write_reg(6'd42, 8'd1, 0);
            write_reg(6'd43, 8'd0, 0);
            write_reg(6'd44, 8'h47, 0);
            write_reg(6'd45, 8'd0, 0);
            write_reg(6'd46, 8'hc0, span);
            if (u_command.ff_geo_hmmv !== 1'b0) $fatal(1, "Native HMMV was tagged as Geo3D");
            wait_command_end();
            if (u_command.reg_nx !== 11'd10 || u_command.reg_ny !== 11'd1 ||
                u_command.ff_dy !== 11'd18 || u_command.ff_command !== 4'hc)
                $fatal(1, "Native HMMV parameters changed");
        end
    endtask

    task automatic test_reuse_line;
        integer i, elapsed;
        bit used_fast;
        begin
            reset_case(SCREEN8, 1, 1, 0, 0, 0);
            run_line(41, 30, 17, 8'ha9, 0, 0, 0, 0, 0, SCREEN8, used_fast, elapsed);
            write_reg(6'd36, 8'd80, 0);
            write_reg(6'd37, 8'd0, 0);
            write_reg(6'd44, 8'h67, 0);
            write_reg(6'd46, 8'h70, 0);
            wait_command_end();
            for (i = 0; i < 65536; i = i + 1) reference[i] = memory[i];

            reset_case(SCREEN8, 1, 1, 0, 0, 0);
            run_line(41, 30, 17, 8'ha9, 0, 0, 0, 1, 0, SCREEN8, used_fast, elapsed);
            if (!used_fast) $fatal(1, "First line was not optimized");
            write_reg(6'd36, 8'd80, 0);
            write_reg(6'd37, 8'd0, 0);
            write_reg(6'd44, 8'h67, 0);
            write_reg(6'd46, 8'h70, 0);
            wait_command_end();
            for (i = 0; i < 65536; i = i + 1)
                if (memory[i] !== reference[i])
                    $fatal(1, "Reusing LINE parameters changed VRAM at word %0d", i);
            $display("PASS subsequent CPU LINE reuses Geo3D parameters");
        end
    endtask

    task automatic bus_byte(input [2:0] address, input [7:0] data);
        integer timeout;
        begin
            timeout = 0;
            while (!geo_ready && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!geo_ready) $fatal(1, "Geo3D bus was not ready");
            @(negedge clk);
            bus_address = address;
            bus_ioreq = 1;
            bus_write = 1;
            bus_wdata = data;
            bus_valid = 1;
            @(negedge clk);
            bus_valid = 0;
            timeout = 0;
            while (!geo_ready && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!geo_ready) $fatal(1, "Geo3D bus request did not complete");
        end
    endtask

    task automatic geo_write(input [7:0] index, input [7:0] value);
        begin
            bus_byte(3'd5, index);
            bus_byte(3'd7, value);
        end
    endtask

    task automatic prepare_face(
        input integer x0, input integer x1, input integer y0, input integer y1,
        input [7:0] color0, input [7:0] color1
    );
        begin
            u_geo.u_engine.pmem[0] = {16'd128, 3'd0, y0[15:0], x0[15:0]};
            u_geo.u_engine.pmem[1] = {16'd128, 3'd0, y0[15:0], x1[15:0]};
            u_geo.u_engine.pmem[2] = {16'd128, 3'd0, y1[15:0], x1[15:0]};
            u_geo.u_engine.pmem[3] = {16'd128, 3'd0, y1[15:0], x0[15:0]};
            u_geo.u_engine.fmem[0] = {color0, 48'd0, 10'd3, 10'd2, 10'd1, 10'd0};
            u_geo.u_engine.fmem[1] = {color1, 48'd0, 10'd3, 10'd2, 10'd1, 10'd0};
            u_geo.u_engine.tmem[0] = 64'd0;
            u_geo.u_engine.tmem[1] = 64'd0;
            u_geo.u_engine.emem[0] = {10'd1, 10'd0};
        end
    endtask

    task automatic wait_geo_end;
        integer timeout;
        begin
            timeout = 0;
            while (!geo_busy && timeout < 1000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (!geo_busy) $fatal(1, "Geo3D RUN did not start");
            timeout = 0;
            while (geo_busy && timeout < 300000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (geo_busy) $fatal(1, "Geo3D RUN did not finish");
            repeat (8) @(negedge clk);
        end
    endtask

    task automatic assert_geo_counts(
        input integer flat, input integer wireframe, input integer texture,
        input integer fast, input integer line, input integer lrmm
    );
        begin
            if (geo_flat_commands != flat || geo_wire_commands != wireframe ||
                geo_texture_commands != texture || geo_fast_starts != fast ||
                geo_line_starts != line || geo_texture_starts != lrmm)
                $fatal(1, "Geo3D counts flat/wire/tex=%0d/%0d/%0d starts fast/line/lrmm=%0d/%0d/%0d",
                       geo_flat_commands, geo_wire_commands, geo_texture_commands,
                       geo_fast_starts, geo_line_starts, geo_texture_starts);
        end
    endtask

    task automatic test_geo_flat(input [9:0] mode, input [3:0] lop, input bit off_screen);
        integer i, x, y, address;
        reg [7:0] old_pixel;
        begin
            reset_case(mode, 0, 1, 0, 0, 1);
            manual_mode = 0;
            prepare_face(off_screen ? 256 : 10, off_screen ? 265 : 19, 4, 6, 8'h35, 8'h80);
            for (i = 0; i < 65536; i = i + 1) reference[i] = memory[i];
            if (off_screen) begin
                geo_write(8'h20, 8'd0);
                geo_write(8'h21, 8'd2);
            end
            geo_write(8'h59, 8'd1);
            geo_write(8'h45, {4'd0, lop});
            geo_write(8'h48, 8'h03);
            wait_geo_end();
            if (mode == SCREEN8 && !off_screen && lop == 0)
                assert_geo_counts(3, 0, 0, 3, 0, 0);
            else
                assert_geo_counts(3, 0, 0, 0, 3, 0);
            if (mode == SCREEN8 && !off_screen) begin
                for (y = 4; y <= 6; y = y + 1) begin
                    for (x = 10; x <= 19; x = x + 1) begin
                        address = y * 256 + x;
                        old_pixel = reference[address / 4][8 * (address % 4) +: 8];
                        reference[address / 4][8 * (address % 4) +: 8] =
                            (lop == 0) ? 8'h35 : (old_pixel ^ 8'h35);
                    end
                end
            end
            if (mode == SCREEN8)
                for (i = 0; i < 65536; i = i + 1)
                    if (memory[i] !== reference[i])
                        $fatal(1, "Geo3D face VRAM mismatch at word %0d", i);
            $display("PASS Geo3D flat mode=%03h LOP=%h off_screen=%0d", mode, lop, off_screen);
        end
    endtask

    task automatic test_geo_mixed;
        begin
            reset_case(SCREEN8, 0, 1, 0, 1, 0);
            manual_mode = 0;
            prepare_face(10, 19, 4, 6, 8'h35, 8'h80);
            geo_write(8'h59, 8'd2);
            geo_write(8'h48, 8'h07);
            wait_geo_end();
            assert_geo_counts(3, 0, 3, 3, 0, 3);
            $display("PASS Geo3D mixed flat/textured faces");
        end
    endtask

    task automatic test_geo_wire;
        begin
            reset_case(SCREEN8, 0, 1, 0, 0, 0);
            manual_mode = 0;
            prepare_face(10, 19, 4, 6, 8'h35, 8'h80);
            geo_write(8'h43, 8'd1);
            geo_write(8'h48, 8'h01);
            wait_geo_end();
            assert_geo_counts(0, 1, 0, 0, 1, 0);
            $display("PASS Geo3D wireframe");
        end
    endtask

    task automatic test_geo_mode_change;
        integer timeout;
        begin
            reset_case(SCREEN8, 0, 1, 0, 0, 0);
            manual_mode = 0;
            prepare_face(10, 209, 4, 6, 8'h35, 8'h80);
            geo_write(8'h59, 8'd1);
            geo_write(8'h48, 8'h03);
            timeout = 0;
            while (!(geo_busy && command_execute && u_geo.u_engine.hold_valid &&
                     geo_fast_starts == 1) && timeout < 100000) begin
                @(negedge clk);
                timeout = timeout + 1;
            end
            if (timeout == 100000) $fatal(1, "Queued Geo3D span was not reached");
            screen_mode = SCREEN5;
            wait_geo_end();
            assert_geo_counts(3, 0, 0, 1, 2, 0);
            if (fallbacks == 0) $fatal(1, "Active HMMV did not return to LINE");
            $display("PASS Geo3D mode change with a queued span");
        end
    endtask

    initial begin
        compare_line(SCREEN8, 1, 1, 0, 0, 41, 100, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 0, 1, 0, 8'h00, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 1, 1, 0, 1, 0, 256, 511, 8'hff, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 1, 1, 250, 10, 2047, 8'h36, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 255, 1, 17, 8'h27, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 0, 512, 17, 8'h27, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 0, 513, 17, 8'h27, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 256, 10, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 1, 1, 0, 0, 511, 1, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 0, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 1, 0);
        compare_line(SCREEN5, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN6, 0, 1, 0, 0, 300, 20, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN7, 1, 1, 0, 0, 300, 20, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 1, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 2, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 3, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'h00, 8, 0, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 1, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 4, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 0, 8'ha9, 0, 8, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 3, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 8'h80, 0, 0, SCREEN8, 0, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 0, -1, SCREEN5, 0, 0);
        compare_line(SCREEN5, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 0, -1, SCREEN8, 1, 0);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 0, -2, SCREEN5, 1, 1);
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 30, 17, 8'ha9, 0, 0, 0, 3, SCREEN5, 1, 1);
        compare_line(SCREEN8, 1, 1, 0, 1, 41, 30, 17, 8'ha9, 0, 0, 0, 3, SCREEN7, 1, 1);
        initial_yjk = 1;
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 20, 17, 8'ha9, 0, 0, 0, 0, SCREEN8, 0, 0);
        initial_yjk = 0;
        switch_yjk = 1;
        compare_line(SCREEN8, 0, 1, 0, 0, 41, 30, 17, 8'ha9, 0, 0, 0, 3, SCREEN8, 1, 1);
        switch_yjk = 0;
        test_native_hmmv(0);
        test_native_hmmv(1);
        test_reuse_line();
        test_geo_flat(SCREEN8, 0, 0);
        test_geo_flat(SCREEN5, 0, 0);
        test_geo_flat(SCREEN8, 3, 0);
        test_geo_flat(SCREEN8, 0, 1);
        test_geo_mixed();
        test_geo_wire();
        test_geo_mode_change();
        test_passed = 1;
        $display("PASS all Geo3D HMMV tests");
        $finish;
    end
endmodule
