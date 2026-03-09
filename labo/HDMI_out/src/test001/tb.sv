// -----------------------------------------------------------------------------
//	Test of tangnano20k_vdp_cartridge.v
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
	longint			clk27m_base		= 64'd1_000_000_000_000 / 64'd27_000_000;		//	ps (27MHz)
	longint			clk14m_base		= 64'd1_000_000_000_000 / 64'd14_318_180;		//	ps (14.31818MHz)

	reg				clk27m;
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

	//	HDMI
	wire			tmds_clk_p;
	wire	[2:0]	tmds_d_p;

	//	SDRAM (directly exposed but unused in current design)
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

	//	Monitor
	int				frame_count;
	int				hsync_count;
	int				pcm_sample_count;
	int				error_count;
	reg				ff_tmds_clk_p_d;
	reg				ff_vsync_prev;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	tangnano20k_vdp_cartridge u_dut (
		.clk27m				( clk27m			),
		.clk14m				( clk14m			),
		.slot_reset_n		( slot_reset_n		),
		.slot_iorq_n		( slot_iorq_n		),
		.slot_rd_n			( slot_rd_n			),
		.slot_wr_n			( slot_wr_n			),
		.slot_wait			( slot_wait			),
		.slot_intr			( slot_intr			),
		.slot_data_dir		( slot_data_dir		),
		.slot_a				( slot_a			),
		.slot_d				( slot_d			),
		.oe_n				( oe_n				),
		.dipsw				( dipsw				),
		.ws2812_led			( ws2812_led		),
		.button				( button			),
		.tmds_clk_p			( tmds_clk_p		),
		.tmds_d_p			( tmds_d_p			),
		.O_sdram_clk		( O_sdram_clk		),
		.O_sdram_cke		( O_sdram_cke		),
		.O_sdram_cs_n		( O_sdram_cs_n		),
		.O_sdram_ras_n		( O_sdram_ras_n		),
		.O_sdram_cas_n		( O_sdram_cas_n		),
		.O_sdram_wen_n		( O_sdram_wen_n		),
		.IO_sdram_dq		( IO_sdram_dq		),
		.O_sdram_addr		( O_sdram_addr		),
		.O_sdram_ba			( O_sdram_ba		),
		.O_sdram_dqm		( O_sdram_dqm		)
	);

	// --------------------------------------------------------------------
	//	clock generators
	// --------------------------------------------------------------------
	always #(clk27m_base/2) begin
		clk27m <= ~clk27m;
	end

	always #(clk14m_base/2) begin
		clk14m <= ~clk14m;
	end

	// --------------------------------------------------------------------
	//	Monitor : video_syncgen の vsync で frame カウント
	// --------------------------------------------------------------------
	always @( posedge clk27m ) begin
		if( !slot_reset_n ) begin
			ff_vsync_prev	<= 1'b0;
			frame_count		<= 0;
		end
		else begin
			ff_vsync_prev <= u_dut.w_vsync;
			if( !ff_vsync_prev && u_dut.w_vsync ) begin
				frame_count <= frame_count + 1;
				$display( "[%t] === Frame #%0d start ===", $realtime, frame_count );
			end
		end
	end

	// --------------------------------------------------------------------
	//	Monitor : hsync カウント
	// --------------------------------------------------------------------
	reg		ff_hsync_prev;
	always @( posedge clk27m ) begin
		if( !slot_reset_n ) begin
			ff_hsync_prev	<= 1'b0;
			hsync_count		<= 0;
		end
		else begin
			ff_hsync_prev <= u_dut.w_hsync;
			if( !ff_hsync_prev && u_dut.w_hsync ) begin
				hsync_count <= hsync_count + 1;
			end
		end
	end

	// --------------------------------------------------------------------
	//	Monitor : PCM fs カウント
	// --------------------------------------------------------------------
	always @( posedge clk27m ) begin
		if( !slot_reset_n ) begin
			pcm_sample_count <= 0;
		end
		else if( u_dut.w_pcm_fs ) begin
			pcm_sample_count <= pcm_sample_count + 1;
			if( pcm_sample_count % 480 == 0 ) begin
				$display( "[%t] PCM sample #%0d : L=0x%06X, R=0x%06X",
					$realtime, pcm_sample_count, u_dut.w_pcm_l, u_dut.w_pcm_r );
			end
		end
	end

	// --------------------------------------------------------------------
	//	Monitor : slot_wait / oe_n の固定値チェック
	// --------------------------------------------------------------------
	always @( posedge clk27m ) begin
		if( slot_reset_n ) begin
			assert( slot_wait == 1'b0 ) else begin
				$display( "[ERROR][%t] slot_wait is not 0!", $realtime );
				error_count <= error_count + 1;
			end
			assert( oe_n == 1'b0 ) else begin
				$display( "[ERROR][%t] oe_n is not 0!", $realtime );
				error_count <= error_count + 1;
			end
		end
	end

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		clk27m			= 0;
		clk14m			= 0;
		slot_reset_n	= 0;
		slot_iorq_n		= 1;
		slot_rd_n		= 1;
		slot_wr_n		= 1;
		slot_a			= 8'h00;
		dipsw			= 2'b00;
		button			= 2'b11;		//	KEY not pressed (active low)
		frame_count		= 0;
		hsync_count		= 0;
		pcm_sample_count = 0;
		error_count		= 0;

		// ---- リセット解除 ----
		repeat( 10 ) @( posedge clk27m );
		slot_reset_n	= 1;
		$display( "[%t] Reset released.", $realtime );

		// ---- シミュレーション実行 ----
		//   480p@60 : 1フレーム = 858*525 = 450450 clk27m ≒ 16.68ms
		//   3フレーム ≒ 50ms で主要動作を確認
		#50ms;

		// ---- 結果表示 ----
		$display( "======================================" );
		$display( "  Frames          : %0d", frame_count );
		$display( "  H-sync count    : %0d", hsync_count );
		$display( "  PCM samples     : %0d", pcm_sample_count );
		$display( "  Errors          : %0d", error_count );
		$display( "======================================" );

		if( error_count == 0 && frame_count > 0 ) begin
			$display( "TEST PASSED" );
		end
		else begin
			$display( "TEST FAILED" );
		end

		$finish;
	end
endmodule
