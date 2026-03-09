// -----------------------------------------------------------------------------
//	Test of sound.v
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
	longint			clk_base		= 64'd1_000_000_000_000 / 64'd27_000_000;	//	ps (27MHz)
	reg				reset_n;
	reg				clk;				//	27MHz
	wire			pcm_fs;
	wire	[23:0]	pcm_l;
	wire	[23:0]	pcm_r;

	int				sample_count;
	int				fs_count;
	int				error_count;

	// --------------------------------------------------------------------
	//	DUT
	// --------------------------------------------------------------------
	sound u_sound (
		.reset_n			( reset_n			),
		.clk				( clk				),
		.pcm_fs				( pcm_fs			),
		.pcm_l				( pcm_l				),
		.pcm_r				( pcm_r				)
	);

	// --------------------------------------------------------------------
	//	clock : 27MHz
	// --------------------------------------------------------------------
	always #(clk_base/2) begin
		clk <= ~clk;
	end

	// --------------------------------------------------------------------
	//	pcm_fs の立ち上がりを監視し、L/R一致チェック・サンプル表示
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( reset_n && pcm_fs ) begin
			sample_count <= sample_count + 1;
			fs_count     <= fs_count + 1;

			// L と R が同一であることを確認
			assert( pcm_l == pcm_r ) else begin
				$display( "[ERROR] sample #%0d : pcm_l(0x%06X) != pcm_r(0x%06X)", sample_count, pcm_l, pcm_r );
				error_count <= error_count + 1;
			end

			// 100サンプルごとにログ出力（量を抑える）
			if( sample_count % 100 == 0 ) begin
				$display( "[%t] sample #%0d : pcm_l=0x%06X, pcm_r=0x%06X, pcm_fs=%b",
					$realtime, sample_count, pcm_l, pcm_r, pcm_fs );
			end
		end
	end

	// --------------------------------------------------------------------
	//	Test bench
	// --------------------------------------------------------------------
	initial begin
		reset_n      = 0;
		clk          = 0;
		sample_count = 0;
		fs_count     = 0;
		error_count  = 0;

		@( negedge clk );
		@( negedge clk );
		@( posedge clk );

		reset_n = 1;
		$display( "[%t] Reset released.", $realtime );

		// ---- 48kHzで 4800サンプル = 100ms ごとにトーンが変わるので、
		//       全8トーン(800ms) + α = 約 1000ms 走らせる。
		//       run.do の "run 1000ms" と対応。

		// -- シミュレーション終了は run.do 側の "run 1000ms" に任せるが、
		//    念のため十分な時間が経ったら自動終了する。
		#1100ms;

		$display( "======================================" );
		$display( "  Total samples : %0d", sample_count );
		$display( "  Errors        : %0d", error_count );
		$display( "======================================" );

		if( error_count == 0 ) begin
			$display( "TEST PASSED" );
		end
		else begin
			$display( "TEST FAILED" );
		end

		$finish;
	end
endmodule
