`timescale 1ns/1ps

module tb_screen8_mask;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg [13:0] screen_pos_x = 14'd0;
	reg left_mask = 1'b0;
	reg [2:0] horizontal_offset = 3'd0;
	wire [1:0] pixel_phase_x;
	wire bg_en;
	wire [7:0] vdp_r, vdp_g, vdp_b;
	reg test_passed = 1'b0;

	always #5 clk = ~clk;

	vdp_timing_control_screen_mode u_screen_mode (
		.reset_n(reset_n), .clk(clk), .screen_pos_x(screen_pos_x),
		.screen_pos_y(10'd40), .pixel_pos_x(screen_pos_x[12:4]), .pixel_pos_y(8'd40),
		.pixel_phase_x(pixel_phase_x), .screen_v_active(1'b1),
		.vram_address(), .vram_valid(), .vram_rdata(32'd0), .vram_interleave(),
		.display_color(), .display_color_en(bg_en), .sprite_off(),
		.interleaving_page(1'b1), .blink(1'b0), .field(1'b0), .screen_mode(),
		.horizontal_offset_l(horizontal_offset), .reg_screen_mode(5'b11100),
		.reg_display_on(1'b1), .reg_pattern_name_table_base(8'd0),
		.reg_color_table_base(12'd0), .reg_pattern_generator_table_base(7'd0),
		.reg_text_back_color(8'd0), .reg_backdrop_color(8'd0), .reg_scroll_planes(1'b0),
		.reg_left_mask(left_mask), .reg_sprite_mode3(1'b0), .reg_flat_interlace_mode(1'b0)
	);

	vdp_color_palette u_palette (
		.reset_n(reset_n), .clk(clk), .screen_pos_x(screen_pos_x[5:0]), .pixel_phase_x(pixel_phase_x),
		.palette_valid(1'b0), .palette_num(8'd0), .palette_r(5'd0), .palette_g(5'd0), .palette_b(5'd0),
		.display_color_screen_mode(8'd0), .display_color_screen_mode_en(bg_en),
		.display_color_sprite(8'd5), .display_color_sprite_transparent(2'd0), .display_color_sprite_en(1'b1),
		.vdp_r(vdp_r), .vdp_g(vdp_g), .vdp_b(vdp_b), .reg_screen_mode(5'b11100),
		.reg_yjk_mode(1'b0), .reg_yae_mode(1'b0), .reg_color0_opaque(1'b1),
		.reg_backdrop_color(8'd0), .reg_ext_palette_mode(1'b0), .reg_sprite_mode3(1'b0)
	);

	task automatic run_case(input bit msk, input [2:0] offset);
		integer phase, x, source_x;
		reg expected_sprite;
		reg [23:0] expected_rgb;
		begin
			@(negedge clk);
			reset_n = 1'b0;
			left_mask = msk;
			horizontal_offset = offset;
			screen_pos_x = 14'h3FF0;
			repeat (4) @(negedge clk);
			reset_n = 1'b1;
			repeat (270) @(negedge clk);
			for (phase = 14'h3FF0; phase < 16'h4000; phase = phase + 1) begin
				@(negedge clk);
				screen_pos_x = phase;
			end
			for (phase = 0; phase < 16 * 21; phase = phase + 1) begin
				@(negedge clk);
				screen_pos_x = phase;
				@(posedge clk);
				#1;
				x = phase / 16;
				source_x = x - 2;
				if (x >= 7 && phase % 16 == 4) begin
					expected_sprite = (!msk || source_x >= 13) &&
						!(source_x >= 5 && source_x < 5 + offset);
					expected_rgb = expected_sprite ? 24'h007B5A : 24'h000000;
					if ({vdp_r, vdp_g, vdp_b} !== expected_rgb)
						$fatal(1, "SCREEN8 MSK=%b R#27=%0d x=%0d expected=%h got=%h",
							msk, offset, x, expected_rgb, {vdp_r, vdp_g, vdp_b});
				end
			end
		end
	endtask

	integer msk, offset;
	initial begin
		for (msk = 0; msk < 2; msk = msk + 1)
			for (offset = 0; offset < 8; offset = offset + 1)
				run_case(msk, offset);
		test_passed = 1'b1;
		$display("SCREEN8 MSK and R#27 sprite mask tests PASSED");
		$finish;
	end
endmodule
