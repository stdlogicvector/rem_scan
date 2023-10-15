library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity uart is
	generic (
		CLK_MHZ		: real := 100.0;
		BAUDRATE	: integer := 921600;
		DATA_BITS	: integer range 6 to 9 := 8;-- 6, 7, 8, 9
		PARITY_BIT	: character := 'N';			-- N(one), O(dd), E(ven)
		STOP_BITS	: real := 1.0;				-- 1.0, 1.5, 2.0
		START_BIT	: std_logic := '0';
		FLOW_CTRL	: boolean := false
	);
	port (
		RST_I		: in	STD_LOGIC;
		CLK_I		: in	STD_LOGIC;	
		
		TX_O		: out	STD_LOGIC;
		RX_I		: in	STD_LOGIC := NOT START_BIT;
		
		CTS_I		: in	STD_LOGIC := '0';
		RTS_O		: out	STD_LOGIC := '0';
		
		TX_DONE_O 	: out 	STD_LOGIC := '0';
		
		PUT_CHAR_I	: in	STD_LOGIC;
		PUT_ACK_O	: out 	STD_LOGIC := '0';
		TX_CHAR_I	: in 	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0);
		TX_FULL_O	: out	STD_LOGIC := '0';
		TX_EMPTY_O	: out	STD_LOGIC := '0';
		
		GET_CHAR_I	: in	STD_LOGIC;
		GET_ACK_O	: out	STD_LOGIC := '0';
		RX_CHAR_O	: out	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		RX_EMPTY_O	: out	STD_LOGIC := '0'
	);
end uart;

architecture RTL of uart is

signal tx_char	: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
signal rx_char	: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');

signal tx_busy	: STD_LOGIC := '0';

signal send		: STD_LOGIC := '0';
signal recv		: STD_LOGIC := '0';

signal fifo_reset	: STD_LOGIC_VECTOR(5 downto 0) := "111110";

type in_state_t	is (S_IN_IDLE, S_IN_WAIT, S_IN_PUT);
signal in_state : in_state_t := S_IN_IDLE;

type tx_state_t	is (S_TX_IDLE, S_TX_READ, S_TX_PUT, S_TX_WAIT);
signal tx_state : tx_state_t := S_TX_IDLE;

type out_state_t	is (S_OUT_IDLE, S_OUT_READ, S_OUT_PUT);
signal out_state : out_state_t := S_OUT_IDLE;

type rx_state_t	is (S_RX_IDLE, S_RX_PUT, S_RX_WAIT);
signal rx_state : rx_state_t := S_RX_IDLE;

-- FIFO Signals

signal tx_fifo_write	: STD_LOGIC := '0';
signal tx_fifo_read		: STD_LOGIC := '0';
signal tx_fifo_full		: STD_LOGIC := '0';
signal tx_fifo_empty	: STD_LOGIC := '0';
signal tx_fifo_wrerr	: STD_LOGIC := '0';
signal tx_fifo_rderr	: STD_LOGIC := '0';
signal tx_fifo_wrack	: STD_LOGIC := '0';
signal tx_fifo_valid	: STD_LOGIC := '0';
signal tx_fifo_din		: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
signal tx_fifo_dout		: STD_LOGIC_VECTOR(9-1 downto 0) := (others => '0');

signal rx_fifo_write	: STD_LOGIC := '0';
signal rx_fifo_read		: STD_LOGIC := '0';
signal rx_fifo_full		: STD_LOGIC := '0';
signal rx_fifo_empty	: STD_LOGIC := '0';
signal rx_fifo_wrerr	: STD_LOGIC := '0';
signal rx_fifo_rderr	: STD_LOGIC := '0';
signal rx_fifo_wrack	: STD_LOGIC := '0';
signal rx_fifo_valid	: STD_LOGIC := '0';
signal rx_fifo_din		: STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
signal rx_fifo_dout		: STD_LOGIC_VECTOR(9-1 downto 0) := (others => '0');

begin

