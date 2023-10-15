library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity toplevel is
	Generic (
		VERSION				: integer := 16#0204#;	-- v02.04
		BUILD				: integer := 3;
		SYS_CLK_FREQ		: real    := 100.0;
		UART_BAUDRATE		: integer := 921600;
		UART_FLOW_CTRL		: boolean := true;
		UART_CMD_BITS		: integer := 8;
		UART_CMD_MAX_ARGS	: integer := 4;
		NR_OF_REGS			: integer := 32;
		VGA_WIDTH			: integer := 800;
		VGA_HEIGHT			: integer := 600;
		SIMULATION			: boolean := false		
	);
	Port (
		CLK50_I		: in	STD_LOGIC;
		RST_I		: in	STD_LOGIC;
		
		CONTROL_O	: out	STD_LOGIC := '0';		-- Acquire Control over REM (active Low, but inverted by OpenDrain MOSFET)
		DCDC_EN_O	: out	STD_LOGIC := '1';

		BTN_I		: in	STD_LOGIC_VECTOR(1 downto 0);	-- Active low
		LED_O		: out	STD_LOGIC := '0';
		
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
		
		VGA_VSYNC_O	: out	STD_LOGIC := '0';
		VGA_HSYNC_O	: out	STD_LOGIC := '0';
		VGA_GRAY_O	: out	STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

		RAM_ADDR_O	: out	STD_LOGIC_VECTOR(18 downto 0) := (others => '0');
		RAM_DATA_IO : inout STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
		RAM_nOE_O	: out	STD_LOGIC := '1';
		RAM_nWE_O	: out	STD_LOGIC := '1';
		RAM_nCE_O	: out	STD_LOGIC := '1';
		
		FLASH_CS_O	: out	STD_LOGIC := '1';
		FLASH_SCK_O	: out	STD_LOGIC := '0';
		FLASH_DQ_IO	: inout	STD_LOGIC_VECTOR(3 downto 0) := (others => 'Z')

		;DBG_O		: out	STD_LOGIC_VECTOR(7 downto 0)
	);
end toplevel;

architecture rem_scan of toplevel is

signal clk100			: std_logic := '0';
signal rst100			: std_logic := '1';

--signal clk50			: std_logic := '0';
--signal rst50			: std_logic := '1';

signal clk_ready		: std_logic := '0';

-- UART		
signal uart_arb_nack	: std_logic;
signal uart_arb_ack		: std_logic;

signal uart_tx			: std_logic;

signal uart_tx_done		: std_logic;

signal uart_put			: std_logic;
signal uart_put_ack		: std_logic;
signal uart_put_char	: std_logic_vector(7 downto 0);
signal uart_put_full	: std_logic;
signal uart_put_empty	: std_logic;

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
signal uart_new_done	: std_logic;

signal uart_new_reply	: std_logic;
signal uart_reply_ack	: std_logic;
signal uart_reply_id	: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_reply_args	: std_logic_vector((UART_CMD_MAX_ARGS*UART_CMD_BITS)-1 downto 0);
signal uart_reply_argn	: std_logic_vector(clogb2(UART_CMD_MAX_ARGS)-1 downto 0);

-- CONTROL
--signal control_o		: std_logic;
signal live_enable		: std_logic;
signal live_mode		: std_logic;

signal scan_start		: std_logic;
signal scan_abort		: std_logic;
signal scan_busy		: std_logic;

signal mux_select		: std_logic;
signal mux_selected		: std_logic;

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
signal pat_pix			: std_logic_vector(31 downto 0);

signal pat_dv			: std_logic;
signal pat_x			: std_logic_vector(15 downto 0);
signal pat_y			: std_logic_vector(15 downto 0);

signal pat_steps_x		: std_logic_vector(15 downto 0);
signal pat_steps_y		: std_logic_vector(15 downto 0);

-- TRANSFORM
signal trn_dv			: std_logic;
signal trn_x			: std_logic_vector(15 downto 0);
signal trn_y			: std_logic_vector(15 downto 0);

-- DAC
signal dac_raw_dv		: std_logic;
signal dac_raw			: std_logic_vector(23 downto 0);
signal dac_done			: std_logic;

signal spi_send			: std_logic;
signal spi_busy			: std_logic;
signal spi_data_tx		: std_logic_vector(23 downto 0);

-- ADC
signal adc_conv			: std_logic;
signal adc_sck			: std_logic;

signal adc_ch_dv		: std_logic;
signal adc_ch0			: std_logic_vector(15 downto 0);
signal adc_ch1			: std_logic_vector(15 downto 0);

