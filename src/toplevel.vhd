library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.util.all;

entity toplevel is
	Generic (
		VERSION				: integer := 16#0101#;	-- v01.00
		BUILD				: integer := 0;
		SYS_CLK_FREQ		: real    := 100.0;
		UART_BAUDRATE		: integer := 921600;
		UART_FLOW_CTRL		: boolean := false;
		UART_CMD_BITS		: integer := 8;
		UART_CMD_MAX_ARGS	: integer := 4;
		NR_OF_REGS			: integer := 32;
		TEST_IMAGE			: boolean := true
	);
	Port (
		CLK50_I		: in	STD_LOGIC;
		RST_I		: in	STD_LOGIC;
		
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
		UART_RX_I	: in	STD_LOGIC;
		UART_RTS_I	: in	STD_LOGIC;
		UART_CTS_O	: out	STD_LOGIC := '0';
--		UART_DTR_I	: in	STD_LOGIC;
--		UART_DSR_O	: out	STD_LOGIC := '0';
--		UART_DCD_O	: out	STD_LOGIC := '0';
--		UART_RI_O	: out	STD_LOGIC := '0';
		
		DBG_O		: out	STD_LOGIC_VECTOR(3 downto 0)
	);
end toplevel;

architecture rem_scan of toplevel is

signal clk100			: std_logic := '0';
signal reset			: std_logic := '1';
signal clk_ready		: std_logic := '0';

-- UART		
signal uart_arb_nack	: std_logic;
signal uart_arb_ack		: std_logic;

signal uart_tx_done		: std_logic;

signal uart_put			: std_logic;
signal uart_put_ack		: std_logic;
signal uart_put_char	: std_logic_vector(7 downto 0);
signal uart_put_full	: std_logic;

signal cmd_put_char		: std_logic;
signal cmd_put_ack		: std_logic;
signal cmd_tx_char		: std_logic_vector(7 downto 0);
signal cmd_tx_full		: std_logic;

signal video_put_char	: std_logic;
signal video_put_ack	: std_logic;
signal video_tx_char	: std_logic_vector(7 downto 0);
signal video_tx_full	: std_logic;

signal uart_get			: std_logic;
signal uart_get_ack		: std_logic;
signal uart_get_char	: std_logic_vector(7 downto 0);
signal uart_get_empty	: std_logic;

-- UART CMD
signal cmd_busy			: std_logic;

signal uart_new_cmd		: std_logic;
signal uart_cmd_ack		: std_logic;
signal uart_cmd_nack	: std_logic;
signal uart_cmd_id		: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_cmd_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0);

signal uart_new_ack		: std_logic;
signal uart_new_nack	: std_logic;

signal uart_new_reply	: std_logic;
signal uart_reply_ack	: std_logic;
signal uart_reply_id	: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_reply_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0);
signal uart_reply_argn	: std_logic_vector(clogb2(UART_CMD_MAX_ARGS)-1 downto 0);

-- CONTROL
signal control_o		: std_logic;

signal scan_start		: std_logic;
signal scan_abort		: std_logic;
signal scan_busy		: std_logic;

signal mux_select		: std_logic;
signal mux_selected		: std_logic;

signal video_sent		: std_logic;

-- REGISTERS
signal reg_write		: std_logic := '0';
signal reg_addr			: std_logic_vector( 7 downto 0) := (others => '0');
signal reg_data_read	: std_logic_vector(15 downto 0) := (others => '0');
signal reg_data_write	: std_logic_vector(15 downto 0) := (others => '0');
signal reg				: array16_t(0 to NR_OF_REGS-1);

-- PATTERN
signal pat_start		: std_logic;
signal pat_abort		: std_logic;
signal pat_busy			: std_logic;
	
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
signal dac_done			: std_logic;

signal spi_send			: std_logic;
signal spi_busy			: std_logic;
signal spi_data_tx		: std_logic_vector(23 downto 0);

signal adc_dv			: std_logic;
signal adc_ch0			: std_logic_vector(15 downto 0);
signal adc_ch1			: std_logic_vector(15 downto 0);

signal counter			: std_logic_vector(10 downto 0) := (others => '0');

begin

clk_gen : entity work.clk_gen
generic map (
	CLK_IN_PERIOD	=> 20.0,	-- 50MHz
	DIFF_CLK_IN		=> false,
	CLKFB_MULT		=> 20,
	DIVCLK_DIVIDE	=> 1,
	CLK_OUT_DIVIDE	=> ( 0 => 10, others => 1 )
)
port map (
	CLK_Ip			=> CLK50_I,
	
	CLK0_O			=> clk100,	-- 50MHz * 20 / 10 = 100MHz
	
	LOCKED_O		=> clk_ready
);

reset <= not RST_I;

process(clk100)
begin
	if rising_edge(clk100) then
		if reset = '1' then
			counter <= (others => '0');
		else
			counter <= inc(counter);
		end if;
	end if;
