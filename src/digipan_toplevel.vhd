library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VComponents.all;
use WORK.util.all;

entity toplevel is
Generic (
	VERSION				: integer := 16#0100#;
	BUILD				: integer := 16#0001#;
	CLOCK_FREQ			: integer := 120000000;
	BAUDRATE			: integer :=   8000000;
	UART_CMD_BITS		: integer := 8;
	UART_CMD_MAXARGS	: integer := 4;
	NR_OF_REGS			: integer := 8
);
Port (
	CLK50M_I	: in 	STD_LOGIC;
	
	RS422_R_I 	: in	STD_LOGIC;
	RS422_D_O 	: out	STD_LOGIC := '0';
	RS422_RE_O 	: out	STD_LOGIC := '0';
	RS422_DE_O 	: out	STD_LOGIC := '0';
	
	UART_TX_O 	: out	STD_LOGIC := '1';
	UART_RX_I 	: in	STD_LOGIC;
	UART_RTS_I	: in	STD_LOGIC;
	UART_CTS_O	: out	STD_LOGIC := '0';
	UART_DTR_I	: in	STD_LOGIC;
	UART_DSR_O	: out	STD_LOGIC := '0';
	UART_DCD_O	: out	STD_LOGIC := '0';
	UART_RI_O	: out	STD_LOGIC := '0';
	
--	flash_cs	: out	STD_LOGIC := '1';
----	flash_sck	: out	STD_LOGIC := '0';
--	flash_dq	: inout	STD_LOGIC_VECTOR(3 downto 0) := (others => 'Z');
	
	PSRAM_SIO	: inout STD_LOGIC_VECTOR(3 downto 0);
	PSRAM_SCK_O	: out	STD_LOGIC := '0';
	PSRAM_nCE_O	: out	STD_LOGIC := '1';
	
	DCDC_EN_O	: out	STD_LOGIC := '0';
	
	LED_R_O		: out	STD_LOGIC := '0';
	LED_G_O		: out	STD_LOGIC := '0'
);
end toplevel;

architecture Behavioral of toplevel is

type state_t is
(
	S_IDLE,
	S_GET,
	S_PUT_H,
	S_WAIT_H,
	S_PUT_L,
	S_WAIT_L
);

signal state				: state_t := S_IDLE;

signal clock				: std_logic;
signal reset				: std_logic;
signal locked				: std_logic;

signal led_g				: std_logic := '0';
signal led_counter			: integer range 0 to 60000000 := 0;

signal in_frame				: std_logic := '0';

-- SENS UART		
signal sens_uart_get		: std_logic := '0';
signal sens_uart_get_ack	: std_logic := '0';
signal sens_uart_get_char	: std_logic_vector(12 downto 0) := (others => '0');
signal sens_uart_get_empty	: std_logic := '0';
signal sens_uart_put_full	: std_logic := '0';

-- CTRL UART		
signal ctrl_uart_put		: std_logic := '0';
signal ctrl_uart_put_ack	: std_logic := '0';
signal ctrl_uart_put_char	: std_logic_vector(7 downto 0) := (others => '0');
signal ctrl_uart_put_full	: std_logic := '0';

signal ctrl_uart_get		: std_logic := '0';
signal ctrl_uart_get_ack	: std_logic := '0';
signal ctrl_uart_get_char	: std_logic_vector(7 downto 0) := (others => '0');
signal ctrl_uart_get_empty	: std_logic := '0';

-- UART Mux
signal ctrl_put				: std_logic_vector(1 downto 0) := "00";
signal ctrl_put_char		: array8_t(1 downto 0) := (others => (others => '0'));

-- CMD Decoder
signal uart_new_cmd			: std_logic;
signal uart_cmd_ack			: std_logic;
signal uart_cmd_id			: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_cmd_args		: std_logic_vector((UART_CMD_MAXARGS*UART_CMD_BITS)-1 downto 0);

signal uart_new_ack			: std_logic;
signal uart_new_nack		: std_logic;

signal uart_new_reply		: std_logic;
signal uart_reply_ack		: std_logic;
signal uart_reply_id		: std_logic_vector(UART_CMD_BITS-1 downto 0);
signal uart_reply_args		: std_logic_vector((UART_CMD_MAXARGS*UART_CMD_BITS)-1 downto 0);
signal uart_reply_argn		: std_logic_vector(clogb2(UART_CMD_MAXARGS)-1 downto 0);

