library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity control is
	Port (
		CLK_I			: in  STD_LOGIC;
		RST_I			: in  STD_LOGIC;
		
		CONTROL_O		: out STD_LOGIC := '0';
		
		SCAN_START_I	: in  STD_LOGIC;
		SCAN_ABORT_I	: in  STD_LOGIC;
		SCAN_BUSY_I		: in  STD_LOGIC;
		
		MUX_SELECT_O	: out	std_logic := '0';
		MUX_SELECT_I	: in	std_logic;
		
		SCAN_START_O	: out	STD_LOGIC := '0';
		SCAN_ABORT_O	: out	STD_LOGIC := '0';
		SCAN_BUSY_O		: out	STD_LOGIC := '0';
		
		CTRL_DELAY_I	: in  STD_LOGIC_VECTOR (15 downto 0)
	);
end control;

architecture Behavioral of control is

type state_t is (
	S_IDLE,
	S_GET_MUX,
	S_DELAY,
	S_START,
	S_SCAN,
	S_LEAVE_MUX
);

signal state	: state_t := S_IDLE;

signal timer	: std_logic_vector(23 downto 0) := x"000000";

begin

process(CLK_I)
begin
	if rising_edge(CLK_I)
	then
		if (RST_I = '1')
		then
			state <= S_IDLE;
		else
			SCAN_START_O <= '0';
			SCAN_ABORT_O <= '0';
			
			timer <= timer + '1';
			
			case (state) is
			when S_IDLE =>
				if (SCAN_START_I = '1')
				then
					CONTROL_O	<= '1';
					SCAN_BUSY_O <= '1';
					timer	<= (others => '0');
					state	<= S_GET_MUX;
				else
					SCAN_BUSY_O <= '0';
					CONTROL_O	<= '0';
				end if;
			
			when S_GET_MUX =>
				MUX_SELECT_O <= '1';
				if (MUX_SELECT_I = '1') then
					state <= S_DELAY;
				end if;
			
			when S_DELAY =>
				if (timer(23 downto 8) >= CTRL_DELAY_I)
				then
					state <= S_START;
				end if;
				
			when S_START =>
				SCAN_START_O <= '1';
				
				if (SCAN_BUSY_I = '1')
				then
					state <= S_SCAN;
				end if;

			when S_SCAN =>
				if (SCAN_ABORT_I = '1')
				then
					SCAN_ABORT_O <= '1';
				end if;
			
				if (SCAN_BUSY_I = '0')
				then
					state <= S_LEAVE_MUX;
				end if;
				
			when S_LEAVE_MUX =>
				MUX_SELECT_O <= '0';
				if (MUX_SELECT_I = '0') then
					state <= S_IDLE;
				end if;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;

