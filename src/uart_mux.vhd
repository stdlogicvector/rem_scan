library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity uart_mux is
	Generic (
		DATA_BITS	: integer range 6 to 9 := 8
	);
	Port (
		CLK_I 		: in  STD_LOGIC;
		RST_I		: in  STD_LOGIC;
		
		SELECT_I	: in	STD_LOGIC;
		SELECT_O	: out	STD_LOGIC := '0';	-- Current Mux State
		
		PUT_CHAR_0_I: in	STD_LOGIC;
		PUT_ACK_0_O	: out 	STD_LOGIC := '0';
		TX_CHAR_0_I	: in 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		TX_FULL_0_O	: out	STD_LOGIC := '0';
		
		PUT_CHAR_1_I: in	STD_LOGIC;
		PUT_ACK_1_O	: out 	STD_LOGIC := '0';
		TX_CHAR_1_I	: in 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		TX_FULL_1_O	: out	STD_LOGIC := '0';
		
		BUSY0_I		: in	STD_LOGIC := '0';	-- Only allow switching when
		BUSY1_I		: in	STD_LOGIC := '0';	-- currently active channel is idle
		
		PUT_CHAR_O	: out	STD_LOGIC := '0';
		PUT_ACK_I	: in 	STD_LOGIC;
		TX_CHAR_O	: out 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		TX_FULL_I	: in	STD_LOGIC
	);
end uart_mux;

architecture Behavioral of uart_mux is

type state_t is (
	S_IDLE,
	S_WAIT
);
signal state		: state_t := S_IDLE;

signal selection	: std_logic := '0';
signal selected 	: std_logic := '0';

begin

SELECT_O	<= selected;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
	
		if selected = '0' then
			PUT_CHAR_O	<= PUT_CHAR_0_I;
			PUT_ACK_0_O	<= PUT_ACK_I;
			TX_CHAR_O	<= TX_CHAR_0_I;
			TX_FULL_0_O <= TX_FULL_I;
			TX_FULL_1_O <= '1';			-- inactive channel is blocked with full=1
		else
			PUT_CHAR_O	<= PUT_CHAR_1_I;
			PUT_ACK_1_O	<= PUT_ACK_I;
			TX_CHAR_O	<= TX_CHAR_1_I;
			TX_FULL_1_O <= TX_FULL_I;
			TX_FULL_0_O <= '1';			-- inactive channel is blocked with full=1
		end if;
			
		if RST_I = '1' then
			selected <= '0';
		else
			case state is
			when S_IDLE =>
				selection <= SELECT_I;
				
				if SELECT_I /= selected then
					state <= S_WAIT;
				end if;
				
			when S_WAIT =>
				if (selected = '0' AND BUSY0_I = '0')
				OR (selected = '1' AND BUSY1_I = '0')
				then
					selected	<= selection;
					state		<= S_IDLE;
				end if;
			end case;
		end if;
	end if;
end process;

end Behavioral;

