library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use Work.util.all;

entity registers is
	generic (
		NR_OF_REGS	: integer	:= 32;
		CLOCK_MHZ	: real 		:= 100.0;
		VERSION		: integer	:= 0;
		BUILD			: integer	:= 0
	);
	Port (
		CLK_I 		: in  STD_LOGIC;
		RST_I 		: in  STD_LOGIC;
		
		WRITE_I		: in  STD_LOGIC;
		ADDR_I		: in  STD_LOGIC_VECTOR ( 7 downto 0);
		DATA_O		: out STD_LOGIC_VECTOR (15 downto 0);
		DATA_I		: in  STD_LOGIC_VECTOR (15 downto 0);
		
		REGISTER_O	: out array16_t(0 to NR_OF_REGS-1)
	);
end registers;

architecture Behavioral of registers is

constant ADDR_WIDTH : integer := clogb2(NR_OF_REGS) - 1;

signal reg	: array16_t(0 to NR_OF_REGS-1) := (
0	=> (
	others => '0'
	),

8	=> x"0000",		-- OFFSET X
9	=> x"0000",		-- OFFSET Y
10	=> x"0100",		-- STEPS X
11	=> x"0100",		-- STEPS Y
12	=> x"00FF",		-- DELTA X
13	=> x"00FF",		-- DELTA Y

16	=> x"030E",		-- CTRL DELAY (2560ns steps) 0us-167.77216ms 	0x030E =   2ms
17	=> x"2710",		-- INI DELAY  (  10ns steps) 0us-655.36us		0x2710 = 100us
18	=> x"05DC",		-- COL DELAY  (  10ns steps) 0us-655.36us		0x05DC =  15us
19	=> x"05DC",		-- ROW DELAY  (  10ns steps) 0us-655.36us		0x05DC =  15us

20 => x"4000",		-- Transform Matrix C00
21 => x"0000",		-- Transform Matrix C01
22 => x"0000",		-- Transform Matrix C02
23 => x"0000",		-- Transform Matrix C10
24 => x"4000",		-- Transform Matrix C11
25 => x"0000",		-- Transform Matrix C12

28	=> int2vec(integer(CLOCK_MHZ), 16),		-- Sys Clk (MHz)
29	=> int2vec(1, 16),						-- PCB VERSION 
30	=> int2vec(VERSION, 16),				-- FPGA VERSION
31	=> int2vec(BUILD, 16),					-- FPGA BUILD
others => x"0000"
);

signal read_only	: std_logic_vector(0 to NR_OF_REGS-1) := 
(
	28 => '1',
	29 => '1',
	30 => '1',
	31 => '1',
	others => '0'
);

begin

rw : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			DATA_O  <= (others => '0');
		else
			DATA_O  <= reg(vec2int(ADDR_I(ADDR_WIDTH downto 0)));

			if (WRITE_I = '1') then
				if (read_only(vec2int(ADDR_I(ADDR_WIDTH downto 0))) = '0') then
					reg(vec2int(ADDR_I(ADDR_WIDTH downto 0))) <= DATA_I;
				end if;
			end if;
		end if;
	end if;
end process rw;

REGISTER_O <= reg;

end Behavioral;