signal adc_sample		: std_logic;
signal adc_dv			: std_logic;
signal adc_data			: std_logic_vector(15 downto 0);

signal adc_avg_sample	: std_logic;
signal adc_avg_dv		: std_logic;
signal adc_avg_sent		: std_logic;
signal adc_avg_data		: std_logic_vector(15 downto 0);

signal adc_proc_dv		: std_logic;
signal adc_proc_data	: std_logic_vector(15 downto 0);

signal adc_dbg			: std_logic_vector(2 downto 0);

-- TESTIMG
signal tst_dv			: std_logic;
signal tst_sent			: std_logic;
signal tst_data			: std_logic_vector(15 downto 0);
signal tst_sample		: std_logic;

-- VIDEO
constant VID_ADDR_W		: integer := clogb2(VGA_HEIGHT*VGA_WIDTH);

signal vid_dv			: std_logic;
signal vid_data			: std_logic_vector(15 downto 0);
signal vid_sent			: std_logic;

signal uart_dv			: std_logic;
signal uart_data		: std_logic_vector(15 downto 0);
signal uart_sent		: std_logic;

signal live_dv			: std_logic;
signal live_addr		: std_logic_vector(VID_ADDR_W-1 downto 0);
signal live_data		: std_logic_vector(15 downto 0);
signal live_sent		: std_logic;

-- VGA
signal vga_read			: std_logic;
signal vga_addr			: std_logic_vector(VID_ADDR_W-1 downto 0);
signal vga_data			: std_logic_vector(7 downto 0);

-- SPI FLASH
signal flash_new_cmd	: std_logic := '0';
signal flash_cmd		: std_logic_vector( 7 downto 0);
signal flash_new_data_w	: std_logic := '0';
signal flash_data_w		: std_logic_vector(31 downto 0);
signal flash_new_data_r	: std_logic := '0';
signal flash_data_r		: std_logic_vector(31 downto 0);

signal flash_rtr		: std_logic := '0';
signal flash_rts		: std_logic := '0';
signal flash_busy		: std_logic := '0';

-- SRAM MUX
constant SRAM_WIDTH		: integer := 8;
constant SRAM_DEPTH		: integer := 19;

signal vid_ram_nwe		: std_logic := '0';
signal vid_ram_nce		: std_logic := '0';
signal vid_ram_noe		: std_logic := '0';
signal vid_ram_dir		: std_logic := '0';
signal vid_ram_addr		: std_logic_vector(SRAM_DEPTH-1 downto 0);
signal vid_ram_data_w	: std_logic_vector(SRAM_WIDTH-1 downto 0);
signal vid_ram_data_r	: std_logic_vector(SRAM_WIDTH-1 downto 0);

signal ini_ram_nwe		: std_logic := '0';
signal ini_ram_nce		: std_logic := '0';
signal ini_ram_noe		: std_logic := '0';
signal ini_ram_dir		: std_logic := '0';
signal ini_ram_addr		: std_logic_vector(SRAM_DEPTH-1 downto 0);
signal ini_ram_data_w	: std_logic_vector(SRAM_WIDTH-1 downto 0);
signal ini_ram_data_r	: std_logic_vector(SRAM_WIDTH-1 downto 0);

-- SRAM INIT
signal init				: std_logic := '0';
signal init_done		: std_logic := '0';

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
--	CLK1_O			=> clk50,
	
	LOCKED_O		=> clk_ready
);

rst100 <= RST_I;

DCDC_EN_O	<= NOT RST_I;

LED_O <= pat_busy;

UART_TX_O <= uart_tx;

uart : entity work.uart
generic map (
	CLK_MHZ			=> SYS_CLK_FREQ,
	BAUDRATE		=> UART_BAUDRATE,
	FLOW_CTRL		=> UART_FLOW_CTRL
)
port map (
	CLK_I			=> clk100,
	RST_I 			=> rst100,
	
	RX_I	 		=> UART_RX_I,
	TX_O 			=> uart_tx,	--UART_TX_O,
	
	CTS_I			=> UART_RTS_I,
	RTS_O			=> UART_CTS_O,
	
	TX_DONE_O		=> uart_tx_done,
	
	PUT_CHAR_I		=> uart_put,
	PUT_ACK_O		=> uart_put_ack,
	TX_CHAR_I		=> uart_put_char,
	TX_FULL_O		=> uart_put_full,
	TX_EMPTY_O		=> uart_put_empty,
	
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
	RST_I			=> rst100,

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
	TX_FULL_I		=> uart_put_full,
	TX_EMPTY_I		=> uart_put_empty
);

