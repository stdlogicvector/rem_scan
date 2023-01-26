library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.STD_LOGIC_MISC.ALL;

entity dac is
	generic (
		CHANNELS	: integer range 1 to 4 := 2
	);
	port (
		CLK_I 		: in  STD_LOGIC;
		RST_I		: in	STD_LOGIC;
	
		CLEAR_I		: in  STD_LOGIC;
	
		DV_I		: in  STD_LOGIC_VECTOR (CHANNELS-1 downto 0);
		CH0_I		: in  STD_LOGIC_VECTOR (15 downto 0);
		CH1_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000";
		CH2_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000";
		CH3_I		: in  STD_LOGIC_VECTOR (15 downto 0) := x"0000";
		
		DV_RAW_I	: in	STD_LOGIC;
		RAW_I		: in	STD_LOGIC_VECTOR (23 downto 0);

		BUSY_O		: out	STD_LOGIC := '1';	-- Default busy because of init sequence on reset
		DONE_O		: out	STD_LOGIC := '0';
		
		-- SPI Interface
		BUSY_I 	 	: in  STD_LOGIC;
		SEND_O 	 	: out STD_LOGIC := '0';
		CMD_O 	 	: out STD_LOGIC_VECTOR (23 downto 0) := (others => '0');
		
		-- Special Pins
		CLEARn_O	: out STD_LOGIC := '0';
		LOADn_O		: out STD_LOGIC := '0'
	);
end dac;

--TODO: Support all channels and make "new_value" input a bus to update one or more channels 

architecture AD57xx of dac is

constant W	: std_logic_vector(1 downto 0) := b"00";
constant R	: std_logic_vector(1 downto 0) := b"10";

constant DAC_REG : std_logic_vector(2 downto 0) := b"000";	-- DAC Values
constant ORS_REG : std_logic_vector(2 downto 0) := b"001";	-- Output Range Select
constant PWR_REG : std_logic_vector(2 downto 0) := b"010";	-- Power Control
constant CTL_REG : std_logic_vector(2 downto 0) := b"011";	-- Control

type ch_id_t	is array(0 to 3) of std_logic_vector(2 downto 0);
constant CH2_ID	: ch_id_t := (b"000", b"010", b"000", b"010");
constant CH4_ID : ch_id_t := (b"000", b"001", b"010", b"011");

--constant CH_0	: std_logic_vector(2 downto 0) := b"000";
--constant CH_1	: std_logic_vector(2 downto 0) := b"001";
--constant CH_2	: std_logic_vector(2 downto 0) := b"010";
--constant CH_3	: std_logic_vector(2 downto 0) := b"011";
constant CH_ALL	: std_logic_vector(2 downto 0) := b"100";

constant CTL_CFG	: std_logic_vector(2 downto 0) := b"001";
constant CTL_CLR	: std_logic_vector(2 downto 0) := b"100";
constant CTL_LOD	: std_logic_vector(2 downto 0) := b"101";

type channel_array is array(0 to 3) of STD_LOGIC_VECTOR(15 downto 0);

signal ch_reg	: channel_array := (others => (others => '0'));
signal raw_reg	: STD_LOGIC_VECTOR(23 downto 0) := (others => '0');
signal new_reg	: STD_LOGIC_VECTOR(CHANNELS-1 downto 0) := (others => '0');
signal busy_reg : STD_LOGIC := '0';

signal ch		 : integer range 0 to CHANNELS-1 := 0;

signal delay_cnt : STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

type state_t is (
	IDLE,
	WAIT_INIT,
	SEND_INIT, TRANSMIT_INIT,
	SEND_RAW, TRANSMIT_RAW,
	SELECT_CH, SEND_CH, TRANSMIT_CH,
	WAIT_LOAD, LOAD_DAC,
	WAIT_CLEAR);
	
signal state : state_t := WAIT_INIT;

constant INIT_STEPS : integer := 5;
signal step : integer range 0 to INIT_STEPS-1 := 0;

type vector_array  is array (0 to (INIT_STEPS-1)) of STD_LOGIC_VECTOR(23 downto 0);
signal init : vector_array :=
(
--	R/!W	   REG		A[2:0]	Data
	W & ORS_REG & CH_ALL  & b"0000000000000" & b"011",	-- Output Range Select 		: +-5V for all DACs (Dummy Write)
	W & ORS_REG & CH_ALL  & b"0000000000000" & b"011",	-- Output Range Select 		: +-5V for all DACs
	W & CTL_REG & CTL_CFG & b"000000000000" & b"1100",	-- Control Register    		: TSD enabled, Clamp Enabled, Clear to 0V, SDO enable
	W & CTL_REG & CTL_CLR & b"0000000000000" & b"000",	-- Clear DAC registers 		: Clear to set 0V
	W & PWR_REG & b"000"  & b"000000" & b"0000001111"	-- Power Control Register	: Power Up all Channels
);

