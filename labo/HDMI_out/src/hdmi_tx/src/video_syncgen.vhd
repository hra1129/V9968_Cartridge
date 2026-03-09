-- ===================================================================
-- TITLE : Video Sync Generator
--
--     DESIGN : S.OSAFUNE (J-7SYSTEM WORKS LIMITED)
--     DATE   : 2010/12/10 -> 2010/12/27
--
--     UPDATE : 2012/02/21 add pixelena signal(for ATM0430D5)
--            : 2013/07/29 add colorbar generator
--            : 2018/05/13 delete dither
--            : 2019/11/08 delete dither (bugfix)
--            : 2022/01/27 add csync signal
--            : 2022/12/13 modity framestart/linestart signal
--            : 2022/12/29 add HDMI control signal, YCbCr pattern
--
-- ===================================================================

-- The MIT License (MIT)
-- Copyright (c) 2010-2022 J-7SYSTEM WORKS LIMITED.
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


-- VHDL 1993 / IEEE 1076-1993
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

entity video_syncgen is
	generic (
		BAR_MODE	: string := "WIDE";		-- "WIDE"  : ARIB STD-B28 Multi-colorbar like
											-- "SD"    : ARIB 75% Colorbar like
		COLORSPACE	: string := "RGB";		-- "RGB"   : RGB888 Full range
											-- "BT601" : ITU-R BT.601 YCbCr Limited range
											-- "BT709" : ITU-R BT.709 YCbCr Limited range
		START_SIG	: string := "SINGLE";	-- "SINGLE": framestart and linestart are 1-clock pulse.
											-- "WIDTH" : framestart and linestart are hsync width.
		EARLY_REQ	: integer := 0;			-- 0-16    : A value that causes "pixrequest" to assert before "active".

		H_TOTAL		: integer := 800;	-- VGA(640x480) : 25.20MHz/25.175MHz
		H_SYNC		: integer := 96;
		H_BACKP		: integer := 48;
		H_ACTIVE	: integer := 640;
		V_TOTAL		: integer := 525;
		V_SYNC		: integer := 2;
		V_BACKP		: integer := 33;
		V_ACTIVE	: integer := 480;

--		H_TOTAL		: integer := 858;	-- SD480p(720x480) : 27.027MHz/27.00MHz
--		H_SYNC		: integer := 62;
--		H_BACKP		: integer := 60;
--		H_ACTIVE	: integer := 720;
--		V_TOTAL		: integer := 525;
--		V_SYNC		: integer := 6;
--		V_BACKP		: integer := 30;
--		V_ACTIVE	: integer := 480;

--		H_TOTAL		: integer := 1650;	-- HD720p(1280x720) : 74.25MHz/74.176MHz
--		H_SYNC		: integer := 40;
--		H_BACKP		: integer := 220;
--		H_ACTIVE	: integer := 1280;
--		V_TOTAL		: integer := 750;
--		V_SYNC		: integer := 5;
--		V_BACKP		: integer := 20;
--		V_ACTIVE	: integer := 720;

--		H_TOTAL		: integer := 2200;	-- HD1080p(1920x1080) : 148.50MHz/148.352MHz
--		H_SYNC		: integer := 44;
--		H_BACKP		: integer := 148;
--		H_ACTIVE	: integer := 1920;
--		V_TOTAL		: integer := 1125;
--		V_SYNC		: integer := 5;
--		V_BACKP		: integer := 36;
--		V_ACTIVE	: integer := 1080;

--		H_TOTAL		: integer := 525;	-- ATM0430D5(480x272) : 9.0MHz
--		H_SYNC		: integer := 40;
--		H_BACKP		: integer := 0;
--		H_ACTIVE	: integer := 480;
--		V_TOTAL		: integer := 288;
--		V_SYNC		: integer := 3;
--		V_BACKP		: integer := 0;
--		V_ACTIVE	: integer := 272;

--		H_TOTAL		: integer := 953;	-- RasPi 5inch HDMI Display(800x480) : 30.0MHz
--		H_SYNC		: integer := 48;
--		H_BACKP		: integer := 40;
--		H_ACTIVE	: integer := 800;
--		V_TOTAL		: integer := 525;
--		V_SYNC		: integer := 3;
--		V_BACKP		: integer := 29;
--		V_ACTIVE	: integer := 480;

		FRAME_TOP	: integer := 0;		-- Re-sync option
		START_HPOS	: integer := 0;		-- Re-sync option
		START_VPOS	: integer := 0		-- Re-sync option
	);
	port (
		reset		: in  std_logic;		-- active high
		video_clk	: in  std_logic;		-- typ 25.2MHz

		scan_ena	: in  std_logic := '0';	-- Scan enable (async input)
		framestart	: out std_logic;		-- Frame start signal (1-clock pulse or hsync width)
		linestart	: out std_logic;		-- Active line start signal (1-clock pluse or hsync width)
		pixrequest	: out std_logic;		-- Pixel data request (Assert earlier than "active".)

		hdmicontrol	: out std_logic_vector(3 downto 0);	-- [0] : Indicate Active video period
														-- [1] : Indicate Video Preamble
														-- [2] : Indicate Video Guardband
														-- [3] : Allow Packet transmission
		active		: out std_logic;		-- active high
		hsync		: out std_logic;		-- active high
		vsync		: out std_logic;		-- active high
		csync		: out std_logic;		-- active high
		hblank		: out std_logic;		-- active high
		vblank		: out std_logic;		-- active high

		cb_rout		: out std_logic_vector(7 downto 0);	-- R / Cr
		cb_gout		: out std_logic_vector(7 downto 0);	-- G / Y
		cb_bout		: out std_logic_vector(7 downto 0)	-- B / Cb
	);
