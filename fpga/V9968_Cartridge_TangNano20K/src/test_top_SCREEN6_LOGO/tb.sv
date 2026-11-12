// -----------------------------------------------------------------------------
//	Test of vdp.v (MSX2+ boot logo: comb scroll synchronized by sprite collision)
//	Copyright (C)2026 Takayuki Hara (HRA!)
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
//	MSX2+ の起動ロゴ (MSX0KDR.ROM 7A00h-7AB1h, 7ADAh-7B44h) の CPU アクセス列を
//	Z80 の T ステート単位で再現し、スプライト衝突 → S#0 読み出し → R#26/R#27 書き込み
//	→ 実効 R#26/R#27 ラッチの相対時刻をラインごとに記録する。
//
//	・CPU 1T = VDP 24 クロック (3.579545MHz : 85.90908MHz)。実機も clk14m から PLL で
//	  VDP クロックを作るため同期している。
//	・MSX の M1 ウェイト (+1T / M1) と Z80 I/O の自動ウェイト、スロットの WAIT を反映する。
//	・ロゴ本体の描画 (VDP コマンド) は省略する。衝突判定用スプライトのみ配置する。
//
//	期待値: 走査線 N の衝突に応答して書いた {R#26, R#27} が、走査線 N+apply_line (既定 2) の
//	実効値になること。実効値のラッチは R#26/R#27 同時、固定位置 X=267 (timing.md)。
//	表示期間中に実効値が変化した場合は MIDLINE として数える。
//	判定:
//		OK        ... 期待値どおり
//		STALE     ... R#26/R#27 とも 1 つ前の書き込み値 (反対側の帯の値)
//		MIX_R27   ... R#26 は新しいが R#27 が古い
//		MIX_R26   ... R#27 は新しいが R#26 が古い
//		OTHER     ... 上記以外
//	結果は logo_lines.csv に出力する。
// --------------------------------------------------------------------

