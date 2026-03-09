-- ===================================================================
-- TITLE : HDMI Transmitter
--
--     DESIGN : s.osafune@j7system.jp (J-7SYSTEM WORKS LIMITED)
--     DATE   : 2022/12/01 -> 2023/01/13
--              2023/06/30 add Type-C AltMode option
--
--
-- ===================================================================

-- The MIT License (MIT)
-- Copyright (c) 2022 J-7SYSTEM WORKS LIMITED.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

-- !! NOTICE !!
--
-- This source code does not include HDMI license.
-- When developing and selling HDMI equipment products, it is necessary to become
-- a member of HDMI Licensing Administrator, Inc.
--  >>> https://www.hdmi.org/


-- hdmi_tx component declaration ------------------------------------------------------------------
--
--  component hdmi_tx
--  generic(
--      -- SUPPORTED_DEVICE_FAMILIES {"MAX 10" "Cyclone 10 LP" "Cyclone V" "Cyclone IV E" "Cyclone IV GX" "Cyclone III"}
--      DEVICE_FAMILY   : string := "Cyclone III";
--      CLOCK_FREQUENCY : real := 25.200;       -- Input clock frequency (MHz)
--
--      ENCODE_MODE     : string := "HDMI";     -- "HDMI"    : HDMI
--                                              -- "LITEHDMI": Reduce HDMI-TX(Null packet only)
--                                              -- "DVI"     : DVI
--      USE_EXTCONTROL  : string := "OFF";      -- "ON"      : Use control port (External HDMI timing generator)
--                                              -- "OFF"     : Internal HDMI timing regenerator
--      SYNC_POLARITY   : string := "NEGATIVE"; -- "NEGATIVE": Invert HSYNC/VSYNC to send
--                                              -- "POSITIVE": Non invert HSYNC/VSYNC to send
--      SCANMODE        : string := "AUTO";     -- "AUTO"    : Displays decides
--                                              -- "OVER"    : Overscanned display
--                                              -- "UNDER"   : Underscanned display
--      PICTUREASPECT   : string := "NONE";     -- "NONE"    : Picture aspect ratio information not present
--                                              -- "4:3"     : 4:3 picture
--                                              -- "16:9"    : 16:9 picture
--      FORMATASPECT    : string := "AUTO";     -- "AUTO"    : Same as picture
--                                              -- "4:3"     : 4:3 format
--                                              -- "16:9"    : 16:9 format
--                                              -- "14:9"    : 14:9 format
--                                              -- "NONE"    : Format aspect ratio information not present
--      PICTURESCALING  : string := "FIT";      -- "FIT"     : Picture has been scaled H and V.
--                                              -- "HEIGHT"  : Scaled vertically
--                                              -- "WIDTH"   : Scaled horizontally
--                                              -- "NONE"    : No scaling
--      COLORSPACE      : string := "RGB";      -- "RGB"     : RGB888 (Fixed at Full range)
--                                              -- "BT601"   : YCbCr444(ITU-R BT.601/SMPTE170M)
--                                              -- "BT709"   : YCbCr444(ITU-R BT.709)
--                                              -- "XVYCC601": YCbCr444(xvYCC BT.601)
--                                              -- "XVYCC709": YCbCr444(xvYCC BT.709)
--      YCC_DATARANGE   : string := "LIMITED";  -- "LIMITED" : Limited data range(16-235,240)
--                                              -- "FULL"    : Full range (0-255)
--      CONTENTTYPE     : string := "GRAPHICS"; -- "GRAPHICS": for PC use(IT Content)
--                                              -- "PHOTO"   : for Digital still pictures
--                                              -- "CINEMA"  : for Cinema material
--                                              -- "GAME"    : for Game machine material
--      REPETITION      : integer := 0;         -- Pixel Repetition Factor (0-9)
--      VIDEO_CODE      : integer := 0;         -- Video Information Codes (1-59, 0=No data)
--
--      USE_AUDIO_PACKET: string := "ON";       -- "ON"      : Use Audio sample packet
--                                              -- "OFF"     : Without Audio sample packet
--      AUDIO_FREQUENCY : real := 44.1;         -- Audio sampling frequency (KHz) : 32.0, 44.1, 48.0, 88.2, 96.0, 176.4, 192.0
--      PCMFIFO_DEPTH   : integer := 8;         -- Sample data fifo depth : 8=256word(35sample), 9=512word(72sample), 10=1024word(145sample)
--      CATEGORY_CODE   : std_logic_vector(7 downto 0) := "00000000"    -- Option
--  );
--  port(
--      reset       : in  std_logic;
--      clk         : in  std_logic;            -- Rise edge drive clock
--      clk_x5      : in  std_logic;            -- Transmitter clock (It synchronizes with clk)
--      cc_swap     : in  std_logic := '0';     -- Type-C AltMode swap option
--
--      control     : in  std_logic_vector(3 downto 0) := "0000";   -- [0] : Indicate Active video period
--                                                                  -- [1] : Indicate Video Preamble
--                                                                  -- [2] : Indicate Video Guardband
--                                                                  -- [3] : Allow Packet transmission
--      active      : in  std_logic := '0';             -- Pixel data active
--      r_data      : in  std_logic_vector(7 downto 0); -- R / Cr
--      g_data      : in  std_logic_vector(7 downto 0); -- G / Y
--      b_data      : in  std_logic_vector(7 downto 0); -- B / Cb
--      hsync       : in  std_logic;                    -- Horizontal sync (active high)
--      vsync       : in  std_logic;                    -- Vertical sync (active high)
--
--      pcm_fs      : in  std_logic := '0';                                 -- PCM fs timing. Assert on rising edge.
--      pcm_l       : in  std_logic_vector(23 downto 0) := (others=>'X');   -- Latch on assertion of pcm_fs
--      pcm_r       : in  std_logic_vector(23 downto 0) := (others=>'X');   -- Latch on assertion of pcm_fs
--
--      data        : out std_logic_vector(2 downto 0);
--      data_n      : out std_logic_vector(2 downto 0);
--      clock       : out std_logic;
--      clock_n     : out std_logic
--  );
--  end component;
--
---------------------------------------------------------------------------------------------------


----------------------------------------------------------------------
-- Miscellaneous submodule
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity hdmi_tx_scfifo is
	generic(
		FIFO_WORD_WIDTH		: integer := 4;
		FIFO_DATA_WIDTH		: integer := 8;
		INSTANCE_RAMSTYLE	: string := "auto"	-- "auto","logic","M9K","M20K"
	);
	port(
		reset	: in  std_logic := '0';
		clk		: in  std_logic;
		init	: in  std_logic := '0';

		wrreq	: in  std_logic;
		data	: in  std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
		rdack	: in  std_logic;
		q		: out std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
		empty	: out std_logic;
		full	: out std_logic;
		usedw	: out std_logic_vector(FIFO_WORD_WIDTH downto 0)
	);
end hdmi_tx_scfifo;

architecture RTL of hdmi_tx_scfifo is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;
	function is_false(S:std_logic) return boolean is begin return(S='0'); end;

	-- signal
	type memory_t is array (0 to 2**FIFO_WORD_WIDTH) of std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
	signal ram : memory_t;
	signal q_reg		: std_logic_vector(FIFO_DATA_WIDTH-1 downto 0);
	signal waddr_reg	: std_logic_vector(FIFO_WORD_WIDTH-1 downto 0);
	signal raddr_reg	: std_logic_vector(FIFO_WORD_WIDTH-1 downto 0);
	signal addr_sig 	: std_logic_vector(FIFO_WORD_WIDTH-1 downto 0);
	signal usedw_reg	: std_logic_vector(FIFO_WORD_WIDTH downto 0);
	signal empty_delay_reg	: std_logic;
	signal empty_sig	: std_logic;

	attribute ramstyle : string;
	attribute ramstyle of ram : signal is INSTANCE_RAMSTYLE;

begin

	-- FIFOメモリ --

	addr_sig <= raddr_reg + '1' when is_true(rdack) else raddr_reg;

	process (clk) begin
		if rising_edge(clk) then
			if is_true(wrreq) then
				ram(conv_integer(waddr_reg)) <= data;
			end if;

			q_reg <= ram(conv_integer(addr_sig));
		end if;
	end process;

	q <= q_reg;


	-- FIFOアドレス制御 --

	empty_sig <= '1' when(usedw_reg = 0) else '0';

	process (clk, reset) begin
		if is_true(reset) then
			waddr_reg <= (others=>'0');
			raddr_reg <= (others=>'0');
			usedw_reg <= (others=>'0');
			empty_delay_reg <= '1';

		elsif rising_edge(clk) then
			if is_true(init) then
				waddr_reg <= (others=>'0');
				raddr_reg <= (others=>'0');
				usedw_reg <= (others=>'0');
				empty_delay_reg <= '1';
			else
				if is_true(wrreq) then
					waddr_reg <= waddr_reg + '1';
				end if;

				if is_true(rdack) then
					raddr_reg <= raddr_reg + '1';
				end if;

				if is_false(wrreq) and is_true(rdack) then
					usedw_reg <= usedw_reg - '1';
				elsif is_true(wrreq) and is_false(rdack) then
					usedw_reg <= usedw_reg + '1';
				end if;

				empty_delay_reg <= empty_sig;
			end if;

		end if;
	end process;

	empty <= '1' when(is_true(empty_sig) or (is_false(empty_sig) and is_true(empty_delay_reg))) else '0';
	full  <= usedw_reg(FIFO_WORD_WIDTH);
	usedw <= usedw_reg;

