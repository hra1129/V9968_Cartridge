`timescale 1ns/1ps

module tb_r23;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg [13:0] screen_pos_x = 14'd0;
	reg [9:0] screen_pos_y = 10'd0;
	reg [7:0] pixel_pos_y = 8'd0;
	reg sprite_nonR23_mode = 1'b0;
	reg sprite_mode3 = 1'b0;
	reg interleave = 1'b0;
	reg [31:0] vram_rdata = 32'd0;
	reg [7:0] vram_rdata8 = 8'd0;
	reg [31:0] attributes [0:31];
	wire [17:0] vram_address;
	wire vram_valid;
	wire [7:0] display_color;
	wire display_color_en;
	wire sprite_collision;
	wire [9:0] sprite_collision_y;
	reg test_passed = 1'b0;

	always #5 clk = ~clk;

	vdp_timing_control_sprite u_dut (
		.reset_n(reset_n), .clk(clk),
		.screen_pos_x(screen_pos_x), .screen_pos_y(screen_pos_y), .pixel_pos_y(pixel_pos_y),
		.screen_v_active(1'b1), .sprite_overmap_v_active(1'b1),
		.vram_address(vram_address), .vram_valid(vram_valid),
		.vram_rdata(vram_rdata), .vram_rdata8(vram_rdata8), .vram_interleave(interleave),
		.display_color(display_color), .display_color_transparent(), .display_color_en(display_color_en),
		.clear_sprite_collision(1'b0), .sprite_collision(sprite_collision),
		.clear_sprite_collision_xy(1'b0), .sprite_collision_x(), .sprite_collision_y(sprite_collision_y),
		.sprite_off(1'b0), .clear_sprite_overmap(1'b0), .sprite_overmap_enable(1'b1),
		.sprite_overmap(), .sprite_overmap_id(),
		.reg_screen_mode(interleave ? 5'b10100 : 5'b01100), .reg_display_on(1'b1),
		.reg_color0_opaque(1'b0), .reg_sprite_magify(1'b0), .reg_sprite_16x16(1'b0),
		.reg_sprite_disable(1'b0), .reg_sprite_attribute_table_base(11'd0),
		.reg_sprite_pattern_generator_table_base(7'd4), .reg_left_mask(1'b0),
		.reg_sprite_nonR23_mode(sprite_nonR23_mode), .reg_sprite_mode3(sprite_mode3),
		.reg_sprite16_mode(1'b0), .reg_sprite_priority_shuffle(1'b0), .reg_ext_palette_mode(1'b1)
	);

	always @(posedge clk) begin
		if (vram_valid && u_dut.w_vp_vram_valid) begin
			if (interleave) begin
				if (vram_address[0])
					vram_rdata <= {
						attributes[{vram_address[6:3], 1'b1}][31:24],
						attributes[{vram_address[6:3], 1'b1}][15:8],
						attributes[{vram_address[6:3], 1'b0}][31:24],
						attributes[{vram_address[6:3], 1'b0}][15:8]
					};
				else
					vram_rdata <= {
						attributes[{vram_address[6:3], 1'b1}][23:16],
						attributes[{vram_address[6:3], 1'b1}][7:0],
						attributes[{vram_address[6:3], 1'b0}][23:16],
						attributes[{vram_address[6:3], 1'b0}][7:0]
					};
			end
			else begin
				vram_rdata <= attributes[vram_address[6:2]];
			end
		end
		if (vram_valid && u_dut.w_ic_vram_valid)
			vram_rdata8 <= (u_dut.u_info_collect.ff_state == 2'd0) ? 8'h05 : 8'hFF;
	end

	task automatic step(input [13:0] x);
		begin
			@(negedge clk);
			screen_pos_x = x;
			@(posedge clk);
			#1;
		end
	endtask

	task automatic run_case(input bit nonR23, input bit use_interleave);
		integer i, phase, visible_count;
		reg [7:0] selected_y;
		begin
			@(negedge clk);
			reset_n = 1'b0;
			interleave = use_interleave;
			sprite_nonR23_mode = nonR23;
			screen_pos_x = 14'd0;
			screen_pos_y = 10'h3FF;
			pixel_pos_y = 8'd0;
			for (i = 0; i < 32; i = i + 1) attributes[i] = 32'h000000D8;
			selected_y = nonR23 ? 8'd40 : 8'd140;
			attributes[0] = {8'h0A, 8'd0, 8'd232, selected_y};
			attributes[1] = {8'h03, 8'd1, 8'd232, selected_y};
			repeat (4) @(negedge clk);
			reset_n = 1'b1;
			step(14'h3DFF);
			screen_pos_y = 10'd40;
			pixel_pos_y = 8'd140;
			step(14'h3FFF);
			for (phase = 0; phase < 16 * 276; phase = phase + 1) begin
				if (phase == 16 * 32) pixel_pos_y = 8'd170;
				step(phase);
			end
			if (u_dut.u_select_visible_planes.selected_pixel_pos_y !== {1'b0, selected_y})
				$fatal(1, "Sprite selection did not retain its line Y (SVNS=%b)", nonR23);
			if (u_dut.w_selected_count !== 5'd2)
				$fatal(1, "Expected two selected sprites (SVNS=%b interleave=%b), got %0d",
					nonR23, use_interleave, u_dut.w_selected_count);

			pixel_pos_y = 8'd140;
			step(14'h3FFF);
			visible_count = 0;
			for (phase = 0; phase < 16 * 256; phase = phase + 1) begin
				step(phase);
				if (display_color_en) begin
					visible_count = visible_count + 1;
					if (display_color !== 8'hA5)
						$fatal(1, "Sprite palette expected A5, got %h (interleave=%b)",
							display_color, use_interleave);
				end
			end
			if (visible_count == 0 || !sprite_collision || sprite_collision_y !== 10'd48)
				$fatal(1, "Expected sprite collision Y=48 (SVNS=%b interleave=%b): pixels=%0d collision=%b Y=%0d",
					nonR23, use_interleave, visible_count, sprite_collision, sprite_collision_y);
		end
	endtask

	//	SP3 selection of one sprite (MGY=16) at sprite Y=y on a line at screen_y / background ring Y=pix_y.
	task automatic run_sp3_select(input bit nonR23, input [9:0] y, input [9:0] screen_y, input [7:0] pix_y,
								  input [8:0] expected_pos_y, input [4:0] expected_count);
		integer i, phase;
		begin
			@(negedge clk);
			reset_n = 1'b0;
			interleave = 1'b0;
			sprite_nonR23_mode = nonR23;
			sprite_mode3 = 1'b1;
			screen_pos_x = 14'd0;
			screen_pos_y = 10'h3FF;
			pixel_pos_y = pix_y;
			for (i = 0; i < 32; i = i + 1) attributes[i] = 32'h000000D8;
			attributes[0] = {8'h00, 8'd16, 6'd0, y};
			repeat (4) @(negedge clk);
			reset_n = 1'b1;
			step(14'h3DFF);
			screen_pos_y = screen_y;
			step(14'h3FFF);
			for (phase = 0; phase < 16 * 276; phase = phase + 1) step(phase);
			if (u_dut.u_select_visible_planes.selected_pixel_pos_y !== expected_pos_y)
				$fatal(1, "SP3 line Y expected %h, got %h (SVNS=%b Y=%0d)",
					expected_pos_y, u_dut.u_select_visible_planes.selected_pixel_pos_y, nonR23, y);
			if (u_dut.w_selected_count !== expected_count)
				$fatal(1, "SP3 expected %0d selected sprites, got %0d (SVNS=%b Y=%0d screen_y=%0d pixel_y=%0d)",
					expected_count, u_dut.w_selected_count, nonR23, y, $signed(screen_y), pix_y);
			sprite_mode3 = 1'b0;
			sprite_nonR23_mode = 1'b0;
		end
	endtask

	initial begin
		//	SVNS=0, Y=1015 (-9) at selection line -1 for display line 0: R#23=0/1 select it, R#23=20 does not.
		run_sp3_select(1'b0, 10'h3F7, 10'h3FF, 8'hFF, 9'h0FF, 5'd1);
		run_sp3_select(1'b0, 10'h3F7, 10'h3FF, 8'h00, 9'h000, 5'd1);
		run_sp3_select(1'b0, 10'h3F7, 10'h3FF, 8'h13, 9'h013, 5'd0);
		//	SVNS=0 wraps at the background ring seam (pixel Y 255 -> 0) like SP1/2.
		run_sp3_select(1'b0, 10'h0FA, 10'd100, 8'h02, 9'h002, 5'd1);
		run_sp3_select(1'b0, 10'h3FA, 10'd100, 8'h04, 9'h004, 5'd1);
		run_sp3_select(1'b0, 10'h0FA, 10'd100, 8'h0A, 9'h00A, 5'd0);
		//	Y=256...767 is off the ring and never displayed.
		run_sp3_select(1'b0, 10'h10A, 10'd100, 8'h0C, 9'h00C, 5'd0);
		run_sp3_select(1'b0, 10'h2FA, 10'd100, 8'h02, 9'h002, 5'd0);
		//	SVNS=1 keeps the signed screen coordinate without wrap.
		run_sp3_select(1'b1, 10'h0FA, 10'd2, 8'h02, 9'h002, 5'd0);
		run_sp3_select(1'b1, 10'h3F7, 10'h3FF, 8'hFF, 9'h1FF, 5'd1);
		run_case(1'b0, 1'b0);
		run_case(1'b1, 1'b0);
		run_case(1'b0, 1'b1);
		run_case(1'b1, 1'b1);
		test_passed = 1'b1;
		$display("Sprite R#23/SVNS collision and integrated EPAL tests PASSED");
		$finish;
	end
endmodule