begin

process(CLK_I) is
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			state 		<= WAIT_INIT;
			BUSY_O		<= '1';
		else
			DONE_O	 	<= '0';
			SEND_O   	<= '0';
			LOADn_O 	<= '1';
			CLEARn_O 	<= '1';
			busy_reg  	<= BUSY_I;
		
			case state is
			when IDLE =>
				BUSY_O	<= '0';
				CMD_O		<= (others => '0');

				if (or_reduce(DV_I) = '1')
				then
					BUSY_O  <= '1';
					
					new_reg <= DV_I;
					
					ch_reg(0) <= CH0_I;
					ch_reg(1) <= CH1_I;
					ch_reg(2) <= CH2_I;
					ch_reg(3) <= CH3_I;
					
					ch <= 0;
										
					state <= SELECT_CH;
				
				elsif (DV_RAW_I = '1')
				then
					BUSY_O  <= '1';
					
					if (RAW_I(7 downto 0) = x"42")
					then
						state	<= SEND_INIT;
					else
						raw_reg	<= RAW_I;
						state	<= SEND_RAW;
					end if;
				elsif (CLEAR_I = '1')
				then
					BUSY_O	<= '1';
					state	<= WAIT_CLEAR;
				end if;
				
			when WAIT_INIT =>
				BUSY_O  <= '1';
				
				if (delay_cnt = 100)
				then
					delay_cnt	<= (others => '0');
					state		<= SEND_INIT;
				else
					delay_cnt	<= delay_cnt + '1';
				end if;
				
			when SEND_INIT =>
				if (busy_reg = '0')
				then
					CMD_O	<= init(step);
					SEND_O	<= '1';
				else
					state	<= TRANSMIT_INIT;
				end if;
				
			when TRANSMIT_INIT =>
				if (busy_reg = '0')
				then
					if (step = (INIT_STEPS-1))
					then
						state	<= WAIT_LOAD;
						step	<= 0;
					else
						state <= WAIT_INIT;
						step	<= step + 1;
					end if;
				end if;
				
			when SEND_RAW =>
				if (busy_reg = '0')
				then
					CMD_O		<= raw_reg;
					SEND_O	<= '1';
				else
					state	<= TRANSMIT_RAW;
				end if;
				
			when TRANSMIT_RAW =>
				if (busy_reg = '0')
				then
					DONE_O	<= '1';
					state		<= IDLE;
				end if;
				
			when SELECT_CH =>
				if (new_reg(ch) = '1')
				then
					state <= SEND_CH;
				else
					state <= WAIT_LOAD;
				end if;
				
			when SEND_CH =>
				if (busy_reg = '0')
				then
					if (CHANNELS = 2) then
						CMD_O <= W & DAC_REG & CH2_ID(ch) & ch_reg(ch);
					elsif (CHANNELS = 4) then
						CMD_O  <= W & DAC_REG & std_logic_vector(to_unsigned(ch, 3)) & ch_reg(ch);
					end if;
					
					SEND_O <= '1';
				else
					state <= TRANSMIT_CH;
				end if;
		
			when TRANSMIT_CH =>
				if (busy_reg = '0')
				then
					if (ch = CHANNELS-1)
					then
						state <= WAIT_LOAD;
					else
						ch <= ch + 1;
						state <= SELECT_CH;
					end if;
				end if;	
						
			when WAIT_LOAD =>
				if (delay_cnt = 5)
				then
					delay_cnt <= (others => '0');
					state 	 <= LOAD_DAC;
				else
					delay_cnt <= delay_cnt + '1';
				end if;
			
			when LOAD_DAC =>
				LOADn_O <= '0';	-- Transmission of channels finished -> Load DAC registers to output new voltages simultaneously
				
				if (delay_cnt = 4)
				then
					delay_cnt <= (others => '0');
					DONE_O	 <= '1';
					state 	 <= IDLE;
				else
					delay_cnt <= delay_cnt + '1';
				end if;
				
			when WAIT_CLEAR =>
				CLEARn_O <= '0';
				
				if (delay_cnt = 4)
				then
					delay_cnt <= (others => '0');
					DONE_O	 <= '1';
					state 	 <= IDLE;
				else
					delay_cnt <= delay_cnt + '1';
				end if;
				
			end case;
		end if;
	end if;
end process;

end AD57xx;

