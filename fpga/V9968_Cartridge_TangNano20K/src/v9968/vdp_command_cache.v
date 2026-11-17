//
//	vdp_command_cache.v
//
//	Copyright (C) 2025 Takayuki Hara
//
//	本ソフトウェアおよび本ソフトウェアに基づいて作成された派生物は、以下の条件を
//	満たす場合に限り、再頒布および使用が許可されます。
//
//	1.ソースコード形式で再頒布する場合、上記の著作権表示、本条件一覧、および下記
//	  免責条項をそのままの形で保持すること。
//	2.バイナリ形式で再頒布する場合、頒布物に付属のドキュメント等の資料に、上記の
//	  著作権表示、本条件一覧、および下記免責条項を含めること。
//	3.書面による事前の許可なしに、本ソフトウェアを販売、および商業的な製品や活動
//	  に使用しないこと。
//
//	本ソフトウェアは、著作権者によって「現状のまま」提供されています。著作権者は、
//	特定目的への適合性の保証、商品性の保証、またそれに限定されない、いかなる明示
//	的もしくは暗黙な保証責任も負いません。著作権者は、事由のいかんを問わず、損害
//	発生の原因いかんを問わず、かつ責任の根拠が契約であるか厳格責任であるか（過失
//	その他の）不法行為であるかを問わず、仮にそのような損害が発生する可能性を知ら
//	されていたとしても、本ソフトウェアの使用によって発生した（代替品または代用サ
//	ービスの調達、使用の喪失、データの喪失、利益の喪失、業務の中断も含め、またそ
//	れに限定されない）直接損害、間接損害、偶発的な損害、特別損害、懲罰的損害、ま
//	たは結果損害について、一切責任を負わないものとします。
//
//	Note that above Japanese version license is the formal document.
//	The following translation is only for reference.
//
//	Redistribution and use of this software or any derivative works,
//	are permitted provided that the following conditions are met:
//
//	1. Redistributions of source code must retain the above copyright
//	   notice, this list of conditions and the following disclaimer.
//	2. Redistributions in binary form must reproduce the above
//	   copyright notice, this list of conditions and the following
//	   disclaimer in the documentation and/or other materials
//	   provided with the distribution.
//	3. Redistributions may not be sold, nor may they be used in a
//	   commercial product or activity without specific prior written
//	   permission.
//
//	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//	"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//	LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
//	FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
//	COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//	INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
//	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//	LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//	CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
//	LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
//	ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//	POSSIBILITY OF SUCH DAMAGE.
//
//-----------------------------------------------------------------------------