-- Internal Registers
signal reg_write			: std_logic := '0';
signal reg_addr				: std_logic_vector( 7 downto 0) := (others => '0');
signal reg_data_read		: std_logic_vector(15 downto 0) := (others => '0');
signal reg_data_write		: std_logic_vector(15 downto 0) := (others => '0');
signal reg_enable			: std_logic := '1';

signal reg					: array16_t(0 to NR_OF_REGS-1) := (others => (others => '0'));

-- SPI FLASH
signal flash_new_cmd		: std_logic := '0';
signal flash_cmd			: std_logic_vector( 7 downto 0);
signal flash_new_data_w		: std_logic := '0';
signal flash_data_w			: std_logic_vector(31 downto 0);
signal flash_new_data_r		: std_logic := '0';
signal flash_data_r			: std_logic_vector(31 downto 0);

signal flash_rtr			: std_logic := '0';
signal flash_rts			: std_logic := '0';
signal flash_busy			: std_logic := '0';

signal debug				: std_logic_vector(4 downto 0);

begin

-- DEBUG
PSRAM_nCE_O <= debug(0);
PSRAM_SIO(0)<= debug(1);
PSRAM_SIO(2)<= debug(2);
PSRAM_SIO(3)<= debug(3);
PSRAM_SCK_O	<= debug(4);

--PSRAM_SIO(0)<= uart_new_cmd;
--PSRAM_SIO(1)<= uart_cmd_ack;
--PSRAM_SIO(2)<= uart_new_reply;
--PSRAM_SIO(3)<= uart_reply_ack;

clkgen : entity work.clockgen
port map (
	CLK50M_I	=> CLK50M_I,
	RESET_I		=> '0',
	LOCKED_O	=> locked,
	CLK120M_O	=> clock
);

reset <= NOT locked;

ctrl_uart : entity work.uart
generic map (
	FASTMODE	=> TRUE,
	CLOCKRATE	=> CLOCK_FREQ,
	BAUDRATE	=> BAUDRATE,
--	FIFO_DEPTH	=> 1024,
	DATA_BITS	=> 8,
	STOP_BITS	=> 1.0,
	FLOW_CTRL	=> true
)
port map (
	CLK_I		=> clock,
	RESET_I		=> reset,
	
	TX_O		=> UART_TX_O,
	RX_I		=> UART_RX_I,
	
	CTS_I		=> UART_RTS_I,
	RTS_O		=> UART_CTS_O,
	
	PUT_CHAR_I	=> ctrl_uart_put,
	PUT_ACK_O	=> ctrl_uart_put_ack,
	TX_CHAR_I	=> ctrl_uart_put_char,
	TX_FULL_O	=> ctrl_uart_put_full,
	
	GET_CHAR_I	=> ctrl_uart_get,
	GET_ACK_O	=> ctrl_uart_get_ack,
	RX_CHAR_O	=> ctrl_uart_get_char,
	RX_EMPTY_O	=> ctrl_uart_get_empty
);

sens_uart : entity work.uart
generic map (
	FASTMODE	=> TRUE,
	CLOCKRATE	=> CLOCK_FREQ,
	BAUDRATE	=> 8000000,
	START_BIT	=> '1', -- TODO: Correctly attach A-Blue, B-White
	DATA_BITS	=> 13,
	STOP_BITS	=> 0.0,
	TX			=> false
)
port map (
	CLK_I		=> clock,
	RESET_I		=> reset,
	
	TX_O		=> RS422_D_O,
	RX_I		=> RS422_R_I,
	
	GET_CHAR_I	=> sens_uart_get,
	GET_ACK_O	=> sens_uart_get_ack,
	RX_CHAR_O	=> sens_uart_get_char,
	RX_EMPTY_O	=> sens_uart_get_empty,
	RX_FULL_O	=> sens_uart_put_full
);

-- RX Only
RS422_RE_O	<= '0';	-- Active LOW
RS422_DE_O	<= '0';

