library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.VCOMPONENTS.ALL;
use work.util.all;

entity adc is
	Port (
		CLK_I    	: IN STD_LOGIC;
		RST_I  		: IN STD_LOGIC;
		
		SAMPLE_I 	: IN STD_LOGIC;				-- Perform an acquisition

		CONV_O  	: OUT STD_LOGIC := '0';		-- Start acquisition
		SCK_O   	: OUT STD_LOGIC := '0';		-- Serial clock
		SD0_I 		: IN  STD_LOGIC;			-- Data in X (falling edge after conv->high signals data is valid)
		SD1_I 		: IN  STD_LOGIC;			-- Data in Y (falling edge after conv->high signals data is valid)

		DV_O 		: OUT STD_LOGIC := '0';
		CH0_O 		: OUT STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		CH1_O 		: OUT STD_LOGIC_VECTOR (15 downto 0) := (others => '0')

		;DBG_O		: OUT STD_LOGIC_VECTOR(2 downto 0)
	);
end adc;

architecture AD79xx of adc is

signal ch0_reg 	: STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
signal ch1_reg 	: STD_LOGIC_VECTOR (15 downto 0) := (others => '0');

signal data_bit : integer range 0 to 17 := 0;

type state_t is (
	INIT,			-- 0
	IDLE,			-- 1
	WAIT_STATE,		-- 2
	CONVERSION,		-- 3
	READ_DATA,		-- 4
	DATA_READY,		-- 5
	WAIT_FOR_IDLE	-- 6
);
signal state 	: state_t := INIT;

attribute fsm_encoding : string;
attribute fsm_encoding of state : signal is "gray";

signal sck		: STD_LOGIC := '0';
signal inited	: STD_LOGIC := '0';

constant timedout : integer := 255;
signal timeout	  : integer range 0 to timedout := 0;

begin

DBG_O <= int2vec(state_t'pos(state), 3);

SCK_O <= sck;

process(CLK_I) is
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			state <= INIT;
			inited <= '0';
		else
			DV_O <= '0';
			CONV_O  <= '0';
			
			timeout <= timeout + 1;
			
			case state is
			when INIT =>
				if (timeout = timedout) then	
					timeout <= 0;
					
					if (SD0_I = '1') AND (SD1_I = '1') then
						inited <= '1';
						state <= IDLE;
					else
						inited <= '0';
						state <= WAIT_STATE;
					end if;
				end if;

				data_bit <= 0;
				sck <= '0';

			when IDLE =>
				if (SAMPLE_I = '1') then
					state	<= WAIT_STATE;
				end if;

				if (SD0_I = '0') OR (SD1_I = '0') then
					state	<= INIT;
				end if;

				timeout  <= 0;
				data_bit <= 0;
				sck <= '0';
				
			when WAIT_STATE =>
				if ((SD0_I = '1') AND (SD1_I= '1')) OR (inited = '0') then
					CONV_O  <= '1';
					
					if (data_bit = 3) then
						data_bit <= 0;
						state <= CONVERSION;
					else
						data_bit <= data_bit + 1;
						state <= WAIT_STATE;
					end if;
				elsif timeout = timedout then
					inited <= '0';
					state <= INIT;
				end if;
				
			when CONVERSION =>
				if (SD0_I = '0') AND (SD1_I = '0') then
					state <= READ_DATA;
				elsif timeout = timedout then
					inited <= '0';
					state <= INIT;
				end if;
						
			when READ_DATA =>
				sck <= not sck;

				if (sck = '1') then
					ch0_reg <= ch0_reg(ch0_reg'HIGH - 1 downto 0) & SD0_I;
					ch1_reg <= ch1_reg(ch1_reg'HIGH - 1 downto 0) & SD1_I;
					
					if (data_bit = 16) then
						state <= DATA_READY;
					else
						data_bit <= data_bit + 1;
						state <= READ_DATA;
					end if;
				end if;
			
			when DATA_READY =>
				CH0_O <= ch0_reg;
				CH1_O <= ch1_reg;
				
				DV_O	<= inited;
				
				timeout	<= 0;
				state	<= WAIT_FOR_IDLE;

			when WAIT_FOR_IDLE =>
				if (SD0_I = '1') AND (SD1_I = '1') then
					inited <= '1';
					state <= IDLE;
				elsif timeout = timedout then
					state <= INIT;
				else
					state <= WAIT_FOR_IDLE;
				end if;
				
			when OTHERS =>
				state <= IDLE;
			end case;
		end if;
	end if;
end process;

end AD79xx;
