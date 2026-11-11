// -----------------------------------------------------------------------------
//	Test of vdp_timing_control_ssg.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
//	
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
// --------------------------------------------------------------------

module tb ();
	localparam		clk_base		= 1_000_000_000/85_909_080;	//	ns
	reg					reset_n;
	reg					clk;

	wire		[11:0]	h_count;
	wire		[ 9:0]	v_count;
	wire		[13:0]	screen_pos_x;
	wire		[ 9:0]	screen_pos_y;
	wire		[ 8:0]	pixel_pos_x;
	wire		[ 7:0]	pixel_pos_y;
	wire				screen_v_active;

	wire				intr_line;				//	pulse
	wire				intr_frame;				//	pulse
	wire				pre_vram_refresh;

	reg					reg_50hz_mode;
	reg					reg_212lines_mode;
	reg					reg_interlace_mode;
	reg			[7:0]	reg_display_adjust;
	reg			[7:0]	reg_interrupt_line;
	reg			[7:0]	reg_vertical_offset;
	reg			[2:0]	reg_horizontal_offset_l;
	reg			[8:3]	reg_horizontal_offset_h;
	reg					reg_interleaving_mode;
	reg			[7:0]	reg_blink_period;
	reg					reg_interrupt_line_nonR23_mode;
	wire		[2:0]	horizontal_offset_l;
	wire		[8:3]	horizontal_offset_h;
	wire				interleaving_page;
	wire				blink;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	vdp_timing_control_ssg u_timing_control_ssg ( .* );

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		clk = 0;
		reset_n = 0;

		reg_50hz_mode = 0;
		reg_212lines_mode = 0;
		reg_interlace_mode = 0;
		reg_display_adjust = 0;
		reg_interrupt_line = 100;
		reg_vertical_offset = 0;
		reg_horizontal_offset_l = 0;
		reg_horizontal_offset_h = 0;
		reg_interleaving_mode = 0;
		reg_blink_period = 0;
		reg_interrupt_line_nonR23_mode = 0;

		@( posedge clk );
		@( posedge clk );
		@( posedge clk );
		reset_n <= 1;
		@( posedge clk );

		$display( "60Hz, non interlace" );
		reg_50hz_mode		= 1'b0;		//	60Hz
		reg_interlace_mode	= 1'b0;		//	non interlace
		repeat( 2736 * 550 * 2 ) @( posedge clk );

		$display( "60Hz, interlace" );
		reg_50hz_mode		= 1'b0;		//	60Hz
		reg_interlace_mode	= 1'b1;		//	interlace
		repeat( 2736 * 550 * 2 ) @( posedge clk );

		$display( "50Hz, non interlace" );
		reg_50hz_mode		= 1'b1;		//	50Hz
		reg_interlace_mode	= 1'b0;		//	non interlace
		repeat( 2736 * 650 * 2 ) @( posedge clk );

		$display( "50Hz, interlace" );
		reg_50hz_mode		= 1'b1;		//	50Hz
		reg_interlace_mode	= 1'b1;		//	interlace
		repeat( 2736 * 650 * 2 ) @( posedge clk );

		$display( "60Hz, non interlace [set adjust]" );
		reg_50hz_mode		= 1'b0;		//	60Hz
		reg_interlace_mode	= 1'b0;		//	non interlace
		reg_display_adjust	= 8'h85;	//	set adjust( 5, 8 )
		repeat( 2736 * 550 * 2 ) @( posedge clk );

		repeat( 10 ) @( posedge clk );
		$finish;
	end
endmodule