end RTL;


library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity hdmi_tx_delay is
	generic(
		DATA_BITWIDTH		: integer := 8;		-- データのビット幅 
		DELAY_DISTANCE		: integer := 10;	-- 遅延させるクロック数(1以上) 
		INSTANCE_RAMSTYLE	: string := "auto"	-- "auto","logic","M9K","M20K"
	);
	port(
		clk			: in  std_logic;
		enable		: in  std_logic := '1';

		data_in		: in  std_logic_vector(DATA_BITWIDTH-1 downto 0);
		data_out	: out std_logic_vector(DATA_BITWIDTH-1 downto 0)
	);
end hdmi_tx_delay;

architecture RTL of hdmi_tx_delay is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;

	-- signal
	type memory_t is array (0 to DELAY_DISTANCE-1) of std_logic_vector(DATA_BITWIDTH-1 downto 0);
	signal ram : memory_t;

	attribute ramstyle : string;
	attribute ramstyle of ram : signal is INSTANCE_RAMSTYLE;

begin

	process (clk) begin
		if rising_edge(clk) then
			if is_true(enable) then
				ram(0) <= data_in;

				if (DELAY_DISTANCE > 1) then
					for i in 1 to DELAY_DISTANCE-1 loop
						ram(i) <= ram(i-1);
					end loop;
				end if;
			end if;
		end if;
	end process;

	data_out <= ram(DELAY_DISTANCE-1);

end RTL;


----------------------------------------------------------------------
-- Audio sample packet assembler
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_misc.all;

entity hdmi_tx_audiopacket_submodule is
	generic(
		PCMFIFO_DEPTH	: integer := 8;		-- 8=256word(35sample), 9=512word(72sample), 10=1024word(145sample)
		AUDIO_FREQUENCY	: real := 44.1;		-- Audio sampling frequency (KHz)
		CATEGORY_CODE	: std_logic_vector(7 downto 0) := "00000000"
	);
	port(
		reset		: in  std_logic;
		clk			: in  std_logic;
		enable		: in  std_logic := '1';	-- PCM capture enable

		pcm_fs		: in  std_logic;						-- PCM fs timing. Assert on rising edge.
		pcm_l		: in  std_logic_vector(23 downto 0);	-- Latch on assertion of pcm_fs
		pcm_r		: in  std_logic_vector(23 downto 0);	-- Latch on assertion of pcm_fs

		out_ready	: in  std_logic;
		out_valid	: out std_logic;
		out_data	: out std_logic_vector(7 downto 0);
		out_sop		: out std_logic;
		out_eop		: out std_logic
						-- num  0   1   2        26   27   28  29  30
						-- data PB0 PB1 PB2 .... PB26 PB27 HB0 HB1 HB2
						--      sop                                eop
	);
end hdmi_tx_audiopacket_submodule;

architecture RTL of hdmi_tx_audiopacket_submodule is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;

	-- PCMサンプリングコード取得 
	function pcmfscode(AF:real) return std_logic_vector is
	begin
		if    (AF =  48.0) then return "0010";
		elsif (AF =  32.0) then return "0011";
		elsif (AF =  88.2) then return "1000";
		elsif (AF =  96.0) then return "1010";
		elsif (AF = 176.4) then return "1100";
		elsif (AF = 192.0) then return "1110";
		else                    return "0000";
		end if;
	end;
	constant PCMFREQ_CODE	: std_logic_vector(3 downto 0) := pcmfscode(AUDIO_FREQUENCY);

	-- signal
	signal fifoready_sig	: std_logic;
	signal bytecounter_reg	: std_logic_vector(2 downto 0);
	signal framecount		: integer range 0 to 191;
	signal pcm_fs_reg		: std_logic_vector(2 downto 0);			-- [0] asynchronous input
	signal pcmdata_reg		: std_logic_vector(2*24-1 downto 0);	-- asynchronous input
	signal pl_bit_reg		: std_logic;
	signal cl_bit_reg		: std_logic;
	signal pr_bit_reg		: std_logic;
	signal cr_bit_reg		: std_logic;

	signal pcmbyte_sig		: std_logic_vector(7 downto 0);
	signal first_sig		: std_logic;
	signal channelno_sig	: std_logic_vector(3 downto 0);
	signal statbit_sig		: std_logic_vector(191 downto 0);
	signal pcmfifo_wr_sig	: std_logic;
	signal pcmfifo_data_sig	: std_logic_vector(8 downto 0);
	signal pcmfifo_ack_sig	: std_logic;
	signal pcmfifo_q_sig	: std_logic_vector(8 downto 0);
	signal pcmfifo_dw_sig	: std_logic_vector(PCMFIFO_DEPTH downto 0);

	signal arrival_sig		: std_logic;
	signal datacounter_reg	: std_logic_vector(4 downto 0);
	signal readack_reg		: std_logic;
	signal marker_reg		: std_logic_vector(3 downto 0);

	attribute altera_attribute : string;
	attribute altera_attribute of RTL : architecture is
	(
		"-name SDC_STATEMENT ""set_false_path -to [get_registers {*hdmi_tx_audiopacket_submodule:*|pcm_fs_reg[0]}]"";" & 
		"-name SDC_STATEMENT ""set_false_path -to [get_registers {*hdmi_tx_audiopacket_submodule:*|pcmdata_reg[*]}]"""
	);

