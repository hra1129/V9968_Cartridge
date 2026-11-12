// -----------------------------------------------------------------------------
//	Test of vdp_cpu_interface.v
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
	localparam		c_time_out		= 100;

	reg					reset_n;
	reg					clk;					//	42.95454MHz

	reg		[1:0]		bus_address;
	reg					bus_ioreq;
	reg					bus_write;
	reg					bus_valid;
	wire				bus_ready;
	reg		[7:0]		bus_wdata;
	wire	[7:0]		bus_rdata;
	wire				bus_rdata_en;
	wire				bus_write_done;

	wire	[16:0]		vram_address;
	wire				vram_write;
	wire				vram_valid;
	reg					vram_ready;
	wire	[7:0]		vram_wdata;
	reg		[7:0]		vram_rdata;
	reg					vram_rdata_en;

	wire				palette_valid;
	wire		[3:0]	palette_num;
	wire		[2:0]	palette_r;
	wire		[2:0]	palette_g;
	wire		[2:0]	palette_b;

	reg			[4:0]	ff_last_palette_num;
	reg			[2:0]	ff_last_palette_r;
	reg			[2:0]	ff_last_palette_g;
	reg			[2:0]	ff_last_palette_b;

	wire				int_n;
	reg					intr_line;					//	pulse
	reg					intr_frame;					//	pulse

	wire				clear_sprite_collision;		//	pulse
	reg					sprite_collision;
	wire				clear_sprite_collision_xy;	//	pulse
	reg			[8:0]	sprite_collision_x;
	reg			[9:0]	sprite_collision_y;

	wire				register_write;
	wire		[5:0]	register_num;
	wire		[7:0]	register_data;

	reg					status_command_enable;		//	S#2 bit0
	reg					status_border_detect;		//	S#2 bit4
	reg					status_transfer_ready;		//	S#2 bit7
	reg			[7:0]	status_color;				//	S#7
	reg			[8:0]	status_border_position;		//	S#8, S#9

	wire	[4:0]		reg_screen_mode;
	wire				reg_sprite_magify;
	wire				reg_sprite_16x16;
	wire				reg_display_on;
	wire	[16:10]		reg_pattern_name_table_base;
	wire	[16:6]		reg_color_table_base;
	wire	[16:11]		reg_pattern_generator_table_base;
	wire	[16:7]		reg_sprite_attribute_table_base;
	wire	[16:11]		reg_sprite_pattern_generator_table_base;
	wire	[7:0]		reg_backdrop_color;
	wire				reg_sprite_disable;
	wire				reg_color0_opaque;
	wire				reg_50hz_mode;
	wire				reg_interleaving_mode;
	wire				reg_interlace_mode;
	wire				reg_212lines_mode;
	wire	[7:0]		reg_text_back_color;
	wire	[7:0]		reg_blink_period;
	wire	[3:0]		reg_color_palette_address;
	wire	[7:0]		reg_display_adjust;
	wire	[7:0]		reg_interrupt_line;
	wire	[7:0]		reg_vertical_offset;
	wire				reg_scroll_planes;
	wire				reg_left_mask;
	wire				reg_yjk_mode;
	wire				reg_yae_mode;
	wire				reg_command_enable;
	wire	[8:0]		reg_horizontal_offset;
	reg		[2:0]		reg_horizontal_offset_l;
	reg		[8:3]		reg_horizontal_offset_h;
	reg		[16:0]		ff_last_vram_address;
	reg		[7:0]		ff_last_vram_wdata;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	vdp_cpu_interface u_cpu_interface ( .* );

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	palette
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( palette_valid ) begin
			ff_last_palette_num	<= { 1'b0, palette_num };
			ff_last_palette_r	<= palette_r;
			ff_last_palette_g	<= palette_g;
			ff_last_palette_b	<= palette_b;
		end
	end

	// --------------------------------------------------------------------
	//	Wait ready
	// --------------------------------------------------------------------
	task wait_ready();
		int time_out;

		time_out = 0;
		while( bus_ready == 1'b0 || bus_ready === 1'bx ) begin
			if( time_out >= c_time_out ) begin
				$display( "[ERROR] wait_ready time out" );
				break;
			end
			@( posedge clk );
			time_out = time_out + 1;
		end
	endtask: wait_ready

	// --------------------------------------------------------------------
	//	Write Access
	// --------------------------------------------------------------------
	task write_io(
		input	[1:0]	address,
		input	[7:0]	wdata
	);
		bus_ioreq <= 1'b1;
		bus_address <= address;
		bus_wdata <= wdata;
		bus_write <= 1'b1;
		bus_valid <= 1'b1;
		@( posedge clk );

		wait_ready();

		bus_ioreq <= 1'b0;
		bus_valid <= 1'b0;
		@( posedge clk );
		@( posedge clk );
		@( posedge clk );
		@( posedge clk );
	endtask: write_io

	// --------------------------------------------------------------------
	//	Read Access
	// --------------------------------------------------------------------
	task read_io(
		input	[1:0]	address,
		input	[7:0]	rdata
	);
		int time_out;

		bus_ioreq <= 1'b1;
		bus_address <= address;
		bus_write <= 1'b0;
		bus_valid <= 1'b1;
		@( posedge clk );

		wait_ready();

		bus_ioreq <= 1'b0;
		bus_valid <= 1'b0;
		time_out = 0;
		while( !vram_ready ) begin
			if( time_out >= c_time_out ) begin
				$display( "[ERROR] vram_ready time out" );
				break;
			end
			@( posedge clk );
			time_out = time_out + 1;
		end
		vram_rdata <= rdata;
		vram_rdata_en <= 1'b1;
		@( posedge clk );
		vram_rdata_en <= 1'b0;
		time_out = 0;
		while( !bus_rdata_en ) begin
			if( time_out >= c_time_out ) begin
				$display( "[ERROR] bus_rdata_en time out" );
				break;
			end
			@( posedge clk );
			time_out = time_out + 1;
		end

		assert( rdata == bus_rdata );
	endtask: read_io

	// --------------------------------------------------------------------
	//	Background task
	// --------------------------------------------------------------------
	task vram_response();
		vram_ready <= 1'b0;
		forever begin
			while( vram_valid == 1'b0 || vram_valid === 1'bx ) begin
				@( posedge clk );
			end
			@( posedge clk );
			@( posedge clk );
			vram_ready <= 1'b1;
			@( posedge clk );
			ff_last_vram_address <= vram_address;
			ff_last_vram_wdata <= vram_wdata;
			vram_ready <= 1'b0;
			@( posedge clk );
		end
	endtask: vram_response

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		clk = 0;
		reset_n = 0;

		bus_address = 0;
		bus_ioreq = 0;
		bus_write = 0;
		bus_valid = 0;
		bus_wdata = 0;

		vram_ready = 0;
		vram_rdata = 0;
		vram_rdata_en = 0;
		ff_last_vram_address = 0;

		ff_last_palette_num = 5'b11111;
		ff_last_palette_r = 0;
		ff_last_palette_g = 0;
		ff_last_palette_b = 0;

		intr_line = 0;
		intr_frame = 0;
		sprite_collision = 0;
		sprite_collision_x = 0;
		sprite_collision_y = 0;

		status_command_enable = 0;		//	S#2 bit0
		status_border_detect = 0;		//	S#2 bit4
		status_transfer_ready = 0;		//	S#2 bit7
		status_color = 0;				//	S#7
		status_border_position = 0;		//	S#8, S#9

		fork
			vram_response();
		join_none

		@( posedge clk );
		@( posedge clk );
		@( posedge clk );
		reset_n <= 1;
		@( posedge clk );

		$display( "[test001] VRAM Write" );
		write_io( 1, 8'h00 );
		write_io( 1, 8'h40 );
		write_io( 0, 8'h12 );
		repeat( 10 ) @( posedge clk );
		assert( ff_last_vram_address == 17'h00000 );
		assert( ff_last_vram_wdata == 8'h12 );

		write_io( 1, 8'h23 );
		write_io( 1, 8'h41 );
		write_io( 0, 8'hAB );
		repeat( 10 ) @( posedge clk );
		assert( ff_last_vram_address == 17'h00123 );
		assert( ff_last_vram_wdata == 8'hAB );

		$display( "[test002] VRAM Write Address Auto Increment" );
		write_io( 0, 8'hCD );
		repeat( 10 ) @( posedge clk );
		assert( ff_last_vram_address == 17'h00124 );
		assert( ff_last_vram_wdata == 8'hCD );

		write_io( 0, 8'hEF );
		repeat( 10 ) @( posedge clk );
		assert( ff_last_vram_address == 17'h00125 );
		assert( ff_last_vram_wdata == 8'hEF );

		$display( "[test003] VRAM Read Address" );
		write_io( 1, 8'h21 );
		write_io( 1, 8'h03 );
		read_io( 0, 8'h56 );
		assert( ff_last_vram_address == 17'h00321 );

		$display( "[test004] VRAM Read Address Auto Increment" );
		read_io( 0, 8'hAB );
		assert( ff_last_vram_address == 17'h00322 );

		read_io( 0, 8'h19 );
		assert( ff_last_vram_address == 17'h00323 );

		read_io( 0, 8'h74 );
		assert( ff_last_vram_address == 17'h00324 );

		$display( "[test005] Write Control Registers" );
		$display( "-- R#0 = 0" );
		write_io( 1, 8'h00 );
		write_io( 1, 8'h80 );
		assert( reg_screen_mode[4:2] == 3'd0 );

		$display( "-- R#0 = 2" );
		write_io( 1, 8'h02 );
		write_io( 1, 8'h80 );
		assert( reg_screen_mode[4:2] == 3'd1 );

		$display( "-- R#0 = 4" );
		write_io( 1, 8'h04 );
		write_io( 1, 8'h80 );
		assert( reg_screen_mode[4:2] == 3'd2 );

		$display( "-- R#0 = 8" );
		write_io( 1, 8'h08 );
		write_io( 1, 8'h80 );
		assert( reg_screen_mode[4:2] == 3'd4 );

		$display( "-- R#0 = 14" );
		write_io( 1, 8'h0E );
		write_io( 1, 8'h80 );
		assert( reg_screen_mode[4:2] == 3'd7 );

		$display( "-- R#1 = 1" );
		write_io( 1, 8'h01 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd1 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd0 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 2" );
		write_io( 1, 8'h02 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd1 );
		assert( reg_screen_mode[1:0] == 2'd0 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 4" );
		write_io( 1, 8'h04 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd0 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 8" );
		write_io( 1, 8'h08 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd2 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 16" );
		write_io( 1, 8'h10 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd1 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 32" );
		write_io( 1, 8'h20 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd0 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 64" );
		write_io( 1, 8'h40 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd0 );
		assert( reg_display_on == 1'd1 );

		$display( "-- R#1 = 128" );
		write_io( 1, 8'h80 );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd0 );
		assert( reg_sprite_16x16 == 1'd0 );
		assert( reg_screen_mode[1:0] == 2'd0 );
		assert( reg_display_on == 1'd0 );

		$display( "-- R#1 = 255" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h81 );
		assert( reg_sprite_magify == 1'd1 );
		assert( reg_sprite_16x16 == 1'd1 );
		assert( reg_screen_mode[1:0] == 2'd3 );
		assert( reg_display_on == 1'd1 );

		$display( "-- R#2 = 255" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h82 );
		assert( reg_pattern_name_table_base == 7'h7F );

		$display( "-- R#2 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h82 );
		assert( reg_pattern_name_table_base == 7'h55 );

		$display( "-- R#2 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h82 );
		assert( reg_pattern_name_table_base == 7'h2A );

		$display( "-- R#3 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h83 );
		assert( reg_color_table_base[13:6] == 8'hFF );

		$display( "-- R#3 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h83 );
		assert( reg_color_table_base[13:6] == 8'h55 );

		$display( "-- R#3 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h83 );
		assert( reg_color_table_base[13:6] == 8'hAA );

		$display( "-- R#4 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h84 );
		assert( reg_pattern_generator_table_base == 6'h3F );

		$display( "-- R#4 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h84 );
		assert( reg_pattern_generator_table_base == 6'h15 );

		$display( "-- R#4 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h84 );
		assert( reg_pattern_generator_table_base == 6'h2A );

		$display( "-- R#5 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h85 );
		assert( reg_sprite_attribute_table_base[14:9] == 6'h3F );

		$display( "-- R#5 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h85 );
		assert( reg_sprite_attribute_table_base[14:9] == 6'h15 );

		$display( "-- R#5 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h85 );
		assert( reg_sprite_attribute_table_base[14:9] == 6'h2A );

		$display( "-- R#6 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h86 );
		assert( reg_sprite_pattern_generator_table_base == 6'h3F );

		$display( "-- R#6 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h86 );
		assert( reg_sprite_pattern_generator_table_base == 6'h15 );

		$display( "-- R#6 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h86 );
		assert( reg_sprite_pattern_generator_table_base == 6'h2A );

		$display( "-- R#7 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h87 );
		assert( reg_backdrop_color == 8'hFF );

		$display( "-- R#7 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h87 );
		assert( reg_backdrop_color == 8'h55 );

		$display( "-- R#7 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h87 );
		assert( reg_backdrop_color == 8'hAA );

		$display( "-- R#8 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h88 );
		assert( reg_sprite_disable == 1'b1 );
		assert( reg_color0_opaque == 1'b1 );

		$display( "-- R#8 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h88 );
		assert( reg_sprite_disable == 1'b0 );
		assert( reg_color0_opaque == 1'b0 );

		$display( "-- R#8 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h88 );
		assert( reg_sprite_disable == 1'b1 );
		assert( reg_color0_opaque == 1'b1 );

		$display( "-- R#9 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h89 );
		assert( reg_50hz_mode == 1'b1 );
		assert( reg_interleaving_mode == 1'b1 );
		assert( reg_interlace_mode == 1'b1 );
		assert( reg_212lines_mode == 1'b1 );

		$display( "-- R#9 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h89 );
		assert( reg_50hz_mode == 1'b0 );
		assert( reg_interleaving_mode == 1'b1 );
		assert( reg_interlace_mode == 1'b0 );
		assert( reg_212lines_mode == 1'b0 );

		$display( "-- R#9 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h89 );
		assert( reg_50hz_mode == 1'b1 );
		assert( reg_interleaving_mode == 1'b0 );
		assert( reg_interlace_mode == 1'b1 );
		assert( reg_212lines_mode == 1'b1 );

		$display( "-- R#10 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h8A );
		assert( reg_color_table_base[16:14] == 3'd7 );

		$display( "-- R#10 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h8A );
		assert( reg_color_table_base[16:14] == 3'd5 );

		$display( "-- R#10 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h8A );
		assert( reg_color_table_base[16:14] == 3'd2 );

		$display( "-- R#11 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h8B );
		assert( reg_sprite_attribute_table_base[16:15] == 2'd3 );

		$display( "-- R#11 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h8B );
		assert( reg_sprite_attribute_table_base[16:15] == 2'd1 );

		$display( "-- R#11 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h8B );
		assert( reg_sprite_attribute_table_base[16:15] == 2'd2 );

		$display( "-- R#12 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h8C );
		assert( reg_text_back_color == 8'hFF );

		$display( "-- R#12 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h8C );
		assert( reg_text_back_color == 8'h55 );

		$display( "-- R#12 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h8C );
		assert( reg_text_back_color == 8'hAA );

		$display( "-- R#13 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h8D );
		assert( reg_blink_period == 8'hFF );

		$display( "-- R#13 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h8D );
		assert( reg_blink_period == 8'h55 );

		$display( "-- R#13 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h8D );
		assert( reg_blink_period == 8'hAA );

		$display( "-- R#18 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h92 );
		assert( reg_display_adjust == 8'hFF );

		$display( "-- R#18 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h92 );
		assert( reg_display_adjust == 8'h55 );

		$display( "-- R#18 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h92 );
		assert( reg_display_adjust == 8'hAA );

		$display( "-- R#19 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h93 );
		assert( reg_interrupt_line == 8'hFF );

		$display( "-- R#19 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h93 );
		assert( reg_interrupt_line == 8'h55 );

		$display( "-- R#19 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h93 );
		assert( reg_interrupt_line == 8'hAA );

		$display( "-- R#23 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h97 );
		assert( reg_vertical_offset == 8'hFF );

		$display( "-- R#23 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h97 );
		assert( reg_vertical_offset == 8'h55 );

		$display( "-- R#23 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h97 );
		assert( reg_vertical_offset == 8'hAA );

		$display( "-- R#25 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h99 );
		assert( reg_scroll_planes == 1'b1 );
		assert( reg_left_mask == 1'b1 );
		assert( reg_yjk_mode == 1'b1 );
		assert( reg_yae_mode == 1'b1 );
		assert( reg_command_enable == 1'b1 );

		$display( "-- R#25 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h99 );
		assert( reg_scroll_planes == 1'b1 );
		assert( reg_left_mask == 1'b0 );
		assert( reg_yjk_mode == 1'b0 );
		assert( reg_yae_mode == 1'b1 );
		assert( reg_command_enable == 1'b1 );

		$display( "-- R#25 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h99 );
		assert( reg_scroll_planes == 1'b0 );
		assert( reg_left_mask == 1'b1 );
		assert( reg_yjk_mode == 1'b1 );
		assert( reg_yae_mode == 1'b0 );
		assert( reg_command_enable == 1'b0 );

		$display( "-- R#26 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h9A );
		assert( reg_horizontal_offset_h == 6'h3F );

		$display( "-- R#26 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h9A );
		assert( reg_horizontal_offset_h == 6'h15 );

		$display( "-- R#26 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h9A );
		assert( reg_horizontal_offset_h == 6'h2A );

		$display( "-- R#27 = FFh" );
		write_io( 1, 8'hFF );
		write_io( 1, 8'h9B );
		assert( reg_horizontal_offset_l == 3'h7 );

		$display( "-- R#27 = 55h" );
		write_io( 1, 8'h55 );
		write_io( 1, 8'h9B );
		assert( reg_horizontal_offset_l == 3'h5 );

		$display( "-- R#27 = AAh" );
		write_io( 1, 8'hAA );
		write_io( 1, 8'h9B );
		assert( reg_horizontal_offset_l == 3'h2 );

		$display( "[test006] Palette Write" );
		$display( "-- R#16 = 4" );
		write_io( 1, 8'h04 );
		write_io( 1, 8'h90 );

		assert( ff_last_palette_num == 5'b11111 );
		assert( ff_last_palette_r == 0 );
		assert( ff_last_palette_g == 0 );
		assert( ff_last_palette_b == 0 );

		write_io( 2, 8'h13 );

		assert( ff_last_palette_num == 5'b11111 );
		assert( ff_last_palette_r == 0 );
		assert( ff_last_palette_g == 0 );
		assert( ff_last_palette_b == 0 );

		write_io( 2, 8'h02 );

		assert( ff_last_palette_num == 5'd4 );
		assert( ff_last_palette_r == 1 );
		assert( ff_last_palette_g == 2 );
		assert( ff_last_palette_b == 3 );

		write_io( 2, 8'h46 );

		assert( ff_last_palette_num == 5'd4 );
		assert( ff_last_palette_r == 1 );
		assert( ff_last_palette_g == 2 );
		assert( ff_last_palette_b == 3 );

		write_io( 2, 8'h05 );

		assert( ff_last_palette_num == 5'd5 );
		assert( ff_last_palette_r == 4 );
		assert( ff_last_palette_g == 5 );
		assert( ff_last_palette_b == 6 );

		repeat( 10 ) @( posedge clk );
		$finish;
	end
endmodule

module tb_sprite_overmap_status ();
	reg clk;
	reg reset_n;
	reg [2:0] bus_address;
	reg bus_ioreq;
	reg bus_write;
	reg bus_valid;
	reg [7:0] bus_wdata;
	wire bus_ready;
	wire [7:0] bus_rdata;
	wire bus_rdata_en;
	reg intr_frame;
	reg sprite_overmap;
	reg [4:0] sprite_overmap_id;
	wire clear_sprite_overmap;
	wire sprite_overmap_enable;

	vdp_cpu_interface u_dut (
		.reset_n(reset_n),
		.clk(clk),
		.bus_address(bus_address),
		.bus_ioreq(bus_ioreq),
		.bus_write(bus_write),
		.bus_valid(bus_valid),
		.bus_ready(bus_ready),
		.bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata),
		.bus_rdata_en(bus_rdata_en),
		.bus_write_done(),
		.vram_address(),
		.vram_write(),
		.vram_valid(),
		.vram_ready(1'b0),
		.vram_wdata(),
		.vram_rdata(8'd0),
		.vram_rdata_en(1'b0),
		.palette_valid(),
		.palette_num(),
		.palette_r(),
		.palette_g(),
		.palette_b(),
		.int_n(),
		.intr_line(1'b0),
		.intr_frame(intr_frame),
		.intr_command_end(1'b0),
		.clear_line_interrupt(1'b0),
		.clear_sprite_collision(),
		.sprite_collision(1'b0),
		.clear_sprite_collision_xy(),
		.sprite_collision_x(9'd0),
		.sprite_collision_y(10'd0),
		.sprite_overmap(sprite_overmap),
		.sprite_overmap_id(sprite_overmap_id),
		.clear_sprite_overmap(clear_sprite_overmap),
		.sprite_overmap_enable(sprite_overmap_enable),
		.clear_border_detect(),
		.read_color(),
		.register_write(),
		.register_num(),
		.register_data(),
		.status_command_execute(1'b0),
		.status_field(1'b0),
		.status_border_detect(1'b0),
		.status_hsync(1'b0),
		.status_vsync(1'b0),
		.status_transfer_ready(1'b0),
		.status_color(8'd0),
		.status_border_position(9'd0),
		.vram_access_mask(1'b0),
		.force_highspeed(1'b0),
		.button(2'd0),
		.reg_screen_mode(),
		.reg_sprite_magify(),
		.reg_sprite_16x16(),
		.reg_display_on(),
		.reg_pattern_name_table_base(),
		.reg_color_table_base(),
		.reg_pattern_generator_table_base(),
		.reg_sprite_attribute_table_base(),
		.reg_sprite_pattern_generator_table_base(),
		.reg_backdrop_color(),
		.reg_sprite_disable(),
		.reg_color0_opaque(),
		.reg_50hz_mode(),
		.reg_interleaving_mode(),
		.reg_interlace_mode(),
		.reg_212lines_mode(),
		.reg_text_back_color(),
		.reg_blink_period(),
		.reg_display_adjust(),
		.reg_interrupt_line(),
		.reg_vertical_offset(),
		.reg_scroll_planes(),
		.reg_left_mask(),
		.reg_yjk_mode(),
		.reg_yae_mode(),
		.reg_command_enable(),
		.reg_sprite_priority_shuffle(),
		.reg_horizontal_offset_l(),
		.reg_horizontal_offset_h(),
		.reg_command_high_speed_mode(),
		.reg_sprite_nonR23_mode(),
		.reg_interrupt_line_nonR23_mode(),
		.reg_sprite_mode3(),
		.reg_ext_palette_mode(),
		.reg_ext_command_mode(),
		.reg_vram256k_mode(),
		.reg_sprite16_mode(),
		.reg_flat_interlace_mode(),
		.pulse0(),
		.pulse1(),
		.pulse2(),
		.pulse3(),
		.pulse4(),
		.pulse5(),
		.pulse6(),
		.pulse7()
	);

	always #5 clk = ~clk;
	always @(posedge clk) begin
		if (clear_sprite_overmap) sprite_overmap <= 1'b0;
	end

	task automatic read_status0;
		input expected_overmap;
		input [4:0] expected_id;
		begin
			bus_ioreq = 1'b1;
			bus_address = 3'd1;
			bus_write = 1'b0;
			bus_valid = 1'b1;
			while (bus_ready !== 1'b1) begin
				@(posedge clk);
				#1;
			end
			@(posedge clk);
			#1;
			if (clear_sprite_overmap !== 1'b1) begin
				$fatal(1, "Status #0 read did not clear sprite overmap");
			end
			bus_valid = 1'b0;
			@(posedge clk);
			#1;
			if (bus_rdata_en !== 1'b1 || bus_rdata[6] !== expected_overmap || bus_rdata[4:0] !== expected_id) begin
				$fatal(1, "Status #0: expected overmap=%b id=%d, got data=%02X", expected_overmap, expected_id, bus_rdata);
			end
			bus_ioreq = 1'b0;
			repeat (2) @(posedge clk);
			#1;
		end
	endtask

	task automatic write_port;
		input [2:0] address;
		input [7:0] data;
		begin
			bus_ioreq = 1'b1;
			bus_address = address;
			bus_write = 1'b1;
			bus_wdata = data;
			bus_valid = 1'b1;
			while (bus_ready !== 1'b1) begin
				@(posedge clk);
				#1;
			end
			@(posedge clk);
			#1;
			bus_valid = 1'b0;
			bus_write = 1'b0;
			bus_ioreq = 1'b0;
			repeat (4) @(posedge clk);
			#1;
		end
	endtask

	task automatic write_register;
		input [5:0] num;
		input [7:0] data;
		begin
			write_port(3'd1, data);
			write_port(3'd1, { 2'b10, num });
		end
	endtask

	task automatic pulse_intr_frame;
		begin
			intr_frame = 1'b1;
			@(posedge clk);
			#1;
			intr_frame = 1'b0;
		end
	endtask

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		bus_address = 3'd0;
		bus_ioreq = 1'b0;
		bus_write = 1'b0;
		bus_valid = 1'b0;
		bus_wdata = 8'd0;
		intr_frame = 1'b0;
		sprite_overmap = 1'b0;
		sprite_overmap_id = 5'd31;
		repeat (3) @(posedge clk);
		#1;
		reset_n = 1'b1;
		sprite_overmap = 1'b1;
		sprite_overmap_id = 5'd6;
		repeat (3) @(posedge clk);
		#1;
		intr_frame = 1'b1;
		@(posedge clk);
		#1;
		intr_frame = 1'b0;
		if (sprite_overmap_enable !== 1'b0) begin
			$fatal(1, "Overmap detection enabled while frame interrupt is pending");
		end
		//	Sprite mode1 (reset default): 5S set before F is hidden while F=1, and the read clears it
		read_status0(1'b0, 5'd6);
		if (sprite_overmap_enable !== 1'b1) begin
			$fatal(1, "Overmap detection disabled after status #0 read");
		end
		sprite_overmap = 1'b0;
		read_status0(1'b0, 5'd6);
		sprite_overmap = 1'b1;
		sprite_overmap_id = 5'd10;
		repeat (3) @(posedge clk);
		#1;
		read_status0(1'b1, 5'd10);

		//	Sprite mode2 (SCREEN5): 5S set before F is hidden while F=1, and the read clears it
		write_register(6'd0, 8'h06);
		sprite_overmap = 1'b1;
		sprite_overmap_id = 5'd12;
		repeat (3) @(posedge clk);
		#1;
		pulse_intr_frame();
		read_status0(1'b0, 5'd12);
		if (sprite_overmap !== 1'b0) begin
			$fatal(1, "Masked status #0 read did not clear sprite overmap");
		end
		//	F=0: 5S is visible in sprite mode2
		sprite_overmap = 1'b1;
		sprite_overmap_id = 5'd13;
		repeat (3) @(posedge clk);
		#1;
		read_status0(1'b1, 5'd13);
		//	Sprite mode3 on SCREEN0 is also masked
		write_register(6'd0, 8'h00);
		write_port(3'd4, 8'h00);
		write_register(6'd20, 8'h08);
		sprite_overmap = 1'b1;
		sprite_overmap_id = 5'd14;
		pulse_intr_frame();
		read_status0(1'b0, 5'd14);
		$display("Sprite overmap status read test PASSED");
		$finish;
	end
endmodule

module tb_port1_latch_reset ();
	reg clk;
	reg reset_n;
	reg [2:0] bus_address;
	reg bus_ioreq;
	reg bus_write;
	reg bus_valid;
	reg [7:0] bus_wdata;
	wire bus_ready;
	wire [7:0] bus_rdata;
	wire bus_rdata_en;
	wire vram_write;
	wire vram_valid;
	reg vram_ready;
	reg vram_rdata_en;
	wire register_write;
	wire [5:0] register_num;
	wire [7:0] register_data;
	wire [7:0] reg_backdrop_color;
	wire [17:11] reg_sprite_pattern_generator_table_base;
	reg [5:0] last_register_num;
	reg [7:0] last_register_data;
	integer register_write_count;
	wire palette_valid;
	wire [7:0] palette_num;
	wire [4:0] palette_r;
	wire [4:0] palette_g;
	wire [4:0] palette_b;
	wire reg_ext_palette_mode;
	wire reg_sprite_priority_shuffle;
	wire reg_scroll_planes;
	wire reg_left_mask;
	wire reg_yjk_mode;
	wire reg_yae_mode;
	wire reg_command_enable;
	reg [7:0] last_palette_num;
	reg [4:0] last_palette_r;
	reg [4:0] last_palette_g;
	reg [4:0] last_palette_b;
	integer palette_write_count;

	vdp_cpu_interface u_dut (
		.reset_n(reset_n),
		.clk(clk),
		.bus_address(bus_address),
		.bus_ioreq(bus_ioreq),
		.bus_write(bus_write),
		.bus_valid(bus_valid),
		.bus_ready(bus_ready),
		.bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata),
		.bus_rdata_en(bus_rdata_en),
		.bus_write_done(),
		.vram_address(),
		.vram_write(vram_write),
		.vram_valid(vram_valid),
		.vram_ready(vram_ready),
		.vram_wdata(),
		.vram_rdata(8'h5A),
		.vram_rdata_en(vram_rdata_en),
		.palette_valid(palette_valid),
		.palette_num(palette_num),
		.palette_r(palette_r),
		.palette_g(palette_g),
		.palette_b(palette_b),
		.int_n(),
		.intr_line(1'b0),
		.intr_frame(1'b0),
		.intr_command_end(1'b0),
		.clear_line_interrupt(1'b0),
		.clear_sprite_collision(),
		.sprite_collision(1'b0),
		.clear_sprite_collision_xy(),
		.sprite_collision_x(9'd0),
		.sprite_collision_y(10'd0),
		.sprite_overmap(1'b0),
		.sprite_overmap_id(5'd31),
		.clear_sprite_overmap(),
		.sprite_overmap_enable(),
		.clear_border_detect(),
		.read_color(),
		.register_write(register_write),
		.register_num(register_num),
		.register_data(register_data),
		.status_command_execute(1'b0),
		.status_field(1'b0),
		.status_border_detect(1'b0),
		.status_hsync(1'b0),
		.status_vsync(1'b0),
		.status_transfer_ready(1'b0),
		.status_color(8'd0),
		.status_border_position(9'd0),
		.vram_access_mask(1'b0),
		.force_highspeed(1'b0),
		.button(2'd0),
		.reg_screen_mode(),
		.reg_sprite_magify(),
		.reg_sprite_16x16(),
		.reg_display_on(),
		.reg_pattern_name_table_base(),
		.reg_color_table_base(),
		.reg_pattern_generator_table_base(),
		.reg_sprite_attribute_table_base(),
		.reg_sprite_pattern_generator_table_base(reg_sprite_pattern_generator_table_base),
		.reg_backdrop_color(reg_backdrop_color),
		.reg_sprite_disable(),
		.reg_color0_opaque(),
		.reg_50hz_mode(),
		.reg_interleaving_mode(),
		.reg_interlace_mode(),
		.reg_212lines_mode(),
		.reg_text_back_color(),
		.reg_blink_period(),
		.reg_display_adjust(),
		.reg_interrupt_line(),
		.reg_vertical_offset(),
		.reg_scroll_planes(reg_scroll_planes),
		.reg_left_mask(reg_left_mask),
		.reg_yjk_mode(reg_yjk_mode),
		.reg_yae_mode(reg_yae_mode),
		.reg_command_enable(reg_command_enable),
		.reg_sprite_priority_shuffle(reg_sprite_priority_shuffle),
		.reg_horizontal_offset_l(),
		.reg_horizontal_offset_h(),
		.reg_command_high_speed_mode(),
		.reg_sprite_nonR23_mode(),
		.reg_interrupt_line_nonR23_mode(),
		.reg_sprite_mode3(),
		.reg_ext_palette_mode(reg_ext_palette_mode),
		.reg_ext_command_mode(),
		.reg_vram256k_mode(),
		.reg_sprite16_mode(),
		.reg_flat_interlace_mode(),
		.pulse0(),
		.pulse1(),
		.pulse2(),
		.pulse3(),
		.pulse4(),
		.pulse5(),
		.pulse6(),
		.pulse7()
	);

	always #5 clk = ~clk;

	always @(posedge clk) begin
		if (palette_valid) begin
			last_palette_num    <= palette_num;
			last_palette_r      <= palette_r;
			last_palette_g      <= palette_g;
			last_palette_b      <= palette_b;
			palette_write_count <= palette_write_count + 1;
		 end
	end

	//	Minimal VRAM model: accept one cycle after request, return read data one cycle later.
	always @(posedge clk) begin
		vram_ready    <= vram_valid & ~vram_ready;
		vram_rdata_en <= vram_valid & vram_ready & ~vram_write;
	end

	always @(posedge clk) begin
		if (register_write) begin
			last_register_num    <= register_num;
			last_register_data   <= register_data;
			register_write_count <= register_write_count + 1;
		end
	end

	task automatic access_io;
		input [2:0] address;
		input       write;
		input [7:0] wdata;
		integer time_out;
		begin
			bus_ioreq   = 1'b1;
			bus_address = address;
			bus_write   = write;
			bus_wdata   = wdata;
			bus_valid   = 1'b1;
			time_out    = 0;
			while (bus_ready !== 1'b1) begin
				@(posedge clk);
				#1;
				time_out = time_out + 1;
				if (time_out > 100) $fatal(1, "bus_ready timeout (accept)");
			end
			@(posedge clk);
			#1;
			bus_valid = 1'b0;
			time_out  = 0;
			while (bus_ready !== 1'b1) begin
				@(posedge clk);
				#1;
				time_out = time_out + 1;
				if (time_out > 100) $fatal(1, "bus_ready timeout (complete)");
			end
			bus_ioreq = 1'b0;
			repeat (4) @(posedge clk);
			#1;
		end
	endtask

	task automatic write_register;
		input [5:0] num;
		input [7:0] value;
		begin
			access_io(3'd1, 1'b1, value);
			access_io(3'd1, 1'b1, { 2'b10, num });
		end
	endtask

	task automatic expect_backdrop;
		input [7:0] expected;
		input [8*48-1:0] name;
		begin
			if (reg_backdrop_color !== expected) begin
				$fatal(1, "%0s: R#7 expected %02X, got %02X", name, expected, reg_backdrop_color);
			end
			$display("-- %0s: OK", name);
		end
	endtask

	//	Expected palette entry for the V9938 format (3bit each, expanded to 5bit)
	task automatic expect_palette9938;
		input [3:0] num;
		input [7:0] rb;
		input [7:0] g;
		input [8*48-1:0] name;
		begin
			expect_palette({ 4'd0, num }, { rb[6:4], rb[6:5] }, { g[2:0], g[2:1] }, { rb[2:0], rb[2:1] }, name);
		end
	endtask

	task automatic expect_palette;
		input [7:0] num;
		input [4:0] r;
		input [4:0] g;
		input [4:0] b;
		input [8*48-1:0] name;
		begin
			if (palette_write_count !== 1) begin
				$fatal(1, "%0s: palette write count expected 1, got %0d", name, palette_write_count);
			end
			if (last_palette_num !== num || last_palette_r !== r || last_palette_g !== g || last_palette_b !== b) begin
				$fatal(1, "%0s: palette expected #%02X R%02X G%02X B%02X, got #%02X R%02X G%02X B%02X",
					name, num, r, g, b, last_palette_num, last_palette_r, last_palette_g, last_palette_b);
			end
			$display("-- %0s: OK", name);
			palette_write_count = 0;
		end
	endtask

	initial begin
		clk = 1'b0;
		reset_n = 1'b0;
		bus_address = 3'd0;
		bus_ioreq = 1'b0;
		bus_write = 1'b0;
		bus_valid = 1'b0;
		bus_wdata = 8'd0;
		vram_ready = 1'b0;
		vram_rdata_en = 1'b0;
		last_register_num = 6'd0;
		last_register_data = 8'd0;
		register_write_count = 0;
		last_palette_num = 8'd0;
		last_palette_r = 5'd0;
		last_palette_g = 5'd0;
		last_palette_b = 5'd0;
		palette_write_count = 0;
		repeat (3) @(posedge clk);
		#1;
		reset_n = 1'b1;
		repeat (3) @(posedge clk);
		#1;

		$display("[test001] Normal port#1 register write");
		write_register(6'd7, 8'h12);
		expect_backdrop(8'h12, "R#7 write");

		//	Fleet Commander II writes an odd byte count to port#1 and relies on this.
		$display("[test002] Port#0 write cancels pending port#1 1st byte");
		access_io(3'd1, 1'b1, 8'h34);
		access_io(3'd0, 1'b1, 8'hA5);
		write_register(6'd7, 8'h23);
		expect_backdrop(8'h23, "port#0 write");

		$display("[test003] Port#0 read cancels pending port#1 1st byte");
		access_io(3'd1, 1'b1, 8'h00);
		access_io(3'd1, 1'b1, 8'h00);
		access_io(3'd1, 1'b1, 8'h45);
		access_io(3'd0, 1'b0, 8'h00);
		write_register(6'd7, 8'h56);
		expect_backdrop(8'h56, "port#0 read");

		$display("[test004] Port#1 status read cancels pending port#1 1st byte");
		access_io(3'd1, 1'b1, 8'h67);
		access_io(3'd1, 1'b0, 8'h00);
		write_register(6'd7, 8'h78);
		expect_backdrop(8'h78, "port#1 read");

		$display("[test005] Port#2 1st byte keeps pending port#1 and replaces its data");
		write_register(6'd16, 8'h01);
		palette_write_count = 0;
		access_io(3'd1, 1'b1, 8'h89);
		access_io(3'd2, 1'b1, 8'h77);
		register_write_count = 0;
		access_io(3'd1, 1'b1, 8'h87);
		if (register_write_count !== 1 || last_register_num !== 6'd7) begin
			$fatal(1, "port#2 write: port#1 2nd byte was not a register write (count=%0d num=%0d)", register_write_count, last_register_num);
		end
		expect_backdrop(8'h77, "port#2 write");
		access_io(3'd2, 1'b1, 8'h07);
		expect_palette9938(4'd1, 8'h77, 8'h07, "palette after port#1 register write");

		$display("[test006] Port#3 write keeps pending port#1 and replaces its data");
		write_register(6'd17, 8'h87);
		access_io(3'd1, 1'b1, 8'h9A);
		access_io(3'd3, 1'b1, 8'h0B);
		expect_backdrop(8'h0B, "port#3 indirect R#7");
		access_io(3'd1, 1'b1, 8'h86);
		if (reg_sprite_pattern_generator_table_base !== 7'h0B) begin
			$fatal(1, "port#3 write: R#6 expected 0B, got %02X", reg_sprite_pattern_generator_table_base);
		end
		$display("-- port#3 write: OK");

		$display("[test007] Port#1 1st byte replaces pending palette R/B");
		write_register(6'd16, 8'h03);
		palette_write_count = 0;
		access_io(3'd2, 1'b1, 8'h12);
		access_io(3'd1, 1'b1, 8'h34);
		access_io(3'd1, 1'b1, 8'h87);
		expect_backdrop(8'h34, "R#7 between palette bytes");
		if (palette_write_count !== 0) $fatal(1, "R#7 write completed a palette entry");
		access_io(3'd2, 1'b1, 8'h05);
		expect_palette9938(4'd3, 8'h34, 8'h05, "palette R/B from port#1 1st byte");

		$display("[test008] Port#3 write replaces pending palette R/B");
		access_io(3'd2, 1'b1, 8'h11);
		access_io(3'd3, 1'b1, 8'h62);
		expect_backdrop(8'h62, "port#3 R#7 between palette bytes");
		access_io(3'd2, 1'b1, 8'h03);
		expect_palette9938(4'd4, 8'h62, 8'h03, "palette R/B from port#3");

		$display("[test009] R#16 write restarts palette byte counter");
		access_io(3'd2, 1'b1, 8'h70);
		write_register(6'd16, 8'h05);
		access_io(3'd2, 1'b1, 8'h21);
		if (palette_write_count !== 0) $fatal(1, "palette completed right after R#16 write");
		access_io(3'd2, 1'b1, 8'h04);
		expect_palette9938(4'd5, 8'h21, 8'h04, "palette after R#16 write");

		$display("[test010] Status read does not reset palette byte counter");
		access_io(3'd2, 1'b1, 8'h56);
		access_io(3'd1, 1'b0, 8'h00);
		access_io(3'd2, 1'b1, 8'h01);
		expect_palette9938(4'd6, 8'h56, 8'h01, "palette across status read");

		$display("[test011] Extended palette keeps its own byte counter");
		access_io(3'd4, 1'b1, 8'h00);
		write_register(6'd20, 8'h10);
		if (reg_ext_palette_mode !== 1'b1) $fatal(1, "extended palette mode was not enabled");
		write_register(6'd16, 8'h40);
		access_io(3'd2, 1'b1, 8'h1F);
		access_io(3'd1, 1'b1, 8'h55);
		access_io(3'd2, 1'b1, 8'h0A);
		access_io(3'd3, 1'b1, 8'h66);
		access_io(3'd2, 1'b1, 8'h03);
		expect_palette(8'h40, 5'h1F, 5'h0A, 5'h03, "extended palette unaffected by data latch");
		access_io(3'd1, 1'b1, 8'h87);
		expect_backdrop(8'h66, "port#1 pair across extended palette");

		$display("[test012] R#16 write restarts extended palette byte counter");
		access_io(3'd2, 1'b1, 8'h01);
		access_io(3'd2, 1'b1, 8'h02);
		write_register(6'd16, 8'h41);
		access_io(3'd2, 1'b1, 8'h02);
		access_io(3'd2, 1'b1, 8'h03);
		if (palette_write_count !== 0) $fatal(1, "extended palette completed right after R#16 write");
		access_io(3'd2, 1'b1, 8'h04);
		expect_palette(8'h41, 5'h02, 5'h03, 5'h04, "extended palette after R#16 write");

		$display("[test013] SPS writes require V58=0 and Lock=0");
		write_register(6'd25, 8'hDB);
		if (reg_sprite_priority_shuffle !== 1'b0 ||
		    {reg_command_enable, reg_yae_mode, reg_yjk_mode, reg_left_mask, reg_scroll_planes} !== 5'b11111)
			$fatal(1, "V58=1 must block SPS without blocking the standard R#25 bits");
		write_register(6'd21, 8'h00);
		write_register(6'd25, 8'h80);
		if (reg_sprite_priority_shuffle !== 1'b1) $fatal(1, "Unlocked V9968 mode did not set SPS");
		access_io(3'd4, 1'b1, 8'h80);
		write_register(6'd25, 8'h5B);
		if (reg_sprite_priority_shuffle !== 1'b1 ||
		    {reg_command_enable, reg_yae_mode, reg_yjk_mode, reg_left_mask, reg_scroll_planes} !== 5'b11111)
			$fatal(1, "Lock must preserve SPS while allowing the standard R#25 bits");
		access_io(3'd4, 1'b1, 8'h00);
		write_register(6'd21, 8'h01);
		write_register(6'd25, 8'h00);
		if (reg_sprite_priority_shuffle !== 1'b1) $fatal(1, "V58=1 changed SPS");
		write_register(6'd21, 8'h00);
		write_register(6'd25, 8'h00);
		if (reg_sprite_priority_shuffle !== 1'b0) $fatal(1, "Unlocked V9968 mode did not clear SPS");
		access_io(3'd4, 1'b1, 8'h80);
		write_register(6'd25, 8'h80);
		if (reg_sprite_priority_shuffle !== 1'b0) $fatal(1, "Lock allowed SPS to be set");

		$display("Port#1 latch reset test PASSED");
		$finish;
	end
endmodule
