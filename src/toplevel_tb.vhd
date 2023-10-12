LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
use work.util.all;

ENTITY toplevel_tb IS
END toplevel_tb;
 
ARCHITECTURE behavior OF toplevel_tb IS 
	signal CLK50_I		: std_logic := '0';
	signal RST_I		: std_logic := '1';
   
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
   
	signal RS232_TX		: std_logic := '1';
	signal RS232_RX		: std_logic := '0';
	
	signal RAM_ADDR		: std_logic_vector(18 downto 0) := (others => '0');
	signal RAM_DATA		: std_logic_vector( 7 downto 0) := (others => '0');
	signal RAM_nOE		: std_logic;
	signal RAM_nWE		: std_logic;
	signal RAM_nCE		: std_logic;

	signal FLASH_DQ_IO	: std_logic_vector(3 downto 0) := (others => 'L');
		
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
	
	type ram_t is array (0 to (2**19)-1) of std_logic_vector (7 downto 0);
	signal ram : ram_t := (others => (others => '0'));
 
BEGIN
   	sim : process
	begin		
		RST_I <= '1';
		wait for 100 ns;	
		RST_I <= '0';

		wait for 400 us;

		setReg(16, 2, RS232_TX);	-- CTRL Delay = 2*2560ns
		setReg(0, 55, RS232_TX);
		setReg(1, 13, RS232_TX);
		
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
		UART_BAUDRATE	=> UART_BAUDRATE,
		UART_FLOW_CTRL	=> false,
		SIMULATION		=> true
	)
	port map (
		CLK50_I			=> CLK50_I,
		RST_I			=> RST_I,
		
		CONTROL_O		=> CONTROL_O,
		BTN_I			=> (others => '0'),
		LED_O			=> open,
		
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
		UART_RTS_I		=> '0',
		UART_CTS_O		=> open,
		
		VGA_VSYNC_O		=> open,
		VGA_HSYNC_O		=> open,
		VGA_GRAY_O		=> open,
		
		RAM_ADDR_O		=> RAM_ADDR,
		RAM_DATA_IO		=> RAM_DATA,
		RAM_nOE_O		=> RAM_nOE,
		RAM_nWE_O		=> RAM_nWE,
		RAM_nCE_O		=> RAM_nCE,
		
		FLASH_CS_O		=> open,
		FLASH_DQ_IO		=> FLASH_DQ_IO,
		
		DBG_O			=> open
	);
	
	FLASH_DQ_IO <= (others => 'L');

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
	
	sram : entity work.sram_sim
	generic map (
		download_on_power_up	=> true,
		clear_on_power_up		=> true, 
		
		size		=> 2**19,
		adr_width	=> 19,
		width		=> 8
	)
	port map (
		nCE			=> RAM_nCE,
		nOE			=> RAM_nOE,
		nWE			=> RAM_nWE,
		
		A			=> RAM_ADDR,
		D			=> RAM_DATA
	);
END;