end video_syncgen;

architecture RTL of video_syncgen is
	-- Misc function
	function is_true(S:std_logic) return boolean is begin return(S='1'); end;
	function is_false(S:std_logic) return boolean is begin return(S='0'); end;
	function to_vector(N,W:integer) return std_logic_vector is begin return conv_std_logic_vector(N,W); end;

	-- カラーバーの各領域終端を取得 --
	function cb_band(N : integer) return integer is
		variable start : integer;
	begin
		start := H_SYNC + H_BACKP - EARLY_REQ - 1;

		if (BAR_MODE = "WIDE") then
			if (N = 0) then
				return start + H_ACTIVE/8;
			elsif (N = 8) then
				return start + H_ACTIVE;
			elsif (N = 9) then
				return start + H_ACTIVE/8 + (3 * H_ACTIVE * 3)/(28*2);
			elsif (N = 10) then
				return start + H_ACTIVE/8 + (7 * H_ACTIVE * 3)/(28*2);
			else
				return start + H_ACTIVE/8 + (N * H_ACTIVE * 3)/28;
			end if;
		else
			if (N = 0) then
				return start;
			elsif (N = 7) then
				return start + H_ACTIVE;
			elsif (N = 8) then
				return start + H_ACTIVE + 1;
			elsif (N = 9) then
				return start + (3 * H_ACTIVE)/(7*2);
			elsif (N = 10) then
				return start + (7 * H_ACTIVE)/(7*2);
			else
				return start + (N * H_ACTIVE)/7;
			end if;
		end if;
	end;

	-- カラーバーのランプパラメーターを取得 --
	function cb_lampbegin return integer is
	begin
		if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
			return 16;
		else
			return 0;
		end if;
	end;

	function cb_lampend return integer is
	begin
		if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
			return 235;
		else
			return 255;
		end if;
	end;

	function cb_lampstep return integer is
	begin
		if (BAR_MODE = "WIDE") then
			return (cb_lampend - cb_lampbegin) * 256 / ((H_ACTIVE * 3 / 4) - 1);
		else
			return (cb_lampend - cb_lampbegin) * 256 / (H_ACTIVE - 1);
		end if;
	end;

	-- 色データの取得 --
	function cb_color(R,G,B : real) return std_logic_vector is
		variable y,cb,cr : real;
	begin
		if (COLORSPACE = "BT601") then
			y  := 0.299*R + 0.587*G + 0.114*B;
			cb := 0.564*(B - y);
			cr := 0.713*(R - y);
			return	to_vector(integer(224.0*cr+128.0), 8) &
					to_vector(integer(219.0*y + 16.0), 8) &
					to_vector(integer(224.0*cb+128.0), 8);
		elsif (COLORSPACE = "BT709") then
			y  := 0.2126*R + 0.7152*G + 0.0722*B;
			cb := 0.5389*(B - y);
			cr := 0.6350*(R - y);
			return	to_vector(integer(224.0*cr+128.0), 8) &
					to_vector(integer(219.0*y + 16.0), 8) &
					to_vector(integer(224.0*cb+128.0), 8);
		else
			return	to_vector(integer(R*255.0), 8) &
					to_vector(integer(G*255.0), 8) &
					to_vector(integer(B*255.0), 8);
		end if;
	end;


	-- Constant declare
	constant PREAMBLE_WIDTH		: integer := 8;
	constant GUARDBAND_WIDTH	: integer := 2;
	constant PACKETAREA_WIDTH	: integer := PREAMBLE_WIDTH + GUARDBAND_WIDTH*2 + 32 + 2; -- +2は開始ディレイ補正分 
	constant ISLANDGAP_WIDTH	: integer := 4;

	constant CB_LEFTBAND	: integer := cb_band(0);
	constant CB_75WHITE		: integer := cb_band(1);
	constant CB_75YELLOW	: integer := cb_band(2);
	constant CB_75CYAN		: integer := cb_band(3);
	constant CB_75GREEN		: integer := cb_band(4);
	constant CB_75MAGENTA	: integer := cb_band(5);
	constant CB_75RED		: integer := cb_band(6);
	constant CB_75BLUE		: integer := cb_band(7);
	constant CB_RIGHTBAND	: integer := cb_band(8);
	constant CB_BLACKBAND	: integer := cb_band(9);
	constant CB_WHITEBAND	: integer := cb_band(10);
	constant CB_NORMAL_V	: integer := V_SYNC + V_BACKP + (V_ACTIVE*7)/12 - 1;
	constant CB_GRAY_V		: integer := V_SYNC + V_BACKP + (V_ACTIVE*8)/12 - 1;
	constant CB_WLAMP_V		: integer := V_SYNC + V_BACKP + (V_ACTIVE*9)/12 - 1;
	constant CB_RLAMP_V		: integer := V_SYNC + V_BACKP + (V_ACTIVE*10)/12 - 1;
	constant CB_GLAMP_V		: integer := V_SYNC + V_BACKP + (V_ACTIVE*11)/12 - 1;
	constant CB_BLAMP_V		: integer := V_SYNC + V_BACKP + V_ACTIVE - 1;

	constant COLOR_BLACK	: std_logic_vector(23 downto 0) := cb_color(0.0 , 0.0 , 0.0 );
	constant COLOR_WHITE	: std_logic_vector(23 downto 0) := cb_color(1.0 , 1.0 , 1.0 );
	constant COLOR_YELLOW	: std_logic_vector(23 downto 0) := cb_color(1.0 , 1.0 , 0.0 );
	constant COLOR_CYAN		: std_logic_vector(23 downto 0) := cb_color(0.0 , 1.0 , 1.0 );
	constant COLOR_RED		: std_logic_vector(23 downto 0) := cb_color(1.0 , 0.0 , 0.0 );
	constant COLOR_BLUE		: std_logic_vector(23 downto 0) := cb_color(0.0 , 0.0 , 1.0 );
	constant COLOR_15WHITE	: std_logic_vector(23 downto 0) := cb_color(0.15, 0.15, 0.15);
	constant COLOR_40WHITE	: std_logic_vector(23 downto 0) := cb_color(0.40, 0.40, 0.40);
	constant COLOR_75WHITE	: std_logic_vector(23 downto 0) := cb_color(0.75, 0.75, 0.75);
	constant COLOR_75YELLOW	: std_logic_vector(23 downto 0) := cb_color(0.75, 0.75, 0.0 );
	constant COLOR_75CYAN	: std_logic_vector(23 downto 0) := cb_color(0.0 , 0.75, 0.75);
	constant COLOR_75GREEN	: std_logic_vector(23 downto 0) := cb_color(0.0 , 0.75, 0.0 );
	constant COLOR_75MAGENTA: std_logic_vector(23 downto 0) := cb_color(0.75, 0.0 , 0.75);
	constant COLOR_75RED	: std_logic_vector(23 downto 0) := cb_color(0.75, 0.0 , 0.0 );
	constant COLOR_75BLUE	: std_logic_vector(23 downto 0) := cb_color(0.0 , 0.0 , 0.75);


	-- signal
	signal hcount		: integer range 0 to H_TOTAL-1;
	signal vcount		: integer range 0 to V_TOTAL-1;
	signal hsync_reg	: std_logic;
	signal vsync_reg	: std_logic;
	signal csync_reg	: std_logic;
	signal hblank_reg	: std_logic;
	signal vblank_reg	: std_logic;
	signal request_reg	: std_logic;
	signal preamble_reg	: std_logic;
	signal guard_reg	: std_logic;
	signal packet_reg	: std_logic;
	signal active_sig	: std_logic;

	signal vs_old_reg	: std_logic;
	signal hs_old_reg	: std_logic;
	signal scan_in_reg	: std_logic;
	signal scanena_reg	: std_logic;
	signal hsync_rise	: boolean;
	signal vsync_rise	: boolean;

	type STATE_CB_AREA is (LEFTBAND1, WHITE, YELLOW, CYAN, GREEN, MAGENTA, RED, BLUE, RIGHTBAND1,
							LEFTBAND2, FULLWHITE, GRAY, RIGHTBAND2,
							LEFTBAND3, WHITELAMP, RIGHTBAND3,
							LEFTBAND4, REDLAMP, RIGHTBAND4,
							LEFTBAND5, GREENLAMP, RIGHTBAND5,
							LEFTBAND6, BLUELAMP, RIGHTBAND6);
	signal areastate : STATE_CB_AREA;
	signal cb_rgb_reg	: std_logic_vector(3*8-1 downto 0);
	signal cblamp_reg	: std_logic_vector(15 downto 0);
	signal chroma_sig	: std_logic_vector(7 downto 0);

	-- Attribute
	attribute altera_attribute : string;
	attribute altera_attribute of RTL : architecture is
	(
		"-name SDC_STATEMENT ""set_false_path -to [get_registers {*video_syncgen:*|scan_in_reg}]"""
	);

