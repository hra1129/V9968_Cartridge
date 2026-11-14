module tb ();
	reg clk;
	reg reset_n;
	reg [13:0] screen_pos_x;
	reg palette_valid;
	reg [7:0] palette_num;
	reg [4:0] palette_r;
	reg [4:0] palette_g;
	reg [4:0] palette_b;
	wire [1:0] pixel_phase_x;
	wire [7:0] display_color_screen_mode;
	wire display_color_screen_mode_en;
	wire [7:0] vdp_r;
	wire [7:0] vdp_g;
	wire [7:0] vdp_b;
	integer scan_clock;

	vdp_timing_control_screen_mode u_screen_mode (
		.reset_n(reset_n),
		.clk(clk),
		.screen_pos_x(screen_pos_x),
		.screen_pos_y(10'd40),
		.pixel_pos_x(screen_pos_x[12:4]),
		.pixel_pos_y(8'd40),
		.pixel_phase_x(pixel_phase_x),
		.screen_v_active(1'b1),
		.vram_address(),
		.vram_valid(),
		.vram_rdata(32'hFFFFFFFF),
		.vram_interleave(),
		.display_color(display_color_screen_mode),
		.display_color_en(display_color_screen_mode_en),
		.display_color_border(),
		.sprite_off(),
		.interleaving_page(1'b1),
		.blink(1'b0),
		.field(1'b0),
		.screen_mode(),
		.horizontal_offset_l(3'd0),
		.reg_screen_mode(5'b10000),
		.reg_display_on(1'b1),
		.reg_pattern_name_table_base(8'd0),
		.reg_color_table_base(12'd0),
		.reg_pattern_generator_table_base(7'd0),
		.reg_text_back_color(8'd0),
		.reg_backdrop_color(8'h00),
		.reg_scroll_planes(1'b0),
		.reg_left_mask(1'b1),
		.reg_sprite_mode3(1'b0),
		.reg_flat_interlace_mode(1'b0)
	);

	vdp_color_palette u_palette (
		.reset_n(reset_n),
		.clk(clk),
		.screen_pos_x(screen_pos_x[5:0]),
		.pixel_phase_x(pixel_phase_x),
		.palette_valid(palette_valid),
		.palette_num(palette_num),
		.palette_r(palette_r),
		.palette_g(palette_g),
		.palette_b(palette_b),
		.display_color_screen_mode(8'h03),
		.display_color_screen_mode_en(display_color_screen_mode_en),
		.display_color_screen_mode_border(1'b0),
		.display_color_sprite(8'h05),
		.display_color_sprite_transparent(2'd0),
		.display_color_sprite_en(1'b1),
		.vdp_r(vdp_r),
		.vdp_g(vdp_g),
		.vdp_b(vdp_b),
		.reg_screen_mode(5'b10000),
		.reg_yjk_mode(1'b0),
		.reg_yae_mode(1'b0),
		.reg_color0_opaque(1'b1),
		.reg_backdrop_color(8'h00),
		.reg_ext_palette_mode(1'b0),
		.reg_sprite_mode3(1'b0)
	);

	always #5 clk = ~clk;

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		screen_pos_x = 14'd0;
		palette_valid = 1'b0;
		palette_num = 8'd0;
		palette_r = 5'd0;
		palette_g = 5'd0;
		palette_b = 5'd0;
		repeat (4) @(posedge clk);
		#1;
		reset_n = 1'b1;
		repeat (270) @(posedge clk);
		#1;
		palette_valid = 1'b1;
		palette_num = 8'd1;
		palette_b = 5'd31;
		@(posedge clk);
		#1;
		palette_num = 8'd3;
		palette_r = 5'd31;
		palette_g = 5'd31;
		@(posedge clk);
		#1;
		palette_valid = 1'b0;

		for (scan_clock = 14'h3FF0; scan_clock < 14'h4000; scan_clock = scan_clock + 1) begin
			screen_pos_x = scan_clock[13:0];
			@(posedge clk);
			#1;
		end

		for (scan_clock = 0; scan_clock < 16 * 20; scan_clock = scan_clock + 1) begin
			screen_pos_x = scan_clock;
			@(posedge clk);
			#1;
			if ((screen_pos_x == 13 * 16 || screen_pos_x == 14 * 16) &&
				u_palette.ff_display_color_sprite_en !== 1'b0) begin
				$fatal(1, "Sprite enabled inside the left mask");
			end
			if (screen_pos_x == 14 * 16 || screen_pos_x == 15 * 16) begin
				$display("x=%0d phase=%0d bg_en=%b sprite_en=%b rgb=%02x,%02x,%02x",
					screen_pos_x[13:4], screen_pos_x[3:0], display_color_screen_mode_en,
					u_palette.ff_display_color_sprite_en,
					vdp_r, vdp_g, vdp_b);
			end
			if (screen_pos_x == 15 * 16 && u_palette.ff_display_color_sprite_en !== 1'b1) begin
				$fatal(1, "Sprite did not become enabled at the first output pixel");
			end
			if (screen_pos_x == 14 * 16 + 4 || screen_pos_x == 15 * 16 + 4) begin
				$display("x=%0d phase=%0d sprite_en=%b rgb=%02x,%02x,%02x",
					screen_pos_x[13:4], screen_pos_x[3:0], u_palette.ff_display_color_sprite_en,
					vdp_r, vdp_g, vdp_b);
			end
			if ((screen_pos_x == 14 * 16 + 4 || screen_pos_x == 14 * 16 + 12) &&
				{vdp_r, vdp_g, vdp_b} !== 24'h000000) begin
				$fatal(1, "Sprite was visible inside the left mask");
			end
			if ((screen_pos_x == 15 * 16 + 4 || screen_pos_x == 15 * 16 + 12) &&
				{vdp_r, vdp_g, vdp_b} !== 24'h0000FF) begin
				$fatal(1, "First unmasked pixel was not covered by the blue sprite");
			end
		end
		$display("Left-mask boundary covered by sprite");
		$finish;
	end

	initial begin
		$dumpfile("wave.vcd");
		$dumpvars(0, tb);
	end
endmodule