uart_decoder : entity work.uart_decoder
generic map (
	DATA_BITS 		=> UART_CMD_BITS,
	MAX_ARGS		=> UART_CMD_MAX_ARGS
)
port map (
	CLK_I			=> clk100,
	RST_I			=> rst100,
	
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
	NEW_DONE_I		=> uart_new_done,
	
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
	RESET_I			=> rst100,
	
	BUSY_O			=> cmd_busy,
	
	NEW_CMD_I		=> uart_new_cmd,
	CMD_ACK_O		=> uart_cmd_ack,
	CMD_NACK_O		=> uart_cmd_nack,
	CMD_ID_I		=> uart_cmd_id,
	CMD_ARGS_I		=> uart_cmd_args,
	
	NEW_ACK_O		=> uart_new_ack,
	NEW_NACK_O		=> uart_new_nack,
	NEW_DONE_O		=> uart_new_done,
	
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
	SCAN_BUSY_I		=> scan_busy AND mux_select,	-- Only really busy when streaming data over UART

	LIVE_O			=> live_enable,

	INIT_O			=> init
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
	RST_I			=> rst100,
	
	WRITE_I			=> reg_write,
	ADDR_I			=> reg_addr,
	DATA_O			=> reg_data_read,
	DATA_I			=> reg_data_write,
	
	REGISTER_O		=> reg
);

control : entity work.control
port map (
	CLK_I 			=> clk100,
	RST_I 			=> rst100,
	
	CONTROL_O		=> CONTROL_O,

	SCAN_START_I	=> scan_start,
	SCAN_ABORT_I	=> scan_abort,
	LIVE_I			=> live_enable,
	
	SCAN_BUSY_O		=> scan_busy,
	LIVE_O			=> live_mode,	
		
	MUX_SELECT_O	=> mux_select,
	MUX_SELECT_I	=> mux_selected,
	
	SCAN_START_O	=> pat_start,
	SCAN_ABORT_O	=> pat_abort,
	SCAN_BUSY_I		=> pat_busy,
	
	CTRL_DELAY_I	=> reg(16)
);

pat_mux : process(clk100)
begin
	if rising_edge(clk100)
	then
		if live_mode = '1' then
			pat_steps_x <= int2vec(VGA_WIDTH, 16);
			pat_steps_y <= int2vec(VGA_HEIGHT, 16);
		else
			pat_steps_x <= reg(8);
			pat_steps_y <= reg(9);
		end if;
	end if;
end process;

pattern : entity work.pattern 
port map (
	CLK_I 		=> clk100,
	RST_I 		=> rst100,
	
	START_I 	=> pat_start,
	ABORT_I		=> pat_abort,
	BUSY_O 		=> pat_busy,

	STEPS_X_I	=> pat_steps_x,
	STEPS_Y_I	=> pat_steps_y,
	DELTA_X_I	=> reg(10),
	DELTA_Y_I	=> reg(11),
	
	INI_DELAY_I	=> reg(17),
	COL_DELAY_I	=> reg(18),
	ROW_DELAY_I	=> reg(19),
		
	DV_O		=> pat_dv,
	X_O			=> pat_x,
	Y_O			=> pat_y,
	MOVED_I		=> dac_done,
	
	SAMPLE_O	=> pat_sample,
	SAMPLED_I	=> vid_sent,
	ROW_O		=> pat_row,
	COL_O		=> pat_col,
	PIX_O		=> pat_pix
);

transform : entity work.transform
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	DV_I		=> pat_dv,
	X_I			=> pat_x,
	Y_I			=> pat_y,
	
	DV_O		=> trn_dv,
	X_O			=> trn_x,
	Y_O			=> trn_y,
	
	CA_I		=> reg(20),
	CB_I		=> reg(21),
	CC_I		=> reg(22),
	CD_I		=> reg(23),
	CE_I		=> reg(24),
	CF_I		=> reg(25)
);

dac : entity work.dac
generic map (
	CHANNELS	=> 2
)
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
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
	RST_I		=> rst100,
	
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

testimg : entity work.testimg
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	SAMPLE_I	=> tst_sample,
	MODE_I		=> reg(1)(3 downto 0),

	ROW_I		=> pat_row,
	COL_I		=> pat_col,

	X_I			=> trn_x,
	Y_I			=> trn_y,

	DV_O		=> tst_dv,
	DATA_O		=> tst_data
);

adc : entity work.adc
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	SAMPLE_I	=> adc_sample,
	
	CONV_O		=> adc_conv,
	SCK_O		=> adc_sck,
	SD0_I		=> ADC_SD0_I,
	SD1_I		=> ADC_SD1_I,
	
	DV_O		=> adc_ch_dv,
	CH0_O		=> adc_ch0,
	CH1_O		=> adc_ch1

	,DBG_O		=> adc_dbg
);