end process;

uart : entity work.uart
generic map (
	CLK_MHZ			=> SYS_CLK_FREQ,
	BAUDRATE		=> UART_BAUDRATE,
	FLOW_CTRL		=> UART_FLOW_CTRL
)
port map (
	CLK_I			=> clk100,
	RST_I 			=> reset,
	
	RX_I	 		=> UART_RX_I,
	TX_O 			=> UART_TX_O,
	
	CTS_I			=> UART_RTS_I,
	RTS_O			=> UART_CTS_O,
	
	TX_DONE_O		=> open,
	
	PUT_CHAR_I		=> uart_put,
	PUT_ACK_O		=> uart_put_ack,
	TX_CHAR_I		=> uart_put_char,
	TX_FULL_O		=> uart_put_full,
	
	GET_CHAR_I		=> uart_get,
	GET_ACK_O		=> uart_get_ack,
	RX_CHAR_O		=> uart_get_char,
	RX_EMPTY_O		=> uart_get_empty
);

uart_mux : entity work.uart_mux
generic map (
	DATA_BITS 		=> UART_CMD_BITS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,

	SELECT_I		=> mux_select,
	SELECT_O		=> mux_selected,
	
	PUT_CHAR_0_I	=> cmd_put_char,
	PUT_ACK_0_O		=> cmd_put_ack,
	TX_CHAR_0_I		=> cmd_tx_char,
	TX_FULL_0_O		=> cmd_tx_full,
	
	PUT_CHAR_1_I	=> video_put_char,
	PUT_ACK_1_O		=> video_put_ack,
	TX_CHAR_1_I		=> video_tx_char,
	TX_FULL_1_O		=> video_tx_full,
	
	BUSY0_I			=> cmd_busy,
	BUSY1_I			=> pat_busy,
	
	PUT_CHAR_O		=> uart_put,
	PUT_ACK_I		=> uart_put_ack,
	TX_CHAR_O		=> uart_put_char,
	TX_FULL_I		=> uart_put_full
);

uart_decoder : entity work.uart_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,
	
	PUT_CHAR_O		=> cmd_put_char,
	PUT_ACK_I		=> cmd_put_ack,
	TX_CHAR_O		=> cmd_tx_char,
	TX_FULL_I		=> cmd_tx_full,
	
	GET_CHAR_O		=> uart_get,
	GET_ACK_I		=> uart_get_ack,
	RX_CHAR_I		=> uart_get_char,
	RX_EMPTY_I		=> uart_get_empty,
	
	NEW_CMD_O		=> uart_new_cmd,
	CMD_ACK_I		=> uart_cmd_ack,
	CMD_NACK_I		=> uart_cmd_nack,
	CMD_ID_O		=> uart_cmd_id,
	CMD_ARGS_O		=> uart_cmd_args,
	
	NEW_ACK_I		=> uart_new_ack,
	NEW_NACK_I		=> uart_new_nack,
	
	NEW_REPLY_I		=> uart_new_reply,
	REPLY_ACK_O		=> uart_reply_ack,
	REPLY_ID_I		=> uart_reply_id,
	REPLY_ARGS_I	=> uart_reply_args,
	REPLY_ARGN_I	=> uart_reply_argn
);

cmd_decoder : entity work.uart_cmd_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS
)
port map (
	CLK_I			=> clk100,
	RESET_I			=> reset,
	
	BUSY_O			=> cmd_busy,
	
	NEW_CMD_I		=> uart_new_cmd,
	CMD_ACK_O		=> uart_cmd_ack,
	CMD_NACK_O		=> uart_cmd_nack,
	CMD_ID_I		=> uart_cmd_id,
	CMD_ARGS_I		=> uart_cmd_args,
	
	NEW_ACK_O		=> uart_new_ack,
	NEW_NACK_O		=> uart_new_nack,
	
	NEW_REPLY_O		=> uart_new_reply,
	REPLY_ACK_I		=> uart_reply_ack,
	REPLY_ID_O		=> uart_reply_id,
	REPLY_ARGS_O	=> uart_reply_args,
	REPLY_ARGN_O	=> uart_reply_argn,
	
	REG_WRITE_O		=> reg_write,
	REG_ADDR_O		=> reg_addr,
	REG_DATA_I		=> reg_data_read,
	REG_DATA_O		=> reg_data_write,
	
	SCAN_START_O	=> scan_start,
	SCAN_ABORT_O	=> scan_abort,
	SCAN_BUSY_I		=> scan_busy
);

