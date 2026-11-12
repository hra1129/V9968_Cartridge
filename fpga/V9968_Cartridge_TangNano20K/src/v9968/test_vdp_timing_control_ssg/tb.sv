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

// --------------------------------------------------------------------
//	R#26/R#27 は実効レジスタにラッチせず、書いた位置から効く。
//	  * BG の VRAM 読み出しタイミングは R#27 によらず固定 (R#27=0 と同じ)
//	  * R#26 は次の読み出しから効く
//	  * R#27 は背景色の出力を 0〜7 ドット遅らせる (左端の押し出し部分は周辺色)
//	SCREEN6 (G5, 512 ドット) で半ドット単位の出力を比較する。
// --------------------------------------------------------------------
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
	wire [8:3] horizontal_offset_h;
	wire [1:0] pixel_phase_x;
	wire [17:0] vram_address;
	wire vram_valid;
	wire [31:0] vram_rdata;
	wire [7:0] display_color;
	wire display_color_en;
	reg [8:3] r26_d1, r26_d2;
	wire [8:0] expected_coarse_pixel_x;

	localparam integer c_lines = 5;			//	A: R#27=0, B: R#27=3, C: R#27 0->3 mid line, D: R#26 0->2 mid line, E: R#27=7
	localparam integer c_cap = 540;
	reg [1:0] cap [0:c_lines-1][0:c_cap-1];
	reg cap_en [0:c_lines-1][0:c_cap-1];
	integer cap_sel;
	integer first_req_x [0:c_lines-1];
	integer n_req;
	integer n_err;
	integer i;

	function automatic [7:0] vram_byte(input [4:0] group, input [1:0] lane);
		vram_byte = ({ 3'd0, group } * 8'd37 + { 6'd0, lane } * 8'd101) ^ 8'h5A;
	endfunction

	//	VRAM data depends only on the X group, so every line has the same picture.
	assign vram_rdata = { vram_byte(vram_address[6:2], 2'd3), vram_byte(vram_address[6:2], 2'd2),
						  vram_byte(vram_address[6:2], 2'd1), vram_byte(vram_address[6:2], 2'd0) };

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
		.horizontal_offset_h(horizontal_offset_h),
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
		.vram_rdata(vram_rdata),
		.vram_interleave(),
		.display_color(display_color),
		.display_color_en(display_color_en),
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
		.reg_left_mask(1'b0),
		.reg_sprite_mode3(1'b0),
		.reg_flat_interlace_mode(1'b0)
	);

	always #5 clk = ~clk;

	always @(posedge clk) begin
		r26_d1 <= horizontal_offset_h;
		r26_d2 <= r26_d1;
	end

	assign expected_coarse_pixel_x = screen_pos_x_clone[12:4] + { r26_d2, 3'd0 };

	task automatic wait_x(input integer x, input [3:0] sub);
		reg [13:0] pos;
		begin
			pos = { x[9:0], sub };
			@(posedge clk);
			while (screen_pos_x_clone !== pos) @(posedge clk);
			#1;
		end
	endtask

	task automatic check(input integer sel, input integer idx, input [1:0] expected, input [8*24-1:0] what);
		begin
			if (cap[sel][idx] !== expected) begin
				if (n_err < 20) begin
					$display("%0s: line%0d idx=%0d (dot %0d) got=%0d expected=%0d",
						what, sel, idx, (idx - 1) / 2, cap[sel][idx], expected);
				end
				n_err = n_err + 1;
			end
		end
	endtask

	//	Fetch timing must not depend on R#27, and the address must follow R#26 immediately.
	always @(posedge clk) begin
		if (reset_n && vram_valid && !screen_pos_x_clone[13] && screen_pos_x_clone[13:4] < 10'd256) begin
			if (u_bg.ff_phase !== 3'd0 || screen_pos_x_clone[3:0] !== 4'd1) begin
				$fatal(1, "VRAM request phase mismatch: X=%0d phase=%0d sub_phase=%0d",
					screen_pos_x_clone[13:4], u_bg.ff_phase, screen_pos_x_clone[3:0]);
			end
			if (vram_address[6:2] !== expected_coarse_pixel_x[7:3]) begin
				$fatal(1, "R#26 VRAM group mismatch: X=%0d R26=%0d expected=%0d address=%0d",
					screen_pos_x_clone[13:4], r26_d2, expected_coarse_pixel_x[7:3], vram_address[6:2]);
			end
			if (cap_sel >= 0 && cap_sel < c_lines && first_req_x[cap_sel] < 0) begin
				first_req_x[cap_sel] = screen_pos_x_clone[13:4];
			end
			n_req = n_req + 1;
		end
	end

	//	G5 output: first half is written at sub phase 7, second half at sub phase 15.
	always @(posedge clk) begin
		if (cap_sel >= 0 && cap_sel < c_lines && !screen_pos_x_clone[13] && screen_pos_x_clone[13:4] < 10'd270) begin
			if (screen_pos_x_clone[3:0] == 4'd3) begin
				cap[cap_sel][2 * screen_pos_x_clone[13:4]] = display_color[1:0];
				cap_en[cap_sel][2 * screen_pos_x_clone[13:4]] = display_color_en;
			end
			else if (screen_pos_x_clone[3:0] == 4'd11) begin
				cap[cap_sel][2 * screen_pos_x_clone[13:4] + 1] = display_color[1:0];
				cap_en[cap_sel][2 * screen_pos_x_clone[13:4] + 1] = display_color_en;
			end
		end
	end

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		reg_horizontal_offset_l = 3'd0;
		reg_horizontal_offset_h = 6'd0;
		cap_sel = -1;
		n_req = 0;
		n_err = 0;
		for (i = 0; i < c_lines; i = i + 1) first_req_x[i] = -1;
		repeat (3) @(posedge clk);
		#1;
		reset_n = 1'b1;
		wait_x(-32, 0);
		wait_x(-32, 0);

		//	A: reference (R#26=0, R#27=0)
		cap_sel = 0;
		//	B: R#27=3 written in H blanking
		wait_x(-32, 0);
		reg_horizontal_offset_l = 3'd3;
		cap_sel = 1;
		//	C: R#27 0 -> 3 in the middle of the line
		wait_x(-32, 0);
		reg_horizontal_offset_l = 3'd0;
		cap_sel = 2;
		wait_x(128, 0);
		reg_horizontal_offset_l = 3'd3;
		//	D: R#26 0 -> 2 in the middle of the line
		wait_x(-32, 0);
		reg_horizontal_offset_l = 3'd0;
		cap_sel = 3;
		wait_x(100, 4);
		reg_horizontal_offset_h = 6'd2;
		//	E: R#27=7 (largest delay) written in H blanking
		wait_x(-32, 0);
		reg_horizontal_offset_h = 6'd0;
		reg_horizontal_offset_l = 3'd7;
		cap_sel = 4;
		wait_x(-32, 0);
		cap_sel = -1;

		if (n_req < 4 * 32) $fatal(1, "Too few VRAM requests: %0d", n_req);
		if (first_req_x[0] !== first_req_x[1]) begin
			$fatal(1, "BG fetch timing depends on R#27: first request X=%0d (R#27=0) / %0d (R#27=3)",
				first_req_x[0], first_req_x[1]);
		end

		//	The background starts at dot 5 (G5). Dot d occupies idx 2d+1 and 2d+2.
		//	B: dots 5..7 are pushed out by R#27=3 and show the backdrop color (0x55 -> 1).
		for (i = 11; i <= 16; i = i + 1) check(1, i, 2'd1, "R27 left mask");
		for (i = 17; i <= 523; i = i + 1) check(1, i, cap[0][i - 6], "R27 delay");
		//	Right end: the last BG half-dot is idx 523 for R#27=0, and it must not move with R#27.
		//	Without the right-end mask, R#27=k leaked delayed data into idx 524..523+2k
		//	(R#27=3: 524..529), so idx 524 is the first half-dot that must be backdrop.
		for (i = 524; i < c_cap; i = i + 1) check(0, i, 2'd1, "right border (R27=0)");
		for (i = 524; i < c_cap; i = i + 1) check(1, i, 2'd1, "right border (R27=3)");
		for (i = 524; i < c_cap; i = i + 1) check(2, i, 2'd1, "right border (R27 mid)");
		//	E: R#27=7 pushes out dots 5..11 (idx 11..24), leaks would reach idx 537 without the mask.
		for (i = 11; i <= 24; i = i + 1) check(4, i, 2'd1, "R27=7 left mask");
		for (i = 25; i <= 523; i = i + 1) check(4, i, cap[0][i - 14], "R27=7 delay");
		for (i = 524; i < c_cap; i = i + 1) check(4, i, 2'd1, "right border (R27=7)");
		//	display_color_en (sprites are gated by it): cleared only in the part pushed out by R#27.
		for (i = 0; i < c_cap; i = i + 1) begin
			if (cap_en[0][i] !== 1'b1) begin
				if (n_err < 20) $display("en (R27=0): idx=%0d got=%0d expected=1", i, cap_en[0][i]);
				n_err = n_err + 1;
			end
			if (i >= 11 && cap_en[1][i] !== (i >= 17)) begin
				if (n_err < 20) $display("en (R27=3): idx=%0d got=%0d expected=%0d", i, cap_en[1][i], i >= 17);
				n_err = n_err + 1;
			end
			if (i >= 11 && cap_en[4][i] !== (i >= 25)) begin
				if (n_err < 20) $display("en (R27=7): idx=%0d got=%0d expected=%0d", i, cap_en[4][i], i >= 25);
				n_err = n_err + 1;
			end
		end
		//	C: same as A before the write, delayed by 3 dots after the write.
		for (i = 11; i < 2 * 120; i = i + 1) check(2, i, cap[0][i], "R27 before write");
		for (i = 2 * 132; i <= 500; i = i + 1) check(2, i, cap[0][i - 6], "R27 after write");
		//	D: same as A before the write, 16 dots further after the next fetch.
		for (i = 11; i < 2 * 100; i = i + 1) check(3, i, cap[0][i], "R26 before write");
		for (i = 2 * 124; i <= 2 * 220; i = i + 1) check(3, i, cap[0][i + 32], "R26 after write");

		if (n_err != 0) $fatal(1, "%0d output mismatches", n_err);
		n_err = 0;
		for (i = 17; i <= 500; i = i + 1) if (cap[0][i] !== cap[0][i - 6]) n_err = n_err + 1;
		if (n_err < 100) $fatal(1, "Reference line is too uniform to detect shifts (%0d differences)", n_err);
		$display("PASS: fixed BG fetch, R#26 from next fetch, R#27 as output delay (first fetch X=%0d)", first_req_x[0]);
		$finish;
	end
endmodule

// --------------------------------------------------------------------
//	SSG passes R#26/R#27 through without latching (pixel_pos_y latch is kept for sprites).
// --------------------------------------------------------------------
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
		if (pixel_pos_x !== 9'd6) $fatal(1, "pixel_pos_x=%0d before R#26 write", pixel_pos_x);
		reg_horizontal_offset_l = 3'd3;
		reg_horizontal_offset_h = 6'd2;
		#0;
		if (horizontal_offset_l !== 3'd3 || horizontal_offset_h !== 6'd2) begin
			$fatal(1, "R#26/R#27 are not passed through: %0d,%0d", horizontal_offset_h, horizontal_offset_l);
		end
		repeat (2) @(posedge clk);
		#1;
		if (pixel_pos_x !== 9'd22) $fatal(1, "R#26 did not take effect immediately: pixel_pos_x=%0d", pixel_pos_x);
		wait (screen_pos_x == 14'd265);
		#1;
		reg_horizontal_offset_h = 6'd4;
		wait (screen_pos_x == 14'd384);
		#1;
		if (pixel_pos_x !== 9'd56) $fatal(1, "R#26 did not take effect immediately: pixel_pos_x=%0d", pixel_pos_x);
		$display("PASS: R#26/R#27 take effect from the write position");
		$finish;
	end
endmodule
