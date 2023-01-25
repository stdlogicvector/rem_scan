LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
ENTITY toplevel_tb IS
END toplevel_tb;
 
ARCHITECTURE behavior OF toplevel_tb IS 
   --Inputs
   signal CLK50_I		: std_logic := '0';
   signal RST_I		: std_logic := '1';
   
   signal nCONTROL_O	: std_logic;
	
   signal DAC_SCK_O	: std_logic;
   signal DAC_nCS_O	: std_logic;
   signal DAC_MOSI_O	: std_logic;
	signal DAC_MISO_I	: std_logic := '0';
   signal DAC_nLOAD_O : std_logic;
   signal DAC_nCLR_O	: std_logic;
   
	signal ADC_CNV_O	: std_logic;
   signal ADC_SCK_O	: std_logic;
	signal ADC_SD0_I	: std_logic := '0';
   signal ADC_SD1_I	: std_logic := '0';
   
	signal RS485_TX_O	: std_logic;
	signal RS485_RX_I	: std_logic := '0';
	
   constant clk_period : time := 20 ns;
 
BEGIN
   
	uut : entity work.toplevel
	port map (
		CLK50_I	=> CLK50_I,
		RST_I		=> RST_I,
		
		nCONTROL_O => nCONTROL_O,
		
		DAC_SCK_O	=> DAC_SCK_O,
		DAC_nCS_O	=> DAC_nCS_O,
		DAC_MISO_I	=> DAC_MISO_I,
		DAC_MOSI_O	=> DAC_MOSI_O,
		DAC_nLOAD_O	=> DAC_nLOAD_O,
		DAC_nCLR_O	=> DAC_nCLR_O,
		
		ADC_CNV_O	=> ADC_CNV_O,
		ADC_SCK_O	=> ADC_SCK_O,
		ADC_SD0_I	=> ADC_SD0_I,
		ADC_SD1_I	=> ADC_SD1_I,
		
		RS485_TX_O	=> RS485_TX_O,
		RS485_RX_I	=> RS485_RX_I
	);

   clk : process
   begin
		CLK50_I <= '0';
		wait for clk_period/2;
		CLK50_I <= '1';
		wait for clk_period/2;
   end process;
 
   sim : process
   begin		
      RST_I <= '1';
      wait for 100 ns;	
		RST_I <= '0';

      wait for clk_period*10;

       

      wait;
   end process;

END;