begin

	-- PCMデータ受信とFIFOキューイング制御 --

	fifoready_sig <= enable when(pcmfifo_dw_sig < 2**PCMFIFO_DEPTH-8) else '0';

	process (clk, reset) begin
		if is_true(reset) then
			pcm_fs_reg <= "000";
			bytecounter_reg <= (others=>'0');
			framecount <= 0;

		elsif rising_edge(clk) then
			pcm_fs_reg <= pcm_fs_reg(1 downto 0) & pcm_fs;

			if ((pcm_fs_reg(2 downto 1) = "01" and is_true(fifoready_sig)) or bytecounter_reg /= "000") then
				bytecounter_reg <= bytecounter_reg + '1';
			end if;

			if (bytecounter_reg = "111") then
				if (framecount = 191) then
					framecount <= 0;
				else
					framecount <= framecount + 1;
				end if;
			end if;

			if (pcm_fs_reg(2 downto 1) = "01" and is_true(fifoready_sig)) then
				pcmdata_reg <= pcm_r & pcm_l;
			end if;
		end if;
	end process;


	-- PCMデータバイトの切り出し --

	with (bytecounter_reg) select pcmbyte_sig <=
		pcmdata_reg(0*8+7 downto 0*8)	when "001",
		pcmdata_reg(1*8+7 downto 1*8)	when "010",
		pcmdata_reg(2*8+7 downto 2*8)	when "011",
		pcmdata_reg(3*8+7 downto 3*8)	when "100",
		pcmdata_reg(4*8+7 downto 4*8)	when "101",
		pcmdata_reg(5*8+7 downto 5*8)	when "110",
		(others=>'X')					when others;


	-- ステータスビット生成とパリティビットの計算 --

	first_sig <= '1' when(framecount = 0) else '0';

	channelno_sig <= "0010" when(bytecounter_reg(2) = '1') else "0001";

	statbit_sig(0) <= '0';						-- 民生用フォーマット 
	statbit_sig(1) <= '0';						-- オーディオサンプルデータ 
	statbit_sig(2) <= '1';						-- 著作権情報設定なし 
	statbit_sig(5 downto 3) <= "000";			-- 2チャネルオーディオ、プリエンファシスなし 
	statbit_sig(7 downto 6) <= "00";			-- モード0 
	statbit_sig(15 downto 8) <= CATEGORY_CODE;	-- 機器カテゴリ 
	statbit_sig(19 downto 16) <= "0000";		-- ソース番号なし 
	statbit_sig(23 downto 20) <= channelno_sig;	-- チャネル番号 
	statbit_sig(27 downto 24) <= PCMFREQ_CODE;	-- サンプリング周波数 
	statbit_sig(29 downto 28) <= "00";			-- クロック精度レベル2 
	statbit_sig(31 downto 30) <= "00";			-- reserved 
	statbit_sig(35 downto 32) <= "1011";		-- 24bit/サンプル 
	statbit_sig(39 downto 36) <= "0000";		-- オリジナルサンプリング周波数指定無し 
	statbit_sig(41 downto 40) <= "00";			-- コピー制限なし 
	statbit_sig(191 downto 42) <= (others=>'0');

	process (clk, reset) begin
		if is_true(reset) then
			pl_bit_reg <= '0';
			cl_bit_reg <= '0';
			pr_bit_reg <= '0';
			cr_bit_reg <= '0';

		elsif rising_edge(clk) then
			case (bytecounter_reg) is
			when "001" =>
				cl_bit_reg <= statbit_sig(framecount);
				pl_bit_reg <= xor_reduce(pcmbyte_sig);
			when "010" =>
				pl_bit_reg <= xor_reduce(pl_bit_reg & pcmbyte_sig);
			when "011" =>
				pl_bit_reg <= xor_reduce(cl_bit_reg & pl_bit_reg & pcmbyte_sig);
			when "100" =>
				cr_bit_reg <= statbit_sig(framecount);
				pr_bit_reg <= xor_reduce(pcmbyte_sig);
			when "101" =>
				pr_bit_reg <= xor_reduce(pr_bit_reg & pcmbyte_sig);
			when "110" =>
				pr_bit_reg <= xor_reduce(cr_bit_reg & pr_bit_reg & pcmbyte_sig);
			when others =>
			end case;

		end if;
	end process;


	-- サブパケットFIFO --

	pcmfifo_data_sig <=	first_sig & pcmbyte_sig when(bytecounter_reg /= "111") else
						first_sig & pr_bit_reg & cr_bit_reg & "00" & pl_bit_reg & cl_bit_reg & "00";

	pcmfifo_wr_sig <= '1' when(bytecounter_reg /= "000") else '0';

	u_fifo : entity work.hdmi_tx_scfifo
	generic map (
		FIFO_WORD_WIDTH	=> PCMFIFO_DEPTH,
		FIFO_DATA_WIDTH	=> 9
	)
	port map (
		reset	=> reset,
		clk		=> clk,
		wrreq	=> pcmfifo_wr_sig,
		data	=> pcmfifo_data_sig,
		rdack	=> pcmfifo_ack_sig,
		q		=> pcmfifo_q_sig,
		usedw	=> pcmfifo_dw_sig
	);


	-- オーディオサンプルパケット送出 --

	arrival_sig <= '1' when(pcmfifo_dw_sig >= 28) else '0';

	pcmfifo_ack_sig <= readack_reg when is_true(out_ready) else '0';

	process (clk, reset) begin
		if is_true(reset) then
			datacounter_reg <= (others=>'0');
			readack_reg <= '0';

		elsif rising_edge(clk) then
			if ((datacounter_reg = 0 and is_true(arrival_sig)) or (datacounter_reg /= 0 and is_true(out_ready))) then
				datacounter_reg <= datacounter_reg + '1';
			end if;

			if (datacounter_reg = 0 and is_true(arrival_sig)) then
				readack_reg <= '1';
			elsif (datacounter_reg = 28) then
				readack_reg <= '0';
			end if;

			for i in 0 to 3 loop
				if (datacounter_reg = 0) then
					marker_reg(i) <= '0';
				elsif (datacounter_reg = i*7+1) then
					marker_reg(i) <= pcmfifo_q_sig(8);
				end if;
			end loop;
		end if;
	end process;

	out_valid <= '1' when(datacounter_reg /= 0) else '0';

	with (datacounter_reg) select out_data <=
		x"02"				when "11101",		-- HB0
		"00001111"			when "11110",		-- HB1
		marker_reg & "0000"	when "11111",		-- HB2
		pcmfifo_q_sig(7 downto 0) when others;	-- PB0-27

	out_sop <= '1' when(datacounter_reg = "00001") else '0';
	out_eop <= '1' when(datacounter_reg = "11111") else '0';

end RTL;


----------------------------------------------------------------------
-- Info packet assembler
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity hdmi_tx_infopacket_submodule is
	generic(
		CLOCK_FREQUENCY	: real := 25.2;			-- Video clock frequency (MHz)
		AUDIO_FREQUENCY	: real := 44.1;			-- Audio sampling frequency (KHz)

		SCANMODE		: string := "AUTO";		-- "AUTO"    : Displays decides
												-- "OVER"    : Overscanned display
												-- "UNDER"   : Underscanned display
		PICTUREASPECT	: string := "NONE";		-- "NONE"    : Picture aspect ratio information not present
												-- "4:3"     : 4:3 picture
												-- "16:9"    : 16:9 picture
		FORMATASPECT	: string := "AUTO";		-- "AUTO"    : Same as picture
												-- "4:3"     : 4:3 format
												-- "16:9"    : 16:9 format
												-- "14:9"    : 14:9 format
												-- "NONE"    : Format aspect ratio information not present
		PICTURESCALING	: string := "FIT";		-- "FIT"     : Picture has been scaled H and V.
												-- "HEIGHT"  : Scaled vertically
												-- "WIDTH"   : Scaled horizontally
												-- "NONE"    : No scaling
		COLORSPACE		: string := "RGB";		-- "RGB"     : RGB888 (Fixed at Full range)
												-- "BT601"   : YCbCr444(ITU-R BT.601/SMPTE170M)
												-- "BT709"   : YCbCr444(ITU-R BT.709)
												-- "XVYCC601": YCbCr444(xvYCC BT.601)
												-- "XVYCC709": YCbCr444(xvYCC BT.709)
		YCC_DATARANGE	: string := "LIMITED";	-- "LIMITED" : Limited data range(16-235,240)
												-- "FULL"    : Full range (0-255)
		CONTENTTYPE		: string := "GRAPHICS";	-- "GRAPHICS": for PC use(IT Content)
												-- "PHOTO"   : for Digital still pictures
												-- "CINEMA"  : for Cinema material
												-- "GAME"    : for Game machine material
		REPETITION		: integer := 0;			-- Pixel Repetition Factor (0-9)
		VIDEO_CODE		: integer := 0			-- Video Information Codes (1-59, 0=No data)
	);
	port(
		reset		: in  std_logic;
		clk			: in  std_logic;

		ready		: out std_logic;
		request		: in  std_logic;	-- Send Info-frame request
		pcm_ena		: out std_logic;	-- pcm capture control

		in_ready	: out std_logic;	-- from audio stream packet
		in_valid	: in  std_logic;
		in_data		: in  std_logic_vector(7 downto 0);
		in_sop		: in  std_logic;
		in_eop		: in  std_logic;

		out_ready	: in  std_logic;
		out_valid	: out std_logic;
		out_data	: out std_logic_vector(7 downto 0);
		out_sop		: out std_logic;
		out_eop		: out std_logic
						-- num  0   1   2        26   27   28  29  30
						-- data PB0 PB1 PB2 .... PB26 PB27 HB0 HB1 HB2
						--      sop                                eop
	);
end hdmi_tx_infopacket_submodule;

