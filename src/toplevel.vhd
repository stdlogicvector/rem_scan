library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.util.all;

entity toplevel is
	Generic (
		VERSION			: integer := 16#0100#;	-- v01.00
		BUILD				: integer := 0;
		SYS_CLK_FREQ	: integer := 100;
		UART_BAUDRATE	: integer := 921600;
		UART_CMD_BITS	: integer := 8;
		UART_CMD_ARGS	: integer := 4;
		NR_OF_REGS		: integer := 32
	);
	Port (
		CLK50_I		: in	STD_LOGIC;
		RST_I			: in	STD_LOGIC;
		
		nCONTROL_O	: out	STD_LOGIC := '1';		-- Acquire Control over REM (active Low)
		
		DAC_SCK_O	: out	STD_LOGIC := '0';		-- DAC for X/Y Out
		DAC_nCS_O	: out	STD_LOGIC := '1';
		DAC_MISO_I	: in	STD_LOGIC;
		DAC_MOSI_O	: out	STD_LOGIC := '0';
		DAC_nLOAD_O	: out	STD_LOGIC := '1';
		DAC_nCLR_O	: out	STD_LOGIC := '1';
		
		ADC_CNV_O	: out	STD_LOGIC := '0';		-- ADC for Video In
		ADC_SCK_O	: out	STD_LOGIC := '0';
		ADC_SD0_I	: in	STD_LOGIC;
		ADC_SD1_I	: in	STD_LOGIC;
		
		UART_TX_O	: out	STD_LOGIC := '1';		-- Control Interface to PC
		UART_RX_I	: in	STD_LOGIC		
	);
end toplevel;

architecture Behavioral of toplevel is

signal clk100			: std_logic := '0';
signal reset			: std_logic := '1';

-- UART		
signal uart_arb_nack		: std_logic;
signal uart_arb_ack		: std_logic;

signal uart_tx_done		: std_logic;
signal uart_put			: std_logic;
signal uart_put_ack		: std_logic;
signal uart_put_char		: std_logic_vector(7 downto 0);
signal uart_put_full		: std_logic;
signal uart_get			: std_logic;
signal uart_get_ack		: std_logic;
signal uart_get_char		: std_logic_vector(7 downto 0);
signal uart_get_empty	: std_logic;

-- UART CMD
signal uart_new_cmd		: std_logic;
signal uart_cmd_ack		: std_logic;
signal uart_cmd_id		: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_cmd_args		: std_logic_vector((UART_CMD_ARGS*UART_CMD_BITS)-1 downto 0);

signal uart_new_ack		: std_logic;
signal uart_new_nack		: std_logic;

signal uart_new_reply	: std_logic;
signal uart_reply_ack	: std_logic;
signal uart_reply_id		: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_reply_args	: std_logic_vector((UART_CMD_ARGS*UART_CMD_BITS)-1 downto 0);
signal uart_reply_argn	: std_logic_vector(clogb2(UART_CMD_ARGS)-1 downto 0);

-- CONTROL
signal control_o		: std_logic;

signal scan_start		: std_logic;
signal scan_abort		: std_logic;
signal scan_busy		: std_logic;

-- REGISTERS
signal reg_write		: std_logic := '0';
signal reg_addr		: std_logic_vector( 7 downto 0) := (others => '0');
signal reg_data_read	: std_logic_vector(15 downto 0) := (others => '0');
signal reg_data_write: std_logic_vector(15 downto 0) := (others => '0');
signal reg				: array16_t(0 to NR_OF_REGS-1);

-- PATTERN
signal pat_scan		: std_logic;
signal pat_abort		: std_logic;
signal pat_busy		: std_logic;
	
signal pat_sample		: std_logic;
signal pat_row			: std_logic_vector(15 downto 0);
signal pat_col			: std_logic_vector(15 downto 0);

signal pat_dv			: std_logic;
signal pat_x			: std_logic_vector(15 downto 0);
signal pat_y			: std_logic_vector(15 downto 0);

-- TRANSFORM
signal trn_dv			: std_logic;
signal trn_x			: std_logic_vector(15 downto 0);
signal trn_y			: std_logic_vector(15 downto 0);

-- DAC&ADC
signal dac_raw_dv		: std_logic;
signal dac_raw			: std_logic_vector(23 downto 0);
signal dac_done		: std_logic;

signal spi_send		: std_logic;
signal spi_busy		: std_logic;
signal spi_data_tx	: std_logic_vector(23 downto 0);

signal adc_dv			: std_logic;
signal adc_ch0			: std_logic_vector(15 downto 0);
signal adc_ch1			: std_logic_vector(15 downto 0);

begin

uart : entity work.uart
generic map (
	CLK_MHZ	=> SYS_CLK_FREQ,
	BAUDRATE	=> UART_BAUDRATE
)
port map (
	CLK_I		=> clk100,
	RST_I 	=> reset,
	
	RX_DN_I 	=> UART_RX_I,
	TX_DN_O 	=> UART_TX_O,
	
	TX_DONE_O	=> open,
	
	PUT_CHAR_I	=> uart_put,
	PUT_ACK_O	=> uart_put_ack,
	TX_CHAR_I	=> uart_put_char,
	TX_FULL_O	=> uart_put_full,
	
	GET_CHAR_I	=> uart_get,
	GET_ACK_O	=> uart_get_ack,
	RX_CHAR_O	=> uart_get_char,
	RX_EMPTY_O	=> uart_get_empty
);

