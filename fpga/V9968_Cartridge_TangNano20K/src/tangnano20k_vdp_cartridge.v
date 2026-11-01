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
	input			clk,			//	PIN04
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

	//	Config ROM (BANK3)
	output			mspi_cs,		//	PIN60
	output			mspi_clk,		//	PIN59
	inout			mspi_hold,		//	PIN63
	inout			mspi_wp,		//	PIN57
	inout			mspi_do,		//	PIN62
	inout			mspi_di,		//	PIN61

	//	HDMI
	output			tmds_clk_p,		//	(PIN33/34)
	output	[2:0]	tmds_d_p,		//	(PIN39/40), (PIN37/38), (PIN35/36)

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
	reg				ff_reset_n0 = 1'b0;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_n1 = 1'b0;		/* synthesis syn_preserve = 1 */
	reg				ff_reset_n2 = 1'b0;		/* synthesis syn_preserve = 1 */
	reg				ff_reset2_n0 = 1'b0;	/* synthesis syn_preserve = 1 */
	reg				ff_reset2_n1 = 1'b0;	/* synthesis syn_preserve = 1 */
	reg				ff_reset2_n2 = 1'b0;	/* synthesis syn_preserve = 1 */
	reg				ff_reset3_n0 = 1'b0;	/* synthesis syn_preserve = 1 */
	reg				ff_reset3_n1 = 1'b0;	/* synthesis syn_preserve = 1 */
	reg				ff_reset3_n2 = 1'b0;	/* synthesis syn_preserve = 1 */
	wire			pll_lock85;
	wire			clk42m;				//	42.95454MHz (geo3d engine: CLKOUTD of u_pll2 = clk85m / 2)
	wire			clk85m;				//	85.90908MHz
	wire			clk85m_n;			//	85.90908MHz (180deg phase shift)
	wire			clk143m;			//	143.18180MHz = clk14m x 10 (HDMI TMDS serializer)
	wire			clk28m;				//	28.63636MHz = clk143m / 5 (HDMI pixel clock)
	wire			reset_n;
	wire			reset_n2;
	wire			reset_n3;
	wire	[2:0]	w_bus_address;
	wire			w_bus_ioreq;
	wire			w_bus_write;
	wire			w_bus_valid;
	wire			w_bus_ready;
	wire	[7:0]	w_bus_wdata;
	wire	[7:0]	w_bus_rdata;
	wire			w_bus_rdata_en;
	wire	[3:0]	w_bus_sysctrl_address;
	wire			w_bus_sysctrl_ioreq;
	wire	[7:0]	w_bus_sysctrl_rdata;
	wire			w_bus_sysctrl_rdata_en;
	wire			w_rom_bus_address;
	wire			w_rom_bus_valid;
	wire			w_rom_bus_ready;
	wire			w_rom_bus_write;
	wire	[7:0]	w_rom_bus_wdata;
	wire	[7:0]	w_rom_bus_rdata;
	wire			w_rom_bus_rdata_en;

	wire			w_bus_vdp_ioreq;
	wire			w_bus_vdp_hit;
	wire			w_bus_vdp_ready;
	wire	[7:0]	w_bus_vdp_rdata;
	wire			w_bus_vdp_rdata_en;
	wire			w_bus_vdp_write_done;
	wire			w_slot_vdp_wait;

	wire			w_sdram_init_busy;

	wire	[22:2]	w_sdram_address;
	wire			w_sdram_write;
	wire			w_sdram_valid;
	wire			w_sdram_refresh;
	wire	[31:0]	w_sdram_wdata;
	wire	[3:0]	w_sdram_wdata_mask;
	wire	[31:0]	w_sdram_rdata;
	wire			w_sdram_rdata_en;

	wire			w_video_de;
	wire			w_video_hs;
	wire			w_video_vs;
	wire	[7:0]	w_video_r;
	wire	[7:0]	w_video_g;
	wire	[7:0]	w_video_b;
	wire			w_hdmi_de;
	wire			w_hdmi_hs;
	wire			w_hdmi_vs;
	wire	[7:0]	w_hdmi_r;
	wire	[7:0]	w_hdmi_g;
	wire	[7:0]	w_hdmi_b;
	wire			w_hdmi_overflow;
	wire			w_hdmi_underflow;
	wire			w_hdmi_input_error;
	reg		[1:0]	ff_hdmi_error = 2'b00;

	wire			w_pulse0;
	wire			w_pulse1;
	wire			w_pulse2;
	wire			w_pulse3;
	wire			w_pulse4;
	wire			w_pulse5;
	wire			w_pulse6;
	wire			w_pulse7;
	wire			w_wr;
	wire			w_sending;
	wire	[7:0]	w_red;
	wire	[7:0]	w_green;
	wire	[7:0]	w_blue;
	wire			w_int_n;
	wire			w_pcm_fs;
	wire	[23:0]	w_pcm_l;
	wire	[23:0]	w_pcm_r;

	assign slot_wait		= w_sdram_init_busy | w_slot_vdp_wait;
	assign oe_n				= 1'b0;

	always @( posedge clk85m ) begin
		ff_reset_n0		<= slot_reset_n;
		ff_reset_n1		<= ff_reset_n0;
		ff_reset_n2		<= ff_reset_n1;
	end

	always @( posedge clk28m ) begin
		ff_reset2_n0	<= slot_reset_n;
		ff_reset2_n1	<= ff_reset2_n0;
		ff_reset2_n2	<= ff_reset2_n1;
	end

	always @( posedge clk85m ) begin
		ff_reset3_n0	<= slot_reset_n;
		ff_reset3_n1	<= ff_reset3_n0;
		ff_reset3_n2	<= ff_reset3_n1;
	end

	assign reset_n	= ff_reset_n2;
	assign reset_n2	= ff_reset2_n2;
	assign reset_n3	= ff_reset3_n2;

	// --------------------------------------------------------------------
	//	clock
	// --------------------------------------------------------------------
	Gowin_rPLL u_pll (
		.clkout			( clk143m			),		//	output clkout	143.1818MHz
		.clkin			( clk14m			)		//	input clkin		14.31818MHz
	);

	Gowin_rPLL2 u_pll2 (
		.clkout			( clk85m			),		//	output clkout	85.90908MHz
		.lock			( pll_lock85		),
		.clkoutp		( clk85m_n			),		//	output clkoutp	85.90908MHz (180deg phase shift)
		.clkoutd		( clk42m			),		//	output clkoutd	42.95454MHz (CLKOUT / 2, geo3d engine only)
		.clkin			( clk14m			)		//	input clkin		14.31818MHz
    );

	Gowin_CLKDIV your_instance_name(
		.clkout			( clk28m			),		//	output clkout	28.63636MHz
		.hclkin			( clk143m			),		//	input hclkin	143.1818MHz
		.resetn			( 1'b1				)		//	input resetn
	);

	// --------------------------------------------------------------------
	//	FullColor Intelligent LED
	// --------------------------------------------------------------------
	msx_slot u_msx_slot (
		.clk				( clk85m					),
		.initial_busy		( w_sdram_init_busy			),
		.p_slot_reset_n		( reset_n					),
		.p_slot_ioreq_n		( slot_iorq_n				),
		.p_slot_wr_n		( slot_wr_n					),
		.p_slot_rd_n		( slot_rd_n					),
		.p_slot_address		( slot_a					),
		.p_slot_data		( slot_d					),
		.p_slot_int			( slot_intr					),
		.p_slot_data_dir	( slot_data_dir				),
		.p_slot_wait		( w_slot_vdp_wait			),
		.int_n				( w_int_n					),
		.bus_address		( w_bus_address				),
		.bus_ioreq			( w_bus_ioreq				),
		.bus_sysctrl_address ( w_bus_sysctrl_address	),
		.bus_sysctrl_ioreq	( w_bus_sysctrl_ioreq		),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_ready			( w_bus_ready				),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_rdata				),
		.bus_rdata_en		( w_bus_rdata_en			),
		.bus_vdp_write_done	( w_bus_vdp_write_done		),
		.dipsw				( dipsw[0]					)
	);

	// --------------------------------------------------------------------
	//	geo3d coprocessor (ports base+5 / base+7)
	// --------------------------------------------------------------------
	wire			w_geo_hit;
	wire			w_geo_ready;
	wire	[7:0]	w_geo_rdata;
	wire			w_geo_rdata_en;
	wire			w_geo_cmd_wr;
	wire	[5:0]	w_geo_cmd_num;
	wire	[7:0]	w_geo_cmd_data;
	wire			w_geo_cmd_ce;
	wire			w_geo_run_busy;

	geo3d_bus u_geo3d (
		.clk				( clk85m					),
		.clk_eng			( clk42m					),
		.reset_n			( reset_n3					),
		.bus_address		( w_bus_address				),
		.bus_ioreq			( w_bus_ioreq				),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid				),
		.bus_wdata			( w_bus_wdata				),
		.hit				( w_geo_hit					),
		.bus_ready			( w_geo_ready				),
		.bus_rdata			( w_geo_rdata				),
		.bus_rdata_en		( w_geo_rdata_en			),
		.cmd_wr				( w_geo_cmd_wr				),
		.cmd_num			( w_geo_cmd_num				),
		.cmd_data			( w_geo_cmd_data			),
		.cmd_ce				( w_geo_cmd_ce				),
		.run_busy			( w_geo_run_busy			)
	);

	assign w_bus_rdata		= ( w_bus_sysctrl_rdata_en ) ? w_bus_sysctrl_rdata:
						  ( w_geo_rdata_en		) ? w_geo_rdata:
						  ( w_bus_vdp_rdata_en	) ? w_bus_vdp_rdata: 8'hFF;
	assign w_bus_rdata_en	= w_bus_sysctrl_rdata_en | w_bus_vdp_rdata_en | w_geo_rdata_en;
	// Offset 6 is reserved for MegaRAM, not a VDP port.
	assign w_bus_vdp_hit	= w_bus_ioreq && w_bus_address <= 3'd4;
	//	System Controller accesses during a ROM command are dropped, not retried.
	assign w_bus_ready		= w_bus_sysctrl_ioreq ? 1'b1:
							  w_geo_hit ? w_geo_ready:
							  w_bus_vdp_hit ? w_bus_vdp_ready: 1'b1;

	// --------------------------------------------------------------------
	//	Config ROM Reader/Writer (I/O 40h-4Fh)
	// --------------------------------------------------------------------
	system_controller u_system_controller (
		.clk				( clk85m					),
		.reset_n			( reset_n					),
		.bus_cs				( w_bus_sysctrl_ioreq		),
		.bus_address		( w_bus_sysctrl_address		),
		.bus_valid			( w_bus_valid				),
		.bus_ready			(							),
		.bus_write			( w_bus_write				),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_sysctrl_rdata		),
		.bus_rdata_en		( w_bus_sysctrl_rdata_en	),
		.rom_bus_address	( w_rom_bus_address			),
		.rom_bus_valid		( w_rom_bus_valid			),
		.rom_bus_ready		( w_rom_bus_ready			),
		.rom_bus_write		( w_rom_bus_write			),
		.rom_bus_wdata		( w_rom_bus_wdata			),
		.rom_bus_rdata		( w_rom_bus_rdata			),
		.rom_bus_rdata_en	( w_rom_bus_rdata_en		)
	);

	ip_spi_rom u_spi_rom (
		.reset_n			( reset_n					),
		.clk				( clk85m					),
		.clk_serial			( clk143m					),
		.bus_cs				( 1'b1						),
		.bus_address		( w_rom_bus_address			),
		.bus_write			( w_rom_bus_write			),
		.bus_valid			( w_rom_bus_valid			),
		.bus_ready			( w_rom_bus_ready			),
		.bus_wdata			( w_rom_bus_wdata			),
		.bus_rdata			( w_rom_bus_rdata			),
		.bus_rdata_en		( w_rom_bus_rdata_en		),
		.stream_rdata		(							),
		.stream_valid		(							),
		.stream_ready		( 1'b0						),
		.stream_stop		( 1'b0						),
		.srom_cs_n			( mspi_cs					),
		.srom_clk			( mspi_clk					),
		.srom_hold_n		( mspi_hold					),
		.srom_wp_n			( mspi_wp					),
		.srom_do			( mspi_do					),
		.srom_di			( mspi_di					)
	);

	// --------------------------------------------------------------------
	//	V9968 core
	// --------------------------------------------------------------------
	vdp u_v9968 (
		.reset_n			( reset_n3					),
		.clk				( clk85m					),
		.initial_busy		( w_sdram_init_busy			),
		.bus_address		( w_bus_address				),
		.bus_ioreq			( w_bus_ioreq				),
		.bus_write			( w_bus_write				),
		.bus_valid			( w_bus_valid & w_bus_vdp_hit ),
		.bus_ready			( w_bus_vdp_ready			),
		.bus_wdata			( w_bus_wdata				),
		.bus_rdata			( w_bus_vdp_rdata			),
		.bus_rdata_en		( w_bus_vdp_rdata_en		),
		.bus_write_done		( w_bus_vdp_write_done		),
		.int_n				( w_int_n					),
		.vram_address		( w_sdram_address[17:2]		),
		.vram_write			( w_sdram_write				),
		.vram_valid			( w_sdram_valid				),
		.vram_wdata			( w_sdram_wdata				),
		.vram_wdata_mask	( w_sdram_wdata_mask		),
		.vram_rdata			( w_sdram_rdata				),
		.vram_rdata_en		( w_sdram_rdata_en			),
		.vram_refresh		( w_sdram_refresh			),
		.display_hs			( w_video_hs				),
		.display_vs			( w_video_vs				),
		.display_en			( w_video_de				),
		.display_r			( w_video_r					),
		.display_g			( w_video_g					),
		.display_b			( w_video_b					),
		.ext_cmd_wr			( w_geo_cmd_wr				),
		.ext_cmd_num		( w_geo_cmd_num				),
		.ext_cmd_data		( w_geo_cmd_data			),
		.ext_cmd_ce			( w_geo_cmd_ce				),
		.force_highspeed	( dipsw[1]					),
		.button				( button					),
		.pulse0				( w_pulse0					),
		.pulse1				( w_pulse1					),
		.pulse2				( w_pulse2					),
		.pulse3				( w_pulse3					),
		.pulse4				( w_pulse4					),
		.pulse5				( w_pulse5					),
		.pulse6				( w_pulse6					),
		.pulse7				( w_pulse7					)
	);

	assign w_sdram_address[22:18]	= 5'd0;

	// --------------------------------------------------------------------
	//	HDMI
	// --------------------------------------------------------------------
	hdmi_converter u_hdmi_converter (
		.reset_n			( slot_reset_n & pll_lock85	),
		.clk42m				( clk42m					),
		.clk28m				( clk28m					),
		.video_de			( w_video_de				),
		.video_vs			( w_video_vs				),
		.video_r			( w_video_r					),
		.video_g			( w_video_g					),
		.video_b			( w_video_b					),
		.display_hs			( w_hdmi_hs					),
		.display_vs			( w_hdmi_vs					),
		.display_en			( w_hdmi_de					),
		.display_r			( w_hdmi_r					),
		.display_g			( w_hdmi_g					),
		.display_b			( w_hdmi_b					),
		.locked				(							),
		.overflow			( w_hdmi_overflow			),
		.underflow			( w_hdmi_underflow			),
		.input_error		( w_hdmi_input_error			)
	);

	always @( posedge clk85m ) begin
		if( !reset_n )
			ff_hdmi_error <= 2'b00;
		else
			ff_hdmi_error <= { ff_hdmi_error[0],
				w_hdmi_overflow | w_hdmi_underflow | w_hdmi_input_error };
	end

	hdmi_tx #(
		.DEVICE_FAMILY		( ""						),
		.CLOCK_FREQUENCY	( 28.63636					),		//	Input clock frequency (MHz)
		.ENCODE_MODE		( "HDMI"					),		//	HDMI
		.USE_EXTCONTROL		( "OFF"						),		//	Generate HDMI preamble/guardband from active
		.SYNC_POLARITY		( "NEGATIVE"				),		//	Invert HSYNC/VSYNC to send
		.SCANMODE			( "AUTO"					),		//	Displays decides
		.PICTUREASPECT		( "NONE"					),		//	Picture aspect ratio information not present
		.FORMATASPECT		( "AUTO"					),		//	Same as picture
		.PICTURESCALING		( "FIT"						),		//	Picture has been scaled H and V
		.COLORSPACE			( "RGB"						),		//	RGB888 (Fixed at Full range)
		.YCC_DATARANGE		( "LIMITED"					),		//	Limited data range(16-235,240)
		.CONTENTTYPE		( "GRAPHICS"				),		//	for PC use(IT Content)
		.REPETITION			( 0							),		//	Pixel Repetition Factor (0-9)
		.VIDEO_CODE			( 0							),		//	Video Information Codes (1-59, 0=No data)
		.USE_AUDIO_PACKET	( "ON"						),		//	Use Audio sample packet
		.AUDIO_FREQUENCY	( 48.0						),		//	Audio sampling frequency (KHz)
		.PCMFIFO_DEPTH		( 8							),		//	Sample data fifo depth : 8=256word(35sample)
		.CATEGORY_CODE		( 8'h00						)
	) u_hdmi_tx (
		.reset				( ~reset_n2					),		//	active high
		.clk				( clk28m					),		//	28.63636MHz pixel clock
		.clk_x5				( clk143m					),		//	143.18180MHz = 5 * 28.63636MHz
		.cc_swap			( 							),		//	Type-C AltMode swap option
		.control			( 4'd0						),		//	HDMI control from video_syncgen
		.active				( w_hdmi_de					),		//	Pixel data active
		.r_data				( w_hdmi_r					),		//	R
		.g_data				( w_hdmi_g					),		//	G
		.b_data				( w_hdmi_b					),		//	B
		.hsync				( w_hdmi_hs					),		//	Horizontal sync
		.vsync				( w_hdmi_vs					),		//	Vertical sync
		.pcm_fs				( w_pcm_fs					),		//	sound
		.pcm_l				( w_pcm_l					),		//	sound
		.pcm_r				( w_pcm_r					),		//	sound
		.data				( tmds_d_p					),		//	TMDS data
		.data_n				( 							),		//	unused: LVDS25 output by CST
		.clock				( tmds_clk_p				),		//	TMDS clock
		.clock_n			( 							)		//	unused: LVDS25 output by CST
	);
	assign w_pcm_fs = 1'b0;
	assign w_pcm_l	= 24'd0;
	assign w_pcm_r	= 24'd0;

	// --------------------------------------------------------------------
	//	SDRAM
	// --------------------------------------------------------------------
	ip_sdram #(
		.FREQ				( 85_909_080				)		//	Hz
	) u_sdram (
		.reset_n			( reset_n					),
		.clk				( clk85m					),		//	85.90908MHz
		.clk_sdram			( clk85m_n					),
		.sdram_init_busy	( w_sdram_init_busy			),
		.bus_address		( w_sdram_address			),
		.bus_valid			( w_sdram_valid				),
		.bus_write			( w_sdram_write				),
		.bus_refresh		( w_sdram_refresh			),
		.bus_wdata			( w_sdram_wdata				),
		.bus_wdata_mask		( w_sdram_wdata_mask		),
		.bus_rdata			( w_sdram_rdata				),
		.bus_rdata_en		( w_sdram_rdata_en			),
		.O_sdram_clk		( O_sdram_clk				),
		.O_sdram_cke		( O_sdram_cke				),
		.O_sdram_cs_n		( O_sdram_cs_n				),		// chip select
		.O_sdram_ras_n		( O_sdram_ras_n				),		// row address select
		.O_sdram_cas_n		( O_sdram_cas_n				),		// columns address select
		.O_sdram_wen_n		( O_sdram_wen_n				),		// write enable
		.IO_sdram_dq		( IO_sdram_dq				),		// 32 bit bidirectional data bus
		.O_sdram_addr		( O_sdram_addr				),		// 11 bit multiplexed address bus
		.O_sdram_ba			( O_sdram_ba				),		// two banks
		.O_sdram_dqm		( O_sdram_dqm				)		// data mask
	);

	// --------------------------------------------------------------------
	//	Debug�p LED
	// --------------------------------------------------------------------
	ip_ws2812_led u_led (
		.reset_n			( reset_n					),
		.clk				( clk85m					),
		.wr					( w_wr | (ff_hdmi_error[1] & ~w_sending) ),
		.sending			( w_sending					),
		.red				( ff_hdmi_error[1] ? 8'hFF : w_red	),
		.green				( ff_hdmi_error[1] ? 8'h00 : w_green	),
		.blue				( ff_hdmi_error[1] ? 8'h00 : w_blue	),
		.ws2812_led			( ws2812_led				)
	);

	// --------------------------------------------------------------------
	//	Debugger
	// --------------------------------------------------------------------
	ip_debugger u_debugger (
		.reset_n			( reset_n					),
		.clk				( clk85m					),
		.pulse0				( w_pulse0					),
		.pulse1				( w_pulse1					),
		.pulse2				( w_pulse2					),
		.pulse3				( w_pulse3					),
		.pulse4				( w_pulse4					),
		.pulse5				( w_pulse5					),
		.pulse6				( w_pulse6					),
		.pulse7				( w_pulse7					),
		.wr					( w_wr						),
		.sending			( w_sending					),
		.red				( w_red						),
		.green				( w_green					),
		.blue				( w_blue					)
	);
endmodule