architecture RTL of hdmi_tx_infopacket_submodule is
	-- Type declare
	constant PACKET_NUM		: integer := 3;		-- テーブルに格納するパケットの数 
	constant PACKET_LENGTH	: integer := 32;
	type PACKETDATA is array(0 to PACKET_NUM*PACKET_LENGTH-1) of std_logic_vector(7 downto 0);

	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;
	function is_false(S:std_logic) return boolean is begin return(S='0'); end;
	function to_vector(N,W:integer) return std_logic_vector is begin return conv_std_logic_vector(N,W); end;
	function sel(B:boolean; T,F:std_logic_vector) return std_logic_vector is
		begin if B then return T; else return F; end if; end;

	-- Infoパケットチェックサム計算 
	function checksum(P:PACKETDATA; T,L:integer) return std_logic_vector is
		variable i : integer;
		variable sum : std_logic_vector(7 downto 0) := X"00";
	begin
		for i in 1 to L loop sum := sum + P(T+i); end loop;
		for i in 28 to 30 loop sum := sum + P(T+i); end loop;
		sum := (not sum) + '1';
		return sum;
	end;

	-- ACR N値計算 
	function calc_acr_n(AF:real) return integer is
	begin
		if    (AF =  32.0) then return  4096;
		elsif (AF =  48.0) then return  6144;
		elsif (AF =  96.0) then return 12288;
		elsif (AF = 192.0) then return 24576;
		elsif (AF =  44.1) then return  6272;
		elsif (AF =  88.2) then return 12544;
		elsif (AF = 176.4) then return 25088;
		else return 0;
		end if;
	end;

	-- ACR CTS値計算 
	function calc_acr_cts(DF,AF:real) return integer is
		variable n : integer;
	begin
		n := calc_acr_n(AF);
		if (n = 6272 or n = 12544 or n = 25088) then
			return integer(DF*1000.0*10.0/9.0);
		else
			return integer(DF*1000.0);
		end if;
	end;

	-- Constant declare
	constant AVIINFO_TOP	: integer := 0*PACKET_LENGTH;
	constant AUDIOINFO_TOP	: integer := 1*PACKET_LENGTH;
	constant ACR_TOP		: integer := 2*PACKET_LENGTH;

	constant SCANINFO		: std_logic_vector(1 downto 0) := sel(SCANMODE="OVER", "01", sel(SCANMODE="UNDER", "10","00"));
	constant PICTUREAR		: std_logic_vector(1 downto 0) :=
				sel(PICTUREASPECT="4:3", "01", sel(PICTUREASPECT="16:9", "10","00"));
	constant SCALING		: std_logic_vector(1 downto 0) :=
				sel(PICTURESCALING="FIT", "11", sel(PICTURESCALING="HEIGHT", "10", sel(PICTURESCALING="WIDTH", "01","00")));
	constant FORMATINFO		: std_logic_vector(0 downto 0) := sel(FORMATASPECT="NONE", "0","1");
	constant FORMATAR		: std_logic_vector(3 downto 0) :=
				sel(FORMATASPECT="AUTO", "1000", sel(FORMATASPECT="4:3", "1001", sel(FORMATASPECT="16:9", "1010", sel(FORMATASPECT="14:9" ,"1011", "0000"))));
	constant Y_CODE			: std_logic_vector(1 downto 0) := sel(COLORSPACE="RGB", "00","10");
	constant COLORIMETRY	: std_logic_vector(1 downto 0) :=
				sel(COLORSPACE="BT601", "01", sel(COLORSPACE="BT709", "10", sel(COLORSPACE="XVYCC601" or COLORSPACE="XVYCC709", "11","00")));
	constant EXCOLORIMETRY	: std_logic_vector(2 downto 0) := sel(COLORSPACE="XVYCC709", "001","000");
	constant RGBQUANTRANGE	: std_logic_vector(1 downto 0) := sel(COLORSPACE="RGB", "10","00");
	constant YCCQUANTRANGE	: std_logic_vector(1 downto 0) := sel(COLORSPACE/="RGB" and YCC_DATARANGE="FULL", "01","00");
	constant ITCONTENT		: std_logic_vector(0 downto 0) := sel(CONTENTTYPE="GRAPHICS", "1","0");
	constant CONTENTCODE	: std_logic_vector(1 downto 0) :=
				sel(CONTENTTYPE="PHOTO", "01", sel(CONTENTTYPE="CINEMA", "10", sel(CONTENTTYPE="GAME", "11","00")));
	constant REPFACTOR		: std_logic_vector(3 downto 0) := to_vector(REPETITION, 4);
	constant VIC_CODE		: std_logic_vector(6 downto 0) := to_vector(VIDEO_CODE, 7);

	constant CODINGTYPE		: std_logic_vector(3 downto 0) := "0001";	-- IEC 60958 PCM
	constant CHANNELCOUNT	: std_logic_vector(2 downto 0) := "001";	-- 2ch
	constant SAMPLEFREQ		: std_logic_vector(2 downto 0) := "000";	-- Refer to stream header
	constant SAMPLESIZE		: std_logic_vector(1 downto 0) := "00";		-- Refer to stream header
	constant SPLOCATION		: std_logic_vector(7 downto 0) := x"00";	-- ch1=FL,ch2=FR
	constant DM_INH			: std_logic := '0';
	constant LEVELSHIFT		: std_logic_vector(3 downto 0) := "0000";	-- 0dB
	constant LFEPBL			: std_logic_vector(1 downto 0) := "00";		-- no information

	constant ACR_CTS		: std_logic_vector(19 downto 0) := to_vector(calc_acr_cts(CLOCK_FREQUENCY, AUDIO_FREQUENCY), 20);
	constant ACR_N			: std_logic_vector(19 downto 0) := to_vector(calc_acr_n(AUDIO_FREQUENCY), 20);

	-- signal
	signal infotable_sig	: PACKETDATA := (others=>x"00");
	signal counter_reg		: std_logic_vector(2+5-1 downto 0);
	signal data_reg			: std_logic_vector(7 downto 0);
	signal valid_reg		: std_logic;
	signal sop_reg			: std_logic;
	signal eop_reg			: std_logic;
	signal pcmena_reg		: std_logic;
	signal ready_old_reg	: std_logic;
	signal infosel_reg		: std_logic;

	signal ready_sig		: std_logic;
	signal out_ready_sig	: std_logic;
	signal in_ready_sig		: std_logic;

begin

	-- パケットデータテーブル作成 --

	assert (ACR_N /= 0) report "AUDIO_FREQUENCY setting value is out of range." severity FAILURE;

	-- AVI infoframe
	infotable_sig(AVIINFO_TOP+28) <= x"82";		-- AVI info header (0x82)
	infotable_sig(AVIINFO_TOP+29) <= x"02";		-- Version (0x02)
	infotable_sig(AVIINFO_TOP+30) <= x"0d";		-- Lengeth (13)

	infotable_sig(AVIINFO_TOP+ 0) <= checksum(infotable_sig, AVIINFO_TOP, 13);
	infotable_sig(AVIINFO_TOP+ 1) <= '0' & Y_CODE & FORMATINFO & "00" & SCANINFO;
	infotable_sig(AVIINFO_TOP+ 2) <= COLORIMETRY & PICTUREAR & FORMATAR;
	infotable_sig(AVIINFO_TOP+ 3) <= ITCONTENT & EXCOLORIMETRY & RGBQUANTRANGE & SCALING;
	infotable_sig(AVIINFO_TOP+ 4) <= '0' & VIC_CODE;
	infotable_sig(AVIINFO_TOP+ 5) <= YCCQUANTRANGE & CONTENTCODE & REPFACTOR;

	-- Audio infoframe
	infotable_sig(AUDIOINFO_TOP+28) <= x"84";	-- Audio info header (0x84)
	infotable_sig(AUDIOINFO_TOP+29) <= x"01";	-- Version (0x01)
	infotable_sig(AUDIOINFO_TOP+30) <= x"0a";	-- Lengeth (10)

	infotable_sig(AUDIOINFO_TOP+ 0) <= checksum(infotable_sig, AUDIOINFO_TOP, 10);
	infotable_sig(AUDIOINFO_TOP+ 1) <= CODINGTYPE & '0' & CHANNELCOUNT;
	infotable_sig(AUDIOINFO_TOP+ 2) <= "000" & SAMPLEFREQ & SAMPLESIZE;
	infotable_sig(AUDIOINFO_TOP+ 4) <= SPLOCATION;
	infotable_sig(AUDIOINFO_TOP+ 5) <= DM_INH & LEVELSHIFT & '0' & LFEPBL;

	-- Audio Clock Regeneration
	infotable_sig(ACR_TOP+28) <= x"01";			-- ACR header (0x01)
	infotable_sig(ACR_TOP+29) <= x"00";			-- 0x00
	infotable_sig(ACR_TOP+30) <= x"00";			-- 0x00

	infotable_sig(ACR_TOP+ 0) <= "00000000";
	infotable_sig(ACR_TOP+ 1) <= "0000" & ACR_CTS(19 downto 16);
	infotable_sig(ACR_TOP+ 2) <= ACR_CTS(15 downto 8);
	infotable_sig(ACR_TOP+ 3) <= ACR_CTS(7 downto 0);
	infotable_sig(ACR_TOP+ 4) <= "0000" & ACR_N(19 downto 16);
	infotable_sig(ACR_TOP+ 5) <= ACR_N(15 downto 8);
	infotable_sig(ACR_TOP+ 6) <= ACR_N(7 downto 0);


	-- インフォメーションパケット送出 --

	ready_sig <= '1' when(counter_reg = 0) else '0';

	process (clk, reset) begin
		if is_true(reset) then
			counter_reg <= (others=>'0');
			valid_reg <= '0';
			sop_reg <= '0';
			eop_reg <= '0';
			pcmena_reg <= '0';

		elsif rising_edge(clk) then
			if ((counter_reg /= 0 or is_true(request)) and is_true(out_ready_sig)) then
				data_reg <= infotable_sig(conv_integer(counter_reg));

				if (counter_reg(4 downto 0) = "00000") then
					valid_reg <= '1';
				elsif (counter_reg(4 downto 0) = "11111") then
					valid_reg <= '0';
				end if;

				if (counter_reg(4 downto 0) = "00000") then
					sop_reg <= '1';
				else
					sop_reg <= '0';
				end if;

				if (counter_reg(4 downto 0) = "11110") then
					eop_reg <= '1';
				else
					eop_reg <= '0';
				end if;

				if (counter_reg = PACKET_NUM*PACKET_LENGTH-1) then
					counter_reg <= (others=>'0');
					pcmena_reg <= '1';
				else
					counter_reg <= counter_reg + '1';
				end if;
			end if;

		end if;
	end process;

	ready <= ready_sig;
	pcm_ena <= pcmena_reg;


	-- オーディオパケットとの調停 --

	process (clk, reset) begin
		if is_true(reset) then
			ready_old_reg <= '0';
			infosel_reg <= '0';

		elsif rising_edge(clk) then
			ready_old_reg <= ready_sig;

			if is_true(infosel_reg) then
				if (is_false(ready_old_reg) and is_true(ready_sig)) then
					infosel_reg <= '0';
				end if;
			else
				if (is_true(request) and ((is_true(in_valid) and is_true(in_eop) and is_true(in_ready_sig)) or is_false(in_valid))) then
					infosel_reg <= '1';
				end if;
			end if;

		end if;
	end process;

	out_ready_sig <= out_ready when is_true(infosel_reg)  else '0';
	in_ready_sig  <= out_ready when is_false(infosel_reg) else '0';

	in_ready  <= in_ready_sig;
	out_valid <= valid_reg when is_true(infosel_reg) else in_valid;
	out_data  <= data_reg  when is_true(infosel_reg) else in_data;
	out_sop   <= sop_reg   when is_true(infosel_reg) else in_sop;
	out_eop   <= eop_reg   when is_true(infosel_reg) else in_eop;

