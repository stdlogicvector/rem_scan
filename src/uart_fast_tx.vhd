library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity uart_fast_tx is
	generic (
		DIVIDER		: integer := 5;		
		DATA_BITS	: integer := 8;			-- 6, 7, 8, 9
		PARITY_BIT	: character := 'N';		-- N(one), O(dd), E(ven)
		STOP_BITS	: real := 1.0;			-- 1.0, 1.5, 2.0
		START_BIT	: std_logic := '0'
	);
	port (
		RST_I		: in	STD_LOGIC;
		CLK_I		: in	STD_LOGIC;
		
		ENABLE_I	: in	STD_LOGIC := '1';
		
		TX_O		: out	STD_LOGIC := NOT START_BIT;
		
		TX_CHAR_I	: in	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		SEND_I		: in	STD_LOGIC;
		
		BUSY_O		: out 	STD_LOGIC := '0'
	);
end uart_fast_tx;

architecture RTL of uart_fast_tx is

type state_t is (
	IDLE,
	START,
	DATA,
	PARITY,
	STOP
);
signal state : state_t := IDLE;

signal dbit	: integer range 0 to DATA_BITS-1  := 0;
signal sbit	: integer range 0 to integer(ceil(STOP_BITS))-1  := 0;
signal char : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal prty : std_logic := '0';

signal strobe	: std_logic := '0';
signal counter	: integer range 0 to DIVIDER-1 := 0;

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			counter <= 0;
		else
			if  (counter = DIVIDER-1) OR
				((state = IDLE) AND (SEND_I = '1'))
			then
				counter <= 0;
				strobe	<= '1';
			else
				counter	<= counter + 1;
				strobe	<= '0';
			end if;
		end if;
	end if;
end process;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			TX_O 	<= NOT START_BIT;
			BUSY_O	<= '0';
			dbit 	<= 0;
			state 	<= IDLE;
		else
		
			if (strobe = '1') then
				case (state) is
				when IDLE =>
					BUSY_O <= '0';
					
					if (ENABLE_I = '1' AND SEND_I = '1') then
						char <= TX_CHAR_I;
						prty <= '0';

						BUSY_O <= '1';
						state <= START;
					end if;
					
				when START =>
					TX_O 	<= START_BIT;
					dbit	<= 0;
					state 	<= DATA;
					
				when DATA =>
					TX_O <= char(0);
						
					char <= '0' & char(DATA_BITS-1 downto 1);
					prty <= prty XOR char(0);
					
					if (dbit = DATA_BITS - 1) then
						dbit <= 0;
						
						if (PARITY_BIT /= 'N') then
							state <= PARITY;
						else
							state <= STOP;
						end if;
					else
						dbit <= dbit + 1;
					end if;
				
				when PARITY =>
					if (PARITY_BIT = 'E') then
						TX_O <= prty;
					elsif (PARITY_BIT = 'O') then
						TX_O <= not prty;
					end if;
				
					sbit	<= 0;
					state	<= STOP;
										
				when STOP =>
					TX_O	<= NOT START_BIT;
					
					if (sbit = integer(ceil(STOP_BITS))-1) then
						sbit	<= 0;
						state 	<= IDLE;
					else
						sbit <= sbit + 1;
					end if;
					

				end case;
			end if;
		end if;
	end if;
end process;

end RTL;

