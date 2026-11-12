// -----------------------------------------------------------------------------
//	Test of vdp_sprite_select_visible_planes.v
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

	// Clock and reset
	reg					reset_n;
	reg					clk;					//	85.90908MHz

	// Input signals
	reg			[13:0]	screen_pos_x;
	reg			[ 8:0]	screen_pos_y;
	reg			[ 7:0]	pixel_pos_y;
	reg					screen_v_active;
	reg					screen_display_v_active;
	reg					screen_h_active;
	reg			[31:0]	vram_rdata;
	reg					vram_interleave;
	reg					sprite_mode2;
	reg					reg_display_on;
	reg					reg_sprite_disable;
	reg					reg_sprite_magify;
	reg					reg_sprite_16x16;
	reg			[17:7]	reg_sprite_attribute_table_base;
	reg					reg_sprite_nonR23_mode;
	reg					reg_sprite_mode3;
	reg					reg_sprite16_mode;
	reg					reg_sprite_priority_shuffle;
	reg					clear_sprite_overmap;
	reg					sprite_overmap_enable;
	reg					clear_sprite_collision;

	// Output signals
	wire		[17:0]	vram_address;
	wire				vram_valid;
	wire				selected_en;
	wire		[5:0]	selected_plane_num;
	wire		[31:0]	selected_attribute;
	wire		[4:0]	selected_count;
	wire		[8:0]	selected_pixel_pos_y;
	wire				start_info_collect;
	wire				sprite_overmap;
	wire		[4:0]	sprite_overmap_id;

	// VRAM simulation
	reg			[31:0]	sprite_attr_table [0:31];
	integer				i;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	vdp_sprite_select_visible_planes u_sprite_select_visible_planes (
		.reset_n						( reset_n							),
		.clk							( clk								),
		.screen_pos_x					( screen_pos_x						),
		.screen_pos_y					( screen_pos_y						),
		.pixel_pos_y					( pixel_pos_y						),
		.screen_v_active				( screen_v_active					),
		.screen_display_v_active		( screen_display_v_active			),
		.screen_h_active				( screen_h_active					),
		.vram_address					( vram_address						),
		.vram_valid						( vram_valid						),
		.vram_rdata						( vram_rdata						),
		.vram_interleave				( vram_interleave					),
		.selected_en					( selected_en						),
		.selected_plane_num				( selected_plane_num				),
		.selected_attribute				( selected_attribute				),
		.selected_count					( selected_count					),
		.selected_pixel_pos_y		( selected_pixel_pos_y				),
		.start_info_collect			( start_info_collect				),
		.clear_sprite_overmap			( clear_sprite_overmap				),
		.sprite_overmap_enable		( sprite_overmap_enable			),
		.sprite_overmap					( sprite_overmap					),
		.sprite_overmap_id				( sprite_overmap_id					),
		.clear_sprite_collision			( clear_sprite_collision			),
		.sprite_mode2					( sprite_mode2						),
		.reg_display_on					( reg_display_on					),
		.reg_sprite_disable				( reg_sprite_disable				),
		.reg_sprite_magify				( reg_sprite_magify					),
		.reg_sprite_16x16				( reg_sprite_16x16					),
		.reg_sprite_attribute_table_base( reg_sprite_attribute_table_base	),
		.reg_sprite_nonR23_mode			( reg_sprite_nonR23_mode			),
		.reg_sprite_mode3				( reg_sprite_mode3					),
		.reg_sprite16_mode				( reg_sprite16_mode					),
		.reg_sprite_priority_shuffle	( reg_sprite_priority_shuffle		)
	);

	// --------------------------------------------------------------------
	//	VRAM simulation
	// --------------------------------------------------------------------
	integer			mid_change_x = -1;
	reg		[7:0]	mid_change_y = 8'd0;

	always @( posedge clk ) begin
		if( vram_valid ) begin
			if( vram_interleave ) begin
				if( vram_address[0] ) begin
					vram_rdata <= {
						sprite_attr_table[{vram_address[6:3], 1'b1}][31:24],
						sprite_attr_table[{vram_address[6:3], 1'b1}][15:8],
						sprite_attr_table[{vram_address[6:3], 1'b0}][31:24],
						sprite_attr_table[{vram_address[6:3], 1'b0}][15:8]
					};
				end
				else begin
					vram_rdata <= {
						sprite_attr_table[{vram_address[6:3], 1'b1}][23:16],
						sprite_attr_table[{vram_address[6:3], 1'b1}][7:0],
						sprite_attr_table[{vram_address[6:3], 1'b0}][23:16],
						sprite_attr_table[{vram_address[6:3], 1'b0}][7:0]
					};
				end
			end
			else begin
				vram_rdata <= sprite_attr_table[vram_address[6:2]];
			end
		end
	end

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	Test task
	// --------------------------------------------------------------------
	task automatic wait_cycles;
		input integer cycles;
		begin
			repeat( cycles ) @( posedge clk );
		end
	endtask

	task automatic initialize_sprite_table;
		begin
			// Initialize sprite attribute table
			for( i = 0; i < 32; i = i + 1 ) begin
				sprite_attr_table[i] = 32'h000000D8;
			end
			
			// Set up some test sprites
			// Format: [31:24]=color, [23:16]=pattern, [15:8]=x, [7:0]=y
			sprite_attr_table[0]  = 32'h0F1040CF;  // y=207, x=64,  pattern=16, color=15 (visible at 208)
			sprite_attr_table[1]  = 32'h0E2050D7;  // y=215, x=80,  pattern=32, color=14 (visible at 216)
			sprite_attr_table[2]  = 32'h0D3060E0;  // y=224, x=96,  pattern=48, color=13 (not visible)
			sprite_attr_table[3]  = 32'h0C4070BF;  // y=191, x=112, pattern=64, color=12 (visible at 192)
			sprite_attr_table[4]  = 32'h0B5080CF;  // y=207, x=128, pattern=80, color=11 (visible at 208)
		end
	endtask

	task automatic simulate_scanline;
		input [7:0] scan_y;
		input [31:0] expected_planes;
		integer scan_x;
		reg [31:0] observed_planes;
		begin
			observed_planes = 32'd0;
			//	In the real SSG, pixel_pos_y is already updated when screen_pos_x == 3FFF.
			pixel_pos_y = scan_y;
			screen_pos_x = 14'h3FFF;
			wait_cycles(1);
			#1;
			if( selected_pixel_pos_y !== { 1'b0, scan_y } ) begin
				$fatal(1, "Latched pixel Y mismatch: expected %03X, observed %03X", { 1'b0, scan_y }, selected_pixel_pos_y);
			end
			screen_pos_x = 14'd0;
			screen_v_active = 1'b1;
			screen_h_active = 1'b1;
			
			$display("=== Scanning line Y=%d ===", scan_y);
			
			// Simulate horizontal scan (sprite collection phase)
			for( scan_x = 0; scan_x < 4352; scan_x = scan_x + 1 ) begin
				@( posedge clk );
				
				// Monitor sprite selection
				if( selected_en ) begin
					$display("  Sprite selected: plane=%d, y_offset=%d, x=%d, pattern=%02X, color=%02X, count=%d",
						selected_plane_num, selected_attribute[7:0], selected_attribute[15:8], selected_attribute[23:16], selected_attribute[31:24], selected_count);
					if( selected_plane_num >= 32 || observed_planes[selected_plane_num] ) begin
						$fatal(1, "Unexpected or duplicate sprite plane %d at Y=%d", selected_plane_num, scan_y);
					end
					if( vram_interleave && selected_attribute[31:24] !== sprite_attr_table[selected_plane_num][31:24] ) begin
						$fatal(1, "Interleaved plane %0d lost attribute+3: expected %02X, got %02X",
							selected_plane_num, sprite_attr_table[selected_plane_num][31:24], selected_attribute[31:24]);
					end
					observed_planes[selected_plane_num] = 1'b1;
				end
				
				if( start_info_collect ) begin
					$display("  Info collection phase started");
				end
				#1;
				screen_pos_x = scan_x + 14'd1;
				if( scan_x == mid_change_x ) begin
					//	R#23 rewritten by the CPU in the middle of the plane scan
					pixel_pos_y = mid_change_y;
					if( selected_pixel_pos_y !== { 1'b0, scan_y } ) begin
						$fatal(1, "Latched pixel Y changed during scan: expected %03X, observed %03X", { 1'b0, scan_y }, selected_pixel_pos_y);
					end
				end
			end
			
			screen_pos_x = 14'h3FFF;
			screen_h_active = 1'b0;
			if( observed_planes !== expected_planes ) begin
				$fatal(1, "Y=%d: expected planes %08X, observed %08X", scan_y, expected_planes, observed_planes);
			end
			wait_cycles(10);
			#1;
		end
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		$display("=== VDP Sprite Select Visible Planes Test ===");
		
		// Initialize signals
		clk = 1'b0;
		reset_n = 1'b0;
		screen_pos_x = 14'd0;
		screen_pos_y = 9'd0;
		pixel_pos_y = 8'd0;
		screen_v_active = 1'b0;
		screen_display_v_active = 1'b1;
		screen_h_active = 1'b0;
		vram_rdata = 32'd0;
		vram_interleave = 1'b0;
		sprite_mode2 = 1'b1;
		reg_display_on = 1'b1;
		reg_sprite_disable = 1'b0;
		reg_sprite_magify = 1'b0;
		reg_sprite_16x16 = 1'b0;
		reg_sprite_attribute_table_base = 11'h1F8;
		reg_sprite_nonR23_mode = 1'b0;
		reg_sprite_mode3 = 1'b0;
		reg_sprite16_mode = 1'b0;
		reg_sprite_priority_shuffle = 1'b0;
		clear_sprite_overmap = 1'b0;
		sprite_overmap_enable = 1'b1;
		clear_sprite_collision = 1'b0;

		// Initialize sprite table
		initialize_sprite_table();

		// Reset sequence
		wait_cycles(10);
		reset_n = 1'b1;
		wait_cycles(10);

		$display("=== Test 1: Normal 8x8 sprites ===");
		reg_sprite_16x16 = 1'b0;
		reg_sprite_magify = 1'b0;
		
		// Test scanlines with different Y positions
		simulate_scanline(8'd208, 32'h00000011);
		simulate_scanline(8'd216, 32'h00000002);
		simulate_scanline(8'd192, 32'h00000008);
		simulate_scanline(8'd100, 32'h00000000);

		$display("=== Test 2: Magnified 8x8 sprites ===");
		reg_sprite_magify = 1'b1;
		
		simulate_scanline(8'd208, 32'h00000011);

		$display("=== Test 3: 16x16 sprites ===");
		reg_sprite_16x16 = 1'b1;
		reg_sprite_magify = 1'b0;
		
		simulate_scanline(8'd208, 32'h00000011);

		$display("=== Test 4: 16x16 magnified sprites ===");
		reg_sprite_16x16 = 1'b1;
		reg_sprite_magify = 1'b1;
		
		simulate_scanline(8'd208, 32'h00000019);

		$display("=== Test 5: Overmap limited to display lines ===");
		sprite_mode2 = 1'b0;
		reg_sprite_16x16 = 1'b0;
		reg_sprite_magify = 1'b0;
		for( i = 0; i < 32; i = i + 1 ) begin
			sprite_attr_table[i] = 32'h000000D0;
		end
		for( i = 0; i < 5; i = i + 1 ) begin
			sprite_attr_table[i] = { 8'h0F, 8'd0, 8'd64, 8'd39 };
		end
		screen_display_v_active = 1'b0;
		simulate_scanline(8'd40, 32'h0000000F);
		if( sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd31 ) begin
			$fatal(1, "Overmap outside display: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		screen_display_v_active = 1'b1;
		simulate_scanline(8'd40, 32'h0000000F);
		if( sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4 ) begin
			$fatal(1, "Overmap inside display: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		clear_sprite_overmap = 1'b1;
		wait_cycles(1);
		#1;
		clear_sprite_overmap = 1'b0;
		if( sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd4 ) begin
			$fatal(1, "Overmap clear: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		simulate_scanline(8'd40, 32'h0000000F);
		if( sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd4 ) begin
			$fatal(1, "Overmap re-detection: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		$display("=== Test 6: First overmap line keeps its plane ID ===");
		clear_sprite_overmap = 1'b1;
		wait_cycles(1);
		#1;
		clear_sprite_overmap = 1'b0;
		for( i = 0; i < 32; i = i + 1 ) begin
			sprite_attr_table[i] = 32'h000000D0;
		end
		for( i = 0; i < 5; i = i + 1 ) begin
			sprite_attr_table[i] = { 8'h0F, 8'd0, 8'd64, 8'd79 };
		end
		sprite_attr_table[5] = 32'h00000078;
		for( i = 6; i <= 10; i = i + 1 ) begin
			sprite_attr_table[i] = { 8'h0F, 8'd0, 8'd64, 8'd39 };
		end
		simulate_scanline(8'd40, 32'h000003C0);
		if( sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd10 ) begin
			$fatal(1, "First overmap line: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		simulate_scanline(8'd80, 32'h0000000F);
		if( sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd10 ) begin
			$fatal(1, "Later line changed first overmap ID: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		$display("=== Test 7: Frame interrupt masks overmap detection ===");
		clear_sprite_overmap = 1'b1;
		wait_cycles(1);
		#1;
		clear_sprite_overmap = 1'b0;
		sprite_overmap_enable = 1'b0;
		simulate_scanline(8'd40, 32'h000003C0);
		if( sprite_overmap !== 1'b0 || sprite_overmap_id !== 5'd10 ) begin
			$fatal(1, "Overmap detected while F is set: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end
		sprite_overmap_enable = 1'b1;
		simulate_scanline(8'd40, 32'h000003C0);
		if( sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd10 ) begin
			$fatal(1, "Overmap not detected after F clear: overmap=%b id=%d", sprite_overmap, sprite_overmap_id);
		end

		$display("=== Test 8: Only planes 0-31 can cause overmap in modes 1/2 ===");
		for( i = 0; i < 2; i = i + 1 ) begin
			sprite_mode2 = (i != 0);
			clear_sprite_overmap = 1'b1;
			wait_cycles(1);
			#1;
			clear_sprite_overmap = 1'b0;
			for( integer plane = 0; plane < 32; plane = plane + 1 ) begin
				sprite_attr_table[plane] = 32'h00000078;
			end
			for( integer plane = 0; plane < (sprite_mode2 ? 8 : 4); plane = plane + 1 ) begin
				sprite_attr_table[plane] = { 8'h0F, 8'd0, 8'd64, 8'd39 };
			end
			simulate_scanline(8'd40, sprite_mode2 ? 32'h000000FF : 32'h0000000F);
			if( sprite_overmap !== 1'b0 ) begin
				$fatal(1, "Mode %0d: plane 32 or later was treated as extra sprite (id=%d)", i + 1, sprite_overmap_id);
			end
			clear_sprite_overmap = 1'b1;
			wait_cycles(1);
			#1;
			clear_sprite_overmap = 1'b0;
			for( integer plane = 0; plane < (sprite_mode2 ? 8 : 4); plane = plane + 1 ) begin
				sprite_attr_table[plane] = { 8'h0F, 8'd0, 8'd64, 8'd39 };
			end
			sprite_attr_table[31] = { 8'h0F, 8'd0, 8'd64, 8'd39 };
			simulate_scanline(8'd40, sprite_mode2 ? 32'h000000FF : 32'h0000000F);
			if( sprite_overmap !== 1'b1 || sprite_overmap_id !== 5'd31 ) begin
				$fatal(1, "Mode %0d: plane 31 was not detected as fifth sprite (overmap=%b id=%d)", i + 1, sprite_overmap, sprite_overmap_id);
			end
		end

		$display("=== Test 9: SpriteMode3 still reports overmap ===");
		clear_sprite_overmap = 1'b1;
		wait_cycles(1);
		#1;
		clear_sprite_overmap = 1'b0;
		reg_sprite_mode3 = 1'b1;
		for( i = 0; i < 32; i = i + 1 ) begin
			sprite_attr_table[i] = 32'h00000028;
		end
		simulate_scanline(8'd40, 32'h0000FFFF);
		if( sprite_overmap !== 1'b1 ) begin
			$fatal(1, "SpriteMode3 overflow flag not set");
		end

		$display("=== Test 10: R#23 change during plane scan does not mix lines ===");
		//	Dragon Quest II title: 16x16 sprites, 8 planes on Y=1F row and 8 planes on Y=2F row.
		//	Changing the line from 2Fh to 30h between plane 1 and plane 2 used to see 10 planes.
		clear_sprite_overmap = 1'b1;
		wait_cycles(1);
		#1;
		clear_sprite_overmap = 1'b0;
		reg_sprite_mode3 = 1'b0;
		sprite_mode2 = 1'b1;
		reg_sprite_16x16 = 1'b1;
		reg_sprite_magify = 1'b0;
		for( i = 0; i < 32; i = i + 1 ) begin
			sprite_attr_table[i] = 32'h000000D8;
		end
		sprite_attr_table[0]  = 32'h0000581F;	sprite_attr_table[1]  = 32'h0000681F;
		sprite_attr_table[2]  = 32'h0000582F;	sprite_attr_table[3]  = 32'h0000682F;
		sprite_attr_table[4]  = 32'h0000583F;	sprite_attr_table[5]  = 32'h0000683F;
		sprite_attr_table[6]  = 32'h0000781F;	sprite_attr_table[7]  = 32'h0000881F;
		sprite_attr_table[8]  = 32'h0000782F;	sprite_attr_table[9]  = 32'h0000882F;
		sprite_attr_table[10] = 32'h0000883F;	sprite_attr_table[11] = 32'h0000581F;
		sprite_attr_table[12] = 32'h0000681F;	sprite_attr_table[13] = 32'h0000582F;
		sprite_attr_table[14] = 32'h0000682F;	sprite_attr_table[15] = 32'h0000583F;
		sprite_attr_table[16] = 32'h0000683F;	sprite_attr_table[17] = 32'h0000781F;
		sprite_attr_table[18] = 32'h0000881F;	sprite_attr_table[19] = 32'h0000782F;
		sprite_attr_table[20] = 32'h0000882F;
		sprite_attr_table[21] = 32'h000000D8;
		mid_change_x = 14'd128 * 2 + 14'd64;
		mid_change_y = 8'h2F;
		simulate_scanline(8'h2E, 32'h000618C3);
		mid_change_x = -1;
		if( sprite_overmap !== 1'b0 ) begin
			$fatal(1, "R#23 change mixed lines and set overmap (id=%d)", sprite_overmap_id);
		end

		$display("=== Test 11: non-R#23 mode latches screen Y for plane selection ===");
		reg_sprite_nonR23_mode = 1'b1;
		screen_pos_y = 9'h123;
		pixel_pos_y = 8'h55;
		screen_pos_x = 14'h3FFF;
		wait_cycles(1);
		#1;
		if( selected_pixel_pos_y !== 9'h123 ) begin
			$fatal(1, "Non-R#23 pixel Y mismatch: expected 123, observed %03X", selected_pixel_pos_y);
		end

		$display("=== Test 12: interleaved SpriteMode2 retains attribute+3 ===");
		reg_sprite_nonR23_mode = 1'b0;
		reg_sprite_16x16 = 1'b0;
		vram_interleave = 1'b1;
		for( i = 0; i < 32; i = i + 1 ) begin
			sprite_attr_table[i] = 32'h000000D8;
		end
		sprite_attr_table[0] = { 8'hA5, 8'h10, 8'd64, 8'd39 };
		sprite_attr_table[1] = { 8'h3B, 8'h20, 8'd80, 8'd39 };
		simulate_scanline(8'd40, 32'h00000003);

		$display("=== Test completed ===");
		$finish;
	end

	// --------------------------------------------------------------------
	//	Monitor
	// --------------------------------------------------------------------
	initial begin
		$dumpfile("wave.vcd");
		$dumpvars(0, tb);
	end

endmodule
