module Gowin_CLKDIV (
	output			clkout,
	input			hclkin,
	input			resetn
);
	assign clkout = hclkin;
endmodule

module Gowin_rPLL (
	output			clkout,
	output			lock,
	input			clkin
);
	assign lock		= 1'b1;
	assign clkout	= clkin;
endmodule

//	Note: clkoutd added for the current top module, which connects
//	.clkoutd ( clk42m ) = CLKOUT/2 (geo3d engine only).
module Gowin_rPLL2 (
	output			clkout,
	output			lock,
	output			clkoutp,
	output			clkoutd,
	input			clkin
);
	reg				ff_clkoutd = 1'b0;
	assign lock		= 1'b1;
	assign clkout	= clkin;
	assign clkoutp	= ~clkin;
	assign clkoutd	= ff_clkoutd;
	always @( posedge clkin ) begin
		ff_clkoutd <= ~ff_clkoutd;
	end
endmodule

module DVI_TX_Top (
	input			I_rst_n,
	input			I_serial_clk,
	input			I_rgb_clk,
	input			I_rgb_vs,
	input			I_rgb_hs,
	input			I_rgb_de,
	input	[7:0]	I_rgb_r,
	input	[7:0]	I_rgb_g,
	input	[7:0]	I_rgb_b,
	output			O_tmds_clk_p,
	output			O_tmds_clk_n,
	output	[2:0]	O_tmds_data_p,
	output	[2:0]	O_tmds_data_n 
);
	assign O_tmds_clk_p		= 1'b0;
	assign O_tmds_clk_n		= 1'b0;
	assign O_tmds_data_p	= 3'd0;
	assign O_tmds_data_n	= 3'd0;
endmodule

// --------------------------------------------------------------------
//	Stub for the VHDL hdmi_tx instantiated by the current
//	tangnano20k_vdp_cartridge.v (u_hdmi_tx). Outputs tied to 0.
// --------------------------------------------------------------------
module hdmi_tx #(
	parameter	DEVICE_FAMILY	= "",
	parameter	CLOCK_FREQUENCY	= 28.63636,
	parameter	ENCODE_MODE		= "HDMI",
	parameter	USE_EXTCONTROL	= "OFF",
	parameter	SYNC_POLARITY	= "NEGATIVE",
	parameter	SCANMODE		= "AUTO",
	parameter	PICTUREASPECT	= "NONE",
	parameter	FORMATASPECT	= "AUTO",
	parameter	PICTURESCALING	= "FIT",
	parameter	COLORSPACE		= "RGB",
	parameter	YCC_DATARANGE	= "LIMITED",
	parameter	CONTENTTYPE		= "GRAPHICS",
	parameter	REPETITION		= 0,
	parameter	VIDEO_CODE		= 0,
	parameter	USE_AUDIO_PACKET	= "ON",
	parameter	AUDIO_FREQUENCY	= 48.0,
	parameter	PCMFIFO_DEPTH	= 8,
	parameter	CATEGORY_CODE	= 8'h00
)(
	input			reset,
	input			clk,
	input			clk_x5,
	input			cc_swap,
	input	[3:0]	control,
	input			active,
	input	[7:0]	r_data,
	input	[7:0]	g_data,
	input	[7:0]	b_data,
	input			hsync,
	input			vsync,
	input			pcm_fs,
	input	[23:0]	pcm_l,
	input	[23:0]	pcm_r,
	output	[2:0]	data,
	output	[2:0]	data_n,
	output			clock,
	output			clock_n
);
	assign data		= 3'd0;
	assign data_n	= 3'd0;
	assign clock	= 1'b0;
	assign clock_n	= 1'b0;
endmodule
