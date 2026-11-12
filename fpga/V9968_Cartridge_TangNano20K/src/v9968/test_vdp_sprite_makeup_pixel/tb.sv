`timescale 1ns/1ps

module tb;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg [13:0] screen_pos_x = 14'd0;
	reg [9:0] screen_pos_y = 10'd40;
	reg sprite_mode2 = 1'b1;
	reg ext_palette = 1'b1;
	reg sprite_mode3 = 1'b0;
	reg [4:0] selected_count = 5'd1;
	reg [3:0] makeup_plane = 4'd0;
	reg [7:0] color = 8'd0;
	reg [3:0] palette_set = 4'd0;
	reg color_plane_x_en = 1'b0;
	reg [31:0] pattern = 32'd0;
	reg pattern_left_en = 1'b0;
	wire [7:0] display_color;
	wire display_color_en;
	wire sprite_collision;
	wire [9:0] sprite_collision_y;
	reg test_passed = 1'b0;

	always #5 clk = ~clk;

	vdp_sprite_makeup_pixel u_dut (
		.reset_n(reset_n), .clk(clk),
		.screen_pos_x(screen_pos_x), .screen_pos_y(screen_pos_y), .screen_v_active(1'b1),
		.sprite_mode2(sprite_mode2), .reg_display_on(1'b1), .reg_color0_opaque(1'b0),
		.reg_sprite_magify(1'b0), .reg_ext_palette_mode(ext_palette),
		.reg_sprite_16x16(1'b0), .reg_sprite_mode3(sprite_mode3),
		.selected_count(selected_count), .makeup_plane(makeup_plane),
		.plane_x(10'd232), .color(color), .palette_set(palette_set),
		.info_mgx(8'd8), .color_plane_x_en(color_plane_x_en), .pattern(pattern),
		.pattern_left_en(pattern_left_en), .pattern_right_en(1'b0),
		.x(), .mgx(), .sample_x(7'd0), .display_color(display_color),
		.display_color_transparent(), .display_color_en(display_color_en),
		.clear_sprite_collision(1'b0), .sprite_collision(sprite_collision),
		.clear_sprite_collision_xy(1'b0), .sprite_collision_x(),
		.sprite_collision_y(sprite_collision_y)
	);

	task automatic reset_case(
		input bit mode2, input bit epal, input bit mode3, input [4:0] count
	);
		begin
			@(negedge clk);
			reset_n = 1'b0;
			screen_pos_x = 14'd0;
			sprite_mode2 = mode2;
			ext_palette = epal;
			sprite_mode3 = mode3;
			selected_count = count;
			color_plane_x_en = 1'b0;
			pattern_left_en = 1'b0;
			repeat (4) @(negedge clk);
			reset_n = 1'b1;
		end
	endtask

	task automatic load_plane(
		input [3:0] plane, input [3:0] group_number,
		input [7:0] plane_color, input [31:0] plane_pattern
	);
		begin
			@(negedge clk);
			makeup_plane = plane;
			palette_set = group_number;
			color = plane_color;
			pattern = plane_pattern;
			color_plane_x_en = 1'b1;
			pattern_left_en = 1'b1;
			@(negedge clk);
			color_plane_x_en = 1'b0;
			pattern_left_en = 1'b0;
		end
	endtask

	task automatic scan_line(input [7:0] expected, input bit expect_collision);
		integer phase, visible_count;
		begin
			visible_count = 0;
			@(negedge clk);
			screen_pos_x = 14'h3FFF;
			@(negedge clk);
			for (phase = 0; phase < 16 * 256; phase = phase + 1) begin
				screen_pos_x = phase;
				@(posedge clk);
				#1;
				if (display_color_en) begin
					visible_count = visible_count + 1;
					if (display_color !== expected)
						$fatal(1, "Sprite color expected %h, got %h at phase %0d", expected, display_color, phase);
				end
				@(negedge clk);
			end
			if (visible_count == 0) $fatal(1, "No sprite pixels were produced");
			if (sprite_collision !== expect_collision)
				$fatal(1, "Collision expected %b, got %b", expect_collision, sprite_collision);
			if (expect_collision && sprite_collision_y !== screen_pos_y + 10'd8)
				$fatal(1, "Collision Y expected %0d, got %0d", screen_pos_y + 10'd8, sprite_collision_y);
		end
	endtask

	initial begin
		reset_case(1'b1, 1'b1, 1'b0, 5'd1);
		load_plane(4'd0, 4'hA, 8'h05, 32'hFFFFFFFF);
		scan_line(8'hA5, 1'b0);

		reset_case(1'b1, 1'b0, 1'b0, 5'd1);
		load_plane(4'd0, 4'hA, 8'h05, 32'hFFFFFFFF);
		scan_line(8'h05, 1'b0);

		reset_case(1'b0, 1'b1, 1'b0, 5'd1);
		load_plane(4'd0, 4'hA, 8'h05, 32'hFFFFFFFF);
		scan_line(8'h05, 1'b0);

		reset_case(1'b1, 1'b1, 1'b0, 5'd2);
		load_plane(4'd0, 4'hA, 8'h01, 32'hFFFFFFFF);
		load_plane(4'd1, 4'h3, 8'h42, 32'hFFFFFFFF);
		scan_line(8'hA3, 1'b0);

		reset_case(1'b1, 1'b1, 1'b0, 5'd2);
		load_plane(4'd0, 4'hA, 8'h01, 32'h00000000);
		load_plane(4'd1, 4'h3, 8'h42, 32'hFFFFFFFF);
		scan_line(8'h32, 1'b0);

		reset_case(1'b1, 1'b1, 1'b0, 5'd2);
		screen_pos_y = 10'd300;
		load_plane(4'd0, 4'hA, 8'h01, 32'hFFFFFFFF);
		load_plane(4'd1, 4'h3, 8'h02, 32'hFFFFFFFF);
		scan_line(8'hA1, 1'b1);

		reset_case(1'b1, 1'b1, 1'b1, 5'd1);
		load_plane(4'd0, 4'hB, 8'h00, 32'h55555555);
		scan_line(8'hB5, 1'b0);

		test_passed = 1'b1;
		$display("Sprite palette groups, CC blending, and collision tests PASSED");
		$finish;
	end
endmodule
