// -----------------------------------------------------------------------------
//	Test of vdp_timing_control.v
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
	localparam			clk_base		= 1_000_000_000/42_954_540;	//	ns

	// ----------------------------------------------------------------
	// テストベンチの信号定義
	// ----------------------------------------------------------------
	reg				reset_n;
	reg				clk;

	wire	[11:0]	h_count;
	wire	[ 9:0]	v_count;
	wire	[13:0]	screen_pos_x;
	wire	[ 9:0]	screen_pos_y;
	wire			intr_line;
	wire			intr_frame;

	// VRAMインターフェース
	wire	[17:0]	screen_mode_vram_address;
	wire			screen_mode_vram_valid;
	reg		[31:0]	screen_mode_vram_rdata;
	wire	[7:0]	screen_mode_display_color;

	wire	[17:0]	sprite_vram_address;
	wire			sprite_vram_valid;
	reg		[31:0]	sprite_vram_rdata;
	reg		[7:0]	sprite_vram_rdata8;
	wire	[7:0]	sprite_display_color;
	wire			sprite_display_color_en;
	reg			test6_vram_enable;
	reg		[31:0]	sprite_attribute_table [0:31];
	wire			sprite_overmap;
	wire	[4:0]	sprite_overmap_id;

	//	レジスタ制御タイミング信号
	reg				clear_sprite_collision;
	wire			sprite_collision;
	reg				clear_sprite_collision_xy;
	wire	[8:0]	sprite_collision_x;
	wire	[9:0]	sprite_collision_y;

	// レジスタ信号
	reg				reg_50hz_mode;
	reg				reg_212lines_mode;
	reg				reg_interlace_mode;
	reg		[7:0]	reg_display_adjust;
	reg		[7:0]	reg_interrupt_line;
	reg		[7:0]	reg_vertical_offset;
	reg		[2:0]	reg_horizontal_offset_l;
	reg		[8:3]	reg_horizontal_offset_h;
	reg		[4:0]	reg_screen_mode;
	reg				reg_display_on;
	reg				reg_color0_opaque;
	reg		[17:10]	reg_pattern_name_table_base;
	reg		[17:6]	reg_color_table_base;
	reg		[17:11]	reg_pattern_generator_table_base;
	reg		[17:7]	reg_sprite_attribute_table_base;
	reg		[17:11]	reg_sprite_pattern_generator_table_base;
	reg				reg_sprite_magify;
	reg				reg_sprite_16x16;
	reg				reg_sprite_disable;
	reg		[7:0]	reg_backdrop_color;
	reg				reg_left_mask;

	// ----------------------------------------------------------------
	// DUTインスタンス
	// ----------------------------------------------------------------
	vdp_timing_control u_dut (
		.reset_n									( reset_n									),
		.clk										( clk										),
		.h_count									( h_count									),
		.v_count									( v_count									),
		.screen_pos_x								( screen_pos_x								),
		.screen_pos_y								( screen_pos_y								),
		.intr_line									( intr_line									),
		.intr_frame									( intr_frame								),
		.screen_mode_vram_address					( screen_mode_vram_address					),
		.screen_mode_vram_valid						( screen_mode_vram_valid					),
		.screen_mode_vram_rdata						( screen_mode_vram_rdata					),
		.screen_mode_display_color					( screen_mode_display_color					),
		.sprite_vram_address						( sprite_vram_address						),
		.sprite_vram_valid							( sprite_vram_valid							),
		.sprite_vram_rdata							( sprite_vram_rdata							),
		.sprite_vram_rdata8							( sprite_vram_rdata8						),
		.sprite_display_color						( sprite_display_color						),
		.sprite_display_color_en					( sprite_display_color_en					),
		.clear_sprite_collision						( clear_sprite_collision					),
		.sprite_collision							( sprite_collision							),
		.clear_sprite_collision_xy					( clear_sprite_collision_xy					),
		.sprite_collision_x							( sprite_collision_x						),
		.sprite_collision_y							( sprite_collision_y						),
		.reg_50hz_mode								( reg_50hz_mode								),
		.reg_212lines_mode							( reg_212lines_mode							),
		.reg_interlace_mode							( reg_interlace_mode						),
		.reg_display_adjust							( reg_display_adjust						),
		.reg_interrupt_line							( reg_interrupt_line						),
		.reg_vertical_offset						( reg_vertical_offset						),
		.reg_horizontal_offset_l					( reg_horizontal_offset_l					),
		.reg_horizontal_offset_h					( reg_horizontal_offset_h					),
		.reg_screen_mode							( reg_screen_mode							),
		.reg_display_on								( reg_display_on							),
		.reg_color0_opaque							( reg_color0_opaque							),
		.reg_pattern_name_table_base				( reg_pattern_name_table_base				),
		.reg_color_table_base						( reg_color_table_base						),
		.reg_pattern_generator_table_base			( reg_pattern_generator_table_base			),
		.reg_sprite_attribute_table_base			( reg_sprite_attribute_table_base			),
		.reg_sprite_pattern_generator_table_base	( reg_sprite_pattern_generator_table_base	),
		.reg_sprite_magify							( reg_sprite_magify							),
		.reg_sprite_16x16							( reg_sprite_16x16							),
		.reg_sprite_disable							( reg_sprite_disable						),
		.reg_backdrop_color							( reg_backdrop_color						),
		.reg_left_mask								( reg_left_mask								),
		.pixel_phase_x								(),
		.clear_line_interrupt						(),
		.pre_vram_refresh							(),
		.vram_interleave							(),
		.status_field								(),
		.status_hsync								(),
		.status_vsync								(),
		.screen_mode_display_color_en				(),
		.screen_mode								(),
		.sprite_display_color_transparent			(),
		.clear_sprite_overmap						( intr_frame ),
		.sprite_overmap_enable					( 1'b1 ),
		.sprite_overmap							( sprite_overmap ),
		.sprite_overmap_id						( sprite_overmap_id ),
		.reg_interleaving_mode						( 1'b0 ),
		.reg_blink_period							( 8'd0 ),
		.reg_text_back_color						( 8'd0 ),
		.reg_scroll_planes							( 1'b0 ),
		.reg_sprite_nonR23_mode						( 1'b0 ),
		.reg_interrupt_line_nonR23_mode				( 1'b0 ),
		.reg_sprite_mode3							( 1'b0 ),
		.reg_sprite16_mode							( 1'b0 ),
		.reg_flat_interlace_mode					( 1'b0 ),
		.reg_sprite_priority_shuffle				( 1'b0 ),
		.reg_ext_palette_mode						( 1'b0 )
	);

	// ----------------------------------------------------------------
	// クロック生成
	// ----------------------------------------------------------------
	always begin
		clk = 1'b0;
		#(clk_base/2);
		clk = 1'b1;
		#(clk_base/2);
	end

	always @(posedge clk) begin
		if (test6_vram_enable && sprite_vram_valid) begin
			sprite_vram_rdata <= sprite_attribute_table[sprite_vram_address[6:2]];
		end
	end

	// ----------------------------------------------------------------
	// 初期化処理
	// ----------------------------------------------------------------
	initial begin
		// 初期値設定
		reset_n = 1'b0;
		screen_mode_vram_rdata = 32'h56781234;
		sprite_vram_rdata = 32'hFFFFFFFF;
		test6_vram_enable = 1'b0;
		reg_50hz_mode = 1'b0;					// 60Hz mode
		reg_212lines_mode = 1'b0;				// 192 lines mode
		reg_interlace_mode = 1'b0;				// Non-interlace
		reg_display_adjust = 8'd0;				// 画面位置調整なし
		reg_interrupt_line = 8'd192;			// 標準的な割り込みライン
		reg_vertical_offset = 8'd0;				// 垂直オフセットなし
		reg_horizontal_offset_l = 3'd0;			// 水平オフセットなし
		reg_horizontal_offset_h = 6'd0;			// 水平オフセットなし
		reg_screen_mode = 5'd0;					// Screen mode 0
		reg_display_on = 1'b1;					// Display ON
		reg_color0_opaque = 1'b0;				// パレット0 の扱い 透明
		reg_pattern_name_table_base = 7'h00;	// パターンネームテーブルベース
		reg_color_table_base = 11'h000;			// カラーテーブルベース
		reg_pattern_generator_table_base = 6'h00; // パターンジェネレータテーブルベース
		reg_sprite_attribute_table_base = 0;
		reg_sprite_pattern_generator_table_base = 0;
		reg_sprite_magify = 0;
		reg_sprite_16x16 = 0;
		reg_sprite_disable = 0;
		clear_sprite_collision = 1'b0;
		clear_sprite_collision_xy = 1'b0;
		sprite_vram_rdata8 = 8'd0;
		reg_backdrop_color = 8'h0F;				// 背景色（白）
		reg_left_mask = 1'b0;

		// リセット解除
		#(clk_base * 10);
		reset_n = 1'b1;
		
		$display("=== VDP Timing Control Test Start ===");
		
		// テスト1: 基本的なタイミング信号の確認
		test_basic_timing();
		
		// テスト2: 50Hz/60Hzモードの切り替え
		test_refresh_rate();
		
		// テスト3: 割り込みライン設定の確認
		test_interrupt_line();
		
		// テスト4: オフセット設定の確認
		test_offset_settings();
		
		// テスト5: 画面モード切り替えの確認
		test_screen_modes();

		// テスト6: SCREEN1 のスプライト同一ライン超過
		test_sprite_overmap();
		
		$display("=== All Tests Completed ===");
		$finish;
	end

	// ----------------------------------------------------------------
	// テスト1: 基本的なタイミング信号の確認
	// ----------------------------------------------------------------
	task test_basic_timing();
		integer h_count_max, v_count_max;
		integer frame_count;
		
		$display("--- Test 1: Basic Timing Signals ---");
		
		frame_count = 0;
		h_count_max = 0;
		v_count_max = 0;
		
		// 2フレーム分の動作を確認
		while (frame_count < 2) begin
			@(posedge clk);
			
			// 最大値を記録
			if (h_count > h_count_max) h_count_max = h_count;
			if (v_count > v_count_max) v_count_max = v_count;
			
			// フレーム割り込みを検出
			if (intr_frame) begin
				frame_count = frame_count + 1;
				$display("Frame %0d: H_MAX=%0d, V_MAX=%0d", frame_count, h_count_max, v_count_max);
			end
		end
		
		$display("Basic timing test completed");
	endtask

	// ----------------------------------------------------------------
	// テスト2: 50Hz/60Hzモードの切り替え
	// ----------------------------------------------------------------
	task test_refresh_rate();
		integer cycle_count_60hz, cycle_count_50hz;
		
		$display("--- Test 2: Refresh Rate Testing ---");
		
		// 60Hzモード測定
		reg_50hz_mode = 1'b0;
		#(clk_base * 100);
		
		cycle_count_60hz = 0;
		@(posedge intr_frame);
		@(negedge intr_frame);
		while (!intr_frame) begin
			@(posedge clk);
			cycle_count_60hz = cycle_count_60hz + 1;
		end
		
		// 50Hzモード測定
		reg_50hz_mode = 1'b1;
		#(clk_base * 100);
		
		cycle_count_50hz = 0;
		@(posedge intr_frame);
		@(negedge intr_frame);
		while (!intr_frame) begin
			@(posedge clk);
			cycle_count_50hz = cycle_count_50hz + 1;
		end
		
		$display("60Hz mode cycles: %0d", cycle_count_60hz);
		$display("50Hz mode cycles: %0d", cycle_count_50hz);
		if (cycle_count_60hz == 0 || cycle_count_50hz <= cycle_count_60hz) begin
			$fatal(1, "Invalid refresh rate measurements");
		end
		$display("Refresh rate test completed");
		
		// 60Hzモードに戻す
		reg_50hz_mode = 1'b0;
	endtask

	// ----------------------------------------------------------------
	// テスト3: 割り込みライン設定の確認
	// ----------------------------------------------------------------
	task test_interrupt_line();
		$display("--- Test 3: Interrupt Line Testing ---");
		
		// 割り込みライン設定を変更してテスト
		reg_interrupt_line = 8'd100;
		#(clk_base * 100);
		
		// フレーム開始を待つ
		@(posedge intr_frame);
		
		// 指定ラインで割り込みが発生するかチェック
		@(posedge intr_line);
		if (screen_pos_y == reg_interrupt_line) begin
			$display("Interrupt line test PASSED: Line %0d", v_count);
		end else begin
			$fatal(1, "Interrupt line test FAILED: Expected %0d, Got screen Y=%0d", reg_interrupt_line, screen_pos_y);
		end
		
		// 割り込みライン設定を元に戻す
		reg_interrupt_line = 8'd192;
	endtask

	// ----------------------------------------------------------------
	// テスト4: オフセット設定の確認
	// ----------------------------------------------------------------
	task test_offset_settings();
		$display("--- Test 4: Offset Settings Testing ---");
		
		// 垂直オフセットテスト
		reg_vertical_offset = 8'd10;
		reg_horizontal_offset_l = 3'd0;
		reg_horizontal_offset_h = 6'd04;
		
		#(clk_base * 1000);  // 少し待つ
		
		$display("Vertical offset: %0d", reg_vertical_offset);
		$display("Horizontal offset_l: %0d", reg_horizontal_offset_l);
		$display("Horizontal offset_h: %0d", reg_horizontal_offset_h);
		$display("Offset settings test completed");
		
		// オフセット設定を元に戻す
		reg_vertical_offset = 8'd0;
		reg_horizontal_offset_l = 3'd0;
		reg_horizontal_offset_h = 6'd0;
	endtask

	// ----------------------------------------------------------------
	// テスト5: 画面モード切り替えの確認
	// ----------------------------------------------------------------
	task test_screen_modes();
		integer mode;
		
		$display("--- Test 5: Screen Mode Testing ---");
		
		// 各画面モードをテスト
		for (mode = 0; mode < 8; mode = mode + 1) begin
			case( mode )
			0:	reg_screen_mode = 5'b00001;	//	SCREEN0:WIDTH40
			1:	reg_screen_mode = 5'b01001;	//	SCREEN0:WIDTH80
			2:	reg_screen_mode = 5'b00000;	//	SCREEN1
			3:	reg_screen_mode = 5'b00100;	//	SCREEN2
			4:	reg_screen_mode = 5'b00010;	//	SCREEN3
			5:	reg_screen_mode = 5'b01000;	//	SCREEN4
			6:	reg_screen_mode = 5'b01100;	//	SCREEN5
			7:	reg_screen_mode = 5'b10000;	//	SCREEN6
			8:	reg_screen_mode = 5'b10100;	//	SCREEN7
			9:	reg_screen_mode = 5'b11100;	//	SCREEN8
			endcase
			#(clk_base * 100);
			$display( "Screen mode set [reg_screen_mode = %05b]", reg_screen_mode );
		end
		
		$display("Screen mode test completed");
		
		// 画面モードを0に戻す
		reg_screen_mode = 5'd0;
	endtask

	// ----------------------------------------------------------------
	// テスト6: SCREEN1 の水平スプライト枚数超過
	// ----------------------------------------------------------------
	task test_sprite_overmap();
		integer plane;
		integer fifth_plane;
		integer previous_fifth_plane;
		integer failures;

		$display("--- Test 6: Sprite Overmap (SCREEN1) ---");
		reg_screen_mode = 5'b00000;
		reg_sprite_attribute_table_base = 11'd0;
		for (plane = 0; plane < 32; plane = plane + 1) begin
			sprite_attribute_table[plane] = 32'h000000D0;
		end
		for (plane = 0; plane < 4; plane = plane + 1) begin
			sprite_attribute_table[plane] = {8'h0F, 8'd0, (8'd32 + plane * 8), 8'd39};
		end
		test6_vram_enable = 1'b1;

		@(posedge intr_frame);
		wait (screen_pos_y == 10'd50 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b0) begin
			$fatal(1, "Four sprites: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		@(posedge intr_frame);
		@(posedge clk);
		#1;
		if (sprite_overmap !== 1'b0) begin
			$fatal(1, "Frame clear before five sprites: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		sprite_attribute_table[4] = {8'h0F, 8'd0, 8'd64, 8'd39};
		wait (screen_pos_y == 10'd50 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "Five sprites: expected overmap=1 id=4, got overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		wait (screen_pos_y == 10'd100 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "Overmap not held within frame: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		@(posedge intr_frame);
		@(posedge clk);
		#1;
		if (sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "Frame clear after five sprites: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		sprite_attribute_table[4] = 32'h000000D0;
		wait (screen_pos_y == 10'd50 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "Next frame with four sprites: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		failures = 0;
		previous_fifth_plane = 4;
		for (fifth_plane = 4; fifth_plane < 32; fifth_plane = fifth_plane + 1) begin
			for (plane = 4; plane < 32; plane = plane + 1) begin
				if (plane < fifth_plane) begin
					sprite_attribute_table[plane] = 32'h00000078;
				end else begin
					sprite_attribute_table[plane] = 32'h000000D0;
				end
			end
			sprite_attribute_table[fifth_plane] = {8'h0F, 8'd0, 8'd64, 8'd39};
			@(posedge intr_frame);
			@(posedge clk);
			#1;
			if (sprite_overmap !== 1'b0 || sprite_overmap_id !== previous_fifth_plane[4:0]) begin
				$display("FAIL before fifth plane %0d: overmap=%b id=%d", fifth_plane, sprite_overmap, sprite_overmap_id);
				failures = failures + 1;
			end
			wait (screen_pos_y == 10'd50 && screen_pos_x == 14'd0);
			#1;
			if (sprite_overmap !== 1'b1 || sprite_overmap_id !== fifth_plane[4:0]) begin
				$display("FAIL fifth plane %0d: expected overmap=1 id=%0d, got overmap=%b id=%d", fifth_plane, fifth_plane, sprite_overmap, sprite_overmap_id);
				failures = failures + 1;
			end else begin
				$display("Fifth plane %0d PASSED", fifth_plane);
			end
			previous_fifth_plane = fifth_plane;
		end
		for (plane = 0; plane < 32; plane = plane + 1) begin
			sprite_attribute_table[plane] = {8'h0F, 8'd0, 8'd64, 8'd209};
		end
		@(posedge intr_frame);
		wait (screen_pos_y == 10'd220 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd31) begin
			$fatal(1, "192 lines, sprites at Y=209: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		reg_vertical_offset = 8'd10;
		@(posedge intr_frame);
		wait (screen_pos_y == 10'd210 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd31) begin
			$fatal(1, "192 lines, offset 10, sprites at Y=209: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		reg_vertical_offset = 8'd0;
		reg_212lines_mode = 1'b1;
		@(posedge u_dut.w_screen_v_active);
		wait (screen_pos_y == 10'd210 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "212 lines, sprites at Y=209: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		reg_vertical_offset = 8'd10;
		@(posedge u_dut.w_screen_v_active);
		wait (screen_pos_y == 10'd207 && screen_pos_x == 14'd0);
		#1;
		if (sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "212 lines, offset 10, sprites at Y=209: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		reg_vertical_offset = 8'd0;
		reg_212lines_mode = 1'b0;
		@(posedge intr_frame);
		wait (screen_pos_y == 10'd220 && screen_pos_x == 14'd0);
		for (plane = 0; plane < 32; plane = plane + 1) begin
			sprite_attribute_table[plane] = {8'h0F, 8'd0, 8'd64, 8'd255};
		end
		wait (screen_pos_y == 10'h3FF && screen_pos_x == 14'd2048);
		#1;
		if (u_dut.w_sprite_overmap_v_active !== 1'b1 || sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "First display line not prefetched: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		@(posedge intr_frame);
		for (plane = 0; plane < 32; plane = plane + 1) begin
			sprite_attribute_table[plane] = {8'h0F, 8'd0, 8'd64, 8'd190};
		end
		wait (screen_pos_y == 10'd190 && screen_pos_x == 14'd2048);
		#1;
		if (u_dut.w_sprite_overmap_v_active !== 1'b1 || sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4) begin
			$fatal(1, "Last display line not prefetched: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		@(posedge intr_frame);
		wait (screen_pos_y == 10'd191 && screen_pos_x == 14'd2048);
		#1;
		if (u_dut.w_sprite_overmap_v_active !== 1'b0 || sprite_overmap !== 1'b0) begin
			$fatal(1, "Overmap detected after last display line: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		test6_vram_enable = 1'b0;
		if (failures != 0) begin
			$fatal(1, "Sprite overmap test FAILED: %0d mismatches in 28 candidate planes", failures);
		end
		$display("Sprite overmap test PASSED");
	endtask

	// ----------------------------------------------------------------
	// モニタリング用の表示（オプション）
	// ----------------------------------------------------------------
//	always @(posedge clk) begin
//		// 重要な状態変化をモニタ
//		if (intr_frame) begin
//			$display("Time: %0t - Frame interrupt detected at V=%0d", $time, screen_pos_y);
//		end
//		
//		if (intr_line) begin
//			$display("Time: %0t - Line interrupt detected at V=%0d", $time, screen_pos_y);
//		end
//	end

endmodule

module tb_collision_once_per_line ();
	reg clk;
	reg reset_n;
	reg [13:0] screen_pos_x;
	reg [9:0] screen_pos_y;
	reg [3:0] makeup_plane;
	reg color_plane_x_en;
	reg pattern_left_en;
	reg clear_sprite_collision;
	wire sprite_collision;
	wire [9:0] sprite_collision_y;
	integer scan_clock;

	vdp_sprite_makeup_pixel u_dut (
		.reset_n(reset_n),
		.clk(clk),
		.screen_pos_x(screen_pos_x),
		.screen_pos_y(screen_pos_y),
		.screen_v_active(1'b1),
		.sprite_mode2(1'b1),
		.reg_display_on(1'b1),
		.reg_color0_opaque(1'b1),
		.reg_sprite_magify(1'b0),
		.reg_ext_palette_mode(1'b0),
		.reg_sprite_16x16(1'b0),
		.reg_sprite_mode3(1'b0),
		.selected_count(5'd2),
		.makeup_plane(makeup_plane),
		.plane_x(10'd232),
		.color(8'h05),
		.palette_set(4'd0),
		.info_mgx(8'd0),
		.color_plane_x_en(color_plane_x_en),
		.pattern(32'hFFFFFFFF),
		.pattern_left_en(pattern_left_en),
		.pattern_right_en(1'b0),
		.x(),
		.mgx(),
		.sample_x(7'd0),
		.display_color(),
		.display_color_transparent(),
		.display_color_en(),
		.clear_sprite_collision(clear_sprite_collision),
		.sprite_collision(sprite_collision),
		.clear_sprite_collision_xy(1'b0),
		.sprite_collision_x(),
		.sprite_collision_y(sprite_collision_y)
	);

	always #5 clk = ~clk;

	task automatic scan_line;
		input clear_on_first_collision;
		reg collision_seen;
		reg collision_cleared;
		begin
			collision_seen = 1'b0;
			collision_cleared = 1'b0;
			screen_pos_x = 14'h3FFF;
			@(posedge clk);
			#1;
			for (scan_clock = 0; scan_clock < 16 * 256; scan_clock = scan_clock + 1) begin
				screen_pos_x = scan_clock;
				@(posedge clk);
				#1;
				if (!collision_seen && sprite_collision) begin
					collision_seen = 1'b1;
					if (sprite_collision_y !== screen_pos_y + 10'd8)
						$fatal(1, "Collision Y expected %0d, got %0d", screen_pos_y + 10'd8, sprite_collision_y);
					if (clear_on_first_collision) clear_sprite_collision = 1'b1;
				end
				else if (clear_sprite_collision) begin
					clear_sprite_collision = 1'b0;
					collision_cleared = 1'b1;
				end
				else if (collision_cleared && sprite_collision) begin
					$fatal(1, "Collision reasserted in the same line at X=%0d", screen_pos_x[13:4]);
				end
			end
			if (!collision_seen || (clear_on_first_collision && !collision_cleared)) begin
				$fatal(1, "Expected collision and status clear did not occur");
			end
		end
	endtask

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		screen_pos_x = 14'd0;
		screen_pos_y = 10'd40;
		makeup_plane = 4'd0;
		color_plane_x_en = 1'b0;
		pattern_left_en = 1'b0;
		clear_sprite_collision = 1'b0;
		repeat (4) @(posedge clk);
		#1;
		reset_n = 1'b1;
		color_plane_x_en = 1'b1;
		pattern_left_en = 1'b1;
		@(posedge clk);
		#1;
		makeup_plane = 4'd1;
		@(posedge clk);
		#1;
		color_plane_x_en = 1'b0;
		pattern_left_en = 1'b0;
		scan_line(1'b1);
		if (sprite_collision !== 1'b0) $fatal(1, "Collision did not clear");
		screen_pos_y = 10'd199;
		scan_line(1'b0);
		if (sprite_collision !== 1'b1) $fatal(1, "Collision was not detected on the next line");
		$display("Collision is reported once per line");
		$finish;
	end
endmodule