end RTL;


----------------------------------------------------------------------
-- Data island assembler 
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity hdmi_tx_dataisland_submodule is
	port(
		reset		: in  std_logic;
		clk			: in  std_logic;

		in_ready	: out std_logic;
		in_valid	: in  std_logic;
		in_data		: in  std_logic_vector(7 downto 0);
		in_sop		: in  std_logic;
		in_eop		: in  std_logic;
						-- num  0   1   2        26   27   28  29  30
						-- data PB0 PB1 PB2 .... PB26 PB27 HB0 HB1 HB2
						--      sop                                eop

		packetready	: in  std_logic;
		preamble	: out std_logic;
		guardband	: out std_logic;
		dataenable	: out std_logic;
		packetdata	: out std_logic_vector(9 downto 0)
						-- [9:6] ch2.d[3:0], [5:2] ch1.d[3:0], [1:0] ch0.d[3:2]
	);
end hdmi_tx_dataisland_submodule;

architecture RTL of hdmi_tx_dataisland_submodule is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;

	-- BCH符号演算 
	function bch(V:std_logic_vector(7 downto 0); D:std_logic) return std_logic_vector is
		variable a : std_logic_vector(7 downto 0);
	begin
		a := '0' & V(7 downto 1);
		if ((V(0) xor D) = '1') then
			a := a xor "10000011";
		end if;
		return a;
	end;

	function bch2(V:std_logic_vector(7 downto 0); D:std_logic_vector(1 downto 0)) return std_logic_vector is
		variable a,b : std_logic_vector(7 downto 0);
	begin
		a := bch(V, D(0));
		b := bch(a, D(1));
		return b;
	end;

	-- Constant declare
	constant READY_COUNT	: std_logic_vector(5 downto 0) := "010101";	-- ready count(21)
	constant START_COUNT	: std_logic_vector(5 downto 0) := "010110";	-- start count(22)
	constant STOP_COUNT		: std_logic_vector(5 downto 0) := "000110";	-- stop count(6)
	constant FIRST_COUNT	: std_logic_vector(5 downto 0) := "100000"; -- data first count(32)
	constant SUBPACKET_NUM	: integer := 4;

	-- signal
	signal counter_reg	: std_logic_vector(5 downto 0);
	signal ready_sig	: std_logic;
	signal init_sig		: std_logic;
	signal shift_sig	: std_logic;
	signal first_sig	: std_logic;
	signal hb_bch_sig	: std_logic;
	signal sb_bch_sig	: std_logic;

	signal datacount	: integer range 0 to 31;
	signal sb_reg		: std_logic_vector(SUBPACKET_NUM*7*8-1 downto 0);
	signal hb_reg		: std_logic_vector(3*8-1 downto 0);
	signal bch_sb_reg	: std_logic_vector(SUBPACKET_NUM*8-1 downto 0);
	signal bch_hb_reg	: std_logic_vector(1*8-1 downto 0);

begin

	-- データアイランド区間の信号生成シーケンサ --

	ready_sig <= '1' when(counter_reg = STOP_COUNT) else '0';

	init_sig  <= not counter_reg(5);
	shift_sig <= counter_reg(5);
	first_sig <= '1' when(counter_reg = FIRST_COUNT) else '0';

	hb_bch_sig <= '1' when(counter_reg(5 downto 3) = "111") else '0';
	sb_bch_sig <= '1' when(counter_reg(5 downto 2) = "1111") else '0';

	process (clk, reset) begin
		if is_true(reset) then
			counter_reg <= STOP_COUNT;

		elsif rising_edge(clk) then
			if (is_true(in_valid) and is_true(in_eop) and is_true(ready_sig)) then
				counter_reg <= READY_COUNT;
			elsif ((counter_reg = READY_COUNT and is_true(packetready)) or (counter_reg /= READY_COUNT and counter_reg /= STOP_COUNT)) then
				counter_reg <= counter_reg + '1';
			end if;

		end if;
	end process;

	with counter_reg(5 downto 1) select preamble <=
		'1' when "01011"|"01100"|"01101"|"01110",
		'0' when others;

	with counter_reg(5 downto 1) select guardband <=
		'1' when "01111"|"00000",
		'0' when others;

	dataenable <= counter_reg(5);


	-- Avalon-ST パケットデータ受信 --

	in_ready <= ready_sig;

	process (clk, reset) begin
		if is_true(reset) then
			datacount <= 0;

		elsif rising_edge(clk) then
			if is_true(shift_sig) then
				for i in 0 to SUBPACKET_NUM-1 loop
					sb_reg(i*7*8+55 downto i*7*8) <= "00" & sb_reg(i*7*8+55 downto i*7*8+2);
				end loop;
				hb_reg <= '0' & hb_reg(2*8+7 downto 1);

			elsif (is_true(in_valid) and is_true(ready_sig)) then
				if is_true(in_eop) then
					datacount <= 0;
				elsif is_true(in_sop) then
					datacount <= 1;
				elsif (datacount /= 0 and datacount /= 31) then
					datacount <= datacount + 1;
				end if;

				if (is_true(in_sop) or datacount /= 0) then
					for i in 0 to SUBPACKET_NUM*7-1 loop
						if (datacount = i) then
							sb_reg(i*8+7 downto i*8) <= in_data;	-- byte0-27 : packet byte
						end if;
					end loop;

					for i in 0 to 2 loop
						if (datacount = i+28) then
							hb_reg(i*8+7 downto i*8) <= in_data;	-- byte28-30 : header byte
						end if;
					end loop;
				end if;
			end if;
		end if;
	end process;


	-- ECCブロック付加と信号アサイン --

	process (clk, reset) begin
		if is_true(reset) then
			bch_sb_reg <= (others=>'0');
			bch_hb_reg <= (others=>'0');

		elsif rising_edge(clk) then
			for i in 0 to SUBPACKET_NUM-1 loop
				if is_true(init_sig) then
					bch_sb_reg(i*8+7 downto i*8) <= (others=>'0');
				elsif is_true(sb_bch_sig) then
					bch_sb_reg(i*8+7 downto i*8) <= "00" & bch_sb_reg(i*8+7 downto i*8+2);
				elsif is_true(shift_sig) then
					bch_sb_reg(i*8+7 downto i*8) <=	bch2(bch_sb_reg(i*8+7 downto i*8), sb_reg(i*7*8+1 downto i*7*8));
				end if;
			end loop;

			if is_true(init_sig) then
				bch_hb_reg <= (others=>'0');
			elsif is_true(hb_bch_sig) then
				bch_hb_reg <= '0' & bch_hb_reg(7 downto 1);
			elsif is_true(shift_sig) then
				bch_hb_reg <= bch(bch_hb_reg, hb_reg(0));
			end if;

		end if;
	end process;

	packetdata(0) <= bch_hb_reg(0) when is_true(hb_bch_sig) else hb_reg(0);
	packetdata(1) <= '0' when is_true(first_sig) else '1';

	gen_loop : for i in 0 to SUBPACKET_NUM-1 generate
		packetdata(i+2) <= bch_sb_reg(i*8+0) when is_true(sb_bch_sig) else sb_reg(i*7*8+0);	-- ch1
		packetdata(i+6) <= bch_sb_reg(i*8+1) when is_true(sb_bch_sig) else sb_reg(i*7*8+1);	-- ch2
	end generate;

end RTL;


----------------------------------------------------------------------
--  TMDS encoder
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity hdmi_tx_tmds_encoder_submodule is
	generic(
		TMDS_CHANNEL	: integer := 0	-- 0,1,2
	);
	port(
		clk		: in  std_logic;

		mode	: in  std_logic_vector(2 downto 0); -- Encode mode
													--     000 : Control/Preamble
													--     001 : Video Active
													--     010 : Data Island
													--     101 : Video Guardband
													--     110 : Data Guardband
		d_in	: in  std_logic_vector(7 downto 0);	-- Video Active period
		s_in	: in  std_logic_vector(3 downto 0);	-- Data Island period
		c_in	: in  std_logic_vector(1 downto 0);	-- Control period

		q_out	: out std_logic_vector(9 downto 0)
	);
end hdmi_tx_tmds_encoder_submodule;