begin

	-- パラメータ値チェック --

	assert (H_SYNC > 0 and H_SYNC + H_BACKP + H_ACTIVE <= H_TOTAL and H_SYNC + H_BACKP > EARLY_REQ)
		report "Horizontal parameter out of range." severity FAILURE;

	assert (H_SYNC + H_BACKP > PACKETAREA_WIDTH + ISLANDGAP_WIDTH + PREAMBLE_WIDTH + GUARDBAND_WIDTH and H_SYNC + H_BACKP + H_ACTIVE + ISLANDGAP_WIDTH <= H_TOTAL)
		report "The HDMI control section in the horizontal blank period is insufficient." severity WARNING;

	assert (V_SYNC > 0 and V_SYNC + V_BACKP + V_ACTIVE <= V_TOTAL)
		report "Vertical parameter out of range." severity FAILURE;


	-- ビデオ同期信号生成 --

	process (video_clk, reset) begin
		if is_true(reset) then
			hcount <= START_HPOS;
			vcount <= START_VPOS;
			hsync_reg   <= '0';
			vsync_reg   <= '0';
			csync_reg   <= '0';
			hblank_reg  <= '1';
			vblank_reg  <= '1';
			request_reg <= '0';
			preamble_reg<= '0';
			guard_reg   <= '0';
			packet_reg  <= '0';

		elsif rising_edge(video_clk) then
			if (hcount = H_TOTAL - 1) then
				hcount <= 0;
			else
				hcount <= hcount + 1;
			end if;

			if (hcount = H_TOTAL - 1) then
				hsync_reg <= '1';
			elsif (hcount = H_SYNC - 1) then
				hsync_reg <= '0';
			end if;

			if (hcount = H_TOTAL - 1) then
				csync_reg <= '1';
			elsif ((is_false(vsync_reg) and hcount = H_SYNC - 1) or (vsync_reg = '1' and hcount = H_TOTAL - H_SYNC)) then
				csync_reg <= '0';
			end if;

			if (hcount = H_SYNC + H_BACKP - 1) then
				hblank_reg <= '0';
			elsif (hcount = H_SYNC + H_BACKP + H_ACTIVE - 1) then
				hblank_reg <= '1';
			end if;

			if (hcount = H_TOTAL - 1) then
				if (vcount = V_TOTAL - 1) then
					vcount <= 0;
				else
					vcount <= vcount + 1;
				end if;

				if (vcount = V_TOTAL - 1) then
					vsync_reg <= '1';
				elsif (vcount = V_SYNC - 1) then
					vsync_reg <= '0';
				end if;

				if (vcount = V_SYNC + V_BACKP - 1) then
					vblank_reg <= '0';
				elsif (vcount = V_SYNC + V_BACKP + V_ACTIVE - 1) then
					vblank_reg <= '1';
				end if;
			end if;


			if is_false(vblank_reg) then
				if (hcount = H_SYNC + H_BACKP - EARLY_REQ - 1) then
					request_reg <= '1';
				elsif (hcount = H_SYNC + H_BACKP + H_ACTIVE - EARLY_REQ - 1) then
					request_reg <= '0';
				end if;

				if (hcount = H_SYNC + H_BACKP - (PREAMBLE_WIDTH + GUARDBAND_WIDTH) - 1) then
					preamble_reg <= '1';
				elsif (hcount = H_SYNC + H_BACKP - GUARDBAND_WIDTH - 1) then
					preamble_reg <= '0';
					guard_reg <= '1';
				elsif (hcount = H_SYNC + H_BACKP - 1) then
					guard_reg <= '0';
				end if;

				if (hcount = H_SYNC + H_BACKP - (PACKETAREA_WIDTH + ISLANDGAP_WIDTH + PREAMBLE_WIDTH + GUARDBAND_WIDTH) - 1) then
					packet_reg <= '0';
				elsif (hcount = H_SYNC + H_BACKP + H_ACTIVE + ISLANDGAP_WIDTH - 1) then
					packet_reg <= '1';
				end if;
			else
				packet_reg <= '1';
			end if;

		end if;
	end process;

	active_sig <= '1' when(is_false(hblank_reg) and is_false(vblank_reg)) else '0';

	hdmicontrol(0) <= active_sig;
	hdmicontrol(1) <= preamble_reg;
	hdmicontrol(2) <= guard_reg;
	hdmicontrol(3) <= packet_reg;

	active <= active_sig;
	hsync  <= hsync_reg;
	vsync  <= vsync_reg;
	csync  <= csync_reg;
	hblank <= hblank_reg;
	vblank <= vblank_reg;


	-- フレームデータ読み出し信号生成 --

	hsync_rise <= (is_false(hs_old_reg) and is_true(hsync_reg));
	vsync_rise <= (is_false(vs_old_reg) and is_true(vsync_reg));

	process (video_clk, reset) begin
		if is_true(reset) then
			vs_old_reg  <= '0';
			hs_old_reg  <= '0';
			scan_in_reg <= '0';
			scanena_reg <= '0';

		elsif rising_edge(video_clk) then
			vs_old_reg <= vsync_reg;
			hs_old_reg <= hsync_reg;
			scan_in_reg <= scan_ena;

			if (vsync_rise) then
				scanena_reg <= scan_in_reg;
			end if;
		end if;
	end process;

