// -----------------------------------------------------------------------------
//	Simulation model of Gowin_rPLL2
//	14.31818MHz --> 85.90908MHz (clkout, clkoutp=180deg)
// -----------------------------------------------------------------------------

module Gowin_rPLL2 (
	output			clkout,
	output			lock,
	output			clkoutp,
	input			clkin
);
	// 85.90908MHz : half period = 500000 / 85.90908 ≈ 5820.1ps
	localparam		CLK85M_HALF_PS	= 5820;
	localparam		LOCK_TIME_PS	= 100_000;		//	100ns

	reg				ff_clkout = 1'b0;
	reg				ff_lock = 1'b0;

	initial begin
		#(LOCK_TIME_PS);
		ff_lock = 1'b1;
	end

	always #(CLK85M_HALF_PS) begin
		ff_clkout <= ~ff_clkout;
	end

	assign clkout	= ff_clkout;
	assign clkoutp	= ~ff_clkout;		//	180 degree phase shift
	assign lock		= ff_lock;
endmodule