architecture RTL of hdmi_tx_tmds_encoder_submodule is
	-- Misc function 
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;
	function is_false(S:std_logic) return boolean is begin return(S='0'); end;

	-- 入力ベクターの1の数を数える 
	function number1s(D:std_logic_vector) return integer is
		variable i,num : integer;
	begin
		num := 0;
		for i in 0 to D'length-1 loop
			if (D(i) = '1') then num := num + 1; end if;
		end loop;
		return num;
	end;

	-- 入力バイトの変換 (ビット変化を4以上にする)
	function byteencode(D:std_logic_vector(7 downto 0)) return std_logic_vector is
		variable num : integer;
		variable code : std_logic;
		variable q_m : std_logic_vector(8 downto 0);
	begin
		num := number1s(D);
		if (num > 4 or (num = 4 and D(0) = '0')) then
			code := '1';
		else
			code := '0';
		end if;

		q_m(0) := D(0);
		for i in 1 to 7 loop
			q_m(i) := q_m(i - 1) xor D(i) xor code;
		end loop;
		q_m(8) := not code;

		return q_m;
	end;

	-- signal 
	signal sel_reg		: std_logic_vector(1 downto 0) := "00";
	signal sel_dly_reg	: std_logic_vector(1 downto 0) := "00";

	signal cnt			: integer range -4 to 4;
	signal qm_reg		: std_logic_vector(8 downto 0);
	signal qout_reg		: std_logic_vector(9 downto 0);
	signal s_reg		: std_logic_vector(3 downto 0);
	signal sout_reg		: std_logic_vector(9 downto 0);
	signal c_reg		: std_logic_vector(3 downto 0);
	signal cout_reg		: std_logic_vector(9 downto 0);

begin

	-- 入力信号をラッチ --

	process (clk) begin
		if rising_edge(clk) then
			sel_dly_reg <= sel_reg;

			case mode is
			when "001" =>
				sel_reg <= "01";
			when "010" =>
				sel_reg <= "10";
			when others =>
				sel_reg <= "00";
			end case;

			qm_reg <= byteencode(d_in);
			s_reg <= s_in;

			if is_true(mode(2)) then
				c_reg <= mode(1 downto 0) & c_in;
			else
				c_reg <= "00" & c_in;
			end if;

		end if;
	end process;


	-- データをTMDSにエンコード --

	process (clk)
		variable num, inc_c : integer;
		variable inv_q, sign_eq : std_logic;
	begin
		if rising_edge(clk) then

			-- Video active区間のエンコード 

			num := number1s(qm_reg(7 downto 0)) - 4;

			if (cnt = 0 or num = 0) then
				inv_q := not qm_reg(8);
				sign_eq := '0';
			elsif ((cnt >= 0 and num >= 0) or (cnt < 0 and num < 0)) then
				inv_q := '1';
				sign_eq := '1';
			else
				inv_q := '0';
				sign_eq := '0';
			end if;

			if ((qm_reg(8) = sign_eq) and not(cnt = 0 or num = 0)) then
				inc_c := num - 1;
			else
				inc_c := num;
			end if;

			if is_false(sel_reg(0)) then
				cnt <= 0;
			elsif is_true(inv_q) then
				cnt <= cnt - inc_c;
			else
				cnt <= cnt + inc_c;
			end if;

			if is_true(inv_q) then
				qout_reg <= inv_q & qm_reg(8) & not qm_reg(7 downto 0);
			else
				qout_reg <= inv_q & qm_reg(8 downto 0);
			end if;

			-- Data Island区間のエンコード(TERC4)

			case s_reg is
			when "0000" => sout_reg <= "1010011100";
			when "0001" => sout_reg <= "1001100011";
			when "0010" => sout_reg <= "1011100100";
			when "0011" => sout_reg <= "1011100010";
			when "0100" => sout_reg <= "0101110001";
			when "0101" => sout_reg <= "0100011110";
			when "0110" => sout_reg <= "0110001110";
			when "0111" => sout_reg <= "0100111100";
			when "1000" => sout_reg <= "1011001100";
			when "1001" => sout_reg <= "0100111001";
			when "1010" => sout_reg <= "0110011100";
			when "1011" => sout_reg <= "1011000110";
			when "1100" => sout_reg <= "1010001110";
			when "1101" => sout_reg <= "1001110001";
			when "1110" => sout_reg <= "0101100011";
			when others => sout_reg <= "1011000011";
			end case;

			-- Control/Guadband区間のエンコード 

			if is_true(c_reg(2)) then			-- Video Guardband
				if (TMDS_CHANNEL = 1) then
					cout_reg <= "0100110011";	-- Ch.1
				else
					cout_reg <= "1011001100";	-- Ch.0 or 2
				end if;

			elsif is_true(c_reg(3)) then		-- Data Island Guardband
				if (TMDS_CHANNEL = 0) then
					case c_reg(1 downto 0) is
					when "00" =>	cout_reg <= "1010001110";	-- TERC4("1100")
					when "01" =>	cout_reg <= "1001110001";	-- TERC4("1101")
					when "10" =>	cout_reg <= "0101100011";	-- TERC4("1110")
					when others =>	cout_reg <= "1011000011";	-- TERC4("1111")
					end case;
				else
					cout_reg <= "0100110011";	-- Ch.1 or 2
				end if;

			else								-- Control
				case c_reg(1 downto 0) is
				when "00" =>	cout_reg <= "1101010100";
				when "01" =>	cout_reg <= "0010101011";
				when "10" =>	cout_reg <= "0101010100";
				when others =>	cout_reg <= "1010101011";
				end case;
			end if;

		end if;
	end process;

	q_out <= qout_reg when is_true(sel_dly_reg(0)) else
			sout_reg when is_true(sel_dly_reg(1)) else
			cout_reg;

end RTL;


----------------------------------------------------------------------
-- Pseudo-differential transmitter (for Intel)
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;

entity hdmi_tx_pdiff_submodule is
	generic(
		DEVICE_FAMILY	: string
	);
	port(
		clk			: in  std_logic;		-- Rise edge drive clock
		clk_x5		: in  std_logic;		-- Transmitter clock (It synchronizes with clk)

		tx_swap		: in  std_logic := '0';	-- Type-C AltMode swap option
		data0_in	: in  std_logic_vector(9 downto 0);
		data1_in	: in  std_logic_vector(9 downto 0);
		data2_in	: in  std_logic_vector(9 downto 0);

		tx			: out std_logic_vector(2 downto 0);
		tx_n		: out std_logic_vector(2 downto 0);
		txc			: out std_logic;
		txc_n		: out std_logic
	);
end hdmi_tx_pdiff_submodule;

architecture RTL of hdmi_tx_pdiff_submodule is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;
	function is_false(S:std_logic) return boolean is begin return(S='0'); end;

	-- signal
	signal start_reg	: std_logic_vector(3 downto 0) := "0000";
	signal data_in_reg	: std_logic_vector(4*10-1 downto 0);
	signal ser_reg		: std_logic_vector(4*10-1 downto 0);
	signal data_p_reg	: std_logic_vector(7 downto 0);
	signal data_n_reg	: std_logic_vector(7 downto 0);
	signal ddo_p_sig	: std_logic_vector(3 downto 0);
	signal ddo_n_sig	: std_logic_vector(3 downto 0);

	attribute preserve  : boolean;	-- レジスタ最適化を抑止 
	attribute preserve  of start_reg	: signal is true;
	attribute preserve  of ser_reg		: signal is true;
	attribute preserve  of data_p_reg	: signal is true;
	attribute preserve  of data_n_reg	: signal is true;

begin

	-- 内部クロックへの載せ替え --

	process (clk) begin
		if rising_edge(clk) then
			if is_true(tx_swap) then
				data_in_reg <= data1_in & data0_in & "0000011111" & data2_in;
			else
				data_in_reg <= "0000011111" & data2_in & data1_in & data0_in;
			end if;
		end if;
	end process;


	-- ラッチ信号の生成とシフトレジスタ --

	process (clk_x5) begin
		if rising_edge(clk_x5) then
			if is_false(start_reg(0)) then
				start_reg <= "1111";
				ser_reg <= data_in_reg;
			else
				start_reg <= '0' & start_reg(3 downto 1);

				for i in 0 to 3 loop
					ser_reg(i*10+9 downto i*10) <= "XX" & ser_reg(i*10+9 downto i*10+2);
				end loop;
			end if;

			for i in 0 to 3 loop
				data_p_reg(i+4) <= ser_reg(i*10+0);		-- positive side datain_h
				data_p_reg(i+0) <= ser_reg(i*10+1);		-- positive side datain_l
				data_n_reg(i+4) <= ser_reg(i*10+0);		-- negative side datain_h
				data_n_reg(i+0) <= ser_reg(i*10+1);		-- negative side datain_l
			end loop;
		end if;
	end process;

	u_ddo_p : altddio_out
	generic map (
		lpm_type				=> "altddio_out",
		intended_device_family	=> DEVICE_FAMILY,
		invert_output			=> "OFF",
		width					=> 4
	)
	port map (
		outclock	=> clk_x5,
		datain_h	=> data_p_reg(7 downto 4),
		datain_l	=> data_p_reg(3 downto 0),
		dataout		=> ddo_p_sig
	);

	u_ddo_n : altddio_out
	generic map (
		lpm_type				=> "altddio_out",
		intended_device_family	=> DEVICE_FAMILY,
		invert_output			=> "ON",
		width					=> 4
	)
	port map (
		outclock	=> clk_x5,
		datain_h	=> data_n_reg(7 downto 4),
		datain_l	=> data_n_reg(3 downto 0),
		dataout		=> ddo_n_sig
	);

	tx    <= ddo_p_sig(2 downto 0);
	tx_n  <= ddo_n_sig(2 downto 0);
	txc   <= ddo_p_sig(3);
	txc_n <= ddo_n_sig(3);

