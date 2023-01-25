library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.VCOMPONENTS.ALL;

entity adc is
	Port (
		CLK_I		: IN STD_LOGIC;
		RST_I		: IN STD_LOGIC;
		
		SAMPLE_I	: IN STD_LOGIC;

		CONV_O	: OUT STD_LOGIC := '0';
		SCK_O		: OUT STD_LOGIC := '0';
		SD0_I 	: IN  STD_LOGIC;
		SD1_I 	: IN  STD_LOGIC;

		DV_O 		: OUT STD_LOGIC := '0';
		CH0_O		: OUT STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		CH1_O		: OUT STD_LOGIC_VECTOR (15 downto 0) := (others => '0')
	);
end adc;

architecture AD79xx of adc is

signal ch0_reg : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
signal ch1_reg : STD_LOGIC_VECTOR (15 downto 0) := (others => '0');

signal data_bit : integer range 0 to 17 := 0;

type state_t is (IDLE, CONVERSION, LOAD_DATA, READ_DATA, DATA_OUT);
signal state : state_t := IDLE;

signal sck_en : STD_LOGIC := '0';

begin

SCK_FWD : ODDR2
	generic map (
		DDR_ALIGNMENT => "NONE", 	-- Sets output alignment to "NONE", "C0", "C1" 
		INIT => '0', 					-- Sets initial state of the Q output to '0' or '1'
		SRTYPE => "SYNC"				-- Specifies "SYNC" or "ASYNC" set/RST_I
	)
	port map (
		Q 	=> SCK_O, 					-- 1-bit output data
		C0 => CLK_I,					-- 1-bit clock input
		C1 => not CLK_I,				-- 1-bit clock input
		CE => sck_en,			  		-- 1-bit clock enable input
		D0 => '0',						-- 1-bit data input (associated with C0)
		D1 => '1',						-- 1-bit data input (associated with C1)
		R	=> RST_I,					-- 1-bit RST_I input
		S	=> '0'
	);

process(CLK_I) is
begin
	if rising_edge(CLK_I)
	then
		if (RST_I = '1')
		then
			state <= IDLE;
			sck_en <= '0';
		else
			DV_O		<= '0';
			CONV_O	<= '0';
			
			case state is
			when IDLE =>
				sck_en <= '0';
				
				if (SAMPLE_I = '1')
				then
					state 	<= CONVERSION;
					CONV_O 	<= '1';
				end if;
				
			when CONVERSION =>
				if (SD0_I = '0') AND (SD1_I = '0')
				then
					state <= LOAD_DATA;
				end if;
			
			when LOAD_DATA =>
				sck_en	<= '1';
				data_bit <= 0;
				state		<= READ_DATA;
			
			when READ_DATA =>
				ch0_reg <= ch0_reg(ch0_reg'HIGH - 1 downto 0) & SD0_I;
				ch1_reg <= ch1_reg(ch1_reg'HIGH - 1 downto 0) & SD1_I;
				
				if (data_bit = 16)
				then
					sck_en	<= '0';
					state		<= DATA_OUT;
				else
					data_bit <= data_bit + 1;
				end if;
			
			when DATA_OUT =>
				CH0_O <= ch0_reg;
				CH1_O <= ch1_reg;
				DV_O <= '1';
				
				state <= IDLE;
				
			end case;
		end if;
	end if;
end process;

end AD79xx;
