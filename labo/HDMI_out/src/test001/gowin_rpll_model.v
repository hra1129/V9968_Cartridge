// -----------------------------------------------------------------------------
//	Simulation model of Gowin_rPLL
//	27MHz --> 135MHz
// -----------------------------------------------------------------------------

module Gowin_rPLL (
	output			clkout,
	input			clkin
);
	// 135MHz : half period = 500000 / 135 ≈ 3703.7ps
	localparam		CLK135M_HALF_PS	= 3704;

	reg				ff_clkout = 1'b0;

	always #(CLK135M_HALF_PS) begin
		ff_clkout <= ~ff_clkout;
	end

	assign clkout = ff_clkout;
endmodule
