`timescale 1ns/1ps

module tb_flushend;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg register_write = 1'b0;
	reg [5:0] register_num = 6'd0;
	reg [7:0] register_data = 8'd0;
	reg register_fill_span = 1'b0;
	wire [17:0] cache_address;
	wire cache_valid, cache_ready, cache_write;
	wire [7:0] cache_wdata, cache_rdata;
	wire cache_rdata_en, flush_start, flush_end;
	wire [17:0] vram_address;
	wire vram_valid, vram_write;
	wire [31:0] vram_wdata;
	wire [3:0] vram_mask;
	reg vram_ready = 1'b0;
	reg [31:0] vram_rdata = 32'd0;
	reg vram_rdata_en = 1'b0;
	wire command_execute, command_end;
	reg cpu_valid = 1'b0;
	wire cpu_ready;
	reg [31:0] memory [0:65535];
	reg [15:0] read_pending = 16'd0;
	reg [31:0] read_data [0:15];
	integer slot_period = 16;
	integer read_latency = 6;
	integer slot = 0;
	integer interrupts = 0;
	integer stale_ends = 0;
	reg monitor_command = 1'b0;
	reg test_passed = 1'b0;
	integer i;

	always #5 clk = ~clk;

	vdp_command u_command (
		.reset_n(reset_n), .clk(clk),
		.cache_vram_address(cache_address), .cache_vram_valid(cache_valid),
		.cache_vram_ready(cache_ready), .cache_vram_write(cache_write),
		.cache_vram_wdata(cache_wdata), .cache_vram_rdata(cache_rdata),
		.cache_vram_rdata_en(cache_rdata_en),
		.cache_flush_start(flush_start), .cache_flush_end(flush_end),
		.register_write(register_write), .register_num(register_num),
		.register_data(register_data), .register_fill_span(register_fill_span),
		.clear_border_detect(1'b0), .read_color(1'b0),
		.status_command_execute(command_execute), .status_border_detect(),
		.status_transfer_ready(), .status_color(), .status_border_position(),
		.screen_mode(10'h040), .reg_yjk_mode(1'b0), .vram_interleave(1'b0),
		.reg_text_back_color(8'd0), .reg_command_enable(1'b1),
		.reg_command_high_speed_mode(1'b1), .reg_ext_command_mode(1'b0),
		.reg_vram256k_mode(1'b1), .vram_access_mask(), .intr_command_end(command_end)
	);

	vdp_command_cache u_cache (
		.reset_n(reset_n), .clk(clk), .start(1'b0),
		.cache_vram_address(cache_address), .cache_vram_valid(cache_valid),
		.cache_vram_ready(cache_ready), .cache_vram_write(cache_write),
		.cache_vram_wdata(cache_wdata), .cache_vram_rdata(cache_rdata),
		.cache_vram_rdata_en(cache_rdata_en),
		.cache_flush_start(flush_start), .cache_flush_end(flush_end),
		.cpu_vram_address(18'h3F000), .cpu_vram_valid(cpu_valid),
		.cpu_vram_ready(cpu_ready), .cpu_vram_write(1'b1), .cpu_vram_wdata(8'hA5),
		.cpu_vram_rdata(), .cpu_vram_rdata_en(),
		.command_vram_address(vram_address), .command_vram_valid(vram_valid),
		.command_vram_ready(vram_ready), .command_vram_write(vram_write),
		.command_vram_wdata(vram_wdata), .command_vram_wdata_mask(vram_mask),
		.command_vram_rdata(vram_rdata), .command_vram_rdata_en(vram_rdata_en)
	);

	always @(posedge clk) begin
		if (!reset_n) begin
			slot <= 0;
			vram_ready <= 1'b0;
			read_pending <= 16'd0;
			vram_rdata_en <= 1'b0;
		end
		else begin
			slot <= slot == slot_period - 1 ? 0 : slot + 1;
			vram_ready <= slot == slot_period - 1;
			read_pending <= {read_pending[14:0], vram_valid && vram_ready && !vram_write};
			read_data[0] <= memory[vram_address[17:2]];
			for (i = 1; i < 16; i = i + 1) read_data[i] <= read_data[i-1];
			vram_rdata_en <= read_pending[read_latency];
			vram_rdata <= read_data[read_latency];
			if (vram_valid && vram_ready && vram_write)
				for (i = 0; i < 4; i = i + 1)
					if (!vram_mask[i]) memory[vram_address[17:2]][i*8 +: 8] <= vram_wdata[i*8 +: 8];
		end
	end

	always @(posedge clk) begin
		if (!reset_n) begin
			interrupts <= 0;
			stale_ends <= 0;
		end
		else begin
			if (command_end) interrupts <= interrupts + 1;
			if (monitor_command && flush_end &&
				(u_command.ff_state != u_command.c_state_finish || u_command.ff_start))
				stale_ends <= stale_ends + 1;
			if (monitor_command && !u_command.ff_start && !command_execute &&
				u_command.ff_state != u_command.c_state_idle)
				$fatal(1, "CE fell before the current command reached idle");
		end
	end

	task automatic write_reg(input [5:0] num, input [7:0] value);
		begin
			@(negedge clk);
			register_num = num;
			register_data = value;
			register_write = 1'b1;
			@(negedge clk);
			register_write = 1'b0;
		end
	endtask

	task automatic configure(input [7:0] x, input [7:0] y, input [7:0] nx, input [7:0] ny, input [7:0] color);
		begin
			write_reg(6'd36, x); write_reg(6'd37, 8'd0);
			write_reg(6'd38, y); write_reg(6'd39, 8'd0);
			write_reg(6'd40, nx); write_reg(6'd41, 8'd0);
			write_reg(6'd42, ny); write_reg(6'd43, 8'd0);
			write_reg(6'd44, color); write_reg(6'd45, 8'd0);
		end
	endtask

	task automatic reset_case;
		integer address;
		begin
			@(negedge clk);
			reset_n = 1'b0;
			monitor_command = 1'b0;
			register_write = 1'b0;
			register_fill_span = 1'b0;
			cpu_valid = 1'b0;
			for (address = 0; address < 65536; address = address + 1) memory[address] = 32'd0;
			repeat (4) @(negedge clk);
			reset_n = 1'b1;
			repeat (4) @(negedge clk);
		end
	endtask

	task automatic wait_flush;
		integer timeout;
		begin
			timeout = 0;
			while (u_command.ff_state != u_command.c_state_finish && timeout < 10000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (timeout == 10000) $fatal(1, "Previous command did not reach its final flush");
		end
	endtask

	task automatic wait_end;
		integer timeout;
		begin
			repeat (2) @(negedge clk);
			if (!command_execute) $fatal(1, "Current command did not start");
			monitor_command = 1'b1;
			timeout = 0;
			while (command_execute && timeout < 10000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (command_execute) $fatal(1, "Current command did not finish");
			repeat (2) @(negedge clk);
			monitor_command = 1'b0;
		end
	endtask

	task automatic check_rectangle(input integer x, input integer y, input integer width, input integer height, input [7:0] color);
		integer row, column, address;
		begin
			for (row = y; row < y + height; row = row + 1)
				for (column = x; column < x + width; column = column + 1) begin
					address = row * 256 + column;
					if (memory[address >> 2][(address & 3)*8 +: 8] !== color)
						$fatal(1, "Wrong pixel at (%0d,%0d): expected %h", column, row, color);
				end
		end
	endtask

	task automatic test_restart(input integer kind, input bit previous_geo, input bit coincident_start);
		integer row, column, timeout, address;
		reg [7:0] command;
		begin
			reset_case();
			configure(8'd0, 8'd2, 8'd60, 8'd0, 8'h35);
			register_fill_span = previous_geo;
			write_reg(6'd46, 8'h70);
			register_fill_span = 1'b0;
			wait_flush();

			configure(8'd16, 8'd8, kind < 2 ? 8'd4 : 8'd5, kind < 2 ? 8'd0 : 8'd4, 8'hC7);
			if (kind == 3 || kind == 5) begin
				for (row = 20; row < 24; row = row + 1)
					for (column = 100; column < 105; column = column + 1) begin
						address = row * 256 + column;
						memory[address >> 2][(address & 3)*8 +: 8] = 8'hC7;
					end
				write_reg(6'd32, 8'd100); write_reg(6'd33, 8'd0);
				write_reg(6'd34, 8'd20); write_reg(6'd35, 8'd0);
			end
			case (kind)
			0, 1: command = 8'h70;
			2: command = 8'hC0;
			3: command = 8'hD0;
			4: command = 8'h80;
			5: command = 8'h90;
			default: $fatal(1, "Invalid test kind");
			endcase
			register_fill_span = kind == 1;
			if (coincident_start) begin
				timeout = 0;
				while (!(u_cache.ff_state == u_cache.c_flush_scan && u_cache.ff_flush_index == 8) && timeout < 1000) begin
					@(negedge clk);
					timeout = timeout + 1;
				end
				if (timeout == 1000) $fatal(1, "Missing flush completion alignment");
				// R#46 creates ff_start on the same edge that the cache raises flush_end.
				register_num = 6'd46;
				register_data = command;
				register_write = 1'b1;
				monitor_command = 1'b1;
				@(negedge clk);
				register_write = 1'b0;
			end
			else begin
				if (!command_execute || flush_end) $fatal(1, "Restart missed the previous flush window");
				write_reg(6'd46, command);
			end
			register_fill_span = 1'b0;
			wait_end();
			if (stale_ends != 1) $fatal(1, "Expected one superseded flush completion, got %0d", stale_ends);
			if (interrupts != (coincident_start ? 2 : 1))
				$fatal(1, "Wrong command-end interrupt count: %0d", interrupts);
			check_rectangle(0, 2, 61, 1, 8'h35);
			check_rectangle(16, 8, 5, kind < 2 ? 1 : 4, 8'hC7);
			if (u_command.reg_nx !== (kind < 2 ? 11'd4 : 11'd5) ||
				u_command.reg_ny !== (kind < 2 ? 11'd0 : 11'd4) || u_command.ff_geo_hmmv)
				$fatal(1, "Wrong final NX/NY/Geo3D state");
			if (kind == 1 && u_command.ff_command !== u_command.c_line)
				$fatal(1, "Geo3D command did not restore LINE at its own completion");
			$display("Flush restart kind=%0d previous_geo=%b coincident=%b passed", kind, previous_geo, coincident_start);
		end
	endtask

	task automatic test_parameter_race(input integer kind, input bit previous_geo, input bit with_stop);
		integer timeout;
		reg [7:0] command;
		begin
			reset_case();
			configure(8'd0, 8'd2, 8'd60, 8'd0, 8'h35);
			register_fill_span = previous_geo;
			write_reg(6'd46, 8'h70);
			register_fill_span = 1'b0;
			wait_flush();
			if (with_stop) write_reg(6'd46, 8'h00);

			// The next parameters arrive before the previous command's final flush ends.
			configure(8'd16, 8'd8, kind == 0 ? 8'd4 : 8'd5, kind == 0 ? 8'd0 : 8'd4, 8'hC7);
			if (!command_execute) $fatal(1, "Parameters missed the previous flush window");
			timeout = 0;
			while (command_execute && timeout < 10000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (command_execute) $fatal(1, "Previous command did not finish");
			if (u_command.reg_nx !== (kind == 0 ? 11'd4 : 11'd5) ||
				u_command.reg_ny !== (kind == 0 ? 11'd0 : 11'd4))
				$fatal(1, "End-of-command write-back overwrote NX/NY written by the CPU");

			command = kind == 0 ? 8'h70 : 8'hC0;
			write_reg(6'd46, command);
			wait_end();
			if (interrupts != 2) $fatal(1, "Wrong command-end interrupt count: %0d", interrupts);
			check_rectangle(0, 2, 61, 1, 8'h35);
			check_rectangle(16, 8, 5, kind == 0 ? 1 : 4, 8'hC7);
			check_rectangle(16, kind == 0 ? 9 : 12, 5, 1, 8'h00);
			$display("Parameter race kind=%0d previous_geo=%b stop=%b passed", kind, previous_geo, with_stop);
		end
	endtask

	task automatic test_geo_interrupt(input bit reissue);
		begin
			reset_case();
			configure(8'd0, 8'd2, 8'd60, 8'd0, 8'h35);
			register_fill_span = 1'b1;
			write_reg(6'd46, 8'h70);
			wait_flush();
			register_fill_span = reissue;
			write_reg(6'd46, reissue ? 8'h70 : 8'h00);
			register_fill_span = 1'b0;
			if (u_command.ff_geo_hmmv !== reissue) $fatal(1, "Wrong Geo3D state after the interrupting R#46");
			if (reissue) wait_end();
			else begin
				repeat (2) @(negedge clk);
				while (command_execute) @(negedge clk);
			end
			check_rectangle(0, 2, 61, 1, 8'h35);
			// STOP itself writes NY back at its end, so only the LINE NX is checked for it.
			if (u_command.reg_nx !== 11'd60 || (reissue && u_command.reg_ny !== 11'd0) || u_command.ff_geo_hmmv)
				$fatal(1, "Interrupted Geo3D HMMV did not restore LINE NX/NY");
			$display("Geo3D interrupt reissue=%b passed", reissue);
		end
	endtask

	task automatic test_cpu_idle_flush;
		integer timeout;
		begin
			reset_case();
			cpu_valid = 1'b1;
			timeout = 0;
			while (!cpu_ready && timeout < 1000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (!cpu_ready) $fatal(1, "CPU write was not accepted");
			@(negedge clk);
			cpu_valid = 1'b0;
			timeout = 0;
			while (memory[18'h3F000 >> 2][7:0] !== 8'hA5 && timeout < 1000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (timeout == 1000) $fatal(1, "CPU idle flush did not write VRAM");
			repeat (100) @(negedge clk);
			if (command_execute || interrupts != 0) $fatal(1, "CPU idle flush changed command status");
			$display("CPU idle flush passed");
		end
	endtask

	integer kind;
	initial begin
		for (kind = 0; kind < 6; kind = kind + 1) begin
			test_restart(kind, 1'b0, 1'b0);
			test_restart(kind, 1'b1, 1'b0);
		end
		test_restart(1, 1'b0, 1'b1);
		test_restart(1, 1'b1, 1'b1);
		for (kind = 0; kind < 2; kind = kind + 1) begin
			test_parameter_race(kind, 1'b0, 1'b0);
			test_parameter_race(kind, 1'b1, 1'b0);
			test_parameter_race(kind, 1'b0, 1'b1);
			test_parameter_race(kind, 1'b1, 1'b1);
		end
		test_geo_interrupt(1'b0);
		test_geo_interrupt(1'b1);
		slot_period = 32;
		read_latency = 3;
		test_restart(2, 1'b0, 1'b0);
		test_restart(3, 1'b1, 1'b0);
		test_cpu_idle_flush();
		test_passed = 1'b1;
		$display("Cache flush completion tests PASSED");
		$finish;
	end
endmodule
