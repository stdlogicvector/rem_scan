library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transform is
	Port (
		CLK_I		: in STD_LOGIC;
		RST_I		: in STD_LOGIC;
		
		DV_I		: in  STD_LOGIC;
		X_I 		: in  STD_LOGIC_VECTOR (15 downto 0);
		Y_I 		: in  STD_LOGIC_VECTOR (15 downto 0);
		
		DV_O		: out STD_LOGIC := '0';
		X_O 		: out STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		Y_O 		: out STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		
		CA_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"4000";
		CB_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000";
		CC_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000";
		CD_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"4000";
		CE_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000";
		CF_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000"
	);
end transform;

architecture Behavioral of transform is

type state_t is (IDLE, MULT_1, MULT_2, ADD_1, ADD_2, OUTPUT);
signal state : state_t := IDLE;

signal mx1, mx2 : signed(31 downto 0) := (others => '0');
signal my1, my2 : signed(31 downto 0) := (others => '0');

signal x : signed(15 downto 0) := (others => '0');
signal y : signed(15 downto 0) := (others => '0');

begin

-- Apply 2D Transformation Matrix to Coordinates
--
--		[A	C  E]		[Xi]
--		[B	D  F] 	*	[Yi]  = [Xo Yo 1]
--		[0	0  1]		[ 1]

process (CLK_I)
begin
	if rising_edge(CLK_I)
	then
		if (RST_I = '1')
		then
			state <= IDLE;
		else
			DV_O <= '0';
		
			case (state) is
			when IDLE =>
				if (DV_I = '1') then
					state <= MULT_1;
				end if;
				
			when MULT_1 =>
				mx1 <= signed(X_I) * signed(CA_I);
				my1 <= signed(Y_I) * signed(CC_I);
				
				state <= MULT_2;
				
			when MULT_2 =>
				mx2 <= signed(X_I) * signed(CB_I);
				my2 <= signed(Y_I) * signed(CD_I);
				
				state <= ADD_1;
				
			when ADD_1 =>
				x <= mx1(29 downto 14) + my1(29 downto 14);
				y <= my2(29 downto 14) + mx2(29 downto 14);
				
				state <= ADD_2;
			
			when ADD_2 =>
				x <= x + signed(CE_I);	-- Translation
				y <= y + signed(CF_I);
				
				state <= OUTPUT;
			
			when OUTPUT =>
				X_O	<= std_logic_vector(x);
				Y_O	<= std_logic_vector(y);
				DV_O <= '1';
				
				state <= IDLE;
				
			end case;
		end if;
	end if;
end process;


end Behavioral;

