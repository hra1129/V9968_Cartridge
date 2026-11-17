`timescale 1ps/1ps

module tb_i2s_receiver;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg i2s_en = 1'b0;
	reg i2s_bclk = 1'b1;
	reg i2s_lrclk = 1'b1;
	reg i2s_din = 1'b1;
	wire pcm_fs;
	wire [23:0] pcm_l;
	wire [23:0] pcm_r;
	reg test_passed = 1'b0;

	always #5820 clk = ~clk;

	ip_i2s_receiver u_dut (
		.reset_n(reset_n), .clk(clk), .i2s_en(i2s_en),
		.i2s_bclk(i2s_bclk), .i2s_lrclk(i2s_lrclk), .i2s_din(i2s_din),
		.pcm_fs(pcm_fs), .pcm_l(pcm_l), .pcm_r(pcm_r)
	);

	integer half_bclk = 162760;
	reg data_bit = 1'b0;

	//	Philips I2S: the data line is one BCLK behind LRCLK.
	task automatic bclk_cycle(input lr, input next_bit);
		begin
			#(half_bclk);
			i2s_bclk = 1'b0;
			i2s_lrclk = lr;
			i2s_din = data_bit;
			data_bit = next_bit;
			#(half_bclk);
			i2s_bclk = 1'b1;
		end
	endtask

	task automatic send_frame(input integer slot, input integer width, input [31:0] left, input [31:0] right);
		integer i;
		begin
			for( i = 0; i < slot; i = i + 1 )
				bclk_cycle(1'b0, (i < width) ? left[width - 1 - i] : 1'b0);
			for( i = 0; i < slot; i = i + 1 )
				bclk_cycle(1'b1, (i < width) ? right[width - 1 - i] : 1'b0);
		end
	endtask

	function automatic [23:0] justify(input integer width, input [31:0] value);
		reg [55:0] wide;
		begin
			wide = { 24'd0, value } << (56 - width);
			justify = wide[55:32];
		end
	endfunction

	integer fs_rise = 0;
	integer fs_fall = 0;
	always @(posedge pcm_fs) fs_rise = fs_rise + 1;
	always @(negedge pcm_fs) fs_fall = fs_fall + 1;

	task automatic check_case(input integer slot, input integer width);
		reg [31:0] l0, r0, l1, r1;
		integer before_fall;
		begin
			l0 = $urandom; r0 = $urandom; l1 = $urandom; r1 = $urandom;
			if( width < 32 ) begin
				l0 = l0 & ((32'd1 << width) - 1); r0 = r0 & ((32'd1 << width) - 1);
				l1 = l1 & ((32'd1 << width) - 1); r1 = r1 & ((32'd1 << width) - 1);
			end
			half_bclk = 1000000000 / (192 * slot);
			send_frame(slot, width, 32'd0, 32'd0);
			before_fall = fs_fall;
			send_frame(slot, width, l0, r0);
			send_frame(slot, width, l1, r1);
			repeat(4) @(posedge clk);
			//	l0/r0 completed at the first BCLK of the l1 frame; the l1 word has completed too.
			if( fs_fall != before_fall + 2 )
				$fatal(1, "slot %0d: pcm_fs fell %0d times", slot, fs_fall - before_fall);
			if( pcm_fs !== 1'b1 ) $fatal(1, "slot %0d: pcm_fs should be high after a left word", slot);
			if( pcm_l !== justify(width, l0) || pcm_r !== justify(width, r0) )
				$fatal(1, "slot %0d width %0d: got L=%06h R=%06h expected L=%06h R=%06h",
					slot, width, pcm_l, pcm_r, justify(width, l0), justify(width, r0));
			send_frame(slot, width, 32'd0, 32'd0);
			repeat(4) @(posedge clk);
			if( pcm_l !== justify(width, l1) || pcm_r !== justify(width, r1) )
				$fatal(1, "slot %0d width %0d: second frame mismatch L=%06h R=%06h", slot, width, pcm_l, pcm_r);
			$display("slot %0d width %0d: L=%06h R=%06h OK", slot, width, pcm_l, pcm_r);
		end
	endtask

	initial begin
		repeat(4) @(posedge clk);
		reset_n = 1'b1;

		$display("[1] i2s_en=0 keeps outputs at 0");
		send_frame(32, 16, 32'h0000FFFF, 32'h0000FFFF);
		send_frame(32, 16, 32'h0000FFFF, 32'h0000FFFF);
		if( pcm_fs !== 1'b0 || pcm_l !== 24'd0 || pcm_r !== 24'd0 || fs_rise != 0 )
			$fatal(1, "Outputs moved while i2s_en=0");

		$display("[2] 16/24/32-bit slots");
		i2s_en = 1'b1;
		check_case(16, 16);
		check_case(32, 16);
		check_case(32, 24);
		check_case(24, 24);
		check_case(32, 32);

		$display("[3] Disabling clears the outputs");
		i2s_en = 1'b0;
		repeat(4) @(posedge clk);
		if( pcm_fs !== 1'b0 || pcm_l !== 24'd0 || pcm_r !== 24'd0 )
			$fatal(1, "Outputs were not cleared by i2s_en=0");

		$display("I2S receiver test PASSED");
		test_passed = 1'b1;
		$finish;
	end

	initial begin
		#(64'd100000000000);
		$fatal(1, "Test timeout");
	end
endmodule
