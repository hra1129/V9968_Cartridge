//
//	ip_i2s_receiver.v
//
//	Copyright (C) 2026 Takayuki Hara
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
//-----------------------------------------------------------------------------
//	Standard (Philips) I2S receiver.
//	  - LRCLK = 0: left channel, LRCLK = 1: right channel.
//	  - The MSB comes one BCLK after the LRCLK transition; data is sampled on the BCLK rising edge.
//	  - Any slot width is accepted. The first 24 bits are left-justified into pcm_l/pcm_r,
//	    shorter words are padded with 0.
//	  - pcm_l/pcm_r are updated when a stereo frame completes and stay stable for one frame.
//	    pcm_fs rises half a frame later, so the receiver (hdmi_tx) can latch them on its own clock.
//	  - i2s_en = 0 forces pcm_fs/pcm_l/pcm_r to 0.
//-----------------------------------------------------------------------------

module ip_i2s_receiver (
	input				reset_n,
	input				clk,				//	85.90908MHz (must be much faster than BCLK)
	input				i2s_en,
	input				i2s_bclk,
	input				i2s_lrclk,
	input				i2s_din,
	output				pcm_fs,
	output		[23:0]	pcm_l,
	output		[23:0]	pcm_r
);
	reg			[2:0]	ff_bclk;
	reg			[1:0]	ff_lrclk;
	reg			[1:0]	ff_din;
	reg			[1:0]	ff_en;
	reg					ff_lr_prev;
	reg			[23:0]	ff_shift;
	reg			[4:0]	ff_bit_count;
	reg			[23:0]	ff_left_word;
	reg			[23:0]	ff_pcm_l;
	reg			[23:0]	ff_pcm_r;
	reg					ff_pcm_fs;
	wire				w_bclk_rise;
	wire				w_lrclk;
	wire				w_din;
	wire		[23:0]	w_word;

	// --------------------------------------------------------------------
	//	Synchronizer (all signals go through the same depth to keep their alignment)
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		ff_bclk		<= { ff_bclk[1:0], i2s_bclk };
		ff_lrclk	<= { ff_lrclk[0], i2s_lrclk };
		ff_din		<= { ff_din[0], i2s_din };
		ff_en		<= { ff_en[0], i2s_en };
	end

	assign w_bclk_rise	= ff_bclk[1] & ~ff_bclk[2];
	assign w_lrclk		= ff_lrclk[1];
	assign w_din		= ff_din[1];

	//	Word including the bit of this BCLK edge (on an LRCLK change it is the LSB of the previous word)
	assign w_word		= ( ff_bit_count < 5'd24 ) ? ( ff_shift | ( { w_din, 23'd0 } >> ff_bit_count ) ) : ff_shift;

	// --------------------------------------------------------------------
	//	Receiver
	// --------------------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n || !ff_en[1] ) begin
			ff_lr_prev		<= 1'b0;
			ff_shift		<= 24'd0;
			ff_bit_count	<= 5'd0;
			ff_left_word	<= 24'd0;
			ff_pcm_l		<= 24'd0;
			ff_pcm_r		<= 24'd0;
			ff_pcm_fs		<= 1'b0;
		end
		else if( w_bclk_rise ) begin
			if( w_lrclk != ff_lr_prev ) begin
				if( !ff_lr_prev ) begin
					//	Left word completed
					ff_left_word	<= w_word;
					ff_pcm_fs		<= 1'b1;
				end
				else begin
					//	Right word completed: one stereo frame is ready
					ff_pcm_l		<= ff_left_word;
					ff_pcm_r		<= w_word;
					ff_pcm_fs		<= 1'b0;
				end
				ff_lr_prev		<= w_lrclk;
				ff_shift		<= 24'd0;
				ff_bit_count	<= 5'd0;
			end
			else if( ff_bit_count < 5'd24 ) begin
				ff_shift		<= w_word;
				ff_bit_count	<= ff_bit_count + 5'd1;
			end
		end
	end

	assign pcm_fs	= ff_pcm_fs;
	assign pcm_l	= ff_pcm_l;
	assign pcm_r	= ff_pcm_r;
endmodule