ADC_CNV_O	<= adc_conv;
ADC_SCK_O	<= adc_sck;

adc_mux : entity work.adc_mux
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	CHANNEL_I	=> reg(0)(0),

	DV_O		=> adc_dv,
	DATA_O		=> adc_data,

	DV_I		=> adc_ch_dv,
	CH0_DATA_I	=> adc_ch0,
	CH1_DATA_I	=> adc_ch1
);

sig_proc : entity work.sig_proc
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	INVERT_I	=> reg(0)(4),
	SHIFT_I		=> reg(0)(5),
	SCALE_I		=> reg(0)(6),
	
	OFFSET_I	=> reg(4),
	FACTOR_I	=> reg(5)(7 downto 0),

	DV_O		=> adc_proc_dv,
	DATA_O		=> adc_proc_data,

	DV_I		=> adc_dv,
	DATA_I		=> adc_data
);

average : entity work.average
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	ENABLE_I	=> reg(0)(3),
	ABORT_I		=> pat_abort,

	NUMBER_I	=> reg(2)(7 downto 0),
	DELAY_I		=> reg(3),

	SAMPLE_I	=> adc_avg_sample,
	DV_O		=> adc_avg_dv,
	DATA_O		=> adc_avg_data,

	SAMPLE_O	=> adc_sample,
	DV_I		=> adc_proc_dv,
	DATA_I		=> adc_proc_data 
);

source_mux : entity work.source_mux
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	CHANNEL_I	=> reg(0)(2),

	SAMPLE_I	=> pat_sample,
	SENT_I		=> vid_sent,
	DV_O		=> vid_dv,
	DATA_O		=> vid_data,

	CH0_SAMPLE_O=> adc_avg_sample,
	CH0_SENT_O	=> adc_avg_sent,
	CH0_DV_I	=> adc_avg_dv,
	CH0_DATA_I	=> adc_avg_data,

	CH1_SAMPLE_O=> tst_sample,
	CH1_SENT_O	=> tst_sent,
	CH1_DV_I	=> tst_dv,
	CH1_DATA_I	=> tst_data
);

video_mux : entity work.video_mux
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	CHANNEL_I	=> live_mode,

	SENT_O		=> vid_sent,
	DV_I		=> vid_dv,
	DATA_I		=> vid_data,

	CH0_SENT_I	=> uart_sent,
	CH0_DV_O	=> uart_dv,
	CH0_DATA_O	=> uart_data,

	CH1_SENT_I	=> live_sent,
	CH1_DV_O	=> live_dv,
	CH1_DATA_O	=> live_data
);

live_addr <= pat_pix(VID_ADDR_W-1 downto 0);

video_ram : entity work.sram_arbiter
generic map (
	WIDTH	=> SRAM_WIDTH,
	DEPTH	=> SRAM_DEPTH
)
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	RAM_nWE_O	=> vid_ram_nwe,
	RAM_nCE_O	=> vid_ram_nce,
	RAM_nOE_O	=> vid_ram_noe,
	RAM_DIR_O	=> vid_ram_dir,
	RAM_ADDR_O	=> vid_ram_addr,
	RAM_DATA_O	=> vid_ram_data_w,
	RAM_DATA_I	=> vid_ram_data_r,

	A_WR_I		=> live_dv,
	A_ACK_O		=> live_sent,
	A_ADDR_I	=> live_addr,
	A_DATA_I	=> live_data(15 downto 8),

	B_RD_I		=> vga_read,
	B_ADDR_I	=> vga_addr,
	B_DATA_O	=> vga_data
);

ram_mux : entity work.ram_mux
generic map (
	WIDTH	=> SRAM_WIDTH,
	DEPTH	=> SRAM_DEPTH
)
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	CHANNEL_I	=> init_done,	-- CH 0 until initialisation is done
	
	RAM_nWE_O	=> RAM_nWE_O,
	RAM_nCE_O	=> RAM_nCE_O,
	RAM_nOE_O	=> RAM_nOE_O,
	RAM_ADDR_O	=> RAM_ADDR_O,
	RAM_DATA_IO => RAM_DATA_IO,
	
	CH0_nWE_I	=> ini_ram_nwe,
	CH0_nCE_I	=> ini_ram_nce,
	CH0_nOE_I	=> ini_ram_noe,
	CH0_DIR_I	=> ini_ram_dir,
	CH0_ADDR_I	=> ini_ram_addr,
	CH0_DATA_I	=> ini_ram_data_w,
	CH0_DATA_O	=> ini_ram_data_r,
	
	CH1_nWE_I	=> vid_ram_nwe,
	CH1_nCE_I	=> vid_ram_nce,
	CH1_nOE_I	=> vid_ram_noe,
	CH1_DIR_I	=> vid_ram_dir,
	CH1_ADDR_I	=> vid_ram_addr,
	CH1_DATA_I	=> vid_ram_data_w,
	CH1_DATA_O	=> vid_ram_data_r
);