tx_fsm : entity work.uart_fast_tx
	GENERIC MAP (
		DIVIDER		=> integer(CLK_MHZ * 1000000.0 / real(BAUDRATE)),	-- 125MHz / 25MHz = 5
		DATA_BITS	=> DATA_BITS,
		PARITY_BIT	=> PARITY_BIT,
		STOP_BITS	=> STOP_BITS,
		START_BIT	=> START_BIT
	)
	PORT MAP (
		RST_I		=> RST_I,
		CLK_I		=> CLK_I,
		
		TX_O		=> TX_O,
		
		TX_CHAR_I	=> tx_char,
		SEND_I		=> send,
		BUSY_O		=> tx_busy
	);

-- RST must be held high for at least five WRCLK clock cycles,
-- and WREN must be low before RST becomes active high,
-- and WREN remains low during this reset cycle.

tx_fifo : entity work.charfifo_tx
port map (
	rst			=> fifo_reset(fifo_reset'high),
	clk			=> CLK_I,
	
	wr_en		=> tx_fifo_write,
	overflow	=> tx_fifo_wrerr,
	full 		=> tx_fifo_full,
	din 		=> zero_resize(tx_fifo_din, 9),
	
	rd_en		=> tx_fifo_read,
	underflow	=> tx_fifo_rderr, 	
	empty 		=> tx_fifo_empty,
	dout		=> tx_fifo_dout
);

tx_ack : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		tx_fifo_wrack <= NOT tx_fifo_wrerr AND NOT tx_fifo_full AND tx_fifo_write;
		tx_fifo_valid <= NOT tx_fifo_rderr AND NOT tx_fifo_empty AND tx_fifo_read;
	end if;
end process;

TX_FULL_O	<= tx_fifo_full;
TX_EMPTY_O	<= tx_fifo_empty;
	
input : process(CLK_I)		-- Put chars into TX FIFO
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			in_state 		<= S_IN_IDLE;
			tx_fifo_write	<= '0';
			tx_fifo_din 	<= (others => '0');
			fifo_reset		<= "111110";
		else
			PUT_ACK_O <= '0';
			
			if (fifo_reset(fifo_reset'high) = '1') then
				fifo_reset(fifo_reset'high downto 1) <= fifo_reset(fifo_reset'high-1 downto 0);
			end if; 
			
			case in_state is
			when S_IN_IDLE =>
				if (PUT_CHAR_I = '1') then
					tx_fifo_din		<= TX_CHAR_I;
					
					if (tx_fifo_full = '0') then
						tx_fifo_write	<= '1';
						in_state 		<= S_IN_PUT;
					else
						in_state		<= S_IN_WAIT;
					end if;
				end if;
				
			when S_IN_WAIT =>
				if (tx_fifo_full = '0') then
					tx_fifo_write	<= '1';
					in_state 		<= S_IN_PUT;
				end if;
				
			when S_IN_PUT =>
				if (tx_fifo_wrack = '1') then
					tx_fifo_write	<= '0';
					PUT_ACK_O 		<= '1';
					in_state 		<= S_IN_IDLE;
				end if;
				
			end case;
		end if;
	end if;
end process input;	
	
transmit : process(CLK_I)		-- Transmit chars TX FIFO
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			tx_state 		<= S_TX_IDLE;
			tx_char			<= (others => '0');
			tx_fifo_read 	<= '0';
			send 			<= '0';
		else
			TX_DONE_O <= '0'; 
		
			case tx_state is
			when S_TX_IDLE =>
				if (CTS_I = '0' OR FLOW_CTRL = FALSE) then	-- CTS is active LOW
					if (tx_fifo_empty = '0') then			-- FIFO not empty -> send chars
						tx_fifo_read	<= '1';
						tx_state 		<= S_TX_READ;
					end if;
				end if;
				
			when S_TX_READ =>
				if (tx_fifo_valid = '1') then
					tx_fifo_read 	<= '0';
					tx_char 		<= tx_fifo_dout(DATA_BITS-1 downto 0);
					send 			<= '1';
					tx_state 		<= S_TX_PUT;
				end if;
				
			when S_TX_PUT =>
				if (tx_busy = '1') then
					send 		<= '0';
					tx_state 	<= S_TX_WAIT;
				end if;
			
			when S_TX_WAIT =>
				if (tx_busy = '0') then
					tx_state <= S_TX_IDLE;
					
					if (tx_fifo_empty = '1') then		-- This was the eol char
						TX_DONE_O <= '1';
					end if;
					
				end if;
			end case;
		end if;
	end if;
end process transmit;
	
rx_fsm : entity work.uart_fast_rx
	GENERIC MAP (
		DIVIDER		=> integer(CLK_MHZ * 1000000.0 / real(BAUDRATE)),
		DATA_BITS	=> DATA_BITS,
		PARITY_BIT	=> PARITY_BIT,
		STOP_BITS	=> STOP_BITS,
		START_BIT	=> START_BIT
	)
	PORT MAP (
		RST_I		=> RST_I,
		CLK_I		=> CLK_I,
		
		RX_I		=> RX_I,
		
		RX_CHAR_O	=> rx_char,
		RECV_O		=> recv
	);

-- RST must be held high for at least five WRCLK clock cycles,
-- and WREN must be low before RST becomes active high,
-- and WREN remains low during this reset cycle.

rx_fifo : entity work.charfifo_rx
port map (
	rst			=> fifo_reset(fifo_reset'high),
	clk			=> CLK_I,
	
	wr_en		=> rx_fifo_write,
	overflow	=> rx_fifo_wrerr,
	full 		=> rx_fifo_full,
	din 		=> zero_resize(rx_fifo_din, 9),
	
	rd_en		=> rx_fifo_read,
	underflow	=> rx_fifo_rderr, 	
	empty 		=> rx_fifo_empty,
	dout		=> rx_fifo_dout
);

rx_ack : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		rx_fifo_wrack <= NOT rx_fifo_wrerr AND NOT rx_fifo_full AND rx_fifo_write;
		rx_fifo_valid <= NOT rx_fifo_rderr AND NOT rx_fifo_empty AND rx_fifo_read;
	end if;
end process;

RX_EMPTY_O <= rx_fifo_empty;		
	
output : process(CLK_I)		-- Take chars from RX FIFO
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			out_state 		<= S_OUT_IDLE;
			rx_fifo_read 	<= '0';
			RX_CHAR_O 		<= (others => '0');
		else
			GET_ACK_O <= '0';
			
			case out_state is
			when S_OUT_IDLE =>
				if (GET_CHAR_I = '1' and rx_fifo_empty = '0') then
					rx_fifo_read 	<= '1';
					out_state 		<= S_OUT_READ;
				end if;
				
			when S_OUT_READ =>
				if (rx_fifo_valid = '1') then
					rx_fifo_read 	<= '0';
					RX_CHAR_O 		<= rx_fifo_dout(DATA_BITS-1 downto 0);
					out_state 		<= S_OUT_PUT;
				end if;
				
			when S_OUT_PUT =>
				GET_ACK_O 	<= '1';
				out_state	<= S_OUT_IDLE;
				
			end case;
		end if;
	end if;
end process output;	

receive : process(CLK_I)	-- Put chars into RX FIFO
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			RTS_O 			<= '1';
			rx_state		<= S_RX_IDLE;
			rx_fifo_din 	<= (others => '0');
			rx_fifo_write	<= '0';
		else
			if (FLOW_CTRL = TRUE) then
				RTS_O <= rx_fifo_full;
			else
				RTS_O <= '0';
			end if;
		
			case rx_state is
			when S_RX_IDLE =>
				if (recv = '1' AND rx_fifo_full = '0') then	-- New char received and FIFO not full
					rx_fifo_write	<= '1';
					rx_fifo_din		<= rx_char;
					rx_state		<= S_RX_PUT;
				end if;
		
			when S_RX_PUT =>
				if (rx_fifo_wrack = '1') then
					rx_fifo_write	<= '0';
					rx_state		<= S_RX_WAIT;
				end if;
				
			when S_RX_WAIT =>
				if (recv = '0') then
					rx_state <= S_RX_IDLE;
				end if;
				
			end case;
		end if;
	end if;
end process receive;

end RTL;