`define SSG		tb.u_vdp_cartridge.u_v9968.u_timing_control.u_ssg
`define CPUIF	tb.u_vdp_cartridge.u_v9968.u_cpu_interface
`define MKP		tb.u_vdp_cartridge.u_v9968.u_timing_control.u_sprite.u_makeup_pixel

module tb ();
	//	VDP クロックは 12ns とし、CPU 1T = 24 クロックの比率だけを実機に合わせる
	localparam integer	clk_half		= 6;
	localparam integer	t_clocks		= 24;

	localparam [7:0]	vdp_io0			= 8'h88;
	localparam [7:0]	vdp_io1			= vdp_io0 + 8'h01;
	localparam [7:0]	vdp_io2			= vdp_io0 + 8'h02;
	localparam [7:0]	vdp_io3			= vdp_io0 + 8'h03;

	//	ロゴは 50 フレーム。シミュレーションする範囲を -g で指定する
	parameter integer	first_frame		= 0;
	parameter integer	num_frames		= 8;
	integer				cur_frame		= -1;
	//	CPU と VDP の位相 (VDP クロック単位, 0-23)
	parameter integer	cpu_phase		= 0;
	//	走査線 N の衝突に応答した書き込みを期待する走査線 (N + apply_line)
	parameter integer	apply_line		= 2;

	reg				clk_dummy;
	reg				clk14m;
	reg				slot_reset_n;
	reg				slot_iorq_n;
	reg				slot_rd_n;
	reg				slot_wr_n;
	wire			slot_wait;
	wire			slot_intr;
	wire			slot_data_dir;
	reg		[7:0]	slot_a;
	wire	[7:0]	slot_d;
	wire			oe_n;
	reg		[1:0]	dipsw;
	wire			ws2812_led;
	reg		[1:0]	button;

	wire			tmds_clk_p;
	wire	[2:0]	tmds_d_p;

	wire			O_sdram_clk;
	wire			O_sdram_cke;
	wire			O_sdram_cs_n;
	wire			O_sdram_ras_n;
	wire			O_sdram_cas_n;
	wire			O_sdram_wen_n;
	wire	[31:0]	IO_sdram_dq;
	wire	[10:0]	O_sdram_addr;
	wire	[ 1:0]	O_sdram_ba;
	wire	[ 3:0]	O_sdram_dqm;

	reg		[7:0]	ff_slot_data;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	tangnano20k_vdp_cartridge u_vdp_cartridge (
		.clk					( clk_dummy				),
		.clk14m					( clk14m				),
		.slot_reset_n			( slot_reset_n			),
		.slot_iorq_n			( slot_iorq_n			),
		.slot_rd_n				( slot_rd_n				),
		.slot_wr_n				( slot_wr_n				),
		.slot_wait				( slot_wait				),
		.slot_intr				( slot_intr				),
		.slot_data_dir			( slot_data_dir			),
		.slot_a					( slot_a				),
		.slot_d					( slot_d				),
		.oe_n					( oe_n					),
		.dipsw					( dipsw					),
		.ws2812_led				( ws2812_led			),
		.button					( button				),
		.tmds_clk_p				( tmds_clk_p			),
		.tmds_d_p				( tmds_d_p				),
		.O_sdram_clk			( O_sdram_clk			),
		.O_sdram_cke			( O_sdram_cke			),
		.O_sdram_cs_n			( O_sdram_cs_n			),
		.O_sdram_ras_n			( O_sdram_ras_n			),
		.O_sdram_cas_n			( O_sdram_cas_n			),
		.O_sdram_wen_n			( O_sdram_wen_n			),
		.IO_sdram_dq			( IO_sdram_dq			),
		.O_sdram_addr			( O_sdram_addr			),
		.O_sdram_ba				( O_sdram_ba			),
		.O_sdram_dqm			( O_sdram_dqm			)
	);

	assign slot_d	= slot_data_dir ? 8'hZZ : ff_slot_data;

	always #(clk_half) begin
		clk14m <= ~clk14m;
	end

	mt48lc2m32b2 u_sdram (
		.Dq					( IO_sdram_dq				), 
		.Addr				( O_sdram_addr				), 
		.Ba					( O_sdram_ba				), 
		.Clk				( O_sdram_clk				), 
		.Cke				( O_sdram_cke				), 
		.Cs_n				( O_sdram_cs_n				), 
		.Ras_n				( O_sdram_ras_n				), 
		.Cas_n				( O_sdram_cas_n				), 
		.We_n				( O_sdram_wen_n				), 
		.Dqm				( O_sdram_dqm				)
	);

	// --------------------------------------------------------------------
	//	Monitor
	// --------------------------------------------------------------------
	longint				vclk = 0;
	always @( posedge clk14m ) begin
		vclk <= vclk + 1;
	end

	wire	[13:0]	m_sx		= `SSG.ff_screen_pos_x;
	wire	[ 9:0]	m_sy		= `SSG.ff_screen_pos_y;
	wire	[13:0]	m_wx		= `SSG.w_screen_pos_x;
	wire	[ 2:0]	m_eff_l		= `SSG.horizontal_offset_l;
	//	R#26/R#27 はラッチしない。R#26 が効き始める BG の VRAM 読み出し開始 (X=-1/F) を基準点として記録する
	wire			m_latch_l	= (m_wx == { 10'h3FF, 4'hF });
	wire			m_latch_h	= m_latch_l;

	//	MSK で隠れない表示期間中 (X=8..255) に R#26/R#27 が変化したら数える
	integer			n_midline;
	reg		[ 8:0]	ff_m_eff;
	always @( posedge clk14m ) begin
		ff_m_eff <= { `SSG.horizontal_offset_h, `SSG.horizontal_offset_l };
		if( !m_sx[13] && m_sx[13:4] >= 10'd8 && m_sx[13:4] < 10'd256 && m_sy < 10'd192 &&
			ff_m_eff != { `SSG.horizontal_offset_h, `SSG.horizontal_offset_l } ) begin
			n_midline++;
			$display( "[LOGO] frame%0d line%0d MIDLINE: effective R#26/R#27 changed at x=%0d", cur_frame, m_sy, dot( m_sx ) );
		end
	end

	function automatic integer dot( input [13:0] x );
		dot = $signed( x[13:4] );
	endfunction

	// --------------------------------------------------------------------
	//	画素照合: VRAM に乱数パターンを直接書き込み、BG 出力 (2bit/hires 画素) が
	//	実効スクロール量どおりの位置から読まれているかを走査線ごとに確かめる。
	//	一致位置 s と 2*スクロール量 の差 (パイプライン定数) が全ラインで一定なら正常。
	// --------------------------------------------------------------------
	`define SCRN	tb.u_vdp_cartridge.u_v9968.u_timing_control.u_screen_mode
	localparam integer	c_pix_x0	= 24;
	localparam integer	c_pix_x1	= 232;
	byte unsigned	vram_img	[0:65535];
	bit		[1:0]	pix_cap		[0:1023];
	integer			pix_n		= 0;
	bit				pix_enable	= 0;
	integer			pix_c0		= -1;
	integer			n_pix_ok	= 0;
	integer			n_pix_ng	= 0;
	integer			n_pix_none	= 0;
	integer			pix_sc		= -1;

	function automatic [1:0] ring_px( input integer y, input integer j );
		integer a;
		a			= ( (j >> 9) & 1 ) * 32'h8000 + y * 128 + ( (j & 511) >> 2 );
		ring_px		= ( vram_img[a] >> ( 6 - 2 * (j & 3) ) ) & 2'd3;
	endfunction

	task automatic pix_check( input integer y, input integer sc );
		integer s, i, found, n_found, c;
		bit ok;
		n_found = 0;
		found	= -1;
		for( s = 0; s < 1024; s++ ) begin
			ok = 1;
			for( i = 0; i < pix_n; i++ ) begin
				if( ring_px( y, (s + i) & 1023 ) != pix_cap[i] ) begin
					ok = 0;
					break;
				end
			end
			if( ok ) begin
				if( n_found == 0 ) found = s;
				n_found++;
			end
		end
		if( n_found != 1 ) begin
			n_pix_none++;
			$display( "[PIX] frame%0d line%0d: no unique match (%0d candidates)", cur_frame, y, n_found );
			return;
		end
		c = ( found - 2 * sc ) & 1023;
		if( pix_c0 < 0 ) begin
			pix_c0 = c;
			$display( "[PIX] pipeline constant = %0d (frame%0d line%0d)", c, cur_frame, y );
		end
		if( c == pix_c0 ) begin
			n_pix_ok++;
		end
		else begin
			n_pix_ng++;
			$display( "[PIX] frame%0d line%0d NG: scroll=%0d drawn_at=%0d (diff %0d hires px)",
				cur_frame, y, sc, (found - pix_c0) & 1023, $signed( ((c - pix_c0 + 512) & 1023) - 512 ) );
		end
	endtask

	always @( posedge clk14m ) begin
		if( pix_enable && cur_frame >= 0 && !m_sx[13] && m_sy < 10'd192 ) begin
			if( m_sx == { 10'd0, 4'd0 } ) begin
				pix_n = 0;
			end
			else if( dot( m_sx ) >= c_pix_x0 && dot( m_sx ) < c_pix_x1 && (m_sx[3:0] == 4'd3 || m_sx[3:0] == 4'd11) ) begin
				pix_cap[ pix_n ] = `SCRN.ff_display_color[1:0];
				pix_n++;
			end
			else if( m_sx == { 10'd128, 4'd0 } ) begin
				pix_sc = scroll_of( `SSG.horizontal_offset_h, `SSG.horizontal_offset_l );
			end
			else if( m_sx == { 10'd240, 4'd0 } ) begin
				if( pix_sc >= 0 ) pix_check( m_sy, pix_sc );
				pix_sc = -1;
			end
		end
	end

	task automatic pix_fill_vram;
		integer a, p, w;
		byte unsigned v;
		for( p = 0; p < 2; p++ ) begin
			for( a = 0; a < 212 * 128; a++ ) begin
				w = p * 32'h8000 + a;
				v = $urandom;
				vram_img[w] = v;
				tb.u_sdram.Bank0[ w >> 2 ][ 8 * (w & 3) +: 8 ] = v;
			end
		end
	endtask

	function automatic integer scroll_of( input [5:0] h, input [2:0] l );
		scroll_of = h * 8 - l;
	endfunction

	function automatic integer wrap512( input integer v );
		integer r;
		r = v % 512;
		if( r < 0 ) r = r + 512;
		if( r >= 256 ) r = r - 512;
		wrap512 = r;
	endfunction

	//	直近のイベント
	longint			last_coll_t;
	integer			last_coll_y;
	integer			last_coll_x;
	longint			last_w26_t;
	integer			last_w26_y, last_w26_x;
	longint			last_w27_t;
	integer			last_w27_y, last_w27_x;

	//	走査線ごとの記録 (index = 期待値を適用すべき走査線)
	bit				exp_valid	[0:1023];
	bit		[5:0]	exp_h		[0:1023];
	bit		[2:0]	exp_l		[0:1023];
	bit		[5:0]	old_h		[0:1023];
	bit		[2:0]	old_l		[0:1023];
	longint			coll_t		[0:1023];
	integer			coll_x		[0:1023];
	longint			cread_t		[0:1023];
	longint			w26_t		[0:1023];
	longint			w27_t		[0:1023];
	integer			w27_x		[0:1023];
	integer			latch_cnt	[0:1023];
	longint			latch_t		[0:1023];
	longint			latch_h_t	[0:1023];
	integer			latch_x		[0:1023];
	integer			w26_x_min, w26_x_max, w27_x_min, w27_x_max;

	integer			cur_scroll;
	integer			fd;

	integer			n_ok, n_stale, n_mix27, n_mix26, n_other, n_late, n_double;
	integer			f_ok, f_stale, f_mix27, f_mix26, f_other, f_late;
	integer			min_margin27;
	integer			max_coll_to_w27;

	reg		ff_m_coll;
	always @( posedge clk14m ) begin
		ff_m_coll <= `MKP.ff_sprite_collision;
		if( `MKP.ff_sprite_collision && !ff_m_coll ) begin
			last_coll_t	= vclk;
			last_coll_y	= m_sy;
			last_coll_x	= dot( `MKP.screen_pos_x );
		end
	end

	always @( posedge clk14m ) begin
		if( `CPUIF.ff_register_write ) begin
			if( `CPUIF.ff_register_num == 6'd26 ) begin
				last_w26_t	= vclk;
				last_w26_y	= m_sy;
				last_w26_x	= dot( m_sx );
			end
			else if( `CPUIF.ff_register_num == 6'd27 ) begin
				last_w27_t	= vclk;
				last_w27_y	= m_sy;
				last_w27_x	= dot( m_sx );
			end
		end
	end

	always @( posedge clk14m ) begin
		if( m_latch_l ) begin
			if( latch_cnt[ m_sy ] == 0 ) begin
				latch_t[ m_sy ]	= vclk;
				latch_x[ m_sy ]	= dot( m_wx );
			end
			latch_cnt[ m_sy ] = latch_cnt[ m_sy ] + 1;
		end
		if( m_latch_h ) begin
			latch_h_t[ m_sy ] = vclk;
		end
	end

	//	表示中央で実効値を採取して判定する
	always @( posedge clk14m ) begin
		integer			y;
		bit		[5:0]	eff_h;
		bit		[2:0]	eff_l;
		string			verdict;
		integer			delta;
		integer			margin26, margin27, c2r, c2w27;

		if( m_sx == { 10'd128, 4'd0 } ) begin
			y		= m_sy;
			eff_h	= `SSG.horizontal_offset_h;
			eff_l	= `SSG.horizontal_offset_l;
			if( exp_valid[ y ] ) begin
				if( eff_h == exp_h[y] && eff_l == exp_l[y] ) begin
					verdict = "OK";			n_ok++;		f_ok++;
				end
				else if( eff_h == old_h[y] && eff_l == old_l[y] ) begin
					verdict = "STALE";		n_stale++;	f_stale++;
				end
				else if( eff_h == exp_h[y] && eff_l == old_l[y] ) begin
					verdict = "MIX_R27";	n_mix27++;	f_mix27++;
				end
				else if( eff_h == old_h[y] && eff_l == exp_l[y] ) begin
					verdict = "MIX_R26";	n_mix26++;	f_mix26++;
				end
				else begin
					verdict = "OTHER";		n_other++;	f_other++;
				end
				if( latch_cnt[y] > 1 ) begin
					n_double++;
				end
				delta		= wrap512( scroll_of( eff_h, eff_l ) - scroll_of( exp_h[y], exp_l[y] ) );
				margin26	= (latch_cnt[y] == 0) ? -9999 : int'( (latch_h_t[y] - w26_t[y]) ) / 16;
				margin27	= (latch_cnt[y] == 0) ? -9999 : int'( (latch_t[y] - w27_t[y]) ) / 16;
				c2r			= int'( cread_t[y] - coll_t[y] ) / t_clocks;
				c2w27		= int'( w27_t[y] - coll_t[y] ) / t_clocks;
				if( latch_cnt[y] != 0 && margin27 < min_margin27 ) min_margin27 = margin27;
				if( c2w27 > max_coll_to_w27 ) max_coll_to_w27 = c2w27;
				$fdisplay( fd, "%0d,%0d,%0d,%0d,%0d,%0d,%0d,%s,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d,%0d",
					cur_frame, cur_scroll, y, exp_h[y], exp_l[y], eff_h, eff_l, verdict, delta,
					coll_x[y], c2r, c2w27, w27_x[y], margin26, margin27, latch_cnt[y], latch_x[y] );
				if( verdict != "OK" ) begin
					$display( "[LOGO] frame%0d scroll=%0d line%0d %s exp=(%0d,%0d) eff=(%0d,%0d) delta=%0d coll_x=%0d coll->C=%0dT coll->R27=%0dT R27@x=%0d margin27=%0d dots latch=%0d@x=%0d",
						cur_frame, cur_scroll, y, verdict, exp_h[y], exp_l[y], eff_h, eff_l, delta,
						coll_x[y], c2r, c2w27, w27_x[y], margin27, latch_cnt[y], latch_x[y] );
				end
				exp_valid[y] = 1'b0;
			end
			latch_cnt[y] = 0;
		end
	end

	// --------------------------------------------------------------------
	//	Z80 bus cycle (T ステートは VDP 24 クロック。信号は VDP クロックの立ち下がりで変化)
	// --------------------------------------------------------------------
	task automatic tclk( input integer n );
		repeat( n ) @( negedge clk14m );
	endtask

	task automatic idle( input integer t );
		tclk( t * t_clocks );
	endtask

	//	I/O マシンサイクル: T1, T2, TW(自動), T3。WAIT は TW の立ち下がりで採取。
	task automatic io_cycle(
		input	[7:0]	address,
		input			is_write,
		input	[7:0]	wdata,
		output	[7:0]	rdata
	);
		//	T1
		slot_a = address;
		tclk( t_clocks / 2 );
		if( is_write ) ff_slot_data = wdata;
		tclk( t_clocks / 2 );
		//	T2
		slot_iorq_n = 1'b0;
		if( is_write ) slot_wr_n = 1'b0;
		else           slot_rd_n = 1'b0;
		tclk( t_clocks );
		//	TW
		tclk( t_clocks / 2 );
		while( slot_wait ) begin
			tclk( t_clocks );
		end
		tclk( t_clocks / 2 );
		//	T3
		tclk( t_clocks / 2 );
		rdata = slot_d;
		slot_iorq_n	= 1'b1;
		slot_wr_n	= 1'b1;
		slot_rd_n	= 1'b1;
		tclk( t_clocks / 2 );
	endtask

	//	OUT (n),A : 12T (M1 5T + n 3T + I/O 4T)
	task automatic z_out_n( input [7:0] port, input [7:0] data );
		logic [7:0] dummy;
		idle( 8 );
		io_cycle( port, 1'b1, data, dummy );
	endtask

	//	IN A,(n) : 12T
	task automatic z_in_n( input [7:0] port, output [7:0] data );
		idle( 8 );
		io_cycle( port, 1'b0, 8'h00, data );
	endtask

	//	OUT (C),r : 14T (M1 5T + M1 5T + I/O 4T)
	task automatic z_out_c( input [7:0] port, input [7:0] data );
		logic [7:0] dummy;
		idle( 10 );
		io_cycle( port, 1'b1, data, dummy );
	endtask

	//	7BA9h: CALL + PUSH AF / LD A,E / OUT (99h),A / LD A,D / OR 80h / OUT (99h),A / POP AF / RET
	task automatic z_vdp_reg( input [5:0] r, input [7:0] v );
		idle( 18 + 12 + 5 );
		z_out_n( vdp_io1, v );
		idle( 5 + 8 );
		z_out_n( vdp_io1, { 2'b10, r } );
		idle( 11 + 11 );
	endtask

	task automatic z_vram_address( input [16:0] address );
		z_vdp_reg( 6'd14, { 5'd0, address[16:14] } );
		z_out_n( vdp_io1, address[7:0] );
		z_out_n( vdp_io1, { 2'b01, address[13:8] } );
	endtask

	task automatic z_vram_fill( input [16:0] address, input integer count, input [7:0] data );
		integer i;
		z_vram_address( address );
		for( i = 0; i < count; i++ ) begin
			z_out_n( vdp_io0, data );
			idle( 5 );
		end
	endtask

	//	7A9Fh: スクロール量 x → { R#26, R#27 }
	function automatic [8:0] conv_scroll( input integer x );
		logic [15:0] hl;
		logic [5:0] h;
		logic [2:0] l;
		hl	= x;
		hl	= hl - 16'd1;
		h	= ( (hl >> 3) + 16'd1 ) & 16'h3F;
		l	= ( -x ) & 7;
		conv_scroll = { h, l };
	endfunction

	//	7A83h: S#2 の VR が 1 → 0 になる (表示開始) まで待つ
	task automatic z_wait_display_start;
		logic [7:0] d;
		idle( 8 );
		z_out_n( vdp_io1, 8'd2 );
		idle( 8 );
		z_out_n( vdp_io1, 8'h8F );
		forever begin
			z_in_n( vdp_io1, d );
			idle( 8 );
			if( d[6] ) begin
				idle( 8 );
				break;
			end
			idle( 13 );
		end
		forever begin
			z_in_n( vdp_io1, d );
			idle( 8 );
			if( !d[6] ) begin
				idle( 8 );
				break;
			end
			idle( 13 );
		end
		idle( 5 );
		z_out_n( vdp_io1, 8'd0 );
		idle( 8 );
		z_out_n( vdp_io1, 8'h8F );
		idle( 11 );
	endtask

	//	7A48h: 1 フレーム分のロゴ表示
	task automatic z_logo_frame( input integer x );
		logic [8:0]	pair_a, pair_b;
		logic [5:0]	cur_h, prev_h, tmp_h;
		logic [2:0]	cur_l, prev_l, tmp_l;
		logic [7:0]	d;
		integer		k, poll, tgt;
		longint		t_read;

		idle( 12 );							//	PUSH HL
		z_wait_display_start();
		//	XOR A / SUB L / LD E,A / LD A,2 / SBC A,H / LD D,A / CALL 7A9F / EX DE,HL / CALL 7A9F / LD BC,559Bh
		idle( 33 + 122 + 5 + 122 + 11 );
		pair_a	= conv_scroll( x );					//	DE
		pair_b	= conv_scroll( 512 - x );			//	HL
		cur_h	= pair_b[8:3];	cur_l	= pair_b[2:0];		//	HL
		prev_h	= pair_a[8:3];	prev_l	= pair_a[2:0];		//	DE
		for( tgt = 0; tgt < 1024; tgt++ ) begin
			exp_valid[tgt] = 1'b0;
		end

		for( k = 0; k < 85; k++ ) begin
			//	LD A,1Ah / OUT (99h),A / LD A,91h / OUT (99h),A
			idle( 8 );
			z_out_n( vdp_io1, 8'h1A );
			idle( 8 );
			z_out_n( vdp_io1, 8'h91 );
			//	EX DE,HL
			idle( 5 );
			tmp_h = cur_h;	cur_h = prev_h;	prev_h = tmp_h;
			tmp_l = cur_l;	cur_l = prev_l;	prev_l = tmp_l;
			//	IN A,(99h) : S#0 を読んで衝突フラグをクリア
			z_in_n( vdp_io1, d );
			//	IN A,(99h) / AND 20h / JP Z
			poll = 0;
			forever begin
				z_in_n( vdp_io1, d );
				t_read = vclk;
				idle( 8 + 11 );
				if( d[5] ) break;
				poll++;
				if( poll > 2000 ) begin
					$display( "[LOGO] frame%0d iteration%0d: collision flag timeout", cur_frame, k );
					break;
				end
			end
			//	OUT (C),H / OUT (C),L
			z_out_c( vdp_io3, { 2'b00, cur_h } );
			z_out_c( vdp_io3, { 5'd0, cur_l } );
			tclk( 4 );

			tgt = last_coll_y + apply_line;
			begin
				integer r26, r27;
				r26 = ( last_w26_y - (last_coll_y + 1) ) * 342 + last_w26_x;
				r27 = ( last_w27_y - (last_coll_y + 1) ) * 342 + last_w27_x;
				if( r26 < w26_x_min ) w26_x_min = r26;
				if( r26 > w26_x_max ) w26_x_max = r26;
				if( r27 < w27_x_min ) w27_x_min = r27;
				if( r27 > w27_x_max ) w27_x_max = r27;
			end
			if( k == 84 ) begin
				//	最後の帯は直後の R#26=0 / R#27=0 書き込みで上書きされるため判定しない
			end
			else if( (m_sy > tgt) || (m_sy == tgt && dot( m_sx ) >= 128) ) begin
				n_late++;
				f_late++;
				$display( "[LOGO] frame%0d scroll=%0d line%0d TOO_LATE: R#27 written at line%0d x=%0d", cur_frame, cur_scroll, tgt, m_sy, dot( m_sx ) );
			end
			else begin
				exp_valid[tgt]	= 1'b1;
				exp_h[tgt]		= cur_h;
				exp_l[tgt]		= cur_l;
				old_h[tgt]		= prev_h;
				old_l[tgt]		= prev_l;
				coll_t[tgt]		= last_coll_t;
				coll_x[tgt]		= last_coll_x;
				cread_t[tgt]	= t_read;
				w26_t[tgt]		= last_w26_t;
				w27_t[tgt]		= last_w27_t;
				w27_x[tgt]		= last_w27_x - 342 * ( tgt - last_w27_y );
			end
			//	DJNZ
			idle( (k == 84) ? 9 : 14 );
		end
		//	POP HL / LD DE,1A00h / CALL 7BA9 / LD DE,1B00h / CALL 7BA9 / RET
		idle( 11 + 11 );
		z_vdp_reg( 6'd26, 8'h00 );
		idle( 11 );
		z_vdp_reg( 6'd27, 8'h00 );
		idle( 11 );
	endtask

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		integer		hl, de, f, frame_no, i;
		integer		scroll_list [0:63];
		integer		n_frames_all;
		logic [8:0]	p;

		clk_dummy		= 0;
		clk14m			= 0;
		slot_reset_n	= 0;
		slot_iorq_n		= 1;
		slot_rd_n		= 1;
		slot_wr_n		= 1;
		slot_a			= 0;
		ff_slot_data	= 0;
		dipsw			= 0;
		button			= 0;

		n_ok = 0; n_stale = 0; n_mix27 = 0; n_mix26 = 0; n_other = 0; n_late = 0; n_double = 0; n_midline = 0;
		w26_x_min = 99999; w26_x_max = -99999; w27_x_min = 99999; w27_x_max = -99999;
		min_margin27	= 99999;
		max_coll_to_w27	= -99999;
		cur_frame		= -1;
		cur_scroll		= 0;
		last_coll_y		= 0;
		for( i = 0; i < 1024; i++ ) begin
			exp_valid[i]	= 1'b0;
			latch_cnt[i]	= 0;
		end

		//	7A24h: スクロール量の列 (x = 225 から 9,8,...,1,0 ずつ 5 フレームごと)
		hl = 225;
		de = -10;
		n_frames_all = 0;
		do begin
			de = de + 1;
			for( i = 0; i < 5; i++ ) begin
				scroll_list[ n_frames_all ] = hl;
				n_frames_all++;
				hl = hl + de;
			end
		end while( de != 0 );

		fd = $fopen( "logo_lines.csv", "w" );
		$fdisplay( fd, "frame,scroll,line,exp_r26,exp_r27,eff_r26,eff_r27,verdict,delta_dots,coll_x,coll_to_cread_T,coll_to_r27_T,r27_write_x,margin26_dots,margin27_dots,latch_count,latch_x" );

		repeat( 10 ) @( posedge clk14m );
		slot_reset_n = 1;
		repeat( 10 ) @( posedge clk14m );
		tclk( cpu_phase );
		$display( "[LOGO] Wait initialization" );

		//	7ADAh 相当 (ロゴ描画コマンドと VRAM 全面フィルは省略)
		z_wait_display_start();
		z_vdp_reg( 6'd1, 8'h23 );
		z_vdp_reg( 6'd0, 8'h08 );		//	SCREEN 6
		z_vdp_reg( 6'd1, 8'h23 );
		z_vdp_reg( 6'd8, 8'h28 );
		z_vdp_reg( 6'd9, 8'h00 );
		z_vdp_reg( 6'd2, 8'h1F );
		z_vdp_reg( 6'd5, 8'hEF );
		z_vdp_reg( 6'd11, 8'h00 );
		z_vdp_reg( 6'd6, 8'h0F );
		z_vdp_reg( 6'd7, 8'h05 );
		$display( "[LOGO] Write sprite tables" );
		pix_fill_vram();
		z_vram_fill( 17'h07800, 'h30, 8'hFF );
		if( tb.u_sdram.Bank0[ 17'h07800 >> 2 ] !== 32'hFFFFFFFF ) begin
			$fatal( 1, "[PIX] SDRAM model address mapping mismatch: %08X", tb.u_sdram.Bank0[ 17'h07800 >> 2 ] );
		end
		z_vram_fill( 17'h07830, 'h10, 8'hF0 );
		z_vram_fill( 17'h07400, 'h200, 8'h05 );
		z_vram_address( 17'h07600 );
		begin
			logic [7:0] attr [0:39];
			attr = '{ 8'h1C, 8'hE8, 8'h00, 8'h00,  8'h1C, 8'hE8, 8'h00, 8'h00,
					  8'h3C, 8'hE8, 8'h00, 8'h00,  8'h3C, 8'hE8, 8'h00, 8'h00,
					  8'h5C, 8'hE8, 8'h00, 8'h00,  8'h5C, 8'hE8, 8'h00, 8'h00,
					  8'h1C, 8'h00, 8'h04, 8'h00,  8'h3C, 8'h00, 8'h04, 8'h00,
					  8'h5C, 8'h00, 8'h04, 8'h00,  8'hD8, 8'h00, 8'h00, 8'h00 };
			for( i = 0; i < 40; i++ ) begin
				z_out_n( vdp_io0, attr[i] );
				idle( 5 );
			end
		end
		z_vdp_reg( 6'd25, 8'h03 );
		z_vdp_reg( 6'd2, 8'h3F );

		//	7A09h
		p = conv_scroll( 255 );
		z_vdp_reg( 6'd26, { 2'd0, p[8:3] } );
		z_vdp_reg( 6'd27, { 5'd0, p[2:0] } );
		z_wait_display_start();
		z_vdp_reg( 6'd1, 8'h63 );
		pix_enable = 1;

		for( f = 0; f < first_frame + num_frames && f < n_frames_all; f++ ) begin
			if( f < first_frame ) continue;
			cur_frame	= f;
			cur_scroll	= scroll_list[f];
			f_ok = 0; f_stale = 0; f_mix27 = 0; f_mix26 = 0; f_other = 0; f_late = 0;
			z_logo_frame( scroll_list[f] );
			//	最後の帯の判定が終わるまで少し待つ
			repeat( 5472 * 2 ) @( posedge clk14m );
			$display( "[LOGO] frame%0d scroll=%0d (R#26,R#27)=(%0d,%0d)/(%0d,%0d): OK=%0d STALE=%0d MIX_R27=%0d MIX_R26=%0d OTHER=%0d TOO_LATE=%0d",
				f, scroll_list[f],
				conv_scroll( scroll_list[f] ) >> 3, conv_scroll( scroll_list[f] ) & 7,
				conv_scroll( 512 - scroll_list[f] ) >> 3, conv_scroll( 512 - scroll_list[f] ) & 7,
				f_ok, f_stale, f_mix27, f_mix26, f_other, f_late );
			//	7A32h: POP DE / POP BC / ADD HL,DE / DJNZ
			idle( 10 + 10 + 11 + 14 );
		end

		$display( "[LOGO] SUMMARY: OK=%0d STALE=%0d MIX_R27=%0d MIX_R26=%0d OTHER=%0d TOO_LATE=%0d DOUBLE_LATCH=%0d",
			n_ok, n_stale, n_mix27, n_mix26, n_other, n_late, n_double );
		$display( "[LOGO] min margin (R#27 write -> latch) = %0d dots, max collision -> R#27 write = %0d T",
			min_margin27, max_coll_to_w27 );
		$display( "[LOGO] write position (X on collision line + 1): R#26 = %0d .. %0d, R#27 = %0d .. %0d, MIDLINE = %0d",
			w26_x_min, w26_x_max, w27_x_min, w27_x_max, n_midline );
		$display( "[PIX] SUMMARY: OK=%0d NG=%0d NO_MATCH=%0d (constant=%0d)", n_pix_ok, n_pix_ng, n_pix_none, pix_c0 );
		if( n_stale != 0 || n_mix27 != 0 || n_mix26 != 0 || n_other != 0 || n_late != 0 || n_midline != 0 || n_pix_ng != 0 || n_pix_none != 0 ) begin
			$fatal( 1, "[LOGO] unexpected scroll mismatches" );
		end
		$fclose( fd );
		$finish;
	end
endmodule
