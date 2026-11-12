`timescale 1ns/1ps

module tb;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg [5:0] screen_pos_x = 6'd0;
	reg [1:0] pixel_phase_x = 2'd0;
	reg palette_valid = 1'b0;
	reg [7:0] palette_num = 8'd0;
	reg [4:0] palette_r = 5'd0;
	reg [4:0] palette_g = 5'd0;
	reg [4:0] palette_b = 5'd0;
	reg [7:0] bg_color = 8'd0;
	reg bg_en = 1'b1;
	reg [7:0] sprite_color = 8'd5;
	reg [1:0] sprite_transparent = 2'd0;
	reg sprite_en = 1'b0;
	reg [4:0] screen_mode = 5'b11100;
	reg yjk_mode = 1'b0;
	reg yae_mode = 1'b0;
	reg ext_palette = 1'b0;
	reg sprite_mode3 = 1'b0;
	wire [7:0] vdp_r, vdp_g, vdp_b;
	reg test_passed = 1'b0;
	reg bg_history [0:63];
	reg sprite_history [0:63];
	reg palette_history [0:63];
	reg [7:0] color_history [0:63];
	integer pixel_number = 0;

	always #5 clk = ~clk;

	vdp_color_palette u_palette (
		.reset_n(reset_n), .clk(clk),
		.screen_pos_x(screen_pos_x), .pixel_phase_x(pixel_phase_x),
		.palette_valid(palette_valid), .palette_num(palette_num),
		.palette_r(palette_r), .palette_g(palette_g), .palette_b(palette_b),
		.display_color_screen_mode(bg_color), .display_color_screen_mode_en(bg_en),
		.display_color_sprite(sprite_color), .display_color_sprite_transparent(sprite_transparent),
		.display_color_sprite_en(sprite_en), .vdp_r(vdp_r), .vdp_g(vdp_g), .vdp_b(vdp_b),
		.reg_screen_mode(screen_mode), .reg_yjk_mode(yjk_mode), .reg_yae_mode(yae_mode),
		.reg_color0_opaque(1'b1), .reg_backdrop_color(8'h03),
		.reg_ext_palette_mode(ext_palette), .reg_sprite_mode3(sprite_mode3)
	);

	task automatic write_palette(
		input [7:0] index, input [4:0] r, input [4:0] g, input [4:0] b
	);
		begin
			@(negedge clk);
			palette_num = index;
			palette_r = r;
			palette_g = g;
			palette_b = b;
			palette_valid = 1'b1;
			@(negedge clk);
			palette_valid = 1'b0;
		end
	endtask

	task automatic pixel(input bit check, input [23:0] expected);
		integer phase;
		begin
			for (phase = 0; phase < 16; phase = phase + 1) begin
				@(negedge clk);
				screen_pos_x = {pixel_number[1:0], phase[3:0]};
				pixel_phase_x = pixel_number[1:0];
				@(posedge clk);
				#1;
				if (check && phase == 4 && {vdp_r, vdp_g, vdp_b} !== expected)
					$fatal(1, "pixel=%0d mode=%b YJK=%b YAE=%b: expected RGB=%h got=%h",
						pixel_number, screen_mode, yjk_mode, yae_mode, expected, {vdp_r, vdp_g, vdp_b});
			end
			pixel_number = pixel_number + 1;
		end
	endtask

	task automatic patterned_pixels(input bit use_yjk, input bit use_yae, input bit use_screen8);
		integer n, sprite_index, bg_index;
		reg [23:0] expected;
		begin
			yjk_mode = use_yjk;
			yae_mode = use_yae;
			screen_mode = use_screen8 || use_yjk ? 5'b11100 : 5'b01100;
			ext_palette = 1'b0;
			sprite_mode3 = 1'b0;
			sprite_transparent = 2'd0;
			for (n = 0; n < 56; n = n + 1) begin
				bg_en = (n % 13 >= 3);
				sprite_en = (n % 7 < 4);
				sprite_color = (n % 2 == 0) ? 8'd5 : 8'd6;
				bg_color = (use_yae && n % 2 == 0) ? 8'h38 : 8'h00;
				bg_history[n] = bg_en;
				sprite_history[n] = sprite_en;
				palette_history[n] = use_yae && n % 2 == 0;
				color_history[n] = sprite_color;
				sprite_index = use_yjk ? n - 4 : n;
				bg_index = use_yjk ? n - 5 : n - 1;
				expected = 24'd0;
				if (n >= 10) begin
					if (sprite_history[sprite_index] && bg_history[bg_index]) begin
						if (use_screen8)
							expected = color_history[sprite_index] == 8'd5 ? 24'h007B5A : 24'h7B7B00;
						else
							expected = color_history[sprite_index] == 8'd5 ? 24'hFF0000 : 24'h00FF00;
					end
					// Preserve the existing SCREEN12 backdrop path in this sprite regression.
					else if (!bg_history[bg_index] && use_yjk && !use_yae)
						expected = 24'h404052;
					else if (!bg_history[bg_index] || palette_history[bg_index])
						expected = 24'h0000FF;
				end
				pixel(n >= 10, expected);
			end
		end
	endtask

	task automatic solid_pixels(input [23:0] expected);
		integer n;
		begin
			for (n = 0; n < 14; n = n + 1) pixel(n >= 10, expected);
		end
	endtask

	task automatic patterned_hires_pixels(input bit screen6);
		integer n, phase;
		reg [23:0] expected;
		begin
			screen_mode = screen6 ? 5'b10000 : 5'b10100;
			yjk_mode = 1'b0;
			ext_palette = 1'b0;
			sprite_mode3 = 1'b0;
			sprite_transparent = 2'd0;
			bg_color = 8'd3;
			sprite_color = 8'd5;
			for (n = 0; n < 56; n = n + 1) begin
				bg_history[n] = (n % 13 >= 3);
				sprite_en = (n % 7 < 4);
				expected = 24'h0000FF;
				if (n >= 10 && sprite_en && bg_history[n - 1]) expected = 24'hFF0000;
				for (phase = 0; phase < 16; phase = phase + 1) begin
					@(negedge clk);
					screen_pos_x = {pixel_number[1:0], phase[3:0]};
					pixel_phase_x = pixel_number[1:0];
					if (phase == 0) bg_en = bg_history[n];
					if (phase == 8) bg_en = (n % 11 < 5);
					@(posedge clk);
					#1;
					if (n >= 10 && (phase == 4 || phase == 12) &&
						{vdp_r, vdp_g, vdp_b} !== expected)
						$fatal(1, "SCREEN%0d pixel=%0d phase=%0d: expected RGB=%h got=%h",
							screen6 ? 6 : 7, pixel_number, phase, expected, {vdp_r, vdp_g, vdp_b});
				end
				pixel_number = pixel_number + 1;
			end
		end
	endtask

	initial begin
		repeat (4) @(negedge clk);
		reset_n = 1'b1;
		repeat (270) @(negedge clk);
		write_palette(8'd3, 5'd0, 5'd0, 5'd31);
		write_palette(8'd5, 5'd31, 5'd0, 5'd0);
		write_palette(8'd6, 5'd0, 5'd31, 5'd0);
		write_palette(8'hA5, 5'd0, 5'd31, 5'd0);

		patterned_pixels(1'b0, 1'b0, 1'b0);
		patterned_pixels(1'b0, 1'b0, 1'b1);
		patterned_pixels(1'b1, 1'b0, 1'b0);
		patterned_pixels(1'b1, 1'b1, 1'b0);

		yjk_mode = 1'b1;
		yae_mode = 1'b0;
		bg_color = 8'd0;
		bg_en = 1'b1;
		sprite_en = 1'b1;
		sprite_color = 8'd5;
		sprite_mode3 = 1'b1;
		sprite_transparent = 2'd2;
		solid_pixels(24'h8B0000);

		bg_color = 8'h40;
		solid_pixels(24'hA92E37);

		yae_mode = 1'b1;
		bg_color = 8'h38;
		solid_pixels(24'h8B008B);

		sprite_mode3 = 1'b0;
		sprite_transparent = 2'd0;
		ext_palette = 1'b1;
		sprite_color = 8'hA5;
		solid_pixels(24'h00FF00);

		write_palette(8'h30, 5'd0, 5'd31, 5'd0);
		sprite_en = 1'b0;
		solid_pixels(24'h00FF00);

		write_palette(8'd0, 5'd0, 5'd0, 5'd31);
		write_palette(8'd1, 5'd31, 5'd0, 5'd0);
		patterned_hires_pixels(1'b1);
		patterned_hires_pixels(1'b0);

		test_passed = 1'b1;
		$display("VDP palette YJK, sprite alignment, masking, and blend tests PASSED");
		$finish;
	end
endmodule