end RTL;


----------------------------------------------------------------------
-- top module
----------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity hdmi_tx is
	generic(
		-- SUPPORTED_DEVICE_FAMILIES {"MAX 10" "Cyclone 10 LP" "Cyclone V" "Cyclone IV E" "Cyclone IV GX" "Cyclone III"}
		DEVICE_FAMILY	: string := "Cyclone III";
		CLOCK_FREQUENCY	: real := 25.200;		-- Input clock frequency (MHz)

		ENCODE_MODE		: string := "HDMI";		-- "HDMI"    : HDMI
												-- "LITEHDMI": Reduce HDMI-TX(Null packet only)
												-- "DVI"     : DVI
		USE_EXTCONTROL	: string := "OFF";		-- "ON"      : Use control port (External HDMI timing generator)
												-- "OFF"     : Internal HDMI timing regenerator
		SYNC_POLARITY	: string := "NEGATIVE";	-- "NEGATIVE": Invert HSYNC/VSYNC to send
												-- "POSITIVE": Non invert HSYNC/VSYNC to send
		SCANMODE		: string := "AUTO";		-- "AUTO"    : Displays decides
												-- "OVER"    : Overscanned display
												-- "UNDER"   : Underscanned display
		PICTUREASPECT	: string := "NONE";		-- "NONE"    : Picture aspect ratio information not present
												-- "4:3"     : 4:3 picture
												-- "16:9"    : 16:9 picture
		FORMATASPECT	: string := "AUTO";		-- "AUTO"    : Same as picture
												-- "4:3"     : 4:3 format
												-- "16:9"    : 16:9 format
												-- "14:9"    : 14:9 format
												-- "NONE"    : Format aspect ratio information not present
		PICTURESCALING	: string := "FIT";		-- "FIT"     : Picture has been scaled H and V.
												-- "HEIGHT"  : Scaled vertically
												-- "WIDTH"   : Scaled horizontally
												-- "NONE"    : No scaling
		COLORSPACE		: string := "RGB";		-- "RGB"     : RGB888 (Fixed at Full range)
												-- "BT601"   : YCbCr444(ITU-R BT.601/SMPTE170M)
												-- "BT709"   : YCbCr444(ITU-R BT.709)
												-- "XVYCC601": YCbCr444(xvYCC BT.601)
												-- "XVYCC709": YCbCr444(xvYCC BT.709)
		YCC_DATARANGE	: string := "LIMITED";	-- "LIMITED" : Limited data range(16-235,240)
												-- "FULL"    : Full range (0-255)
		CONTENTTYPE		: string := "GRAPHICS";	-- "GRAPHICS": for PC use(IT Content)
												-- "PHOTO"   : for Digital still pictures
												-- "CINEMA"  : for Cinema material
												-- "GAME"    : for Game machine material
		REPETITION		: integer := 0;			-- Pixel Repetition Factor (0-9)
		VIDEO_CODE		: integer := 0;			-- Video Information Codes (1-59, 0=No data)

		USE_AUDIO_PACKET: string := "ON";		-- "ON"      : Use Audio sample packet
												-- "OFF"     : Without Audio sample packet
		AUDIO_FREQUENCY	: real := 44.1;			-- Audio sampling frequency (KHz) : 32.0, 44.1, 48.0, 88.2, 96.0, 176.4, 192.0
		PCMFIFO_DEPTH	: integer := 8;			-- Sample data fifo depth : 8=256word(35sample), 9=512word(72sample), 10=1024word(145sample)
		CATEGORY_CODE	: std_logic_vector(7 downto 0) := "00000000"
	);
	port(
		reset		: in  std_logic;
		clk			: in  std_logic;			-- Rise edge drive clock
		clk_x5		: in  std_logic;			-- Transmitter clock (It synchronizes with clk)
		cc_swap		: in  std_logic := '0';		-- Type-C AltMode swap option

		control		: in  std_logic_vector(3 downto 0) := "0000";	-- [0] : Indicate Active video period
																	-- [1] : Indicate Video Preamble
																	-- [2] : Indicate Video Guardband
																	-- [3] : Allow Packet transmission
		active		: in  std_logic := '0';				-- Pixel data active
		r_data		: in  std_logic_vector(7 downto 0);	-- R / Cr
		g_data		: in  std_logic_vector(7 downto 0);	-- G / Y
		b_data		: in  std_logic_vector(7 downto 0);	-- B / Cb
		hsync		: in  std_logic;					-- Horizontal sync (active high)
		vsync		: in  std_logic;					-- Vertical sync (active high)

		pcm_fs		: in  std_logic := '0';									-- PCM fs timing. Assert on rising edge.
		pcm_l		: in  std_logic_vector(23 downto 0) := (others=>'X');	-- Latch on assertion of pcm_fs
		pcm_r		: in  std_logic_vector(23 downto 0) := (others=>'X');	-- Latch on assertion of pcm_fs

		data		: out std_logic_vector(2 downto 0);
		data_n		: out std_logic_vector(2 downto 0);
		clock		: out std_logic;
		clock_n		: out std_logic
	);
end hdmi_tx;

