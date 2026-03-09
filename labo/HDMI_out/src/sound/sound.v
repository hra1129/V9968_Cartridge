// ---------------------------------------------------------
//	テスト用サウンド生成器
// =========================================================
//	2026/Feb/25th t.hara
// ---------------------------------------------------------

module sound (
	input			reset_n,
	input			clk,		//	27MHz
	output			pcm_fs,
	output	[23:0]	pcm_l,
	output	[23:0]	pcm_r
);
	reg		[9:0]	ff_div;		//	27000000/48000 = 562.5
	wire			w_48khz;
	reg				ff_pcm_fs;
	reg		[23:0]	ff_pcm_l;
	reg		[23:0]	ff_pcm_r;
	reg		[12:0]	ff_tone_length;	//	4800 count
	wire			w_tone_change;
	reg		[2:0]	ff_tone_state;
	reg		[7:0]	ff_tone_freq;
	reg		[7:0]	ff_tone_count;
	reg				ff_tone_pulse;
	wire			w_tone_flip;

	// ---------------------------------------------------------
	//	Clock Divider
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_div <= 10'd561;
		end
		else if( w_48khz ) begin
			ff_div <= 10'd561;
		end
		else begin
			ff_div <= ff_div - 10'd1;
		end
	end
	assign w_48khz		= (ff_div == 10'd0);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_pcm_fs <= 1'b0;
		end
		else if( w_48khz ) begin
			ff_pcm_fs <= 1'b1;
		end
		else if( ff_div == 10'd280 ) begin
			ff_pcm_fs <= 1'b0;
		end
		else begin
			//	hold
		end
	end

	// ---------------------------------------------------------
	//	Tone State
	// ---------------------------------------------------------
	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_tone_length	<= 13'd0;
		end
		else if( !w_48khz ) begin
			//	hold
		end
		else if( w_tone_change ) begin
			ff_tone_length	<= 13'd0;
		end
		else begin
			ff_tone_length	<= ff_tone_length + 13'd1;
		end
	end
	assign w_tone_change	= (ff_tone_length == 13'd4799);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_tone_state	<= 3'd0;
			ff_tone_freq	<= 8'd109;
		end
		else if( !w_48khz ) begin
			//	hold
		end
		else if( w_tone_change ) begin
			ff_tone_state	<= ff_tone_state + 3'd1;

			case( ff_tone_state )
			3'd0:	ff_tone_freq <= 8'd109;
			3'd1:	ff_tone_freq <= 8'd122;
			3'd2:	ff_tone_freq <= 8'd129;
			3'd3:	ff_tone_freq <= 8'd145;
			3'd4:	ff_tone_freq <= 8'd163;
			3'd5:	ff_tone_freq <= 8'd173;
			3'd6:	ff_tone_freq <= 8'd194;
			3'd7:	ff_tone_freq <= 8'd219;
			endcase
		end
		else begin
			//	hold
		end
	end

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_tone_count	<= 8'd0;
			ff_tone_pulse	<= 1'b0;
		end
		else if( !w_48khz ) begin
			//	hold
		end
		else if( w_tone_change ) begin
			ff_tone_count	<= 8'd0;
			ff_tone_pulse	<= 1'b1;
		end
		else if( w_tone_flip ) begin
			ff_tone_count	<= 8'd0;
			ff_tone_pulse	<= ~ff_tone_pulse;
		end
		else begin
			ff_tone_count	<= ff_tone_count + 8'd1;
		end
	end
	assign w_tone_flip	= (ff_tone_count == ff_tone_freq);

	always @( posedge clk ) begin
		if( !reset_n ) begin
			ff_pcm_l <= 24'd0;
			ff_pcm_r <= 24'd0;
		end
		else begin
			if( ff_tone_pulse ) begin
				ff_pcm_l <= 24'h700000;
				ff_pcm_r <= 24'h700000;
			end
			else begin
				ff_pcm_l <= 24'd0;
				ff_pcm_r <= 24'd0;
			end
		end
	end

	assign pcm_fs	= ff_pcm_fs;
	assign pcm_l	= ff_pcm_l;
	assign pcm_r	= ff_pcm_r;
endmodule
