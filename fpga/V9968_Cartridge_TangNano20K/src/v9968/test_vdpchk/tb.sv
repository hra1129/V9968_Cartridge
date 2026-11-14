// -----------------------------------------------------------------------------
//	test_vdpchk: runs the VDPCHK.COM test script (test/VDPCHK/vdpchk.hex) on the VDP RTL
//
//	FILLP / FILLC / READ use a backdoor to the VRAM model after the shared cache has
//	been flushed.  Registers, status, CPU VRAM access (CPUW/CPUR) and CPU transfers
//	(FEED/DRAIN) go through the bus like on the real machine.
//
//	plusargs: +dir=<folder of vdpchk.hex and pat.hex>  +from=<first test>  +to=<last test>
//	For every failed test the read log is written to fail_<n>.hex.
// -----------------------------------------------------------------------------
`timescale 1ns/1ps
module tb;
	reg clk = 0, reset_n = 0; always #5 clk = ~clk;
	reg [2:0] ba = 0; reg bv = 0, bw = 0; reg [7:0] bd = 0;
	wire br; wire [7:0] brd; wire brde, bwd, int_n;
	wire [17:2] va; wire vw, vv, vref; wire [31:0] vwd; wire [3:0] vm; wire [31:0] vrd; wire vre;
	wire dhs, dvs, den; wire [7:0] dr, dg, db;
	vdp u (.reset_n(reset_n), .clk(clk), .initial_busy(1'b0),
		.bus_address(ba), .bus_ioreq(1'b1), .bus_write(bw), .bus_valid(bv), .bus_ready(br), .bus_wdata(bd),
		.bus_rdata(brd), .bus_rdata_en(brde), .bus_write_done(bwd), .int_n(int_n),
		.vram_address(va), .vram_write(vw), .vram_valid(vv), .vram_wdata(vwd), .vram_wdata_mask(vm),
		.vram_rdata(vrd), .vram_rdata_en(vre), .vram_refresh(vref),
		.display_hs(dhs), .display_vs(dvs), .display_en(den), .display_r(dr), .display_g(dg), .display_b(db),
		.force_highspeed(1'b0), .ext_cmd_wr(1'b0), .ext_cmd_num(6'd0), .ext_cmd_data(8'd0), .ext_cmd_fill_span(1'b0),
		.ext_cmd_ce(), .button(2'b00), .pulse0(), .pulse1(), .pulse2(), .pulse3(), .pulse4(), .pulse5(), .pulse6(), .pulse7());

	// --- VRAM model (32 bit words, read latency LAT)
	localparam LAT = 10;
	reg [31:0] M [0:65535];
	reg [LAT-1:0] rsr = 0; reg [31:0] rp [0:LAT-1]; integer i;
	always @(posedge clk) begin
		if (vv && vw) for (i = 0; i < 4; i = i + 1) if (!vm[i]) M[va][i*8 +: 8] <= vwd[i*8 +: 8];
		rsr <= {rsr[LAT-2:0], vv & ~vw};
		rp[0] <= M[va]; for (i = 1; i < LAT; i = i + 1) rp[i] <= rp[i-1];
	end
	assign vre = rsr[LAT-1]; assign vrd = rp[LAT-1];

	// --- bus
	task out(input [2:0] p, input [7:0] v);
		begin
			while (!br) @(posedge clk);
			@(posedge clk); ba <= p; bd <= v; bw <= 1; bv <= 1;
			@(posedge clk); bv <= 0;
			repeat (2) @(posedge clk); while (!br) @(posedge clk); repeat (4) @(posedge clk);
		end
	endtask
	task inp(input [2:0] p, output [7:0] v);
		begin
			while (!br) @(posedge clk);
			@(posedge clk); ba <= p; bw <= 0; bv <= 1;
			@(posedge clk); bv <= 0;
			while (!brde) @(posedge clk); v = brd;
			repeat (2) @(posedge clk); while (!br) @(posedge clk); repeat (4) @(posedge clk);
		end
	endtask
	task vreg(input [5:0] r, input [7:0] v); begin out(3'd1, v); out(3'd1, {2'b10, r}); end endtask
	task rstat(input [3:0] n, output [7:0] v); begin vreg(15, {4'd0, n}); inp(3'd1, v); vreg(15, 8'd0); end endtask

	// --- backdoor (logical address, interleave of the current mode)
	function [16:0] phys(input [16:0] a); phys = u.w_vram_interleave ? { a[0], a[16:1] } : a; endfunction
	function [7:0] lrd(input [16:0] a); reg [16:0] p; begin p = phys(a); lrd = M[p[16:2]][p[1:0]*8 +: 8]; end endfunction
	task lwr(input [16:0] a, input [7:0] v); reg [16:0] p; begin p = phys(a); M[p[16:2]][p[1:0]*8 +: 8] = v; end endtask
	task cache_quiet;
		integer n; begin
			n = 0;
			while (n < 8) begin
				@(posedge clk);
				if (u.u_cache.ff_valid == 8'd0 && u.u_cache.ff_state == 4'd0 && !u.u_cache.ff_flush_pending &&
					!u.u_cache.ff_cpu_timer_active && !u.u_cache.ff_vram_valid) n = n + 1;
				else n = 0;
			end
		end
	endtask

	// --- script
	reg [7:0] S [0:65535];
	reg [7:0] PAT [0:255];
	reg [15:0] CRC_T [0:255];
	integer pc, from_n, to_n, cur, total, ng, tmo, fd, k, n, lim, c;
	reg [15:0] crc, exp_crc;
	reg [7:0] lg [0:262143];
	integer lgn;
	reg active;
	reg [7:0] op, a0, a1, s, v;
	reg [16:0] addr;
	integer len;
	reg [1023:0] dir, fname;

	function [7:0] fb; begin fb = S[pc]; pc = pc + 1; end endfunction
	function [15:0] fw; begin fw = {S[pc + 1], S[pc]}; pc = pc + 2; end endfunction
	task log_b(input [7:0] b);
		begin
			crc = {crc[7:0], 8'd0} ^ CRC_T[crc[15:8] ^ b];
			if (lgn < 262144) lg[lgn] = b;
			lgn = lgn + 1;
		end
	endtask
	task fetch_a24_len;
		reg [7:0] l, m, h; reg [15:0] w;
		begin l = fb(); m = fb(); h = fb(); addr = {h[0], m, l}; w = fw(); len = (w == 0) ? 65536 : w; end
	endtask
	task timeout_stop; begin tmo = 1; vreg(46, 8'd0); vreg(15, 8'd0); end endtask
	task finish_run;
		begin
			$display("RESULT: %0d/%0d (tests %0d-%0d)", ng, total, from_n, to_n);
			if (ng == 0) $display("SUCCESS OF ALL");
			$finish;
		end
	endtask

	initial begin
		for (i = 0; i < 65536; i = i + 1) M[i] = 32'h0;
		for (i = 0; i < 256; i = i + 1) begin
			c = i << 8;
			for (k = 0; k < 8; k = k + 1) c = (c & 16'h8000) ? ((c << 1) ^ 16'h1021) : (c << 1);
			CRC_T[i] = c[15:0];
		end
		if (!$value$plusargs("dir=%s", dir)) dir = "../../../../../test/VDPCHK";
		if (!$value$plusargs("from=%d", from_n)) from_n = 1;
		if (!$value$plusargs("to=%d", to_n)) to_n = 99999;
		if (!$value$plusargs("lim=%d", lim)) lim = 16000000;
		$sformat(fname, "%0s/vdpchk.hex", dir); $readmemh(fname, S);
		$sformat(fname, "%0s/pat.hex", dir); $readmemh(fname, PAT);
		repeat (10) @(posedge clk); reset_n = 1; repeat (50) @(posedge clk);

		// V9968 detection as done by VDPCHK.COM
		rstat(1, s); $display("S#1 = %02h (ID %0d)", s, (s >> 1) & 31);
		inp(3'd4, s); $display("P#4 = %02h", s);
		out(3'd4, 8'h00); inp(3'd4, s); $display("P#4 after unlock = %02h", s);
		vreg(21, 8'h00); rstat(1, s); $display("S#1 (V58=0) = %02h (ID %0d)", s, (s >> 1) & 31);
		if (((s >> 1) & 31) != 3) $display("WARNING: V9968 not detected");
		vreg(20, 8'h00); vreg(21, 8'h01); out(3'd4, 8'h80);

		pc = 0; cur = 0; total = 0; ng = 0; active = 0;
		forever begin
			op = fb();
			case (op)
			8'h00: finish_run;
			8'h01: begin
				cur = fw(); crc = 16'hFFFF; lgn = 0; tmo = 0;
				active = (cur >= from_n && cur <= to_n);
				if (cur > to_n) finish_run;
			end
			8'h02: begin
				exp_crc = fw();
				if (active) begin
					total = total + 1;
					if (crc !== exp_crc || tmo) begin
						ng = ng + 1;
						$display("NG %0d%s exp_crc=%04h got=%04h len=%0d at %0t", cur, tmo ? "T" : "", exp_crc, crc, lgn, $time);
						$sformat(fname, "fail_%0d.hex", cur);
						fd = $fopen(fname, "w");
						for (k = 0; k < lgn && k < 262144; k = k + 1) $fdisplay(fd, "%02h", lg[k]);
						$fclose(fd);
					end
					else if (cur % 50 == 0) $display("ok %0d at %0t", cur, $time);
				end
			end
			8'h03: begin a0 = fb(); a1 = fb(); vreg(a0[5:0], a1); end
			8'h04: begin a0 = fb(); out(3'd4, a0); end
			8'h05: begin
				if (active) begin
					vreg(17, 8'd32);
					for (k = 0; k < 15; k = k + 1) out(3'd3, S[pc + k]);
				end
				pc = pc + 15;
			end
			8'h06: if (active) begin
				vreg(15, 8'd2); n = 0;
				inp(3'd1, s);
				while (s[0] && n < lim) begin n = n + 1; inp(3'd1, s); end
				if (s[0]) timeout_stop; else vreg(15, 8'd0);
			end
			8'h07: begin
				a0 = fb();
				if (active) begin
					k = a0 + 1;
					vreg(17, 8'hAC); vreg(15, 8'd2); n = 0;
					inp(3'd1, s);
					while (s[0] && n < lim) begin
						if (s[7]) begin out(3'd3, PAT[k & 255]); k = k + 1; end
						else n = n + 1;
						inp(3'd1, s);
					end
					if (s[0]) timeout_stop; else vreg(15, 8'd0);
				end
			end
			8'h08: if (active) begin
				vreg(15, 8'd2); n = 0; k = 0;
				forever begin
					inp(3'd1, s);
					if (s[7]) begin vreg(15, 8'd7); inp(3'd1, v); log_b(v); k = k + 1; vreg(15, 8'd2); end
					if (!s[0]) break;
					n = n + 1;
					if (n >= lim) begin timeout_stop; break; end
				end
				vreg(15, 8'd0);
				log_b(k[7:0]); log_b(k[15:8]);
			end
			8'h09: begin
				a0 = fb(); a1 = fb();
				if (active) begin rstat(a0[3:0], s); if (a1 != 0) log_b(s & a1); end
			end
			8'h0A: begin
				fetch_a24_len; a0 = fb();
				if (active) begin
					cache_quiet;
					for (k = 0; k < len; k = k + 1) begin
						n = addr + k;
						c = n >> 8;
						lwr(n, PAT[((n & 255) + (c & 255) * 8'h4D + (c >> 8) * 8'h9B + a0) & 255]);
					end
				end
			end
			8'h0B: begin
				fetch_a24_len; a0 = fb();
				if (active) begin cache_quiet; for (k = 0; k < len; k = k + 1) lwr(addr + k, a0); end
			end
			8'h0C: begin
				fetch_a24_len;
				if (active) begin cache_quiet; for (k = 0; k < len; k = k + 1) log_b(lrd(addr + k)); end
			end
			8'h0D: begin
				fetch_a24_len; a0 = fb();
				if (active) begin
					vreg(14, {5'd0, addr[16:14]}); out(3'd1, addr[7:0]); out(3'd1, {2'b01, addr[13:8]});
					for (k = 0; k < len; k = k + 1) out(3'd0, PAT[(a0 + k) & 255]);
				end
			end
			8'h0E: begin
				fetch_a24_len;
				if (active) begin
					vreg(14, {5'd0, addr[16:14]}); out(3'd1, addr[7:0]); out(3'd1, {2'b00, addr[13:8]});
					for (k = 0; k < len; k = k + 1) begin inp(3'd0, v); log_b(v); end
				end
			end
			8'h0F: begin a0 = fb(); n = fw(); n = fw(); end		// V9968 sections always run here
			default: begin $display("SCRIPT ERROR op=%02h at %0d", op, pc - 1); $finish; end
			endcase
		end
	end
endmodule