uart_decoder : entity work.uart_decoder
generic map (
	DATA_BITS	=> UART_CMD_BITS,
	MAX_ARGS	=> UART_CMD_MAXARGS
)
port map (
	CLK_I			=> clock,
	RESET_I			=> reset,
	
	PUT_CHAR_O		=> ctrl_put(0),
	PUT_ACK_I		=> ctrl_uart_put_ack,
	TX_CHAR_O		=> ctrl_put_char(0),
	TX_FULL_I		=> ctrl_uart_put_full,
	
	GET_CHAR_O		=> ctrl_uart_get,
	GET_ACK_I		=> ctrl_uart_get_ack,
	RX_CHAR_I		=> ctrl_uart_get_char,
	RX_EMPTY_I		=> ctrl_uart_get_empty,
	
	NEW_CMD_O		=> uart_new_cmd,
	CMD_ACK_I		=> uart_cmd_ack,
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
	MAX_ARGS		=> UART_CMD_MAXARGS,
	DEBUG_REGS		=> 2
)
port map (
	CLK_I			=> clock,
	RESET_I			=> reset,
	
	NEW_CMD_I		=> uart_new_cmd,
	CMD_ACK_O		=> uart_cmd_ack,
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
	
	FL_NEW_CMD_O	=> flash_new_cmd,
	FL_CMD_O		=> flash_cmd,
	FL_NEW_DATA_O	=> flash_new_data_w,
	FL_DATA_O		=> flash_data_w,
	
	FL_RTR_O		=> flash_rtr,
	FL_RTS_I		=> flash_rts,
	FL_BUSY_I		=> flash_busy,
	
	FL_NEW_DATA_I	=> flash_new_data_r,
	FL_DATA_I		=> flash_data_r,
	
	DEBUG_I(0)		=> x"DEAD",
	DEBUG_I(1)		=> x"BEEF"
);

registers : entity work.register_file
generic map (
	NR_OF_REGS		=> NR_OF_REGS,
	CLOCK_MHZ		=> real(CLOCK_FREQ) / 1000000.0,
	VERSION			=> VERSION,
	BUILD			=> BUILD
)
port map (
	CLK_I			=> clock,
	RESET_I			=> reset,
	
	WRITE_I			=> reg_write,
	ADDR_I			=> reg_addr,
	DATA_O			=> reg_data_read,
	DATA_I			=> reg_data_write,
	
	REGISTERS_O		=> reg
);

DCDC_EN_O	<= reg(0)(0);
LED_G_O		<= NOT reg(0)(0);

debug(0)	<= RS422_R_I;
debug(1)	<= ctrl_uart_put_full;
debug(2)	<= sens_uart_get_empty;
debug(3)	<= sens_uart_put_full;
debug(4)	<= UART_RTS_I;

translate: process (clock)
begin
	if rising_edge(clock) then
		if (reset = '1') then
			state <= S_IDLE;
		else
			sens_uart_get <= '0';
			ctrl_put(1) <= '0';
			
			case (state) is
			when S_IDLE =>
				if ((NOT sens_uart_get_empty) AND
					(NOT ctrl_uart_put_full)) = '1'
				then
					sens_uart_get <= '1';
					state <= S_GET;
				end if;
				
			when S_GET =>
				if (sens_uart_get_ack = '1') then
					ctrl_put_char(1) 	<= "000" & bit_reverse(sens_uart_get_char)(12 downto 8);
					
					state <= S_PUT_H;
				end if;
		
			when S_PUT_H =>
				ctrl_put(1) 	<= '1';
				state <= S_WAIT_H;
				
			when S_WAIT_H =>
				if (ctrl_uart_put_ack = '1' OR reg(1)(0) = '0') then
					ctrl_put_char(1) 	<= bit_reverse(sens_uart_get_char)(7 downto 0);
					
					state <= S_PUT_L;
				end if;
				
			when S_PUT_L =>
				ctrl_put(1) 	<= '1';
				state <= S_WAIT_L;				
			
			when S_WAIT_L =>
				if (ctrl_uart_put_ack = '1' OR reg(1)(0) = '0') then
					state <= S_IDLE;
				end if;
			
			end case;
			
		end if;
	end if;
end process;

mux : process(clock)
begin
	if rising_edge(clock) then
		ctrl_uart_put	   <= ctrl_put(0) OR (ctrl_put(1) AND reg(1)(0));
	
		if ctrl_put(0) = '1' then
			ctrl_uart_put_char <= ctrl_put_char(0);
		elsif (ctrl_put(1) AND reg(1)(0)) = '1' then
			ctrl_uart_put_char <= ctrl_put_char(1);
		end if;

	end if;
end process;

LED_R_O <= sens_uart_get_empty;

end Behavioral;