module tb_scroll_group_alignment ();
	reg clk;
	reg reset_n;
	reg [2:0] reg_horizontal_offset_l;
	reg [8:3] reg_horizontal_offset_h;
	wire [13:0] screen_pos_x;
	wire [13:0] screen_pos_x_clone;
	wire [9:0] screen_pos_y;
	wire [8:0] pixel_pos_x;
	wire [7:0] pixel_pos_y;
	wire screen_v_active;
	wire [2:0] horizontal_offset_l;
	wire [1:0] pixel_phase_x;
	wire [17:0] vram_address;
	wire vram_valid;
	wire [8:0] expected_coarse_pixel_x;
	integer baseline_requests;
	integer mismatch_requests;
	integer first_mismatch_x;

	vdp_timing_control_ssg u_ssg (
		.reset_n(reset_n),
		.clk(clk),
		.h_count(),
		.v_count(),
		.screen_pos_x(screen_pos_x),
		.screen_pos_x_clone(screen_pos_x_clone),
		.screen_pos_y(screen_pos_y),
		.pixel_pos_x(pixel_pos_x),
		.pixel_pos_y(pixel_pos_y),
		.screen_v_active(screen_v_active),
		.sprite_overmap_v_active(),
		.intr_line(),
		.intr_frame(),
		.clear_line_interrupt(),
		.pre_vram_refresh(),
		.reg_display_on(1'b1),
		.reg_50hz_mode(1'b0),
		.reg_212lines_mode(1'b0),
		.reg_interlace_mode(1'b0),
		.reg_display_adjust(8'd0),
		.reg_interrupt_line(8'd0),
		.reg_vertical_offset(8'd0),
		.reg_horizontal_offset_l(reg_horizontal_offset_l),
		.reg_horizontal_offset_h(reg_horizontal_offset_h),
		.reg_interleaving_mode(1'b0),
		.reg_flat_interlace_mode(1'b0),
		.reg_blink_period(8'd0),
		.reg_interrupt_line_nonR23_mode(1'b0),
		.horizontal_offset_l(horizontal_offset_l),
		.horizontal_offset_h(),
		.interleaving_page(),
		.blink(),
		.status_field(),
		.status_hsync(),
		.status_vsync()
	);

	vdp_timing_control_screen_mode u_bg (
		.reset_n(reset_n),
		.clk(clk),
		.screen_pos_x(screen_pos_x_clone),
		.screen_pos_y(screen_pos_y),
		.pixel_pos_x(pixel_pos_x),
		.pixel_pos_y(pixel_pos_y),
		.pixel_phase_x(pixel_phase_x),
		.screen_v_active(1'b1),
		.vram_address(vram_address),
		.vram_valid(vram_valid),
		.vram_rdata(32'hFFFFFFFF),
		.vram_interleave(),
		.display_color(),
		.display_color_en(),
		.sprite_off(),
		.interleaving_page(1'b1),
		.blink(1'b0),
		.field(1'b0),
		.screen_mode(),
		.horizontal_offset_l(horizontal_offset_l),
		.reg_screen_mode(5'b10000),
		.reg_display_on(1'b1),
		.reg_pattern_name_table_base(8'd0),
		.reg_color_table_base(12'd0),
		.reg_pattern_generator_table_base(7'd0),
		.reg_text_back_color(8'd0),
		.reg_backdrop_color(8'h55),
		.reg_scroll_planes(1'b0),
		.reg_left_mask(1'b1),
		.reg_sprite_mode3(1'b0),
		.reg_flat_interlace_mode(1'b0)
	);

	assign expected_coarse_pixel_x = screen_pos_x_clone[12:4] + { u_ssg.ff_horizontal_offset_h, 3'd0 } - horizontal_offset_l;

	always #5 clk = ~clk;

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		reg_horizontal_offset_l = 3'd0;
		reg_horizontal_offset_h = 6'd0;
		baseline_requests = 0;
		mismatch_requests = 0;
		first_mismatch_x = -1;
		repeat (3) @(posedge clk);
		#1;
		reset_n = 1'b1;
		wait (screen_pos_x == 14'd100);
		#1;
		reg_horizontal_offset_h = 6'd2;
		wait (screen_pos_x == 14'd140);
		#1;
		if (u_ssg.ff_horizontal_offset_h !== 6'd0 || u_bg.w_pos_x[2:0] !== 3'd0) begin
			$fatal(1, "R#26 changed during the active display line");
		end
		reg_horizontal_offset_l = 3'd3;
		wait (screen_pos_x == 14'd512);
		#1;
		if (baseline_requests < 2 || mismatch_requests != 0 || first_mismatch_x != -1 || horizontal_offset_l !== 3'd0 ||
			u_ssg.ff_horizontal_offset_h !== 6'd0) begin
			$fatal(1, "BG groups changed before the line boundary: baseline=%0d mismatches=%0d first=%0d",
				baseline_requests, mismatch_requests, first_mismatch_x);
		end
		wait (horizontal_offset_l == 3'd3);
		#1;
		if (u_ssg.ff_horizontal_offset_h !== 6'd2 || screen_pos_x_clone !== 14'h10AF) begin
			$fatal(1, "R#26/R#27 were not latched together at X=266/F: X=%0h", screen_pos_x_clone);
		end
		wait (u_ssg.ff_horizontal_offset_h == 6'd2);
		#1;
		if (horizontal_offset_l !== 3'd3 || 		screen_pos_x_clone !== 14'h10AF) begin
					$fatal(1, "R#26 was not latched with R#27: X=%0h", screen_pos_x_clone);
		end
		wait (screen_pos_x_clone == 14'd100);
		#1;
		reg_horizontal_offset_l = 3'd0;
		reg_horizontal_offset_h = 6'd4;
		wait (screen_pos_x_clone == 14'd512);
		#1;
		if (horizontal_offset_l !== 3'd3 || u_ssg.ff_horizontal_offset_h !== 6'd2) begin
			$fatal(1, "R#26/R#27 changed during the active display line");
		end
		wait (horizontal_offset_l == 3'd0);
		#1;
		if (u_ssg.ff_horizontal_offset_h !== 6'd4 || screen_pos_x_clone !== 14'h10AF) begin
			$fatal(1, "R#27 decrease latch mismatch: low=%0d high=%0d X=%0h",
				horizontal_offset_l, u_ssg.ff_horizontal_offset_h, screen_pos_x_clone);
		end
		wait (u_ssg.ff_horizontal_offset_h == 6'd4);
		#1;
		if (horizontal_offset_l !== 3'd0 || screen_pos_x_clone !== 14'h10AF) begin
			$fatal(1, "R#26 decrease latch mismatch: low=%0d high=%0d X=%0h",
				horizontal_offset_l, u_ssg.ff_horizontal_offset_h, screen_pos_x_clone);
		end
		$display("R#26/R#27 latch together at X=267 for both scroll directions");
		$finish;
	end

	always @(posedge clk) begin
		if (reset_n && vram_valid && screen_pos_x_clone < 14'd512) begin
			if (u_bg.ff_phase !== 3'd0 || screen_pos_x_clone[3:0] !== 4'd1) begin
				$fatal(1, "VRAM request phase mismatch: X=%0d phase=%0d sub_phase=%0d",
					screen_pos_x_clone[13:4], u_bg.ff_phase, screen_pos_x_clone[3:0]);
			end
			if (vram_address[6:2] !== expected_coarse_pixel_x[7:3]) begin
				$fatal(1, "R#26 VRAM group mismatch: X=%0d R26=%0d expected=%0d address=%0d",
					screen_pos_x_clone[13:4], u_ssg.ff_horizontal_offset_h,
					expected_coarse_pixel_x[7:3], vram_address[6:2]);
			end
			if (horizontal_offset_l == 3'd0 && u_bg.w_pos_x[2:0] == 3'd0) begin
				baseline_requests = baseline_requests + 1;
			end
			else if (u_bg.w_pos_x[2:0] != 3'd0) begin
				mismatch_requests = mismatch_requests + 1;
				if (first_mismatch_x == -1) first_mismatch_x = screen_pos_x_clone;
				$display("BG group mismatch X=%0d phase=%0d reference_low=%0d VRAM=%05x",
					screen_pos_x_clone[13:4], u_bg.ff_phase, u_bg.w_pos_x[2:0], vram_address);
			end
		end
	end

	initial begin
		$dumpfile("scroll_group.vcd");
		$dumpvars(0, tb_scroll_group_alignment);
	end
endmodule

module tb_scroll_midline ();
	reg clk;
	reg reset_n;
	reg [2:0] reg_horizontal_offset_l;
	reg [8:3] reg_horizontal_offset_h;
	wire [13:0] screen_pos_x;
	wire [8:0] pixel_pos_x;
	wire [2:0] horizontal_offset_l;
	wire [8:3] horizontal_offset_h;

	vdp_timing_control_ssg u_dut (
		.reset_n(reset_n),
		.clk(clk),
		.h_count(),
		.v_count(),
		.screen_pos_x(screen_pos_x),
		.screen_pos_x_clone(),
		.screen_pos_y(),
		.pixel_pos_x(pixel_pos_x),
		.pixel_pos_y(),
		.screen_v_active(),
		.sprite_overmap_v_active(),
		.intr_line(),
		.intr_frame(),
		.clear_line_interrupt(),
		.pre_vram_refresh(),
		.reg_display_on(1'b1),
		.reg_50hz_mode(1'b0),
		.reg_212lines_mode(1'b0),
		.reg_interlace_mode(1'b0),
		.reg_display_adjust(8'd0),
		.reg_interrupt_line(8'd0),
		.reg_vertical_offset(8'd0),
		.reg_horizontal_offset_l(reg_horizontal_offset_l),
		.reg_horizontal_offset_h(reg_horizontal_offset_h),
		.reg_interleaving_mode(1'b0),
		.reg_flat_interlace_mode(1'b0),
		.reg_blink_period(8'd0),
		.reg_interrupt_line_nonR23_mode(1'b0),
		.horizontal_offset_l(horizontal_offset_l),
		.horizontal_offset_h(horizontal_offset_h),
		.interleaving_page(),
		.blink(),
		.status_field(),
		.status_hsync(),
		.status_vsync()
	);

	always #5 clk = ~clk;

	task automatic expect_offsets;
		input [13:0] position;
		input [2:0] expected_low;
		input [8:3] expected_high;
		begin
			wait (screen_pos_x == position);
			#1;
			if (horizontal_offset_l !== expected_low || horizontal_offset_h !== expected_high) begin
				$fatal(1, "X=%0d: BG offset=%0d,%0d", position[13:4],
					horizontal_offset_h, horizontal_offset_l);
			end
		end
	endtask

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		reg_horizontal_offset_l = 3'd0;
		reg_horizontal_offset_h = 6'd0;
		repeat (3) @(posedge clk);
		#1;
		reset_n = 1'b1;
		wait (screen_pos_x == 14'd100);
		#1;
		reg_horizontal_offset_l = 3'd3;
		reg_horizontal_offset_h = 6'd2;
		expect_offsets(14'd126, 3'd0, 6'd0);
		expect_offsets(14'd127, 3'd0, 6'd0);
		wait (screen_pos_x == 14'd140);
		#1;
		reg_horizontal_offset_l = 3'd5;
		expect_offsets(14'd254, 3'd0, 6'd0);
		expect_offsets(14'd255, 3'd0, 6'd0);
		wait (screen_pos_x == 14'd265);
		#1;
		reg_horizontal_offset_h = 6'd4;
		expect_offsets(14'd382, 3'd0, 6'd0);
		expect_offsets(14'd383, 3'd0, 6'd0);
		wait (screen_pos_x == 14'd384);
		#1;
		if (pixel_pos_x !== 9'd24) $fatal(1, "R#26 changed before the next active display line");
		wait (horizontal_offset_l == 3'd5);
		wait (screen_pos_x == 14'd79);
		#1;
		if (horizontal_offset_h !== 6'd4 || horizontal_offset_l !== 3'd5) begin
			$fatal(1, "R#26/R#27 were not latched together before active video");
		end
		$display("R#26 and R#27 latch together before active video");
		$finish;
	end
endmodule
