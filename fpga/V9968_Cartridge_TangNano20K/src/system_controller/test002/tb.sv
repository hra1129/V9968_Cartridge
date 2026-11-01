// MSX slot/System Controller routing, read bus release, and busy access regression.
module tb;
	reg test_passed = 0;
	reg clk = 0;
	always #5820 clk = ~clk;
	reg reset_n = 0, initial_busy = 1, dipsw = 0;
	reg ioreq_n = 1, wr_n = 1, rd_n = 1;
	reg [7:0] address = 0, wdata = 0;
	wire [7:0] data;
	wire data_dir;
	wire slot_wait;
	assign data = !wr_n ? wdata : 8'hZZ;
	wire [2:0] bus_address;
	wire [3:0] sys_address;
	wire vdp_cs, sys_cs, valid, write;
	wire [7:0] bus_wdata, sys_rdata;
	wire sys_rdata_en, sys_ready;
	reg legacy_rdata_en = 0;
	reg [7:0] legacy_rdata;
	reg rom_ready = 0;
	wire [7:0] bus_rdata = sys_rdata_en ? sys_rdata : legacy_rdata;
	wire bus_rdata_en = sys_rdata_en | legacy_rdata_en;
	integer vdp_count = 0, sys_count = 0;
	integer seen_vdp, seen_sys, before_vdp, before_sys;

	msx_slot u_slot (
		.clk(clk), .initial_busy(initial_busy), .p_slot_reset_n(reset_n),
		.p_slot_ioreq_n(ioreq_n), .p_slot_wr_n(wr_n), .p_slot_rd_n(rd_n),
		.p_slot_address(address), .p_slot_data(data), .p_slot_int(),
		.p_slot_data_dir(data_dir), .p_slot_wait(slot_wait), .int_n(1'b1),
		.bus_address(bus_address), .bus_ioreq(vdp_cs),
		.bus_sysctrl_address(sys_address), .bus_sysctrl_ioreq(sys_cs),
		.bus_write(write), .bus_valid(valid), .bus_ready(1'b1),
		.bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
		.bus_vdp_write_done(valid && vdp_cs && write),
		.dipsw(dipsw)
	);
	system_controller u_controller (
		.clk(clk), .reset_n(reset_n), .bus_cs(sys_cs), .bus_address(sys_address),
		.bus_valid(valid), .bus_ready(sys_ready), .bus_write(write),
		.bus_wdata(bus_wdata), .bus_rdata(sys_rdata), .bus_rdata_en(sys_rdata_en),
		.rom_bus_address(), .rom_bus_valid(), .rom_bus_ready(rom_ready),
		.rom_bus_write(), .rom_bus_wdata(), .rom_bus_rdata(8'h00), .rom_bus_rdata_en(1'b0)
	);
	always @(posedge clk) begin
		legacy_rdata_en <= valid && vdp_cs && !write;
		legacy_rdata <= 8'hE0 | {5'd0, bus_address};
		if( valid && vdp_cs ) begin
			vdp_count = vdp_count + 1;
			seen_vdp = bus_address;
		end
		if( valid && sys_cs ) begin
			sys_count = sys_count + 1;
			seen_sys = sys_address;
		end
		if( vdp_cs && sys_cs ) $fatal(1, "Overlapping chip selects");
	end

	task access(input wr, input [7:0] port, input [7:0] value,
				input expected_en, input [7:0] expected_data, input integer route);
		@(negedge clk);
		before_vdp = vdp_count;
		before_sys = sys_count;
		address = port;
		wdata = value;
		wr_n = !wr;
		rd_n = wr;
		ioreq_n = 0;
		#1;
		if( (route != 1 || port[2:0] >= 3'd5) && slot_wait !== 1'b0 )
			$fatal(1, "Unexpected WAIT on port %h", port);
		repeat(40) @(negedge clk);
		if( data_dir !== expected_en || (!wr && expected_en && data !== expected_data) )
			$fatal(1, "Port %h: dir=%b data=%h expected dir=%b data=%h",
				port, data_dir, data, expected_en, expected_data);
		if( !wr && !expected_en && data !== 8'hZZ ) $fatal(1, "Read bus not released");
		if( vdp_count - before_vdp != (route == 1) ||
			sys_count - before_sys != (route == 2) )
			$fatal(1, "Port %h: wrong route or repeated access", port);
		if( route == 1 && seen_vdp != port[2:0] ) $fatal(1, "Wrong legacy address");
		if( route == 2 && seen_sys != port[3:0] ) $fatal(1, "Wrong system address");
		ioreq_n = 1;
		wr_n = 1;
		rd_n = 1;
		repeat(15) @(negedge clk);
		if( data_dir !== 0 || data !== 8'hZZ ) $fatal(1, "Idle bus not released");
	endtask

	integer i, bank;
	initial begin
		repeat(5) @(negedge clk);
		reset_n = 1;
		repeat(5) @(negedge clk);
		access(1, 8'h40, 8'h80, 0, 0, 0);
		initial_busy = 0;
		repeat(5) @(negedge clk);
		for( bank = 0; bank < 2; bank = bank + 1 ) begin
			dipsw = bank[0];
			for( i = 8'h40; i <= 8'h4F; i = i + 1 )
				access(0, i[7:0], 0, 0, 0, 2);
			for( i = 0; i < 8; i = i + 1 ) begin
				access(0, (bank ? 8'h98 : 8'h88) + i[7:0], 0, 1, 8'hE0 + i[7:0], 1);
				access(0, (bank ? 8'h88 : 8'h98) + i[7:0], 0, 0, 0, 0);
			end
			access(0, 8'h3F, 0, 0, 0, 0);
			access(0, 8'h50, 0, 0, 0, 0);
		end
		access(1, 8'h40, 8'h80, 0, 0, 2);
		access(0, 8'h40, 0, 1, 8'h7F, 2);
		access(1, 8'h41, 8'h02, 0, 0, 2);
		access(0, 8'h41, 0, 0, 0, 2);
		access(1, 8'h41, 8'h01, 0, 0, 2);
		access(0, 8'h41, 0, 1, 8'hFE, 2);
		access(1, 8'h42, 8'h01, 0, 0, 2);
		access(0, 8'h42, 0, 1, 8'hFE, 2);
		access(1, 8'h46, 8'h01, 0, 0, 2);
		if( sys_ready ) $fatal(1, "Expected command busy");
		access(0, 8'h40, 0, 0, 0, 2);
		access(1, 8'h40, 0, 0, 0, 2);
		access(0, 8'h98, 0, 1, 8'hE0, 1);
		access(0, 8'h9D, 0, 1, 8'hE5, 1);
		access(0, 8'h9F, 0, 1, 8'hE7, 1);
		rom_ready = 1;
		wait(sys_ready);
		access(0, 8'h40, 0, 1, 8'h7F, 2);
		access(0, 8'h41, 0, 1, 8'hFE, 2);
		test_passed = 1;
		$display("[RESULT] ALL TESTS PASSED: slot decode, bus release, busy access isolation");
		$finish;
	end

	initial begin
		#500_000_000;
		$fatal(1, "Simulation timeout");
	end
endmodule