gen_pulse : if (START_SIG = "SINGLE") generate
	framestart <= '1' when(hcount = 0 and vcount = FRAME_TOP) else '0';
	linestart  <= scanena_reg when(hsync_rise and is_false(vblank_reg)) else '0';
end generate;
gen_width : if (START_SIG /= "SINGLE") generate
	framestart <= '1' when(is_true(hsync_reg) and vcount = FRAME_TOP) else '0';
	linestart  <= scanena_reg when(is_true(hsync_reg) and is_false(vblank_reg)) else '0';
end generate;

	pixrequest <= scanena_reg when is_true(request_reg) else '0';


	-- カラーバー信号生成 --

	chroma_sig <= cblamp_reg(15 downto 8) + 2;	-- 色差ランプ中心位置補正 

	process (video_clk, reset) begin
		if is_true(reset) then
			areastate <= LEFTBAND1;
			cblamp_reg <= (others=>'0');
			cb_rgb_reg <= (others=>'0');

		elsif rising_edge(video_clk) then
			if (hcount = CB_LEFTBAND-1) then
				cblamp_reg <= to_vector(cb_lampbegin, 8) & x"00";
			else
				cblamp_reg <= cblamp_reg + to_vector(cb_lampstep, 16);
			end if;

			case areastate is
			when LEFTBAND1 =>
				if (hcount = CB_LEFTBAND) then
					areastate <= WHITE;
					cb_rgb_reg <= COLOR_75WHITE;
				end if;

			when WHITE =>
				if (hcount = CB_75WHITE) then
					areastate <= YELLOW;
					cb_rgb_reg <= COLOR_75YELLOW;
				end if;

			when YELLOW =>
				if (hcount = CB_75YELLOW) then
					areastate <= CYAN;
					cb_rgb_reg <= COLOR_75CYAN;
				end if;

			when CYAN =>
				if (hcount = CB_75CYAN) then
					areastate <= GREEN;
					cb_rgb_reg <= COLOR_75GREEN;
				end if;

			when GREEN =>
				if (hcount = CB_75GREEN) then
					areastate <= MAGENTA;
					cb_rgb_reg <= COLOR_75MAGENTA;
				end if;

			when MAGENTA =>
				if (hcount = CB_75MAGENTA) then
					areastate <= RED;
					cb_rgb_reg <= COLOR_75RED;
				end if;

			when RED =>
				if (hcount = CB_75RED) then
					areastate <= BLUE;
					cb_rgb_reg <= COLOR_75BLUE;
				end if;

			when BLUE =>
				if (hcount = CB_75BLUE) then
					areastate <= RIGHTBAND1;
					cb_rgb_reg <= COLOR_40WHITE;
				end if;

			when RIGHTBAND1 =>
				if (hcount = CB_RIGHTBAND) then
					if (vcount = CB_NORMAL_V) then
						areastate <= LEFTBAND2;
						cb_rgb_reg <= COLOR_CYAN;
					else
						areastate <= LEFTBAND1;
					end if;
				end if;


			when LEFTBAND2 =>
				if (hcount = CB_LEFTBAND) then
					areastate <= FULLWHITE;
					cb_rgb_reg <= COLOR_WHITE;
				end if;

			when FULLWHITE =>
				if (hcount = CB_75WHITE) then
					areastate <= GRAY;
					cb_rgb_reg <= COLOR_75WHITE;
				end if;

			when GRAY =>
				if (hcount = CB_75BLUE) then
					areastate <= RIGHTBAND2;
					cb_rgb_reg <= COLOR_BLUE;
				end if;

			when RIGHTBAND2 =>
				if (hcount = CB_RIGHTBAND) then
					if (vcount = CB_GRAY_V) then
						areastate <= LEFTBAND3;
						cb_rgb_reg <= COLOR_YELLOW;
					else
						areastate <= LEFTBAND2;
						cb_rgb_reg <= COLOR_CYAN;
					end if;
				end if;


			when LEFTBAND3 =>
				if (hcount = CB_LEFTBAND) then
					areastate <= WHITELAMP;

					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- Y LAMP Begin
						cb_rgb_reg <= x"80" & cblamp_reg(15 downto 8) & x"80";
					else
						-- WHITE LAMP Begin
						cb_rgb_reg <= cblamp_reg(15 downto 8) & cblamp_reg(15 downto 8) & cblamp_reg(15 downto 8);
					end if;
				end if;

			when WHITELAMP =>
				if (hcount = CB_75BLUE) then
					areastate <= RIGHTBAND3;
					cb_rgb_reg <= COLOR_RED;
				else
					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- Y LAMP
						cb_rgb_reg <= x"80" & cblamp_reg(15 downto 8) & x"80";
					else
						-- WHITE LAMP
						cb_rgb_reg <= cblamp_reg(15 downto 8) & cblamp_reg(15 downto 8) & cblamp_reg(15 downto 8);
					end if;
				end if;

			when RIGHTBAND3 =>
				if (hcount = CB_RIGHTBAND) then
					if (vcount = CB_WLAMP_V) then
						areastate <= LEFTBAND4;
						cb_rgb_reg <= COLOR_15WHITE;
					else
						areastate <= LEFTBAND3;
						cb_rgb_reg <= COLOR_YELLOW;
					end if;
				end if;


			when LEFTBAND4 =>
				if (hcount = CB_LEFTBAND) then
					areastate <= REDLAMP;

					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- Cr LAMP (50% Y) Begin
						cb_rgb_reg <= chroma_sig & x"80" & x"80";
					else
						 -- RED LAMP begin
						cb_rgb_reg <= cblamp_reg(15 downto 8) & x"00" & x"00";
					end if;
				end if;

			when REDLAMP =>
				if (hcount = CB_75BLUE) then
					areastate <= RIGHTBAND4;
					cb_rgb_reg <= COLOR_15WHITE;
				else
					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- Cr LAMP (50% Y)
						cb_rgb_reg <= chroma_sig & x"80" & x"80";
					else
						 -- RED LAMP
						cb_rgb_reg(23 downto 16) <= cblamp_reg(15 downto 8);
					end if;
				end if;

			when RIGHTBAND4 =>
				if (hcount = CB_RIGHTBAND) then
					if (vcount = CB_RLAMP_V) then
						areastate <= LEFTBAND5;
					else
						areastate <= LEFTBAND4;
					end if;
				end if;


			when LEFTBAND5 =>
				if (hcount = CB_LEFTBAND) then
					areastate <= GREENLAMP;

					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- Cb LAMP (50% Y) begin
						cb_rgb_reg <= x"80" & x"80" & chroma_sig;
					else
						-- GREEN LAMP begin
						cb_rgb_reg <= x"00" & cblamp_reg(15 downto 8) & x"00";
					end if;
				end if;

			when GREENLAMP =>
				if (hcount = CB_75BLUE) then
					areastate <= RIGHTBAND5;
					cb_rgb_reg <= COLOR_15WHITE;
				else
					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- Cb LAMP (50% Y)
						cb_rgb_reg <= x"80" & x"80" & chroma_sig;
					else
						-- GREEN LAMP
						cb_rgb_reg(15 downto 8) <= cblamp_reg(15 downto 8);
					end if;
				end if;

			when RIGHTBAND5 =>
				if (hcount = CB_RIGHTBAND) then
					if (vcount = CB_GLAMP_V) then
						areastate <= LEFTBAND6;
					else
						areastate <= LEFTBAND5;
					end if;
				end if;


			when LEFTBAND6 =>
				if (hcount = CB_LEFTBAND) then
					areastate <= BLUELAMP;

					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- 0%/100% BAR Begin
						cb_rgb_reg <= COLOR_BLACK;
					else
						-- BLUE LAMP Begin
						cb_rgb_reg <= x"00" & x"00" & cblamp_reg(15 downto 8);
					end if;

				end if;

			when BLUELAMP =>
				if (hcount = CB_75BLUE) then
					areastate <= RIGHTBAND6;
					cb_rgb_reg <= COLOR_15WHITE;
				else
					if (COLORSPACE = "BT601" or COLORSPACE = "BT709") then
						-- 0%/100% BAR
						if (hcount = CB_BLACKBAND) then
							cb_rgb_reg <= COLOR_WHITE;
						elsif (hcount = CB_WHITEBAND) then
							cb_rgb_reg <= COLOR_BLACK;
						end if;
					else
						-- BLUE LAMP
						cb_rgb_reg(7 downto 0) <= cblamp_reg(15 downto 8);
					end if;
				end if;

			when RIGHTBAND6 =>
				if (hcount = CB_RIGHTBAND) then
					if (vcount = CB_BLAMP_V) then
						areastate <= LEFTBAND1;
						cb_rgb_reg <= COLOR_40WHITE;
					else
						areastate <= LEFTBAND6;
					end if;
				end if;

			end case;

		end if;
	end process;

	cb_rout <= cb_rgb_reg(2*8+7 downto 2*8) when is_true(request_reg) else x"00";
	cb_gout <= cb_rgb_reg(1*8+7 downto 1*8) when is_true(request_reg) else x"00";
	cb_bout <= cb_rgb_reg(0*8+7 downto 0*8) when is_true(request_reg) else x"00";


end RTL;