init_ram : entity work.init_ram
generic map (
	WIDTH	=> SRAM_WIDTH,
	DEPTH	=> SRAM_DEPTH,
	ADDRESS => 2048*256,	-- Start at page 2048 (Offset = 524288)
	SIZE	=> switch(SIMULATION, 256, 800*600/4)
)
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,
	
	INIT_I		=> init,
	DONE_O		=> init_done,
	
	RAM_nWE_O	=> ini_ram_nwe,
	RAM_nCE_O	=> ini_ram_nce,
	RAM_nOE_O	=> ini_ram_noe,
	RAM_DIR_O	=> ini_ram_dir,
	RAM_ADDR_O	=> ini_ram_addr,
	RAM_DATA_O	=> ini_ram_data_w,
	RAM_DATA_I	=> ini_ram_data_r,
	
	FL_NEW_CMD_O	=> flash_new_cmd,
	FL_CMD_O		=> flash_cmd,
	FL_NEW_DATA_O	=> flash_new_data_w,
	FL_DATA_O		=> flash_data_w,
	
	FL_RTR_O		=> flash_rtr,
	FL_RTS_I		=> flash_rts,
	FL_BUSY_I		=> flash_busy,
	
	FL_NEW_DATA_I	=> flash_new_data_r,
	FL_DATA_I		=> flash_data_r
);

flash : entity work.flash_wrapper
generic map (
	CLK_MHZ			=> SYS_CLK_FREQ,
	SIMULATION		=> SIMULATION
)
port map (
	CLK_I			=> clk100,
	RESET_I			=> rst100,
	
	nCS_O			=> FLASH_CS_O,
	SCK_O			=> FLASH_SCK_O,
	DQ_IO			=> FLASH_DQ_IO,

	NEW_CMD_I		=> flash_new_cmd,
	CMD_I			=> flash_cmd,
	NEW_DATA_I		=> flash_new_data_w,
	DATA_I			=> flash_data_w,
	
	RTR_I			=> flash_rtr,
	RTS_O			=> flash_rts,
	BUSY_O			=> flash_busy,
	
	NEW_DATA_O		=> flash_new_data_r,
	DATA_O			=> flash_data_r
);

vga : entity work.vga
port map (
	CLK_I		=> clk100,
	RST_I		=> rst100,

	ENABLE_I	=> init_done,
	SCALE_I		=> reg(0)(9 downto 8),

	READ_O		=> vga_read,
	ADDR_O		=> vga_addr,
	DATA_I		=> vga_data,

	HSYNC_O		=> VGA_HSYNC_O,
	VSYNC_O		=> VGA_VSYNC_O,
	GRAY_O		=> VGA_GRAY_O
);

video : entity work.video_tx
port map (
	CLK_I 		=> clk100,
	RST_I 		=> rst100,
		
	LOW_RES_I	=> reg(0)(1),

	SENT_O		=> uart_sent,
	DV_I		=> uart_dv,
	DATA_I 		=> uart_data,
		
	PUT_CHAR_O	=> video_put_char,
	PUT_ACK_I	=> video_put_ack,
	TX_CHAR_O	=> video_tx_char,
	TX_FULL_I	=> video_tx_full
);

DBG_O <= (

	0	=> video_put_char,
	1	=> video_put_ack,
	2	=> video_tx_full,
	3	=> uart_put_empty,
	
	4	=> uart_tx,
	5	=> UART_RTS_I,
	6	=> mux_selected,
	7	=> pat_busy,
	
--	0	=> adc_sample,
--	1	=> adc_conv,
--	2	=> ADC_SD0_I,
--	3	=> ADC_SD1_I,
--	4	=> adc_dbg(0),
--	5	=> adc_dbg(1),
--	6	=> adc_dbg(2),
--	7	=> pat_busy,

--	0	=> live_mode,
--	1	=> live_dv,
--	2	=> live_sent,
--	3	=> vga_read,
--	4	=> vid_sent,
--	5	=> vid_dv,
--	6	=> pat_sample,
--	7	=> pat_start,

	others => '0'
);

end rem_scan;

