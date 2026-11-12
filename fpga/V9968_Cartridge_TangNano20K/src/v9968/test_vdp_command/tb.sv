`timescale 1ns/1ps

module tb;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg register_write = 1'b0;
	reg [5:0] register_num = 6'd0;
	reg [7:0] register_data = 8'd0;
	reg read_color = 1'b0;
	reg [9:0] screen_mode = 10'h008;
	reg vram_interleave = 1'b0;
	reg hold_memory = 1'b0;
	wire [17:0] cache_address;
	wire cache_valid;
	wire cache_write;
	wire [7:0] cache_wdata;
	wire cache_ready = !hold_memory;
	reg [7:0] cache_rdata;
	reg cache_rdata_en;
	wire flush_start;
	reg flush_end;
	wire command_execute;
	wire transfer_ready;
	wire [7:0] status_color;
	reg [7:0] memory [0:262143];
	reg [7:0] pending_data;
	reg [2:0] pending_cycles;
	reg test_passed = 1'b0;

	always #5 clk = ~clk;

	vdp_command u_command (
		.reset_n(reset_n), .clk(clk),
		.cache_vram_address(cache_address), .cache_vram_valid(cache_valid),
		.cache_vram_ready(cache_ready), .cache_vram_write(cache_write),
		.cache_vram_wdata(cache_wdata), .cache_vram_rdata(cache_rdata),
		.cache_vram_rdata_en(cache_rdata_en),
		.cache_flush_start(flush_start), .cache_flush_end(flush_end),
		.register_write(register_write), .register_num(register_num),
		.register_data(register_data), .register_fill_span(1'b0),
		.clear_border_detect(1'b0), .read_color(read_color),
		.status_command_execute(command_execute), .status_border_detect(),
		.status_transfer_ready(transfer_ready), .status_color(status_color),
		.status_border_position(), .screen_mode(screen_mode),
		.reg_yjk_mode(1'b0), .vram_interleave(vram_interleave),
		.reg_text_back_color(8'd0), .reg_command_enable(1'b1),
		.reg_command_high_speed_mode(1'b1), .reg_ext_command_mode(1'b1),
		.reg_vram256k_mode(1'b0), .vram_access_mask(), .intr_command_end()
	);

	always @(posedge clk) begin
		if (!reset_n) begin
			cache_rdata <= 8'd0;
			cache_rdata_en <= 1'b0;
			flush_end <= 1'b0;
			pending_data <= 8'd0;
			pending_cycles <= 3'd0;
		end
		else begin
			cache_rdata_en <= 1'b0;
			flush_end <= flush_start;
			if (pending_cycles != 0) begin
				pending_cycles <= pending_cycles - 1'b1;
				if (pending_cycles == 1) begin
					cache_rdata <= pending_data;
					cache_rdata_en <= 1'b1;
				end
			end
			if (cache_valid && cache_ready) begin
				if (cache_write) begin
					memory[cache_address] <= cache_wdata;
				end
				else begin
					if (pending_cycles != 0) $fatal(1, "Overlapping memory reads");
					pending_data <= memory[cache_address];
					pending_cycles <= 3'd3;
				end
			end
		end
	end

	function automatic [17:0] physical_address(input [17:0] address);
		physical_address = vram_interleave ? {address[17], address[0], address[16:1]} : address;
	endfunction

	task automatic reset_case(input [9:0] mode, input bit interleave);
		begin
			@(negedge clk);
			reset_n = 1'b0;
			screen_mode = mode;
			vram_interleave = interleave;
			register_write = 1'b0;
			read_color = 1'b0;
			hold_memory = 1'b0;
			repeat (4) @(negedge clk);
			reset_n = 1'b1;
			repeat (4) @(negedge clk);
		end
	endtask

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

	task automatic wait_command_end;
		integer timeout;
		begin
			timeout = 0;
			while (!command_execute && timeout < 100) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (!command_execute) $fatal(1, "Command did not start");
			while (command_execute && timeout < 3000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (command_execute) $fatal(1, "Command did not finish");
		end
	endtask

	task automatic set_destination(input [8:0] x);
		begin
			write_reg(6'd36, x[7:0]);
			write_reg(6'd37, {7'd0, x[8]});
			write_reg(6'd38, 8'd0);
			write_reg(6'd39, 8'd0);
		end
	endtask

	task automatic set_source(input [8:0] x);
		begin
			write_reg(6'd32, x[7:0]);
			write_reg(6'd33, {7'd0, x[8]});
			write_reg(6'd34, 8'd0);
			write_reg(6'd35, 8'd0);
		end
	endtask

	task automatic set_size(input [8:0] nx);
		begin
			write_reg(6'd40, nx[7:0]);
			write_reg(6'd41, {7'd0, nx[8]});
			write_reg(6'd42, 8'd1);
			write_reg(6'd43, 8'd0);
		end
	endtask

	task automatic test_fg4(input [9:0] mode, input bit interleave);
		reg [17:0] a0, a1, a2, a127, a130, a131, a132, a384;
		begin
			reset_case(mode, interleave);
			a0 = physical_address(18'd0);
			a1 = physical_address(18'd1);
			a2 = physical_address(18'd2);
			a127 = physical_address(18'd127);
			a130 = physical_address(18'd130);
			a131 = physical_address(18'd131);
			a132 = physical_address(18'd132);
			a384 = physical_address(18'd384);
			memory[a0] = 8'h12;
			write_reg(6'd45, 8'h80);
			set_destination(9'd0);
			write_reg(6'd44, 8'h0A);
			write_reg(6'd46, 8'h50);
			wait_command_end();
			if (memory[a0] !== 8'hA2)
				$fatal(1, "FG4 PSET even: mode=%h interleave=%b byte=%h", mode, interleave, memory[a0]);
			set_destination(9'd1);
			write_reg(6'd44, 8'h0B);
			write_reg(6'd46, 8'h50);
			wait_command_end();
			if (memory[a0] !== 8'hAB)
				$fatal(1, "FG4 PSET odd: mode=%h interleave=%b byte=%h", mode, interleave, memory[a0]);

			set_source(9'd0);
			write_reg(6'd46, 8'h40);
			wait_command_end();
			if (status_color !== 8'h0A) $fatal(1, "FG4 POINT even: mode=%h got=%h", mode, status_color);
			set_source(9'd1);
			write_reg(6'd46, 8'h40);
			wait_command_end();
			if (status_color !== 8'h0B) $fatal(1, "FG4 POINT odd: mode=%h got=%h", mode, status_color);

			memory[a0] = 8'h11;
			memory[a1] = 8'h22;
			memory[a2] = 8'h33;
			set_destination(9'd0);
			set_size(9'd4);
			write_reg(6'd44, 8'hCD);
			write_reg(6'd46, 8'hC0);
			wait_command_end();
			if (memory[a0] !== 8'hCD || memory[a1] !== 8'hCD || memory[a2] !== 8'h33)
				$fatal(1, "FG4 HMMV step: mode=%h bytes=%h,%h,%h", mode, memory[a0], memory[a1], memory[a2]);

			memory[a130] = 8'h12;
			memory[a131] = 8'h34;
			memory[a132] = 8'h56;
			set_destination(9'd4);
			write_reg(6'd38, 8'd1);
			set_size(9'd4);
			write_reg(6'd44, 8'h07);
			write_reg(6'd46, 8'h80);
			wait_command_end();
			if (memory[a130] !== 8'h77 || memory[a131] !== 8'h77 || memory[a132] !== 8'h56)
				$fatal(1, "FG4 LMMV: mode=%h bytes=%h,%h,%h", mode, memory[a130], memory[a131], memory[a132]);

			memory[a384] = 8'h12;
			set_destination(9'd0);
			write_reg(6'd38, 8'd3);
			write_reg(6'd44, 8'h0A);
			write_reg(6'd46, 8'h52);
			wait_command_end();
			set_destination(9'd1);
			write_reg(6'd38, 8'd3);
			write_reg(6'd44, 8'h05);
			write_reg(6'd46, 8'h52);
			wait_command_end();
			if (memory[a384] !== 8'hB7)
				$fatal(1, "FG4 PSET OR: mode=%h byte=%h", mode, memory[a384]);

			memory[a0] = 8'h31;
			memory[a127] = 8'h42;
			set_destination(9'd254);
			set_size(9'd4);
			write_reg(6'd44, 8'hEF);
			write_reg(6'd46, 8'hC0);
			wait_command_end();
			if (memory[a127] !== 8'hEF || memory[a0] !== 8'h31)
				$fatal(1, "FG4 256-pixel boundary: mode=%h bytes=%h,%h", mode, memory[a127], memory[a0]);
			$display("FG4 mode=%h interleave=%b passed", mode, interleave);
		end
	endtask

	task automatic wait_lmcm_pixel(input [7:0] expected);
		integer timeout;
		begin
			timeout = 0;
			while ((u_command.ff_state !== 6'd30 || status_color !== expected) && timeout < 2000) begin
				@(negedge clk);
				timeout = timeout + 1;
			end
			if (timeout >= 2000 || transfer_ready !== 1'b1)
				$fatal(1, "LMCM pixel not ready: expected=%h got=%h TR=%b", expected, status_color, transfer_ready);
		end
	endtask

	task automatic read_lmcm_pixel(input [7:0] expected);
		begin
			wait_lmcm_pixel(expected);
			@(negedge clk);
			read_color = 1'b1;
			@(negedge clk);
			read_color = 1'b0;
			if (transfer_ready !== 1'b0) $fatal(1, "S#7 read did not clear TR");
		end
	endtask

	task automatic read_status_color(input [7:0] expected);
		begin
			if (status_color !== expected)
				$fatal(1, "S#7: expected=%h got=%h", expected, status_color);
			@(negedge clk);
			read_color = 1'b1;
			@(negedge clk);
			read_color = 1'b0;
			if (transfer_ready !== 1'b0) $fatal(1, "S#7 read did not clear TR");
		end
	endtask

	initial begin
		test_fg4(10'h001, 1'b0);
		test_fg4(10'h002, 1'b0);
		test_fg4(10'h004, 1'b0);
		test_fg4(10'h008, 1'b0);
		test_fg4(10'h010, 1'b0);
		test_fg4(10'h020, 1'b1);
		test_fg4(10'h040, 1'b1);
		test_fg4(10'h080, 1'b0);
		test_fg4(10'h100, 1'b0);
		test_fg4(10'h200, 1'b0);

		reset_case(10'h010, 1'b0);
		memory[0] = 8'h12;
		set_destination(9'd0);
		write_reg(6'd45, 8'h00);
		write_reg(6'd44, 8'h03);
		write_reg(6'd46, 8'h50);
		wait_command_end();
		if (memory[0] !== 8'hD2) $fatal(1, "SCREEN6 without FG4 must use 2-bit pixels");

		reset_case(10'h040, 1'b1);
		memory[0] = 8'h12;
		set_destination(9'd0);
		write_reg(6'd45, 8'h00);
		write_reg(6'd44, 8'hA5);
		write_reg(6'd46, 8'h50);
		wait_command_end();
		if (memory[0] !== 8'hA5) $fatal(1, "SCREEN8 without FG4 must use 8-bit pixels");

		reset_case(10'h008, 1'b0);
		memory[0] = 8'h34;
		set_source(9'd0);
		set_size(9'd2);
		write_reg(6'd44, 8'hCC);
		write_reg(6'd45, 8'h00);
		if (transfer_ready !== 1'b0) $fatal(1, "R#44 did not clear TR");
		hold_memory = 1'b1;
		write_reg(6'd46, 8'hA0);
		@(negedge clk);
		if (transfer_ready !== 1'b0 || status_color !== 8'hCC)
			$fatal(1, "LMCM start: expected TR=0 and previous S#7 while VRAM is stalled");
		repeat (8) @(negedge clk);
		if (transfer_ready !== 1'b0) $fatal(1, "LMCM start TR changed while VRAM was stalled");
		read_status_color(8'hCC);
		hold_memory = 1'b0;
		read_lmcm_pixel(8'h03);
		read_lmcm_pixel(8'h04);
		wait_command_end();
		$display("LMCM TR=0 start and early S#7 read passed");

		reset_case(10'h008, 1'b0);
		memory[0] = 8'h12;
		memory[1] = 8'h34;
		memory[2] = 8'h56;
		memory[3] = 8'h78;
		memory[32] = 8'h00;
		set_destination(9'd64);
		set_size(9'd1);
		write_reg(6'd44, 8'h0F);
		write_reg(6'd45, 8'h00);
		write_reg(6'd46, 8'hB0);
		wait_command_end();
		if (transfer_ready !== 1'b1 || status_color !== 8'h0F)
			$fatal(1, "LMMC did not leave TR=1 and S#7=0F");
		set_source(9'd0);
		set_size(9'd8);
		write_reg(6'd46, 8'hA0);
		repeat (100) @(negedge clk);
		if (transfer_ready !== 1'b1 || status_color !== 8'h0F || !command_execute)
			$fatal(1, "LMCM did not preserve the pending S#7 value");
		read_status_color(8'h0F);
		read_lmcm_pixel(8'h01);
		read_lmcm_pixel(8'h02);
		read_lmcm_pixel(8'h03);
		read_lmcm_pixel(8'h04);
		read_lmcm_pixel(8'h05);
		read_lmcm_pixel(8'h06);
		read_lmcm_pixel(8'h07);
		read_lmcm_pixel(8'h08);
		wait_command_end();
		$display("LMCM TR=1 start: F1234567 and final pixel 8 passed");

		test_passed = 1'b1;
		$display("VDP command tests PASSED");
		$finish;
	end
endmodule
