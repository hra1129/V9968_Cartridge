`timescale 1ns/1ps

module tb_line_interrupt;
	// 割込み経路だけを使い、それ以外のVDP入出力ポートは未接続。
	reg test_passed = 1'b0;
	reg clk = 1'b0;
	reg reset_n = 1'b0;
	reg intr_line = 1'b0;
	reg intr_frame = 1'b0;
	reg intr_command_end = 1'b0;
	reg clear_line_interrupt = 1'b0;
	wire int_n;
	wire [7:0] bus_rdata;

	always #5 clk = ~clk;

	vdp_cpu_interface dut (
		.clk						( clk						),
		.reset_n					( reset_n					),
		.bus_address				( 3'd0						),
		.bus_ioreq					( 1'b0						),
		.bus_write					( 1'b0						),
		.bus_valid					( 1'b0						),
		.bus_wdata					( 8'd0						),
		.bus_rdata					( bus_rdata					),
		.int_n						( int_n						),
		.intr_line					( intr_line					),
		.intr_frame					( intr_frame				),
		.intr_command_end			( intr_command_end			),
		.clear_line_interrupt		( clear_line_interrupt		),
		.sprite_overmap				( 1'b1						),
		.sprite_overmap_id			( 5'd0						),
		.sprite_collision			( 1'b0						)
	);

	initial begin
		repeat (2) @(negedge clk);
		reset_n = 1'b1;
		force dut.ff_line_interrupt_enable = 1'b1;

		@(negedge clk);
		intr_line = 1'b1;
		@(negedge clk);
		intr_line = 1'b0;
		if (int_n !== 1'b0) $fatal(1, "line interrupt was not asserted");

		intr_frame = 1'b1;
		@(negedge clk);
		intr_frame = 1'b0;
		if (int_n !== 1'b0) $fatal(1, "frame interrupt cleared a pending line interrupt");

		clear_line_interrupt = 1'b1;
		@(negedge clk);
		clear_line_interrupt = 1'b0;
		if (int_n !== 1'b0) $fatal(1, "frame clear pulse cleared a pending line interrupt");

		release dut.ff_line_interrupt_enable;
		force dut.ff_line_interrupt_enable = 1'b0;
		intr_frame = 1'b1;
		@(negedge clk);
		intr_frame = 1'b0;
		if (int_n !== 1'b1) $fatal(1, "disabled line interrupt was not cleared at frame");

		release dut.ff_line_interrupt_enable;
		force dut.ff_line_interrupt_enable = 1'b1;
		@(negedge clk);
		intr_line = 1'b1;
		intr_frame = 1'b1;
		@(negedge clk);
		intr_line = 1'b0;
		intr_frame = 1'b0;
		if (int_n !== 1'b0) $fatal(1, "simultaneous line interrupt was lost at frame");

		force dut.w_read = 1'b1;
		force dut.ff_port1 = 1'b1;
		force dut.ff_status_register_pointer = 4'd1;
		@(negedge clk);
		release dut.w_read;
		release dut.ff_port1;
		release dut.ff_status_register_pointer;
		if (int_n !== 1'b1) $fatal(1, "reading status register 1 did not clear the line interrupt");

		force dut.w_read = 1'b1;
		force dut.ff_port1 = 1'b1;
		force dut.ff_status_register_pointer = 4'd0;
		intr_line = 1'b1;
		@(negedge clk);
		intr_line = 1'b0;
		release dut.w_read;
		release dut.ff_port1;
		release dut.ff_status_register_pointer;
		if (int_n !== 1'b0) $fatal(1, "line interrupt coincident with S#0 read was lost");

		force dut.ff_status_register_pointer = 4'd1;
		force dut.ff_port1 = 1'b1;
		force dut.w_read = 1'b1;
		@(negedge clk);
		release dut.w_read;
		if (int_n !== 1'b1) $fatal(1, "S#1 read failed to clear FH");
		repeat (2) @(negedge clk);
		intr_line = 1'b1;
		@(negedge clk);
		intr_line = 1'b0;
		force dut.w_read = 1'b1;
		@(negedge clk);
		release dut.w_read;
		if (bus_rdata[0] !== 1'b1 || int_n !== 1'b1)
			$fatal(1, "S#1 returned stale FH before clearing it");

		intr_line = 1'b1;
		force dut.w_read = 1'b1;
		@(negedge clk);
		intr_line = 1'b0;
		release dut.w_read;
		if (bus_rdata[0] !== 1'b0 || int_n !== 1'b0)
			$fatal(1, "new FH coincident with S#1 read was lost");

		force dut.w_read = 1'b1;
		intr_frame = 1'b1;
		@(negedge clk);
		intr_frame = 1'b0;
		release dut.w_read;
		if (dut.ff_frame_interrupt !== 1'b1)
			$fatal(1, "frame interrupt coincident with S#1 read was lost");

		force dut.ff_status_register_pointer = 4'd0;
		repeat (2) @(negedge clk);
		force dut.w_read = 1'b1;
		@(negedge clk);
		release dut.w_read;
		if (dut.ff_frame_interrupt !== 1'b0) $fatal(1, "S#0 read failed to clear F");
		repeat (2) @(negedge clk);
		intr_frame = 1'b1;
		@(negedge clk);
		intr_frame = 1'b0;
		force dut.w_read = 1'b1;
		@(negedge clk);
		release dut.w_read;
		if (bus_rdata[7] !== 1'b1 || bus_rdata[6] !== 1'b0)
			$fatal(1, "S#0 returned stale F or failed to mask 5S");
		release dut.ff_port1;
		release dut.ff_status_register_pointer;

		force dut.ff_port1 = 1'b0;
		force dut.ff_port4 = 1'b1;
		force dut.ff_bus_wdata = 8'h07;
		force dut.w_write = 1'b1;
		intr_line = 1'b1;
		intr_frame = 1'b1;
		intr_command_end = 1'b1;
		@(negedge clk);
		intr_line = 1'b0;
		intr_frame = 1'b0;
		intr_command_end = 1'b0;
		if (dut.ff_line_interrupt !== 1'b1 || dut.ff_frame_interrupt !== 1'b1 ||
		    dut.ff_command_end_interrupt !== 1'b1)
			$fatal(1, "new interrupt coincident with port 4 ACK was lost");
		@(negedge clk);
		if (dut.ff_line_interrupt !== 1'b0 || dut.ff_frame_interrupt !== 1'b0 ||
		    dut.ff_command_end_interrupt !== 1'b0)
			$fatal(1, "port 4 ACK failed to clear pending interrupts");
		release dut.w_write;
		release dut.ff_port4;
		release dut.ff_bus_wdata;
		release dut.ff_port1;

		for (integer i = 0; i < 2; i = i + 1) begin
			intr_line = 1'b1;
			@(negedge clk);
			intr_line = 1'b0;
			if (int_n !== 1'b0) $fatal(1, "line interrupt was not asserted");
			force dut.ff_register_write = 1'b1;
			if (i == 0) force dut.ff_register_num = 6'd0;
			else force dut.ff_register_num = 6'd19;
			@(negedge clk);
			release dut.ff_register_write;
			release dut.ff_register_num;
			if (int_n !== 1'b1) $fatal(1, "R#0/R#19 write did not clear FH");
			repeat (2) @(negedge clk);
		end

		$display("PASS: interrupt flags survive coincident reads and ACKs");
		test_passed = 1'b1;
		$finish;
	end
endmodule
