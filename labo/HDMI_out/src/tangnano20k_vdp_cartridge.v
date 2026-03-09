// -----------------------------------------------------------------------------
//	tangnano20k_vdp_cartridge.v
//	Copyright (C)2025 Takayuki Hara (HRA!)
//	
//	 Permission is hereby granted, free of charge, to any person obtaining a 
//	copy of this software and associated documentation files (the "Software"), 
//	to deal in the Software without restriction, including without limitation 
//	the rights to use, copy, modify, merge, publish, distribute, sublicense, 
//	and/or sell copies of the Software, and to permit persons to whom the 
//	Software is furnished to do so, subject to the following conditions:
//	
//	The above copyright notice and this permission notice shall be included in 
//	all copies or substantial portions of the Software.
//	
//	The Software is provided "as is", without warranty of any kind, express or 
//	implied, including but not limited to the warranties of merchantability, 
//	fitness for a particular purpose and noninfringement. In no event shall the 
//	authors or copyright holders be liable for any claim, damages or other 
//	liability, whether in an action of contract, tort or otherwise, arising 
//	from, out of or in connection with the Software or the use or other dealings 
//	in the Software.
// -----------------------------------------------------------------------------

module tangnano20k_vdp_cartridge (
	input			clk27m,			//	PIN04		(27MHz)
	input			clk14m,			//	PIN80
	input			slot_reset_n,	//	PIN86
	input			slot_iorq_n,	//	PIN18
	input			slot_rd_n,		//	PIN15
	input			slot_wr_n,		//	PIN16
	output			slot_wait,		//	PIN72
	output			slot_intr,		//	PIN71
	output			slot_data_dir,	//	PIN19
	input	[7:0]	slot_a,			//	PIN17, 49, 48, 41, 42, 76, 31, 30
	inout	[7:0]	slot_d,			//	PIN73, 74, 75, 85, 77, 27, 28, 29
	output			oe_n,			//	PIN20
	input	[1:0]	dipsw,			//	PIN52, 53
	output			ws2812_led,		//	PIN79
	input	[1:0]	button,			//	PIN87, 88	KEY2, KEY1

	//	HDMI
	output			tmds_clk_p,		//	(PIN33/34)
//	output			tmds_clk_n,		//	dummy
	output	[2:0]	tmds_d_p,		//	(PIN39/40), (PIN37/38), (PIN35/36)
//	output	[2:0]	tmds_d_n,		//	dummy

	output			O_sdram_clk,
	output			O_sdram_cke,
	output			O_sdram_cs_n,	// chip select
	output			O_sdram_ras_n,	// row address select
	output			O_sdram_cas_n,	// columns address select
	output			O_sdram_wen_n,	// write enable
	inout	[31:0]	IO_sdram_dq,	// 32 bit bidirectional data bus
	output	[10:0]	O_sdram_addr,	// 11 bit multiplexed address bus
	output	[ 1:0]	O_sdram_ba,		// two banks
	output	[ 3:0]	O_sdram_dqm		// data mask
);
	reg				ff_reset_n0 = 1'b0;
	reg				ff_reset_n1 = 1'b0;
	reg				ff_reset_n2 = 1'b0;
	reg				ff_reset2_n0 = 1'b0;
	reg				ff_reset2_n1 = 1'b0;
	reg				ff_reset2_n2 = 1'b0;
	reg				ff_reset2_n3 = 1'b0;
	wire			pll_lock215;
	wire			pll_lock85;
	wire			clk85m;				//	85.90908MHz
	wire			clk85m_n;			//	85.90908MHz (180deg phase shift)
	wire			clk135m;			//	135MHz
	wire			reset_n;
	wire			reset_n2;

	reg				ff_reset3_n0 = 1'b0;
	reg				ff_reset3_n1 = 1'b0;
	reg				ff_reset3_n2 = 1'b0;
	wire			reset_n3;
	wire			w_framestart;
	wire			w_linestart;
	wire			w_pixrequest;
	wire	[3:0]	w_hdmicontrol;
	wire			w_active;
	wire			w_hsync;
	wire			w_vsync;
	wire			w_csync;
	wire			w_hblank;
	wire			w_vblank;
	wire	[7:0]	w_cb_rout;
	wire	[7:0]	w_cb_gout;
	wire	[7:0]	w_cb_bout;
	wire			w_pcm_fs;
	wire	[23:0]	w_pcm_l;
	wire	[23:0]	w_pcm_r;

	assign slot_wait		= 1'b0;
	assign oe_n				= 1'b0;

	always @( posedge clk85m ) begin
		ff_reset_n0		<= slot_reset_n;
		ff_reset_n1		<= ff_reset_n0;
		ff_reset_n2		<= ff_reset_n1;
	end

	always @( posedge clk14m ) begin
		ff_reset2_n0	<= slot_reset_n;
		ff_reset2_n1	<= ff_reset2_n0;
		ff_reset2_n2	<= ff_reset2_n1;
		ff_reset2_n3	<= ff_reset2_n2;
	end

	assign reset_n	= ff_reset_n2;
	assign reset_n2	= ff_reset2_n3;

	always @( posedge clk27m ) begin
		ff_reset3_n0	<= slot_reset_n;
		ff_reset3_n1	<= ff_reset3_n0;
		ff_reset3_n2	<= ff_reset3_n1;
	end

	assign reset_n3	= ff_reset3_n2;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	Gowin_rPLL u_pll (
		.clkout			( clk135m			),		//	output clkout	135MHz
		.clkin			( clk27m			)		//	input clkin		27MHz
	);

	Gowin_rPLL2 u_pll2 (
		.clkout			( clk85m			),		//	output clkout	85.90908MHz
		.lock			( pll_lock85		),
		.clkoutp		( clk85m_n			),		//	output clkoutp	85.90908MHz (180deg phase shift)
		.clkin			( clk14m			)		//	input clkin		14.31818MHz
    );

	// --------------------------------------------------------------------
	//	Video Sync Generator (720x480 test pattern)
	// --------------------------------------------------------------------
	video_syncgen #(
		.BAR_MODE		( "WIDE"			),		//	ARIB STD-B28 Multi-colorbar like
		.COLORSPACE		( "RGB"				),		//	RGB888 Full range
		.START_SIG		( "SINGLE"			),		//	framestart and linestart are 1-clock pulse
		.EARLY_REQ		( 0					),

		.H_TOTAL		( 858				),		//	SD480p(720x480) : 27.027MHz/27.00MHz
		.H_SYNC			( 62				),
		.H_BACKP		( 60				),
		.H_ACTIVE		( 720				),
		.V_TOTAL		( 525				),
		.V_SYNC			( 6					),
		.V_BACKP		( 30				),
		.V_ACTIVE		( 480				),

		.FRAME_TOP		( 0					),
		.START_HPOS		( 0					),
		.START_VPOS		( 0					)
	) u_video_syncgen (
		.reset			( ~reset_n3			),		//	active high
		.video_clk		( clk27m			),
		.scan_ena		( 1'b0				),
		.framestart		( w_framestart		),
		.linestart		( w_linestart		),
		.pixrequest		( w_pixrequest		),
		.hdmicontrol	( w_hdmicontrol		),
		.active			( w_active			),
		.hsync			( w_hsync			),
		.vsync			( w_vsync			),
		.csync			( w_csync			),
		.hblank			( w_hblank			),
		.vblank			( w_vblank			),
		.cb_rout		( w_cb_rout			),
		.cb_gout		( w_cb_gout			),
		.cb_bout		( w_cb_bout			)
	);

	sound u_sound (
		.reset_n		( reset_n3			),
		.clk			( clk27m			),
		.pcm_fs			( w_pcm_fs			),
		.pcm_l			( w_pcm_l			),
		.pcm_r			( w_pcm_r			)
	);

	// --------------------------------------------------------------------
	//	HDMI
	// --------------------------------------------------------------------
	hdmi_tx #(
		.DEVICE_FAMILY		( "MAX 10"			),
		.CLOCK_FREQUENCY	( 27.000			),		//	Input clock frequency (MHz)
		.ENCODE_MODE		( "HDMI"			),		//	HDMI
		.USE_EXTCONTROL		( "ON"				),		//	Use control port (External HDMI timing generator)
		.SYNC_POLARITY		( "NEGATIVE"		),		//	Invert HSYNC/VSYNC to send
		.SCANMODE			( "AUTO"			),		//	Displays decides
		.PICTUREASPECT		( "NONE"			),		//	Picture aspect ratio information not present
		.FORMATASPECT		( "AUTO"			),		//	Same as picture
		.PICTURESCALING		( "FIT"				),		//	Picture has been scaled H and V
		.COLORSPACE			( "RGB"				),		//	RGB888 (Fixed at Full range)
		.YCC_DATARANGE		( "LIMITED"			),		//	Limited data range(16-235,240)
		.CONTENTTYPE		( "GRAPHICS"		),		//	for PC use(IT Content)
		.REPETITION			( 0					),		//	Pixel Repetition Factor (0-9)
		.VIDEO_CODE			( 0					),		//	Video Information Codes (1-59, 0=No data)
		.USE_AUDIO_PACKET	( "ON"				),		//	Use Audio sample packet
		.AUDIO_FREQUENCY	( 48.0				),		//	Audio sampling frequency (KHz)
		.PCMFIFO_DEPTH		( 8					),		//	Sample data fifo depth : 8=256word(35sample)
		.CATEGORY_CODE		( 8'h00				)
	) u_hdmi_tx (
		.reset				( ~reset_n3			),		//	active high
		.clk				( clk27m			),		//	27MHz pixel clock
		.clk_x5				( clk135m			),		//	135MHz = 5 * 27MHz
		.cc_swap			( 					),		//	Type-C AltMode swap option
		.control			( w_hdmicontrol		),		//	HDMI control from video_syncgen
		.active				( w_active			),		//	Pixel data active
		.r_data				( w_cb_rout			),		//	R
		.g_data				( w_cb_gout			),		//	G
		.b_data				( w_cb_bout			),		//	B
		.hsync				( w_hsync			),		//	Horizontal sync
		.vsync				( w_vsync			),		//	Vertical sync
		.pcm_fs				( w_pcm_fs			),		//	sound
		.pcm_l				( w_pcm_l			),		//	sound
		.pcm_r				( w_pcm_r			),		//	sound
		.data				( tmds_d_p			),		//	TMDS data
		.data_n				( 					),		//	TMDS data (inverted)
		.clock				( tmds_clk_p		),		//	TMDS clock
		.clock_n			( 					)		//	TMDS clock (inverted)
	);

endmodule
