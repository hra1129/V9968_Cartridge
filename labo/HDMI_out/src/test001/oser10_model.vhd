-- -----------------------------------------------------------------------------
--	Simulation model of Gowin OSER10 (10:1 Serializer)
-- -----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity OSER10 is
	generic (
		GSREN : string := "false";
		LSREN : string := "false"
	);
	port (
		RESET : in  std_logic := '0';
		PCLK  : in  std_logic;
		FCLK  : in  std_logic;
		D0    : in  std_logic;
		D1    : in  std_logic;
		D2    : in  std_logic;
		D3    : in  std_logic;
		D4    : in  std_logic;
		D5    : in  std_logic;
		D6    : in  std_logic;
		D7    : in  std_logic;
		D8    : in  std_logic;
		D9    : in  std_logic;
		Q     : out std_logic
	);
end OSER10;

architecture SIM of OSER10 is
	signal data_reg  : std_logic_vector(9 downto 0) := (others => '0');
	signal shift_reg : std_logic_vector(9 downto 0) := (others => '0');
	signal count     : integer range 0 to 9 := 0;
begin

	-- Latch parallel data on PCLK rising edge
	process (PCLK)
	begin
		if rising_edge(PCLK) then
			data_reg <= D9 & D8 & D7 & D6 & D5 & D4 & D3 & D2 & D1 & D0;
		end if;
	end process;

	-- Serialize on FCLK rising edge (DDR-like: 5 FCLK = 10 bits)
	process (FCLK)
	begin
		if rising_edge(FCLK) then
			if RESET = '1' then
				shift_reg <= (others => '0');
				count     <= 0;
			elsif count = 0 then
				shift_reg <= data_reg;
				count     <= 1;
			else
				shift_reg <= '0' & shift_reg(9 downto 1);
				if count = 9 then
					count <= 0;
				else
					count <= count + 1;
				end if;
			end if;
		end if;
	end process;

	Q <= shift_reg(0);

end SIM;