module vdp_command_cache (
	input				reset_n,
	input				clk,
	input				start,
	input		[21:0]	cache_vram_address,
	input				cache_vram_valid,
	output				cache_vram_ready,
	input				cache_vram_write,
	input		[7:0]	cache_vram_wdata,
	output		[7:0]	cache_vram_rdata,
	output				cache_vram_rdata_en,
	input				cache_flush_start,
	output				cache_flush_end,
	input		[21:0]	cpu_vram_address,
	input				cpu_vram_valid,
	output				cpu_vram_ready,
	input				cpu_vram_write,
	input		[7:0]	cpu_vram_wdata,
	output		[7:0]	cpu_vram_rdata,
	output				cpu_vram_rdata_en,
	output		[21:0]	command_vram_address,
	output				command_vram_valid,
	input				command_vram_ready,
	output				command_vram_write,
	output		[31:0]	command_vram_wdata,
	output		[3:0]	command_vram_wdata_mask,
	input		[31:0]	command_vram_rdata,
	input				command_vram_rdata_en
);
	localparam [3:0] c_idle         = 4'd0;
	localparam [3:0] c_evict_write  = 4'd1;
	localparam [3:0] c_evict_read   = 4'd2;
	localparam [3:0] c_read_request = 4'd3;
	localparam [3:0] c_read_wait    = 4'd4;
	localparam [3:0] c_flush_scan   = 4'd5;
	localparam [3:0] c_flush_write  = 4'd6;
	localparam [3:0] c_lookup       = 4'd7;
	localparam [3:0] c_process      = 4'd8;

	reg		[19:0]	ff_address [0:7];
	reg		[31:0]	ff_data [0:7];
	reg		[3:0]	ff_mask [0:7];
	reg		[7:0]	ff_valid;
	reg		[7:0]	ff_loaded;
	reg		[2:0]	ff_age [0:7];
	reg		[3:0]	ff_state;
	reg		[3:0]	ff_flush_index;
	reg				ff_flush_pending;
	reg				ff_flush_command;
	reg				ff_flush_end;
	reg		[8:0]	ff_cpu_idle_count;
	reg				ff_cpu_timer_active;
	reg		[2:0]	ff_target;
	reg		[21:0]	ff_pending_address;
	reg				ff_pending_cpu;
	reg				ff_pending_write;
	reg		[7:0]	ff_pending_wdata;
	reg				ff_lookup_hit;
	reg				ff_lookup_free;
	reg		[2:0]	ff_lookup_age;
	reg		[7:0]	ff_cache_rdata;
	reg				ff_cache_rdata_en;
	reg		[7:0]	ff_cpu_rdata;
	reg				ff_cpu_rdata_en;
	reg		[19:0]	ff_vram_address;
	reg				ff_vram_valid;
	reg				ff_vram_write;
	reg		[31:0]	ff_vram_wdata;
	reg		[3:0]	ff_vram_mask;

	wire		[21:0]	w_address;
	wire		[21:0]	w_input_address;
	wire		[7:0]	w_hit;
	wire		[7:0]	w_free;
	wire		[7:0]	w_oldest;
	wire				w_hit_found;
	wire				w_free_found;
	wire		[2:0]	w_hit_index;
	wire		[2:0]	w_free_index;
	wire		[2:0]	w_oldest_index;
	wire		[2:0]	w_target;
	wire		[2:0]	w_previous_age;
	wire				w_available;
	wire				w_cpu_accept;
	wire				w_command_accept;
	genvar				line;
	integer				index;

	assign w_input_address = cpu_vram_valid ? cpu_vram_address : cache_vram_address;
	assign w_address = ff_pending_address;
	generate
		for( line = 0; line < 8; line = line + 1 ) begin: gen_lookup
			assign w_hit[line]    = ff_valid[line] && ff_address[line] == w_address[21:2];
			assign w_free[line]   = !ff_valid[line];
			assign w_oldest[line] = ff_age[line] == 3'd7;
		end
	endgenerate
	assign w_hit_found  = |w_hit;
	assign w_free_found = |w_free;
	assign w_hit_index = w_hit[0] ? 3'd0 : w_hit[1] ? 3'd1 : w_hit[2] ? 3'd2 :
	                     w_hit[3] ? 3'd3 : w_hit[4] ? 3'd4 : w_hit[5] ? 3'd5 :
	                     w_hit[6] ? 3'd6 : 3'd7;
	assign w_free_index = w_free[0] ? 3'd0 : w_free[1] ? 3'd1 : w_free[2] ? 3'd2 :
	                      w_free[3] ? 3'd3 : w_free[4] ? 3'd4 : w_free[5] ? 3'd5 :
	                      w_free[6] ? 3'd6 : 3'd7;
	assign w_oldest_index = w_oldest[0] ? 3'd0 : w_oldest[1] ? 3'd1 :
	                        w_oldest[2] ? 3'd2 : w_oldest[3] ? 3'd3 :
	                        w_oldest[4] ? 3'd4 : w_oldest[5] ? 3'd5 :
	                        w_oldest[6] ? 3'd6 : 3'd7;
	assign w_target = w_hit_found ? w_hit_index : w_free_found ? w_free_index : w_oldest_index;
	assign w_previous_age = w_hit_found || !w_free_found ? ff_age[w_target] : 3'd7;
	assign w_available = ff_state == c_idle && !ff_vram_valid &&
	                     !ff_cache_rdata_en && !ff_cpu_rdata_en && !ff_flush_pending;
	assign cpu_vram_ready   = w_available;
	assign cache_vram_ready = w_available && !cpu_vram_valid && !cache_flush_start;
	assign w_cpu_accept     = cpu_vram_valid && cpu_vram_ready;
	assign w_command_accept = cache_vram_valid && cache_vram_ready;
	assign cache_vram_rdata    = ff_cache_rdata;
	assign cache_vram_rdata_en = ff_cache_rdata_en;
	assign cpu_vram_rdata      = ff_cpu_rdata;
	assign cpu_vram_rdata_en   = ff_cpu_rdata_en;
	assign cache_flush_end     = ff_flush_end;
	assign command_vram_address    = { ff_vram_address, 2'b00 };
	assign command_vram_valid      = ff_vram_valid;
	assign command_vram_write      = ff_vram_write;
	assign command_vram_wdata      = ff_vram_wdata;
	assign command_vram_wdata_mask = ff_vram_mask;

	always @( posedge clk ) begin
		if( !reset_n || start ) begin
			ff_valid            <= 8'd0;
			ff_loaded           <= 8'd0;
			ff_state            <= c_idle;
			ff_flush_index      <= 4'd0;
			ff_flush_pending    <= 1'b0;
			ff_flush_command    <= 1'b0;
			ff_flush_end        <= 1'b0;
			ff_cpu_idle_count   <= 9'd0;
			ff_cpu_timer_active <= 1'b0;
			ff_target           <= 3'd0;
			ff_pending_address  <= 22'd0;
			ff_pending_cpu      <= 1'b0;
			ff_pending_write    <= 1'b0;
			ff_pending_wdata    <= 8'd0;
			ff_lookup_hit       <= 1'b0;
			ff_lookup_free      <= 1'b0;
			ff_lookup_age       <= 3'd0;
			ff_cache_rdata      <= 8'd0;
			ff_cache_rdata_en   <= 1'b0;
			ff_cpu_rdata        <= 8'd0;
			ff_cpu_rdata_en     <= 1'b0;
			ff_vram_address     <= 20'd0;
			ff_vram_valid       <= 1'b0;
			ff_vram_write       <= 1'b0;
			ff_vram_wdata       <= 32'd0;
			ff_vram_mask        <= 4'b1111;
			for( index = 0; index < 8; index = index + 1 ) begin
				ff_address[index] <= 20'd0;
				ff_data[index]    <= 32'd0;
				ff_mask[index]    <= 4'b1111;
				ff_age[index]     <= 3'd0;
			end
		end
		else begin
			ff_cache_rdata_en <= 1'b0;
			ff_cpu_rdata_en   <= 1'b0;
			ff_flush_end      <= 1'b0;
			if( cache_flush_start ) begin
				ff_flush_pending <= 1'b1;
				ff_flush_command <= 1'b1;
			end
			if( w_cpu_accept ) begin
				ff_cpu_idle_count   <= 9'd256;
				ff_cpu_timer_active <= 1'b1;
			end
			else if( ff_cpu_timer_active ) begin
				if( ff_cpu_idle_count == 9'd1 ) begin
					ff_cpu_timer_active <= 1'b0;
					ff_flush_pending    <= 1'b1;
				end
				else begin
					ff_cpu_idle_count <= ff_cpu_idle_count - 9'd1;
				end
			end
			case( ff_state )
			c_idle: begin
				if( w_cpu_accept || w_command_accept ) begin
					ff_pending_address <= w_input_address;
					ff_pending_cpu     <= w_cpu_accept;
					ff_pending_write   <= w_cpu_accept ? cpu_vram_write : cache_vram_write;
					ff_pending_wdata   <= w_cpu_accept ? cpu_vram_wdata : cache_vram_wdata;
					ff_state           <= c_lookup;
				end
				else if( ff_flush_pending ) begin
					ff_flush_pending    <= 1'b0;
					ff_cpu_timer_active <= 1'b0;
					ff_flush_index      <= 4'd0;
					ff_state            <= c_flush_scan;
				end
			end
			c_lookup: begin
				ff_target      <= w_target;
				ff_lookup_hit  <= w_hit_found;
				ff_lookup_free <= w_free_found;
				ff_lookup_age  <= w_previous_age;
				ff_state       <= c_process;
			end
			c_process: begin
					for( index = 0; index < 8; index = index + 1 ) begin
						if( index == ff_target ) begin
							ff_age[index] <= 3'd0;
						end
						else if( ff_valid[index] && ff_age[index] < ff_lookup_age ) begin
							ff_age[index] <= ff_age[index] + 3'd1;
						end
					end
					if( ff_pending_write ) begin
						ff_state <= c_idle;
						if( !ff_lookup_hit && !ff_lookup_free && ff_mask[ff_target] != 4'b1111 ) begin
							ff_vram_address <= ff_address[ff_target];
							ff_vram_valid   <= 1'b1;
							ff_vram_write   <= 1'b1;
							ff_vram_wdata   <= ff_data[ff_target];
							ff_vram_mask    <= ff_mask[ff_target];
							ff_state        <= c_evict_write;
						end
						if( !ff_lookup_hit ) begin
							ff_address[ff_target] <= ff_pending_address[21:2];
							ff_mask[ff_target]    <= 4'b1111;
							ff_loaded[ff_target]  <= 1'b0;
						end
						ff_valid[ff_target] <= 1'b1;
						ff_data[ff_target][ff_pending_address[1:0]*8 +: 8] <= ff_pending_wdata;
						ff_mask[ff_target][ff_pending_address[1:0]] <= 1'b0;
					end
					else if( ff_lookup_hit && (ff_loaded[ff_target] || !ff_mask[ff_target][ff_pending_address[1:0]]) ) begin
						ff_state <= c_idle;
						if( ff_pending_cpu ) begin
							ff_cpu_rdata    <= ff_data[ff_target][ff_pending_address[1:0]*8 +: 8];
							ff_cpu_rdata_en <= 1'b1;
						end
						else begin
							ff_cache_rdata    <= ff_data[ff_target][ff_pending_address[1:0]*8 +: 8];
							ff_cache_rdata_en <= 1'b1;
						end
					end
					else begin
						if( !ff_lookup_hit ) begin
							ff_address[ff_target] <= ff_pending_address[21:2];
							ff_mask[ff_target]    <= 4'b1111;
							ff_loaded[ff_target]  <= 1'b0;
							ff_valid[ff_target]   <= 1'b1;
						end
						if( !ff_lookup_hit && !ff_lookup_free && ff_mask[ff_target] != 4'b1111 ) begin
							ff_vram_address <= ff_address[ff_target];
							ff_vram_valid   <= 1'b1;
							ff_vram_write   <= 1'b1;
							ff_vram_wdata   <= ff_data[ff_target];
							ff_vram_mask    <= ff_mask[ff_target];
							ff_state        <= c_evict_read;
						end
						else begin
							ff_vram_address <= ff_pending_address[21:2];
							ff_vram_valid   <= 1'b1;
							ff_vram_write   <= 1'b0;
							ff_vram_mask    <= 4'b1111;
							ff_state        <= c_read_request;
						end
					end
			end
			c_evict_write: begin
				if( ff_vram_valid && command_vram_ready ) begin
					ff_vram_valid <= 1'b0;
					ff_state      <= c_idle;
				end
			end
			c_evict_read: begin
				if( ff_vram_valid && command_vram_ready ) begin
					ff_vram_address <= ff_pending_address[21:2];
					ff_vram_write   <= 1'b0;
					ff_vram_mask    <= 4'b1111;
					ff_state        <= c_read_request;
				end
			end
			c_read_request: begin
				if( ff_vram_valid && command_vram_ready ) begin
					ff_vram_valid <= 1'b0;
					ff_state      <= c_read_wait;
				end
			end
			c_read_wait: begin
				if( command_vram_rdata_en ) begin
					for( index = 0; index < 4; index = index + 1 ) begin
						if( ff_mask[ff_target][index] ) begin
							ff_data[ff_target][index*8 +: 8] <= command_vram_rdata[index*8 +: 8];
						end
					end
					ff_loaded[ff_target] <= 1'b1;
					if( ff_pending_cpu ) begin
						ff_cpu_rdata    <= ff_mask[ff_target][ff_pending_address[1:0]] ?
						                   command_vram_rdata[ff_pending_address[1:0]*8 +: 8] :
						                   ff_data[ff_target][ff_pending_address[1:0]*8 +: 8];
						ff_cpu_rdata_en <= 1'b1;
					end
					else begin
						ff_cache_rdata    <= ff_mask[ff_target][ff_pending_address[1:0]] ?
						                     command_vram_rdata[ff_pending_address[1:0]*8 +: 8] :
						                     ff_data[ff_target][ff_pending_address[1:0]*8 +: 8];
						ff_cache_rdata_en <= 1'b1;
					end
					ff_state <= c_idle;
				end
			end
			c_flush_scan: begin
				if( ff_flush_index == 4'd8 ) begin
					ff_flush_end     <= ff_flush_command || cache_flush_start;
					ff_flush_command <= 1'b0;
					ff_state         <= c_idle;
				end
				else if( ff_valid[ff_flush_index[2:0]] && ff_mask[ff_flush_index[2:0]] != 4'b1111 ) begin
					ff_vram_address <= ff_address[ff_flush_index[2:0]];
					ff_vram_valid   <= 1'b1;
					ff_vram_write   <= 1'b1;
					ff_vram_wdata   <= ff_data[ff_flush_index[2:0]];
					ff_vram_mask    <= ff_mask[ff_flush_index[2:0]];
					ff_state        <= c_flush_write;
				end
				else begin
					ff_valid[ff_flush_index[2:0]] <= 1'b0;
					ff_flush_index <= ff_flush_index + 4'd1;
				end
			end
			c_flush_write: begin
				if( ff_vram_valid && command_vram_ready ) begin
					ff_vram_valid <= 1'b0;
					ff_valid[ff_flush_index[2:0]] <= 1'b0;
					ff_flush_index <= ff_flush_index + 4'd1;
					ff_state       <= c_flush_scan;
				end
			end
			default: ff_state <= c_idle;
			endcase
		end
	end
endmodule