architecture RTL of hdmi_tx is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;
	function is_false(S:std_logic) return boolean is begin return(S='0'); end;

	-- Constant declare
	constant PREAMBLE_WIDTH		: integer := 8;
	constant GUARDBAND_WIDTH	: integer := 2;
	constant PACKETAREA_WIDTH	: integer := PREAMBLE_WIDTH + GUARDBAND_WIDTH*2 + 32 + 2; -- +2は開始ディレイ補正分 
	constant ISLANDGAP_WIDTH	: integer := 4;
	constant DELAY_DISTANCE		: integer := PACKETAREA_WIDTH + ISLANDGAP_WIDTH + PREAMBLE_WIDTH + GUARDBAND_WIDTH;
	constant START_COUNT		: std_logic_vector(5 downto 0) := "010110";	-- LITEHDMI counter start count(22)
	constant STOP_COUNT			: std_logic_vector(5 downto 0) := "000110";	-- LITEHDMI counter stop count(6)

	-- signal
	signal cc_swap_reg		: std_logic;
	signal active_reg		: std_logic_vector(DELAY_DISTANCE+4-1 downto 0);
	signal control_sig		: std_logic_vector(3 downto 0);
	signal datain_sig		: std_logic_vector(2+3*8-1 downto 0);
	signal pixeldata_sig	: std_logic_vector(datain_sig'range);
	signal sync_sig			: std_logic_vector(1 downto 0);

	signal vsync_old_reg	: std_logic;
	signal ready_old_reg	: std_logic;
	signal request_reg		: std_logic;
	signal counter_reg		: std_logic_vector(5 downto 0);
	signal start_bool		: boolean;
	signal clear_bool		: boolean;
	signal ready_sig		: std_logic := '0';
	signal pcm_ena_sig		: std_logic;

	signal audio_ready_sig	: std_logic;
	signal audio_valid_sig	: std_logic;
	signal audio_data_sig	: std_logic_vector(7 downto 0);
	signal audio_sop_sig	: std_logic;
	signal audio_eop_sig	: std_logic;
	signal packet_ready_sig	: std_logic;
	signal packet_valid_sig	: std_logic;
	signal packet_data_sig	: std_logic_vector(7 downto 0);
	signal packet_sop_sig	: std_logic;
	signal packet_eop_sig	: std_logic;

	signal preamble_sig		: std_logic;
	signal guardband_sig	: std_logic;
	signal dataenable_sig	: std_logic;
	signal packetdata_sig	: std_logic_vector(9 downto 0);
	signal mode_sig			: std_logic_vector(2 downto 0);
	signal data_sig			: std_logic_vector(3*4-1 downto 0);
	signal ctrl_sig			: std_logic_vector(3*2-1 downto 0);
	signal q_sig			: std_logic_vector(3*10-1 downto 0);

begin

	-- アイランド区間信号生成 --

gen_intgen : if ((ENCODE_MODE = "HDMI" or ENCODE_MODE = "LITEHDMI")and USE_EXTCONTROL /= "ON") generate
	process (clk, reset) begin
		if is_true(reset) then
			active_reg <= (others=>'0');
		elsif rising_edge(clk) then
			active_reg <= active & active_reg(active_reg'left downto 1);
		end if;
	end process;

	control_sig(0) <= active_reg(4);
	control_sig(1) <= '1' when(is_false(active_reg(4+GUARDBAND_WIDTH)) and is_true(active_reg(4+GUARDBAND_WIDTH+PREAMBLE_WIDTH))) else '0';
	control_sig(2) <= '1' when(is_false(active_reg(4)) and is_true(active_reg(4+GUARDBAND_WIDTH))) else '0';
	control_sig(3) <= '1' when(is_false(active_reg(0)) and is_false(active_reg(active_reg'left))) else '0';

	datain_sig <= vsync & hsync & r_data & g_data & b_data;

	u_delay : entity work.hdmi_tx_delay
	generic map (
		DATA_BITWIDTH	=> datain_sig'length,
		DELAY_DISTANCE	=> DELAY_DISTANCE
	)
	port map (
		clk			=> clk,
		data_in		=> datain_sig,
		data_out	=> pixeldata_sig
	);
end generate;
gen_extgen : if ((ENCODE_MODE = "HDMI" or ENCODE_MODE = "LITEHDMI")and USE_EXTCONTROL = "ON") generate
	control_sig <= control;
	pixeldata_sig <= vsync & hsync & r_data & g_data & b_data;
end generate;
gen_dvigen : if (ENCODE_MODE = "DVI") generate
	pixeldata_sig <= vsync & hsync & r_data & g_data & b_data;
end generate;

	sync_sig <= not pixeldata_sig(25 downto 24) when(SYNC_POLARITY = "NEGATIVE") else pixeldata_sig(25 downto 24);


	-- フレーム先頭パケット開始信号 --

	start_bool <= (is_true(vsync_old_reg) and is_false(pixeldata_sig(25)));
	clear_bool <= (is_true(ready_old_reg) and is_false(ready_sig));

	process (clk, reset) begin
		if is_true(reset) then
			vsync_old_reg <= '0';
			ready_old_reg <= '0';
			request_reg <= '0';

		elsif rising_edge(clk) then
			vsync_old_reg <= pixeldata_sig(25);
			ready_old_reg <= ready_sig;

			if is_true(request_reg) then
				if clear_bool then
					request_reg <= '0';
				end if;
			else
				if start_bool then
					request_reg <= '1';
				end if;
			end if;

		end if;
	end process;


	-- オーディオサンプルパケット生成 --

gen_audio : if (ENCODE_MODE = "HDMI" and USE_AUDIO_PACKET = "ON") generate
	u_audio : entity work.hdmi_tx_audiopacket_submodule
	generic map (
		PCMFIFO_DEPTH	=> PCMFIFO_DEPTH,
		AUDIO_FREQUENCY	=> AUDIO_FREQUENCY,
		CATEGORY_CODE	=> CATEGORY_CODE
	)
	port map (
		reset		=> reset,
		clk			=> clk,

		enable		=> pcm_ena_sig,
		pcm_fs		=> pcm_fs,
		pcm_l		=> pcm_l,
		pcm_r		=> pcm_r,

		out_ready	=> audio_ready_sig,
		out_valid	=> audio_valid_sig,
		out_data	=> audio_data_sig,
		out_sop		=> audio_sop_sig,
		out_eop		=> audio_eop_sig
	);
end generate;
gen_noaudio : if (ENCODE_MODE = "HDMI" and USE_AUDIO_PACKET /= "ON") generate
	audio_valid_sig <= '0';
	audio_data_sig  <= (others=>'0');
	audio_sop_sig   <= '0';
	audio_eop_sig   <= '0';
end generate;


	-- インフォメーションパケット生成 --

gen_info : if (ENCODE_MODE = "HDMI") generate
	u_info : entity work.hdmi_tx_infopacket_submodule
	generic map (
		CLOCK_FREQUENCY	=> CLOCK_FREQUENCY,
		AUDIO_FREQUENCY	=> AUDIO_FREQUENCY,
		SCANMODE		=> SCANMODE,
		PICTUREASPECT	=> PICTUREASPECT,
		FORMATASPECT	=> FORMATASPECT,
		PICTURESCALING	=> PICTURESCALING,
		COLORSPACE		=> COLORSPACE,
		YCC_DATARANGE	=> YCC_DATARANGE,
		CONTENTTYPE		=> CONTENTTYPE,
		REPETITION		=> REPETITION,
		VIDEO_CODE		=> VIDEO_CODE
	)
	port map (
		reset		=> reset,
		clk			=> clk,

		ready		=> ready_sig,
		request		=> request_reg,
		pcm_ena		=> pcm_ena_sig,

		in_ready	=> audio_ready_sig,
		in_valid	=> audio_valid_sig,
		in_data		=> audio_data_sig,
		in_sop		=> audio_sop_sig,
		in_eop		=> audio_eop_sig,

		out_ready	=> packet_ready_sig,
		out_valid	=> packet_valid_sig,
		out_data	=> packet_data_sig,
		out_sop		=> packet_sop_sig,
		out_eop		=> packet_eop_sig
	);
end generate;


	-- パケットデータエンコード --

gen_data : if (ENCODE_MODE = "HDMI") generate
	u_data : entity work.hdmi_tx_dataisland_submodule
	port map (
		reset		=> reset,
		clk			=> clk,

		in_ready	=> packet_ready_sig,
		in_valid	=> packet_valid_sig,
		in_data		=> packet_data_sig,
		in_sop		=> packet_sop_sig,
		in_eop		=> packet_eop_sig,

		packetready	=> control_sig(3),
		preamble	=> preamble_sig,
		guardband	=> guardband_sig,
		dataenable	=> dataenable_sig,
		packetdata	=> packetdata_sig
	);

	data_sig <= packetdata_sig & sync_sig;

end generate;
gen_nodata : if (ENCODE_MODE = "LITEHDMI") generate	-- Nullパケットのみを送信するLite実装 
	process (clk, reset) begin
		if is_true(reset) then
			counter_reg <= STOP_COUNT;

		elsif rising_edge(clk) then
			if start_bool then
				counter_reg <= START_COUNT;
			elsif (counter_reg /= STOP_COUNT) then
				counter_reg <= counter_reg + '1';
			end if;

		end if;
	end process;

	with counter_reg(5 downto 1) select preamble_sig <=
		'1' when "01011"|"01100"|"01101"|"01110",
		'0' when others;

	with counter_reg(5 downto 1) select guardband_sig <=
		'1' when "01111"|"00000",
		'0' when others;

	dataenable_sig <= counter_reg(5);

	data_sig(1 downto 0) <= sync_sig;
	data_sig(3 downto 2) <= "00" when(counter_reg = "100000") else "10";
	data_sig(11 downto 4) <= (others=>'0');

end generate;


	-- TMDS信号生成 --

gen_hdmi : if (ENCODE_MODE = "HDMI" or ENCODE_MODE = "LITEHDMI") generate
	mode_sig <=	"001" when is_true(control_sig(0)) else		-- Video Active
				"101" when is_true(control_sig(2)) else		-- Video Guardband
				"010" when is_true(dataenable_sig) else		-- Data Active
				"110" when is_true(guardband_sig) else		-- Data Guardband
				"000";										-- Control

	ctrl_sig(1 downto 0) <= sync_sig;
	ctrl_sig(5 downto 2) <=	"0001" when is_true(control_sig(1)) else	-- Video Preamble
							"0101" when is_true(preamble_sig) else		-- Data Preamble
							"0000";
end generate;
gen_dvi : if (ENCODE_MODE = "DVI") generate
	mode_sig <= "001" when is_true(active) else "000";
	data_sig <= (others=>'X');
	ctrl_sig <= "0000" & sync_sig;
end generate;

	gen_enc : for i in 0 to 2 generate
		u : entity work.hdmi_tx_tmds_encoder_submodule
		generic map (
			TMDS_CHANNEL => i
		)
		port map (
			clk		=> clk,
			mode	=> mode_sig,
			d_in	=> pixeldata_sig(i*8+7 downto i*8),
			s_in	=> data_sig(i*4+3 downto i*4),
			c_in	=> ctrl_sig(i*2+1 downto i*2),
			q_out	=> q_sig(i*10+9 downto i*10)
		);
	end generate;


	process (clk) begin
		if rising_edge(clk) then
			cc_swap_reg <= cc_swap;
		end if;
	end process;

	u_ser : entity work.hdmi_tx_pdiff_submodule
	generic map (
		DEVICE_FAMILY	=> DEVICE_FAMILY
	)
	port map (
		clk			=> clk,
		clk_x5		=> clk_x5,

		tx_swap		=> cc_swap_reg,
		data0_in	=> q_sig(0*10+9 downto 0*10),
		data1_in	=> q_sig(1*10+9 downto 1*10),
		data2_in	=> q_sig(2*10+9 downto 2*10),

		tx			=> data,
		tx_n		=> data_n,
		txc			=> clock,
		txc_n		=> clock_n
	);


end RTL;
