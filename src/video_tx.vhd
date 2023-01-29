library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity video_tx is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
		LOW_RES_I	: in	STD_LOGIC := '0';
		
		DV_I		: in	STD_LOGIC;
		DATA_I 		: in	STD_LOGIC_VECTOR(15 downto 0);
		
		SENT_O		: out	STD_LOGIC := '0';
		
		PUT_CHAR_O	: out	STD_LOGIC := '0';
		PUT_ACK_I	: in 	STD_LOGIC;
		TX_CHAR_O	: out 	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
		TX_FULL_I	: in	STD_LOGIC
	);
end video_tx;

architecture Behavioral of video_tx is

signal data		: std_logic_vector(15 downto 0);

type state_t is
(
	S_IDLE,
	S_SEND_HI,
	S_WAIT_HI,
	S_SEND_LO,
	S_WAIT_LO
);

signal state	: state_t := S_IDLE;

begin

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
		else
			PUT_CHAR_O	<= '0';
			SENT_O		<= '0';
			
			case (state) is
			when S_IDLE =>
				data <= DATA_I;
				
				if DV_I = '1' then
					state <= S_SEND_HI;
				end if;
				
			when S_SEND_HI =>
				TX_CHAR_O	<= data(15 downto 8);
				
				if (TX_FULL_I = '0') then
					PUT_CHAR_O	<= '1';
					state		<= S_WAIT_HI;
				end if;
				
			when S_WAIT_HI =>
				if (PUT_ACK_I = '1') then
					if (LOW_RES_I = '0') then
						state <= S_SEND_LO;
					else
						state	<= S_IDLE;
						SENT_O	<= '1';
					end if;
				end if;
					
			when S_SEND_LO =>
				TX_CHAR_O	<= data(7 downto 0);
				
				if (TX_FULL_I = '0') then
					PUT_CHAR_O	<= '1';
					state		<= S_WAIT_LO;
				end if;
				
			when S_WAIT_LO =>
				if (PUT_ACK_I = '1') then
					state	<= S_IDLE;
					SENT_O	<= '1';
				end if;
			
			end case;
		end if;
	end if;
end process;

end Behavioral;