uart_decoder : entity work.uart_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS			=> UART_CMD_ARGS
)
port map (
	CLK_I				=> clk100,
	RST_I				=> reset,
	
	PUT_CHAR_O		=> uart_put,
	PUT_ACK_I		=> uart_put_ack,
	TX_CHAR_O		=> uart_put_char,
	TX_FULL_I		=> uart_put_full,
	
	GET_CHAR_O		=> uart_get,
	GET_ACK_I		=> uart_get_ack,
	RX_CHAR_I		=> uart_get_char,
	RX_EMPTY_I		=> uart_get_empty,
	
	NEW_CMD_O		=> uart_new_cmd,
	CMD_ACK_I		=> uart_cmd_ack,
	CMD_ID_O			=> uart_cmd_id,
	CMD_ARGS_O		=> uart_cmd_args,
	
	NEW_ACK_I		=> uart_new_ack,
	NEW_NACK_I		=> uart_new_nack,
	
	NEW_REPLY_I		=> uart_new_reply,
	REPLY_ACK_O		=> uart_reply_ack,
	REPLY_ID_I		=> uart_reply_id,
	REPLY_ARGS_I	=> uart_reply_args,
	REPLY_ARGN_I	=> uart_reply_argn
);

registers : entity work.registers
generic map (
	NR_OF_REGS		=> NR_OF_REGS,
	CLOCK_MHZ		=> SYS_CLK_FREQ,
	VERSION			=> VERSION,
	BUILD				=> BUILD
)
port map (
	CLK_I				=> clk100,
	RST_I				=> reset,
	
	WRITE_I			=> reg_write,
	ADDR_I			=> reg_addr,
	DATA_O			=> reg_data_read,
	DATA_I			=> reg_data_write,
	
	REGISTERS_O		=> reg
);

nCONTROL_O <= not control_o;

control : entity work.control
port map (
	CLK_I 			=> clk100,
	RST_I 			=> reset,
	
	CONTROL_O		=> control_o,
		
	SCAN_START_I	=> scan_start,
	SCAN_ABORT_I	=> scan_abort,
	SCAN_BUSY_O		=> scan_busy,
	
	SCAN_START_O	=> pat_start,
	SCAN_ABORT_O	=> pat_abort,
	SCAN_BUSY_I		=> pat_busy,
	
	CTRL_DELAY_I	=> reg(16)
);

pattern : entity work.pattern 
port map (
	CLK_I 		=> clk100,
	RST_I 		=> reset,
	
	START_I 		=> pat_start,
	BUSY_O 		=> pat_busy,
	
	OFFSET_X_I	=> reg(8),
	OFFSET_Y_I	=> reg(9),
	STEPS_X_I	=> reg(10),
	STEPS_Y_I	=> reg(11),
	DELTA_X_I	=> reg(12),
	DELTA_Y_I	=> reg(13),
	
	INI_DELAY_I	=> reg(17),
	COL_DELAY_I	=> reg(18),
	ROW_DELAY_I	=> reg(19),
		
	DV_O			=> pat_dv,
	X_O			=> pat_x,
	Y_O			=> pat_y,
	
	SAMPLE_O		=> pat_sample,
	SAMPLED_I	=> adc_dv,
	ROW_O			=> pat_row,
	COL_O			=> pat_col
);

transform : entity work.transform
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,
	
	DV_I			=> pat_dv,
	X_I			=> pat_x,
	Y_I			=> pat_y,
	
	DV_O			=> trn_dv,
	X_O			=> trn_x,
	Y_O			=> trn_y,
	
	C00_I			=> reg(20),
	C01_I			=> reg(21),
	C02_I			=> reg(22),
	C10_I			=> reg(23),
	C11_I			=> reg(24),
	C12_I			=> reg(25)
);

dac : entity work.dac
generic map (
	CHANNELS		=> 2
)
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,
	
	CLEAR_I		=> '0',
		
	DV_I			=> trn_dv & trn_dv,
	CH0_I			=> trn_x,
	CH1_I			=> trn_y,
	
	DV_RAW_I		=> dac_raw_dv,
	RAW_I			=> dac_raw,
	
	BUSY_O		=> open,
	DONE_O		=> dac_done,
	
	BUSY_I		=> spi_busy,
	SEND_O		=> spi_send,
	CMD_O			=> spi_data_tx,
	
	LOADn_O		=> DAC_nLOAD_O,
	CLEARn_O		=> DAC_nCLR_O	
);

spi : entity work.spi_master
generic map (
	SLAVES		=> 1,
	WIDTH			=> 24
)
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,
	
	SEND_I		=> spi_send,
	CONT_I		=> '0',
	BUSY_O		=> spi_busy,
	CPOL_I		=> '0',
	CPHA_I		=> '1',
	
	CLKDIV_I		=> x"01",
	SLAVE_I		=> "1",
	
	TX_I			=> spi_data_tx,
	RX_O			=> open,
	
	CSn_O(0)		=> DAC_nCS_O,
	SCK_O			=> DAC_SCK_O,
	MISO_I		=> DAC_MISO_I,
	MOSI_O		=> DAC_MOSI_O	
);

adc : entity work.adc
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,
	
	SAMPLE_I		=> pat_sample,
	
	CONV_O		=> ADC_CNV_O,
	SCK_O			=> ADC_SCK_O,
	SD0_I			=> ADC_SD0_I,
	SD1_I			=> ADC_SD1_I,
	
	DV_O			=> adc_dv,
	CH0_O			=> adc_ch0,
	CH1_O			=> adc_ch1
);

end Behavioral;