registers : entity work.registers
generic map (
	NR_OF_REGS		=> NR_OF_REGS,
	CLOCK_MHZ		=> SYS_CLK_FREQ,
	VERSION			=> VERSION,
	BUILD			=> BUILD
)
port map (
	CLK_I			=> clk100,
	RST_I			=> reset,
	
	WRITE_I			=> reg_write,
	ADDR_I			=> reg_addr,
	DATA_O			=> reg_data_read,
	DATA_I			=> reg_data_write,
	
	REGISTER_O		=> reg
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
	
	MUX_SELECT_O	=> mux_select,
	MUX_SELECT_I	=> mux_selected,
	
	SCAN_START_O	=> pat_start,
	SCAN_ABORT_O	=> pat_abort,
	SCAN_BUSY_I		=> pat_busy,
	
	CTRL_DELAY_I	=> reg(16)
);

DBG_O <= (
	0	=> pat_sample,
	1	=> video_sent,
	2	=> mux_select,
	3	=> mux_selected,
	others => '0'
);

pattern : entity work.pattern 
port map (
	CLK_I 		=> clk100,
	RST_I 		=> reset,
	
	START_I 	=> pat_start,
	ABORT_I		=> pat_abort,
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
		
	DV_O		=> pat_dv,
	X_O			=> pat_x,
	Y_O			=> pat_y,
	MOVED_I		=> dac_done,
	
	SAMPLE_O	=> pat_sample,
	SAMPLED_I	=> video_sent,
	ROW_O		=> pat_row,
	COL_O		=> pat_col
);


transform : entity work.transform
port map (
	CLK_I		=> clk100,
	RST_I		=> reset,
	
	DV_I		=> pat_dv,
	X_I			=> pat_x,
	Y_I			=> pat_y,
	
	DV_O		=> trn_dv,
	X_O			=> trn_x,
	Y_O			=> trn_y,
	
	C00_I		=> reg(20),
	C01_I		=> reg(21),
	C02_I		=> reg(22),
	C10_I		=> reg(23),
	C11_I		=> reg(24),
	C12_I		=> reg(25)
);

dac : entity work.dac
generic map (
	CHANNELS	=> 2
)
port map (
	CLK_I		=> clk100,
	RST_I		=> reset,
	
	CLEAR_I		=> '0',
		
	DV_I		=> trn_dv & trn_dv,
	CH0_I		=> trn_x,
	CH1_I		=> trn_y,
	
	DV_RAW_I	=> dac_raw_dv,
	RAW_I		=> dac_raw,
	
	BUSY_O		=> open,
	DONE_O		=> dac_done,
	
	BUSY_I		=> spi_busy,
	SEND_O		=> spi_send,
	CMD_O		=> spi_data_tx,
	
	LOADn_O		=> DAC_nLOAD_O,
	CLEARn_O	=> DAC_nCLR_O	
);

spi : entity work.spi_master
generic map (
	SLAVES		=> 1,
	WIDTH		=> 24
)
port map (
	CLK_I		=> clk100,
	RST_I		=> reset,
	
	CLKDIV_I	=> x"01",
	CPOL		=> '0',
	CPHA		=> '1',
	
	SEND_I		=> spi_send,
	CONT_I		=> '0',
	BUSY_O		=> spi_busy,
	SLAVE_I		=> "0",
	
	TX_I		=> spi_data_tx,
	RX_O		=> open,
	
	CSn_O(0)	=> DAC_nCS_O,
	SCK_O		=> DAC_SCK_O,
	MISO_I		=> DAC_MISO_I,
	MOSI_O		=> DAC_MOSI_O	
);

--TODO: Averaging
-- (pat_sample triggers statemachine that generates multiple samples and averages them)

test : if TEST_IMAGE = TRUE generate

process(clk100)
begin
	if rising_edge(clk100) then
		if (pat_sample = '1') then
			adc_ch0 <= pat_col(7 downto 0) & pat_row(7 downto 0);
			adc_dv <= '1';
		else
			adc_dv <= '0';
		end if;
	end if;
end process;

end generate;

no_test : if TEST_IMAGE = FALSE generate

adc : entity work.adc
port map (
	CLK_I		=> clk100,
	RST_I		=> reset,
	
	SAMPLE_I	=> pat_sample,
	
	CONV_O		=> ADC_CNV_O,
	SCK_O		=> ADC_SCK_O,
	SD0_I		=> ADC_SD0_I,
	SD1_I		=> ADC_SD1_I,
	
	DV_O		=> adc_dv,
	CH0_O		=> adc_ch0,
	CH1_O		=> adc_ch1
);

end generate;

--TODO: Video Signal Processing (LUT?, Brightness/Contrast?)

video : entity work.video_tx
port map (
	CLK_I 		=> clk100,
	RST_I 		=> reset,
		
	CHANNEL_I	=> reg(0)(0),
	LOW_RES_I	=> reg(0)(1),
		
	DV_I		=> adc_dv & adc_dv,
	CH0_I 		=> adc_ch0,
	CH1_I 		=> adc_ch1,
		
	SENT_O		=> video_sent,
		
	PUT_CHAR_O	=> video_put_char,
	PUT_ACK_I	=> video_put_ack,
	TX_CHAR_O	=> video_tx_char,
	TX_FULL_I	=> video_tx_full
);

end rem_scan;

