// -----------------------------------------------------------------------------
//	Test of vdp_sprite_info_collect.v
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
	localparam		clk_base		= 1_000_000_000/42_954_540;	//	ns
	localparam		c_line_end		= 10'd340;					//	last dot of the horizontal blanking

	// Clock and reset
	reg					reset_n;
	reg					clk;					//	42.95454MHz

	// DUT input signals
	reg		[13:0]		screen_pos_x;
	reg					screen_v_active;
	reg					screen_h_active;
	reg					start_en;
	wire				start_info_collect;
	wire	[17:0]		vram_address;
	wire				vram_valid;
	reg		[7:0]		vram_rdata8;
	reg		[31:0]		vram_rdata;
	reg					selected_en;
	reg		[5:0]		selected_plane_num;
	reg		[31:0]		selected_attribute;
	reg		[4:0]		selected_count;
	wire	[7:0]		y;
	wire	[7:0]		mgy;
	wire	[1:0]		bit_shift;
	wire	[6:0]		sample_y;
	wire	[3:0]		makeup_plane;
	wire	[7:0]		color;
	wire	[3:0]		palette_set;
	wire	[9:0]		plane_x;
	wire	[7:0]		mgx;
	wire				color_plane_x_en;
	wire	[31:0]		pattern;
	wire				pattern_left_en;
	wire				pattern_right_en;
	reg					sprite_mode2;
	reg					reg_display_on;
	reg					reg_sprite_magify;
	reg					reg_sprite_16x16;
	reg		[17:11]		reg_sprite_pattern_generator_table_base;
	reg		[17:7]		reg_sprite_attribute_table_base;
	reg					reg_sprite_mode3;

	// VRAM model
	reg		[17:0]		ff_vram_latch;
	reg		[2:0]		ff_vram_delay;

	// Expectations
	logic	[17:0]		exp_address[$];
	reg		[5:0]		e_plane_num	[0:15];
	reg		[31:0]		e_attribute	[0:15];
	reg		[31:0]		e_attribute2[0:15];
	reg		[31:0]		e_pattern_l	[0:15];
	reg		[31:0]		e_pattern_r	[0:15];
	int					plane_index;
	int					right_count;
	int					error_count;
	reg					check_en;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	vdp_sprite_info_collect u_sprite_info_collect (
		.reset_n									( reset_n									),
		.clk										( clk										),
		.start_info_collect							( start_info_collect						),
		.screen_pos_x								( screen_pos_x								),
		.screen_v_active							( screen_v_active							),
		.screen_h_active							( screen_h_active							),
		.vram_address								( vram_address								),
		.vram_valid									( vram_valid								),
		.vram_rdata8								( vram_rdata8								),
		.vram_rdata									( vram_rdata								),
		.selected_en								( selected_en								),
		.selected_plane_num							( selected_plane_num						),
		.selected_attribute							( selected_attribute						),
		.selected_count								( selected_count							),
		.y											( y											),
		.mgy										( mgy										),
		.bit_shift									( bit_shift									),
		.sample_y									( sample_y									),
		.makeup_plane								( makeup_plane								),
		.color										( color										),
		.palette_set								( palette_set								),
		.plane_x									( plane_x									),
		.mgx										( mgx										),
		.color_plane_x_en							( color_plane_x_en							),
		.pattern									( pattern									),
		.pattern_left_en							( pattern_left_en							),
		.pattern_right_en							( pattern_right_en							),
		.sprite_mode2								( sprite_mode2								),
		.reg_display_on								( reg_display_on							),
		.reg_sprite_magify							( reg_sprite_magify							),
		.reg_sprite_16x16							( reg_sprite_16x16							),
		.reg_sprite_pattern_generator_table_base	( reg_sprite_pattern_generator_table_base	),
		.reg_sprite_attribute_table_base			( reg_sprite_attribute_table_base			),
		.reg_sprite_mode3							( reg_sprite_mode3							)
	);

	// --------------------------------------------------------------------
	//	Clock and timing generator (same h_active rule as vdp_timing_control_sprite)
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	assign start_info_collect	= start_en && (screen_pos_x == { 10'd259, 4'd14 });
	//	Stand-in for vdp_sprite_divider
	assign sample_y				= y[6:0] ^ 7'h25;

	always @( posedge clk ) begin
		if( !reset_n ) begin
			screen_pos_x <= { 10'h3FC, 4'd0 };
		end
		else if( screen_pos_x == { c_line_end, 4'hF } ) begin
			screen_pos_x <= { 10'h3FC, 4'd0 };
		end
		else begin
			screen_pos_x <= screen_pos_x + 14'd1;
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			screen_h_active <= 1'b0;
		end
		else if( screen_pos_x[3:0] == 4'hF ) begin
			if( screen_pos_x[13:4] == 10'h3FF ) begin
				screen_h_active <= 1'b1;
			end
			else if( screen_pos_x[13:4] == 10'd255 ) begin
				screen_h_active <= 1'b0;
			end
		end
	end

	// --------------------------------------------------------------------
	//	VRAM model: data derived from the address, valid 4 clocks after the request
	// --------------------------------------------------------------------
	function automatic [7:0] f8( input [17:0] a );
		f8 = (a[7:0] ^ a[15:8] ^ { 6'd0, a[17:16] }) + 8'h5A;
	endfunction

	function automatic [31:0] f32( input [17:0] a );
		f32 = { f8( a ^ 18'd3 ), f8( a ^ 18'd2 ), f8( a ^ 18'd1 ), f8( a ) };
	endfunction

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_vram_delay <= 3'd0;
		end
		else if( vram_valid ) begin
			ff_vram_latch	<= vram_address;
			ff_vram_delay	<= 3'd4;
			vram_rdata8		<= 8'hxx;
			vram_rdata		<= 32'hxxxx_xxxx;
		end
		else if( ff_vram_delay != 3'd0 ) begin
			ff_vram_delay	<= ff_vram_delay - 3'd1;
			if( ff_vram_delay == 3'd1 ) begin
				vram_rdata8		<= f8( ff_vram_latch );
				vram_rdata		<= f32( ff_vram_latch );
			end
		end
	end

	// --------------------------------------------------------------------
	//	Monitor (sampled on negedge, where all inputs and outputs are stable)
	// --------------------------------------------------------------------
	task automatic fail( input string msg );
		$display( "[ERROR] %0t: %s", $realtime, msg );
		error_count++;
	endtask

	always @( negedge clk ) begin
		if( check_en ) begin
			if( vram_valid ) begin
				if( exp_address.size() == 0 ) begin
					fail( $sformatf( "Unexpected VRAM request %05X", vram_address ) );
				end
				else begin
					automatic logic [17:0] a = exp_address.pop_front();
					if( vram_address !== a ) begin
						fail( $sformatf( "VRAM address %05X, expected %05X", vram_address, a ) );
					end
				end
			end
			if( color_plane_x_en ) begin
				if( plane_index >= selected_count ) begin
					fail( $sformatf( "Unexpected color_plane_x_en (plane %0d)", plane_index ) );
				end
				else begin
					automatic logic [31:0] at = e_attribute[ plane_index ];
					automatic logic [31:0] a2 = e_attribute2[ plane_index ];
					automatic logic [7:0] exp_color;
					automatic logic [9:0] exp_x;
					if( reg_sprite_mode3 ) begin
						exp_color	= at[31:24];
						exp_x		= a2[9:0];
					end
					else if( sprite_mode2 ) begin
						exp_color	= f8( sp2_color_address( e_plane_num[ plane_index ], at[3:0] ) );
						exp_x		= { 2'd0, at[15:8] };
					end
					else begin
						exp_color	= at[31:24];
						exp_x		= { 2'd0, at[15:8] };
					end
					if( makeup_plane !== plane_index[3:0] ) fail( $sformatf( "makeup_plane %0d, expected %0d", makeup_plane, plane_index ) );
					if( color !== exp_color ) fail( $sformatf( "plane %0d: color %02X, expected %02X", plane_index, color, exp_color ) );
					if( plane_x !== exp_x ) fail( $sformatf( "plane %0d: plane_x %03X, expected %03X", plane_index, plane_x, exp_x ) );
					if( y !== at[7:0] ) fail( $sformatf( "plane %0d: y %02X, expected %02X", plane_index, y, at[7:0] ) );
					if( reg_sprite_mode3 ) begin
						if( mgx !== a2[23:16] ) fail( $sformatf( "plane %0d: mgx %02X, expected %02X", plane_index, mgx, a2[23:16] ) );
						if( mgy !== at[23:16] ) fail( $sformatf( "plane %0d: mgy %02X, expected %02X", plane_index, mgy, at[23:16] ) );
						if( bit_shift !== at[15:14] ) fail( $sformatf( "plane %0d: bit_shift %0d, expected %0d", plane_index, bit_shift, at[15:14] ) );
						if( palette_set !== at[27:24] ) fail( $sformatf( "plane %0d: palette_set %0d, expected %0d", plane_index, palette_set, at[27:24] ) );
					end
				end
			end
			if( pattern_left_en && plane_index < selected_count ) begin
				if( pattern !== e_pattern_l[ plane_index ] ) fail( $sformatf( "plane %0d: pattern left %08X, expected %08X", plane_index, pattern, e_pattern_l[ plane_index ] ) );
			end
			if( pattern_right_en ) begin
				if( plane_index >= selected_count ) begin
					fail( $sformatf( "Unexpected pattern_right_en (plane %0d)", plane_index ) );
				end
				else if( pattern !== e_pattern_r[ plane_index ] ) begin
					fail( $sformatf( "plane %0d: pattern right %08X, expected %08X", plane_index, pattern, e_pattern_r[ plane_index ] ) );
				end
				plane_index++;
				right_count++;
			end
		end
	end

	// --------------------------------------------------------------------
	//	Expected addresses
	// --------------------------------------------------------------------
	function automatic [17:0] sp2_color_address( input [5:0] pn, input [3:0] yy );
		sp2_color_address = { reg_sprite_attribute_table_base[17:10], 1'b0, reg_sprite_attribute_table_base[8:7] & pn[4:3], pn[2:0], yy };
	endfunction

	function automatic [17:0] sp3_attribute2_address( input [5:0] pn );
		sp3_attribute2_address = { reg_sprite_attribute_table_base[17:9], reg_sprite_attribute_table_base[8:7] & pn[5:4], pn[3:0], 3'd4 };
	endfunction

	function automatic [17:0] sp3_pattern_address( input [31:0] at, input [31:0] a2 );
		logic [6:0]		sy;
		logic [6:0]		ym;
		logic [14:0]	pa;
		sy = at[6:0] ^ 7'h25;
		if( at[29] ) sy = ~sy;
		case( at[15:14] )
		2'd0:		ym = { 3'd0, sy[3:0] };
		2'd1:		ym = { 2'd0, sy[4:0] };
		2'd2:		ym = { 1'd0, sy[5:0] };
		default:	ym = sy;
		endcase
		pa = { a2[31:28], 4'd0, a2[27:24] } + { a2[14:12], 1'b0, ym, 4'd0 };
		sp3_pattern_address = { reg_sprite_pattern_generator_table_base, 11'd0 } + { pa, 3'd0 };
	endfunction

	//	Build expectations of plane#0...#n-1 from e_plane_num/e_attribute
	task automatic prepare( input int n );
		logic [17:0] a;
		exp_address.delete();
		for( int i = 0; i < n; i++ ) begin
			if( reg_sprite_mode3 ) begin
				a = sp3_attribute2_address( e_plane_num[i] );
				exp_address.push_back( a );
				e_attribute2[i] = f32( a );
				a = sp3_pattern_address( e_attribute[i], e_attribute2[i] );
				exp_address.push_back( a );
				exp_address.push_back( a + 18'd4 );
				e_pattern_l[i] = f32( a );
				e_pattern_r[i] = f32( a + 18'd4 );
			end
			else begin
				if( sprite_mode2 ) begin
					exp_address.push_back( sp2_color_address( e_plane_num[i], e_attribute[i][3:0] ) );
				end
				if( reg_sprite_16x16 ) begin
					a = { reg_sprite_pattern_generator_table_base, e_attribute[i][23:18], 1'b0, e_attribute[i][3:0] };
					exp_address.push_back( a );
					exp_address.push_back( a | 18'h10 );
					e_pattern_l[i] = { 24'd0, f8( a ) };
					e_pattern_r[i] = { 24'd0, f8( a | 18'h10 ) };
				end
				else begin
					a = { reg_sprite_pattern_generator_table_base, e_attribute[i][23:16], e_attribute[i][2:0] };
					exp_address.push_back( a );
					e_pattern_l[i] = { 24'd0, f8( a ) };
					e_pattern_r[i] = 32'd0;
				end
			end
		end
	endtask

	// --------------------------------------------------------------------
	//	Run one line: write n selected planes in the active period, collect in the blanking
	// --------------------------------------------------------------------
	task automatic wait_x( input [13:0] x );
		do @( negedge clk ); while( screen_pos_x !== x );
	endtask

	task automatic run_line( input string name, input int n, input int count );
		int errors_before;
		errors_before	= error_count;
		selected_count	= count;
		prepare( (reg_display_on && count != 0) ? count : 0 );
		plane_index		= 0;
		right_count		= 0;
		wait_x( { 10'h3FF, 4'hF } );
		check_en		= 1'b1;
		for( int i = 0; i < n; i++ ) begin
			wait_x( { 10'(i * 8 + 4), 4'd0 } );
			selected_en			= 1'b1;
			selected_plane_num	= e_plane_num[i];
			selected_attribute	= e_attribute[i];
			@( negedge clk );
			selected_en			= 1'b0;
		end
		start_en		= 1'b1;
		wait_x( { c_line_end, 4'hF } );
		start_en		= 1'b0;
		check_en		= 1'b0;
		if( right_count != ((reg_display_on && count != 0) ? count : 0) ) fail( $sformatf( "%s: %0d planes collected, expected %0d", name, right_count, count ) );
		if( exp_address.size() != 0 ) fail( $sformatf( "%s: %0d VRAM requests missing", name, exp_address.size() ) );
		$display( "[%s] %s", (error_count == errors_before) ? "OK" : "NG", name );
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		clk				= 0;
		reset_n			= 0;
		screen_v_active	= 1;
		start_en		= 0;
		selected_en		= 0;
		selected_plane_num	= 0;
		selected_attribute	= 0;
		selected_count	= 0;
		vram_rdata8		= 0;
		vram_rdata		= 0;
		sprite_mode2	= 0;
		reg_display_on	= 1;
		reg_sprite_magify	= 0;
		reg_sprite_16x16	= 0;
		reg_sprite_pattern_generator_table_base	= 7'b1010101;
		reg_sprite_attribute_table_base			= 11'b101_0101_1011;
		reg_sprite_mode3	= 0;
		error_count		= 0;
		check_en		= 0;
		repeat( 20 ) @( negedge clk );
		reset_n			= 1;
		repeat( 20 ) @( negedge clk );

		// SP1 8x8: attribute = { color, pattern, x, y offset }
		for( int i = 0; i < 4; i++ ) begin
			e_plane_num[i]	= 6'(i * 7 + 3);
			e_attribute[i]	= { 8'(i + 1), 8'(i * 37 + 5), 8'(i * 61 + 9), 8'(i * 3 + 1) & 8'h07 };
		end
		run_line( "SP1 8x8", 4, 4 );

		// SP1 16x16
		reg_sprite_16x16	= 1;
		for( int i = 0; i < 4; i++ ) begin
			e_attribute[i]	= { 8'(i + 9), 8'(i * 53 + 17), 8'(255 - i * 19), 8'(i * 5 + 2) & 8'h0F };
		end
		run_line( "SP1 16x16", 4, 4 );

		// SP2 16x16 with color table read (SAT[8:7] masks plane#[4:3])
		sprite_mode2	= 1;
		for( int i = 0; i < 8; i++ ) begin
			e_plane_num[i]	= 6'(i * 4 + 1);
			e_attribute[i]	= { 8'hEE, 8'(i * 29 + 3), 8'(i * 31 + 7), 8'(i * 7 + 4) & 8'h0F };
		end
		run_line( "SP2 16x16 SAT[8:7]=11", 8, 8 );
		reg_sprite_attribute_table_base[8:7]	= 2'b01;
		run_line( "SP2 16x16 SAT[8:7]=01", 8, 8 );

		// SP2 8x8
		reg_sprite_16x16	= 0;
		run_line( "SP2 8x8", 8, 8 );

		// SP3: attribute = { 2'b00, RVY, RVX, palette set, MGY, bit shift, 6'd0, y offset }
		reg_sprite_mode3	= 1;
		reg_sprite_attribute_table_base[8:7]	= 2'b10;
		for( int i = 0; i < 16; i++ ) begin
			e_plane_num[i]	= 6'(i * 4 + (i & 3));
			e_attribute[i]	= { 2'b00, 1'(i >> 1), 1'(i >> 2), 4'(15 - i), 8'(i * 11 + 16), 2'(i), 6'd0, 8'(i * 9 + 2) & 8'h7F };
		end
		run_line( "SP3 16 planes", 16, 16 );
		reg_sprite_attribute_table_base[8:7]	= 2'b11;
		run_line( "SP3 3 planes", 3, 3 );

		// No collection when nothing is selected or the display is off
		reg_sprite_mode3	= 0;
		sprite_mode2		= 0;
		run_line( "count=0", 0, 0 );
		reg_display_on		= 0;
		run_line( "display off", 2, 2 );
		reg_display_on		= 1;
		run_line( "display on again", 2, 2 );

		if( error_count == 0 ) begin
			$display( "PASS: vdp_sprite_info_collect" );
		end
		else begin
			$display( "FAIL: %0d errors", error_count );
		end
		$finish;
	end
endmodule
