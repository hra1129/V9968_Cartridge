`timescale 1ps/1ps

module tb_vram_prefetch_wait;
	reg test_passed = 1'b0;
	reg clk = 1'b0;
	always #5820 clk = ~clk;

	reg reset_n = 1'b0;
	reg initial_busy = 1'b1;
	reg dipsw = 1'b1;
	reg slot_ioreq_n = 1'b1;
	reg slot_rd_n = 1'b1;
	reg slot_wr_n = 1'b1;
	reg [7:0] slot_address = 8'd0;
	reg [7:0] slot_wdata = 8'd0;
	wire [7:0] slot_data;
	wire slot_data_dir;
	wire vdp_wait;
	wire slot_wait = initial_busy | vdp_wait;
	assign slot_data = !slot_wr_n ? slot_wdata : 8'hZZ;

	wire [2:0] bus_address;
	wire bus_ioreq;
	wire bus_write;
	wire bus_valid;
	wire [7:0] bus_wdata;
	wire bus_ready;
	wire [7:0] bus_rdata;
	wire bus_rdata_en;
	wire bus_write_done;
	wire bus_is_vdp = bus_ioreq && bus_address <= 3'd4;

	msx_slot u_slot (
		.clk(clk), .initial_busy(initial_busy), .p_slot_reset_n(reset_n),
		.p_slot_ioreq_n(slot_ioreq_n), .p_slot_rd_n(slot_rd_n), .p_slot_wr_n(slot_wr_n),
		.p_slot_address(slot_address), .p_slot_data(slot_data), .p_slot_int(),
		.p_slot_data_dir(slot_data_dir), .p_slot_wait(vdp_wait), .int_n(1'b1),
		.bus_address(bus_address), .bus_ioreq(bus_ioreq),
		.bus_sysctrl_address(), .bus_sysctrl_ioreq(),
		.bus_write(bus_write), .bus_valid(bus_valid),
		.bus_ready(bus_is_vdp ? bus_ready : 1'b1), .bus_wdata(bus_wdata),
		.bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
		.bus_vdp_write_done(bus_write_done), .dipsw(dipsw)
	);

	wire [17:0] cpu_vram_address;
	wire cpu_vram_write;
	wire cpu_vram_valid;
	wire cpu_vram_ready;
	wire [7:0] cpu_vram_wdata;
	wire [7:0] cpu_vram_rdata;
	wire cpu_vram_rdata_en;
	reg vram_access_mask = 1'b0;

	vdp_cpu_interface u_cpu (
		.reset_n(reset_n), .clk(clk),
		.bus_address(bus_address), .bus_ioreq(bus_ioreq), .bus_write(bus_write),
		.bus_valid(bus_valid && bus_is_vdp), .bus_ready(bus_ready),
		.bus_wdata(bus_wdata), .bus_rdata(bus_rdata), .bus_rdata_en(bus_rdata_en),
		.bus_write_done(bus_write_done),
		.vram_address(cpu_vram_address), .vram_write(cpu_vram_write),
		.vram_valid(cpu_vram_valid), .vram_ready(cpu_vram_ready),
		.vram_wdata(cpu_vram_wdata), .vram_rdata(cpu_vram_rdata),
		.vram_rdata_en(cpu_vram_rdata_en),
		.palette_valid(), .palette_num(), .palette_r(), .palette_g(), .palette_b(),
		.int_n(), .intr_line(1'b0), .intr_frame(1'b0), .intr_command_end(1'b0),
		.clear_line_interrupt(1'b0), .clear_sprite_collision(), .sprite_collision(1'b0),
		.clear_sprite_collision_xy(), .sprite_collision_x(9'd0), .sprite_collision_y(10'd0),
		.clear_sprite_overmap(), .sprite_overmap_enable(), .sprite_overmap(1'b0),
		.sprite_overmap_id(5'd31), .clear_border_detect(), .read_color(),
		.register_write(), .register_num(), .register_data(),
		.status_command_execute(1'b0), .status_field(1'b0), .status_border_detect(1'b0),
		.status_hsync(1'b0), .status_vsync(1'b0), .status_transfer_ready(1'b0),
		.status_color(8'd0), .status_border_position(9'd0),
		.vram_access_mask(vram_access_mask), .force_highspeed(1'b0),
		.reg_screen_mode(), .reg_sprite_magify(), .reg_sprite_16x16(), .reg_display_on(),
		.reg_pattern_name_table_base(), .reg_color_table_base(),
		.reg_pattern_generator_table_base(), .reg_sprite_attribute_table_base(),
		.reg_sprite_pattern_generator_table_base(), .reg_backdrop_color(),
		.reg_sprite_disable(), .reg_color0_opaque(), .reg_50hz_mode(),
		.reg_interleaving_mode(), .reg_interlace_mode(), .reg_212lines_mode(),
		.reg_text_back_color(), .reg_blink_period(), .reg_display_adjust(),
		.reg_interrupt_line(), .reg_vertical_offset(), .reg_scroll_planes(),
		.reg_left_mask(), .reg_yjk_mode(), .reg_yae_mode(), .reg_command_enable(),
		.reg_sprite_priority_shuffle(), .reg_horizontal_offset_l(), .reg_horizontal_offset_h(),
		.reg_command_high_speed_mode(), .reg_sprite_nonR23_mode(),
		.reg_interrupt_line_nonR23_mode(), .reg_sprite_mode3(), .reg_ext_palette_mode(),
		.reg_ext_command_mode(), .reg_vram256k_mode(), .reg_sprite16_mode(),
		.reg_flat_interlace_mode(), .button(2'd0),
		.pulse0(), .pulse1(), .pulse2(), .pulse3(), .pulse4(), .pulse5(), .pulse6(), .pulse7()
	);

	reg [17:0] command_address = 18'd0;
	reg command_valid = 1'b0;
	reg command_write = 1'b0;
	reg [7:0] command_wdata = 8'd0;
	wire command_ready;
	wire [17:0] cache_address;
	wire cache_valid;
	wire cache_ready;
	wire cache_write;
	wire [31:0] cache_wdata;
	wire [3:0] cache_wdata_mask;
	wire [31:0] cache_rdata;
	wire cache_rdata_en;

	vdp_command_cache u_cache (
		.reset_n(reset_n), .clk(clk), .start(1'b0),
		.cache_vram_address(command_address), .cache_vram_valid(command_valid),
		.cache_vram_ready(command_ready), .cache_vram_write(command_write),
		.cache_vram_wdata(command_wdata), .cache_vram_rdata(), .cache_vram_rdata_en(),
		.cache_flush_start(1'b0), .cache_flush_end(),
		.cpu_vram_address(cpu_vram_address), .cpu_vram_valid(cpu_vram_valid),
		.cpu_vram_ready(cpu_vram_ready), .cpu_vram_write(cpu_vram_write),
		.cpu_vram_wdata(cpu_vram_wdata), .cpu_vram_rdata(cpu_vram_rdata),
		.cpu_vram_rdata_en(cpu_vram_rdata_en),
		.command_vram_address(cache_address), .command_vram_valid(cache_valid),
		.command_vram_ready(cache_ready), .command_vram_write(cache_write),
		.command_vram_wdata(cache_wdata), .command_vram_wdata_mask(cache_wdata_mask),
		.command_vram_rdata(cache_rdata), .command_vram_rdata_en(cache_rdata_en)
	);

	reg [3:0] h_count = 4'd0;
	reg [7:0] refresh_count = 8'd0;
	reg force_refresh = 1'b0;
	reg periodic_refresh = 1'b0;
	reg display_contention = 1'b0;
	wire pre_refresh = force_refresh || (periodic_refresh && refresh_count == 8'd100);
	wire screen_valid = display_contention && h_count == 4'd1;
	wire [17:2] sdram_address;
	wire sdram_valid;
	wire sdram_write;
	wire [31:0] sdram_wdata;
	wire [3:0] sdram_wdata_mask;
	wire [31:0] sdram_rdata;
	wire sdram_rdata_en;

	always @(posedge clk) begin
		h_count <= h_count + 4'd1;
		refresh_count <= refresh_count + 8'd1;
	end

	vdp_vram_interface u_vram_interface (
		.reset_n(reset_n), .clk(clk), .initial_busy(initial_busy),
		.h_count(h_count), .vram_interleave(1'b0),
		.screen_mode_vram_address(18'h3F000), .screen_mode_vram_valid(screen_valid),
		.screen_mode_vram_rdata(),
		.sprite_vram_address(18'd0), .sprite_vram_valid(1'b0),
		.sprite_vram_rdata(), .sprite_vram_rdata8(),
		.command_vram_address(cache_address), .command_vram_valid(cache_valid),
		.command_vram_ready(cache_ready), .command_vram_write(cache_write),
		.command_vram_wdata(cache_wdata), .command_vram_wdata_mask(cache_wdata_mask),
		.command_vram_rdata(cache_rdata), .command_vram_rdata_en(cache_rdata_en),
		.cpu_vram_address(18'd0), .cpu_vram_valid(1'b0), .cpu_vram_ready(),
		.cpu_vram_write(1'b0), .cpu_vram_wdata(8'd0), .cpu_vram_rdata(),
		.cpu_vram_rdata_en(), .vram_address(sdram_address), .vram_valid(sdram_valid),
		.vram_write(sdram_write), .vram_wdata(sdram_wdata),
		.vram_wdata_mask(sdram_wdata_mask), .vram_rdata(sdram_rdata),
		.vram_rdata_en(sdram_rdata_en), .pre_vram_refresh(pre_refresh), .vram_refresh()
	);

	reg [31:0] memory [0:65535];
	reg [7:0] expected [0:262143];
	reg [31:0] read_pipe [0:7];
	reg [7:0] read_valid = 8'd0;
	integer stage;
	assign sdram_rdata = read_pipe[7];
	assign sdram_rdata_en = read_valid[7];

	always @(posedge clk) begin
		if( !reset_n ) begin
			read_valid <= 8'd0;
		end
		else begin
			read_valid <= { read_valid[6:0], sdram_valid && !sdram_write };
			read_pipe[0] <= memory[sdram_address];
			for( stage = 1; stage < 8; stage = stage + 1 ) begin
				read_pipe[stage] <= read_pipe[stage-1];
			end
			if( sdram_valid && sdram_write ) begin
				if( !sdram_wdata_mask[0] ) memory[sdram_address][7:0]   <= sdram_wdata[7:0];
				if( !sdram_wdata_mask[1] ) memory[sdram_address][15:8]  <= sdram_wdata[15:8];
				if( !sdram_wdata_mask[2] ) memory[sdram_address][23:16] <= sdram_wdata[23:16];
				if( !sdram_wdata_mask[3] ) memory[sdram_address][31:24] <= sdram_wdata[31:24];
			end
		end
	end

	function automatic [7:0] initial_byte(input [17:0] address);
		initial_byte = address[7:0] ^ address[15:8] ^ { 6'd0, address[17:16] } ^ 8'h5A;
	endfunction

	integer cpu_read_requests = 0;
	integer cpu_write_events = 0;
	integer cpu_read_events = 0;
	integer long_write_waits = 0;
	integer inter_access_cycles = 8;
	time max_fast_read_time = 0;
	always @(posedge clk) begin
		if( reset_n ) begin
			if( cpu_vram_valid && cpu_vram_ready && !cpu_vram_write )
				cpu_read_requests <= cpu_read_requests + 1;
			if( bus_write_done ) cpu_write_events <= cpu_write_events + 1;
			if( bus_rdata_en ) begin
				cpu_read_events <= cpu_read_events + 1;
				if( slot_ioreq_n || slot_rd_n )
					$fatal(1, "VDP response was generated outside an active read");
			end
		end
	end

	always @(negedge clk) begin
		if( reset_n && !slot_ioreq_n && !slot_rd_n &&
		    slot_address[7:3] == (dipsw ? 5'h13 : 5'h11) &&
		    slot_address[2:0] <= 3'd4 && !slot_wait ) begin
			if( slot_data_dir !== 1'b1 || (^slot_data) === 1'bx )
				$fatal(1, "WAIT released before read data was driven");
		end
	end

	task automatic write_port(input [7:0] port, input [7:0] value);
		integer cycles;
		integer before_events;
		begin
			@(negedge clk);
			before_events = cpu_write_events;
			slot_address = port;
			slot_wdata = value;
			slot_wr_n = 1'b0;
			slot_ioreq_n = 1'b0;
			#1;
			if( slot_wait !== 1'b1 ) $fatal(1, "WRITE %h did not assert WAIT", port);
			cycles = 0;
			while( slot_wait !== 1'b0 ) begin
				if( slot_wait !== 1'b1 ) $fatal(1, "WRITE %h WAIT is unknown", port);
				@(negedge clk);
				cycles = cycles + 1;
				if( cycles > 4000 ) $fatal(1, "WRITE %h WAIT timeout", port);
			end
			if( cycles >= 60 ) long_write_waits = long_write_waits + 1;
			if( cpu_write_events != before_events + 1 )
				$fatal(1, "WRITE %h was dropped or repeated", port);
			repeat(3) @(negedge clk);
			if( slot_wait !== 1'b0 ) $fatal(1, "WRITE %h WAIT reasserted", port);
			slot_ioreq_n = 1'b1;
			slot_wr_n = 1'b1;
			repeat(inter_access_cycles) @(negedge clk);
		end
	endtask

	task automatic read_port(input [7:0] port, input [7:0] value,
	                         input integer min_cycles, input integer max_cycles,
	                         input integer phase_ps);
		integer cycles;
		integer before_events;
		time start_time;
		time elapsed;
		begin
			@(negedge clk);
			#(phase_ps);
			before_events = cpu_read_events;
			slot_address = port;
			slot_rd_n = 1'b0;
			slot_ioreq_n = 1'b0;
			start_time = $time;
			#1;
			if( slot_wait !== 1'b1 ) $fatal(1, "READ %h did not assert WAIT", port);
			cycles = 0;
			while( slot_wait !== 1'b0 ) begin
				if( slot_wait !== 1'b1 ) $fatal(1, "READ %h WAIT is unknown", port);
				@(negedge clk);
				cycles = cycles + 1;
				if( cycles > 4000 ) $fatal(1, "READ %h WAIT timeout", port);
			end
			elapsed = $time - start_time;
			if( min_cycles >= 0 && cycles < min_cycles )
				$fatal(1, "READ %h WAIT too short: %0d clocks", port, cycles);
			if( max_cycles >= 0 && cycles > max_cycles )
				$fatal(1, "READ %h prefetch too slow: %0d clocks", port, cycles);
			if( max_cycles >= 0 && elapsed > max_fast_read_time ) max_fast_read_time = elapsed;
			if( cpu_read_events != before_events + 1 )
				$fatal(1, "READ %h was dropped or repeated", port);
			if( slot_data_dir !== 1'b1 || slot_data !== value )
				$fatal(1, "READ %h expected %02h, got %02h (dir=%b)", port, value, slot_data, slot_data_dir);
			repeat(3) @(negedge clk);
			if( slot_wait !== 1'b0 || slot_data_dir !== 1'b1 || slot_data !== value )
				$fatal(1, "READ %h response was not held", port);
			slot_ioreq_n = 1'b1;
			slot_rd_n = 1'b1;
			repeat(inter_access_cycles) @(negedge clk);
		end
	endtask

	task automatic no_wait_access(input [7:0] port, input bit write_access);
		integer before_reads;
		integer before_writes;
		begin
			@(negedge clk);
			before_reads = cpu_read_events;
			before_writes = cpu_write_events;
			slot_address = port;
			slot_wdata = 8'hA6;
			slot_rd_n = write_access;
			slot_wr_n = !write_access;
			slot_ioreq_n = 1'b0;
			#1;
			if( slot_wait !== 1'b0 ) $fatal(1, "Unexpected WAIT on port %h", port);
			repeat(16) @(negedge clk);
			if( slot_wait !== 1'b0 ) $fatal(1, "WAIT appeared on port %h", port);
			if( cpu_read_events != before_reads || cpu_write_events != before_writes )
				$fatal(1, "Unrelated port %h reached the VDP", port);
			if( !write_access && (slot_data_dir !== 1'b0 || slot_data !== 8'hZZ) )
				$fatal(1, "VDP drove an unrelated port %h", port);
			slot_ioreq_n = 1'b1;
			slot_rd_n = 1'b1;
			slot_wr_n = 1'b1;
			repeat(8) @(negedge clk);
		end
	endtask

	task automatic set_read_address(input [7:0] base, input [13:0] address);
		begin
			write_port(base + 8'd1, address[7:0]);
			write_port(base + 8'd1, { 2'b00, address[13:8] });
		end
	endtask

	task automatic set_write_address(input [7:0] base, input [13:0] address);
		begin
			write_port(base + 8'd1, address[7:0]);
			write_port(base + 8'd1, { 2'b01, address[13:8] });
		end
	endtask

	task automatic write_register(input [7:0] base, input [5:0] number, input [7:0] value);
		begin
			write_port(base + 8'd1, value);
			write_port(base + 8'd1, { 2'b10, number });
		end
	endtask

	task automatic wait_prefetch;
		integer cycles;
		begin
			cycles = 0;
			while( u_cpu.ff_busy !== 1'b0 ) begin
				@(negedge clk);
				cycles = cycles + 1;
				if( cycles > 4000 ) $fatal(1, "Prefetch timeout");
			end
		end
	endtask

	task automatic command_write_byte(input [17:0] address, input [7:0] value);
		integer cycles;
		begin
			@(negedge clk);
			command_address = address;
			command_wdata = value;
			command_write = 1'b1;
			command_valid = 1'b1;
			cycles = 0;
			while( command_ready !== 1'b1 ) begin
				@(negedge clk);
				cycles = cycles + 1;
				if( cycles > 4000 ) $fatal(1, "Command cache timeout");
			end
			@(posedge clk);
			@(negedge clk);
			command_valid = 1'b0;
			expected[address] = value;
		end
	endtask

	integer i;
	integer before_reads;
	reg [7:0] base = 8'h98;
	initial begin
		for( i = 0; i < 262144; i = i + 1 ) expected[i] = initial_byte(i[17:0]);
		for( i = 0; i < 65536; i = i + 1 )
			memory[i] = { expected[i*4+3], expected[i*4+2], expected[i*4+1], expected[i*4] };
		repeat(5) @(negedge clk);
		reset_n = 1'b1;
		repeat(5) @(negedge clk);
		if( slot_wait !== 1'b1 ) $fatal(1, "SDRAM initialization WAIT was lost");
		initial_busy = 1'b0;
		repeat(5) @(negedge clk);

		$display("[1] Read-address prefetch, fast response, and delayed refresh");
		before_reads = cpu_read_requests;
		set_read_address(base, 14'h0243);
		wait_prefetch();
		if( cpu_read_requests != before_reads + 1 )
			$fatal(1, "Read address did not initiate exactly one prefetch");
		force_refresh = 1'b1;
		read_port(base, expected[18'h00243], -1, 14, 0);
		no_wait_access(8'h40, 1'b0);
		no_wait_access(8'h40, 1'b1);
		no_wait_access(base + 8'd5, 1'b0);
		no_wait_access(base + 8'd5, 1'b1);
		no_wait_access(base + 8'd6, 1'b0);
		no_wait_access(base + 8'd6, 1'b1);
		no_wait_access(base + 8'd7, 1'b0);
		no_wait_access(base + 8'd7, 1'b1);
		no_wait_access(8'h88, 1'b0);
		fork
			begin
				read_port(base, expected[18'h00244], 60, -1, 2000);
			end
			begin
				repeat(80) @(negedge clk);
				if( slot_wait !== 1'b1 || slot_data_dir !== 1'b0 || slot_data !== 8'hZZ )
					$fatal(1, "Delayed read escaped WAIT or drove premature data");
				force_refresh = 1'b0;
			end
		join

		$display("[2] Pending status and address writes are preserved during prefetch");
		set_read_address(base, 14'h0343);
		wait_prefetch();
		force_refresh = 1'b1;
		read_port(base, expected[18'h00343], -1, 14, 0);
		fork
			begin read_port(base + 8'd1, 8'h1F, 60, -1, 0); end
			begin repeat(80) @(negedge clk); force_refresh = 1'b0; end
		join
		set_read_address(base, 14'h0383);
		wait_prefetch();
		force_refresh = 1'b1;
		read_port(base, expected[18'h00383], -1, 14, 0);
		fork
			begin write_port(base + 8'd1, 8'h55); end
			begin repeat(80) @(negedge clk); force_refresh = 1'b0; end
		join
		write_port(base + 8'd1, 8'h04);
		read_port(base, expected[18'h00455], -1, -1, 0);

		$display("[3] Shared read/write buffer and mixed access order");
		set_read_address(base, 14'h0500);
		wait_prefetch();
		write_port(base, 8'hA7);
		expected[18'h00501] = 8'hA7;
		set_write_address(base, 14'h0600);
		read_port(base, 8'hA7, -1, -1, 0);
		read_port(base, expected[18'h00600], -1, -1, 0);
		set_read_address(base, 14'h0501);
		read_port(base, 8'hA7, -1, -1, 0);

		$display("[4] Prefetched data survives a subsequent command write");
		set_read_address(base, 14'h0700);
		wait_prefetch();
		command_write_byte(18'h00700, 8'hC3);
		read_port(base, initial_byte(18'h00700), -1, -1, 0);
		set_read_address(base, 14'h0700);
		read_port(base, 8'hC3, -1, -1, 0);

		$display("[5] Burst writes, cache eviction, refresh and sequential reads");
		set_write_address(base, 14'h1000);
		force_refresh = 1'b1;
		display_contention = 1'b1;
		periodic_refresh = 1'b1;
		long_write_waits = 0;
		fork
			begin
				for( i = 0; i < 64; i = i + 1 ) begin
					write_port(base, i[7:0] ^ 8'h96);
					expected[18'h01000 + i] = i[7:0] ^ 8'h96;
				end
			end
			begin
				repeat(1400) @(negedge clk);
				force_refresh = 1'b0;
			end
		join
		if( long_write_waits == 0 ) $fatal(1, "Cache eviction did not exercise a delayed write");
		set_read_address(base, 14'h1000);
		inter_access_cycles = 4;
		for( i = 0; i < 64; i = i + 1 )
			read_port(base, expected[18'h01000 + i], -1, -1, (i % 11) * 1000);
		inter_access_cycles = 8;

		$display("[6] MXC read and write masking");
		vram_access_mask = 1'b1;
		set_read_address(base, 14'h0800);
		read_port(base, 8'hFF, -1, -1, 0);
		vram_access_mask = 1'b0;
		read_port(base, expected[18'h00801], -1, -1, 0);
		vram_access_mask = 1'b1;
		set_write_address(base, 14'h0810);
		write_port(base, 8'hE2);
		vram_access_mask = 1'b0;
		set_read_address(base, 14'h0810);
		read_port(base, expected[18'h00810], -1, -1, 0);

		$display("[7] 14-bit, 17-bit and 18-bit address wrap");
		periodic_refresh = 1'b0;
		display_contention = 1'b0;
		write_register(base, 6'd14, 8'h00);
		set_write_address(base, 14'h3FFF);
		write_port(base, 8'hA1);
		expected[18'h03FFF] = 8'hA1;
		write_port(base, 8'hA2);
		expected[18'h00000] = 8'hA2;
		set_read_address(base, 14'h3FFF);
		read_port(base, expected[18'h03FFF], -1, -1, 0);
		read_port(base, expected[18'h00000], -1, -1, 0);
		write_register(base, 6'd0, 8'h06);
		write_register(base, 6'd14, 8'h07);
		set_write_address(base, 14'h3FFF);
		write_port(base, 8'hB1);
		expected[18'h1FFFF] = 8'hB1;
		write_port(base, 8'hB2);
		expected[18'h00000] = 8'hB2;
		write_register(base, 6'd14, 8'h07);
		set_read_address(base, 14'h3FFF);
		read_port(base, expected[18'h1FFFF], -1, -1, 0);
		read_port(base, expected[18'h00000], -1, -1, 0);
		write_port(base + 8'd4, 8'h00);
		write_register(base, 6'd21, 8'h00);
		write_register(base, 6'd14, 8'h0F);
		set_write_address(base, 14'h3FFF);
		write_port(base, 8'hC1);
		expected[18'h3FFFF] = 8'hC1;
		write_port(base, 8'hC2);
		expected[18'h00000] = 8'hC2;
		write_register(base, 6'd14, 8'h0F);
		set_read_address(base, 14'h3FFF);
		read_port(base, expected[18'h3FFFF], -1, -1, 0);
		read_port(base, expected[18'h00000], -1, -1, 0);

		$display("[8] Alternate 88h decode and clock-phase sweep");
		dipsw = 1'b0;
		base = 8'h88;
		write_register(base, 6'd14, 8'h00);
		for( i = 0; i < 12; i = i + 1 ) begin
			set_read_address(base, 14'h0A00 + i);
			wait_prefetch();
			read_port(base, expected[18'h00A00 + i], -1, 14, i * 900);
		end
		no_wait_access(8'h98, 1'b0);
		$display("VRAM prefetch/WAIT integration PASSED; max prefetched-read response %0t ps", max_fast_read_time);
		test_passed = 1'b1;
		$finish;
	end

	initial begin
		#2000000000;
		$fatal(1, "Test timeout");
	end
endmodule
