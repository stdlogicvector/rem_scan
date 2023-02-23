LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use work.util.all;

ENTITY toplevel_tb IS
END toplevel_tb;
 
ARCHITECTURE behavior OF toplevel_tb IS 
	signal CLK50_I		: std_logic := '0';
	signal RST_I		: std_logic := '0';
   
	signal CONTROL_O	: std_logic;
	
	signal DAC_SCK_O	: std_logic;
	signal DAC_nCS_O	: std_logic;
	signal DAC_MOSI_O	: std_logic;
	signal DAC_MISO_I	: std_logic := '0';
	signal DAC_nLOAD_O 	: std_logic;
	signal DAC_nCLR_O	: std_logic;
   
	signal ADC_CNV_O	: std_logic;
	signal ADC_SCK_O	: std_logic;
	signal ADC_SD0_I	: std_logic := '0';
	signal ADC_SD1_I	: std_logic := '0';
   
	signal RS232_TX		: std_logic;
	signal RS232_RX		: std_logic := '0';
	
	constant clk_period	: time := 20 ns;
	
	constant UART_BAUDRATE : integer := 921600;
	
	procedure setReg(reg : integer; val : integer; signal uart : out std_logic) is
	begin
		log("Set Register 0x" & to_hstring(int2vec(reg, 8)) & " = 0x" & to_hstring(int2vec(val, 16)));
		uart_puts("{W" & to_hstring(int2vec(reg, 8)) & to_hstring(int2vec(val, 16)) & "}", uart, UART_BAUDRATE);
	end procedure;
 
	procedure scan_start(signal uart : out std_logic) is
	begin
		log("Starting Scan");
		uart_puts("{S}", uart, UART_BAUDRATE);
	end procedure;
	
	procedure live_start(signal uart : out std_logic) is
	begin
		log("Starting Live");
		uart_puts("{L}", uart, UART_BAUDRATE);
	end procedure;

	procedure scan_abort(signal uart : out std_logic) is
	begin
		log("Aborting Scan");
		uart_puts("{X}", uart, UART_BAUDRATE);
	end procedure;
 
BEGIN
   	sim : process
	begin		
		RST_I <= '0';
		wait for 100 ns;	
		RST_I <= '1';

		wait for clk_period*10;

		--setReg(16, 20, RS232_TX);	-- CTRL Delay = 20*2560ns
		
		--scan_start(RS232_TX);
		live_start(RS232_TX);

		wait;
	end process;
   
	clk : process
	begin
		clock(50.0, 0.0ns, CLK50_I);
	end process;
 
	uut : entity work.toplevel
	generic map (
		UART_BAUDRATE	=> UART_BAUDRATE
	)
	port map (
		CLK50_I			=> CLK50_I,
		RST_I			=> RST_I,
		
		CONTROL_O		=> CONTROL_O,
		
		DAC_SCK_O		=> DAC_SCK_O,
		DAC_nCS_O		=> DAC_nCS_O,
		DAC_MISO_I		=> DAC_MISO_I,
		DAC_MOSI_O		=> DAC_MOSI_O,
		DAC_nLOAD_O		=> DAC_nLOAD_O,
		DAC_nCLR_O		=> DAC_nCLR_O,
		
		ADC_CNV_O		=> ADC_CNV_O,
		ADC_SCK_O		=> ADC_SCK_O,
		ADC_SD0_I		=> ADC_SD0_I,
		ADC_SD1_I		=> ADC_SD1_I,
		
		UART_TX_O		=> RS232_RX,
		UART_RX_I		=> RS232_TX,
		
		VGA_VSYNC_O		=> open,
		VGA_HSYNC_O		=> open,
		VGA_GRAY_O		=> open
	);

	dac : entity work.tb_dac
	port map (
		SCK_I		=> DAC_SCK_O,
		nCS_I		=> DAC_nCS_O,
		MISO_O		=> DAC_MISO_I,
		MOSI_I		=> DAC_MOSI_O,
		nLOAD_I		=> DAC_nLOAD_O,
		nCLR_I		=> DAC_nCLR_O
	);
	
	adc : entity work.tb_adc
	port map (
		CNV_I		=> ADC_CNV_O,
		SCK_I		=> ADC_SCK_O,
		SD0_O		=> ADC_SD0_I,
		SD1_O		=> ADC_SD1_I
	);
END;
