library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED."+";
use IEEE.STD_LOGIC_UNSIGNED."-";
use IEEE.STD_LOGIC_UNSIGNED."<";
use IEEE.NUMERIC_STD.ALL;
use Work.util.all;

entity uart_decoder is
	generic (
		DATA_BITS		: integer := 8;
		MAX_ARGS			: integer := 10
	);
	port (
		RESET_I			: in	std_logic;
		CLK_I				: in	std_logic;		
		
		TX_BUSY_O		: out	std_logic := '0';
		RX_BUSY_O		: out	std_logic := '0';
		
	-- uart connections
		PUT_CHAR_O		: out	std_logic := '0';
		PUT_ACK_I		: in	std_logic;
		TX_CHAR_O		: out	std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		TX_FULL_I		: in	std_logic;
		
		GET_CHAR_O		: out	std_logic := '0';
		GET_ACK_I		: in	std_logic;
		RX_CHAR_I		: in	std_logic_vector(DATA_BITS-1 downto 0);
		RX_EMPTY_I		: in	std_logic;
		
	-- control connections
		NEW_CMD_O		: out	std_logic := '0';
		CMD_ACK_I 		: in	std_logic;
		CMD_ID_O			: out	std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		CMD_ARGS_O		: out	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0) := (others => '0');
		
		NEW_ACK_I		: in	std_logic;
		NEW_NACK_I		: in	std_logic;
		
		NEW_REPLY_I		: in 	std_logic;
		REPLY_ACK_O		: out	std_logic := '0';
		REPLY_ID_I		: in	std_logic_vector(DATA_BITS-1 downto 0);
		REPLY_ARGS_I	: in  std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0);
		REPLY_ARGN_I	: in  std_logic_vector(clogb2(MAX_ARGS)-1 downto 0)
	);
end uart_decoder;

architecture RTL of uart_decoder is

type std_logic_bus is array(natural range <>) of std_logic_vector(DATA_BITS-1 downto 0);

-- Protocol Chars

constant ESC			: character := character'val(27);
constant START			: character := '{';
constant STOP			: character := '}';
constant ACK			: character := '!';
constant NACK			: character := '?';

------------------------------------------------

constant esc_char		: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(ESC);
constant start_char	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(START);
constant stop_char	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(STOP);
constant ack_char		: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(ACK);
constant nack_char	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(NACK);

------------------------------------------------

type rx_state_t is (S_WAIT_FOR_CHAR, S_GET_CHAR);
signal rx_state : rx_state_t := S_WAIT_FOR_CHAR;

type p_state_t is (S_WAIT_FOR_START, S_CMD_ID, S_CMD_ARG, S_WAIT_FOR_STOP);
signal p_state : p_state_t := S_WAIT_FOR_START;

type h_state_t is (S_WAIT_FOR_CMD, S_WAIT_FOR_REPLY_ACK, S_WAIT_FOR_REPLY_FINISH);
signal h_state : h_state_t := S_WAIT_FOR_CMD;

type r_state_t is (S_WAIT_FOR_REPLY, S_SEND_ACK, S_SEND_ID, S_SEND_ARGS, S_SEND_STOP, S_SEND_END_ACK, S_WAIT_FOR_END_ACK);
signal r_state : r_state_t := S_WAIT_FOR_REPLY;

signal rx_char			: std_logic_vector(DATA_BITS-1 downto 0);
signal new_char		: std_logic := '0';
signal new_cmd			: std_logic := '0';
signal handler_busy	: std_logic := '0';
signal reply_sent		: std_logic	:= '0';

signal cmd_active		: std_logic := '0';

-- Command Signals
constant ARG_NR_WIDTH	: integer := clogb2(MAX_ARGS);

signal rx_id			: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal rx_args			: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));
signal rx_arg			: std_logic_vector(ARG_NR_WIDTH-1 downto 0) := (others => '0');

signal tx_id			: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal tx_args			: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));
signal tx_arg			: std_logic_vector(ARG_NR_WIDTH-1 downto 0) := (others => '0');
signal tx_arg_n		: std_logic_vector(ARG_NR_WIDTH-1 downto 0) := (others => '0');

-- ASCII to Hex Conversion Signals
signal rx_nib			: integer range 0 to 1	:= 0;	-- Nibble Count
signal tx_nib			: integer range 0 to 1	:= 0;	-- Nibble Count

signal ack_reply		: std_logic := '0';

begin

get_chars : process(CLK_I) -- Get Chars from UART RX FIFO
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			rx_char	 <= (others => '0');
			new_char <= '0';
			
			rx_state <= S_WAIT_FOR_CHAR;
		else
			-- Defaults
			GET_CHAR_O 	<= '0';
			new_char 	<= '0';
			
			case rx_state is
			when S_WAIT_FOR_CHAR =>
				if (RX_EMPTY_I = '0' AND handler_busy = '0') then
					GET_CHAR_O	<= '1';
					rx_state <= S_GET_CHAR;
				end if;
				
			when S_GET_CHAR =>
				if (GET_ACK_I = '1') then
					rx_char <= RX_CHAR_I;
					new_char <= '1';
					rx_state <= S_WAIT_FOR_CHAR;
				end if;
				
			end case;
		end if;
	end if;
end process get_chars;

parse : process(CLK_I)		-- Parse Chars into Command ID and Command ARGS
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			cmd_active	<= '0';
			p_state		<= S_WAIT_FOR_START;
			rx_arg 		<= (others => '0');
			rx_nib		<= 0;
		else
			-- Defaults
			new_cmd 	<= '0';
			
			if (new_char = '1' AND handler_busy = '0') then
				if (rx_char = esc_char) then
					cmd_active	<= '0';
					p_state		<= S_WAIT_FOR_START;
				elsif (rx_char = stop_char) then
					new_cmd		<= cmd_active;
					cmd_active	<= '0';
					p_state		<= S_WAIT_FOR_START;
				else
					case p_state is
					when S_WAIT_FOR_START =>
						if (rx_char = start_char) then
							cmd_active	<= '1';
							p_state 	<= S_CMD_ID;
						end if;
						
					when S_CMD_ID =>
						rx_id 	<= rx_char;
						rx_args	<= (others => (others => '0'));
						rx_arg	<= (others => '0');
						rx_nib	<= 1;
						
						p_state <= S_CMD_ARG;
						
					when S_CMD_ARG =>
						case rx_char(7 downto 4) is																																-- Convert 2 ASCII chars into one byte
						when "0011" 			=> rx_args(vec2int(rx_arg)) <= rx_args(vec2int(rx_arg))(3 downto 0) & rx_char(3 downto 0);				-- 0..9
						when "0100" | "0110" => rx_args(vec2int(rx_arg)) <= rx_args(vec2int(rx_arg))(3 downto 0) & (rx_char(3 downto 0) + x"9");	-- A..F | a..f
						when others 			=> rx_args(vec2int(rx_arg)) <= rx_args(vec2int(rx_arg))(3 downto 0) & b"0000";
						end case;
						
						if (rx_nib = 0) then		-- Hi Nibble
							rx_nib <= 1;
							
							if (vec2int(rx_arg) < MAX_ARGS) then
								rx_arg <= inc(rx_arg);
							else
								p_state <= S_WAIT_FOR_STOP;
							end if;
						else							-- Lo Nibble
							rx_nib <= 0;
						end if;
						
					when S_WAIT_FOR_STOP =>
						null;
						
					end case;
				end if;
			end if;
		end if;
	end if;
end process parse;

RX_BUSY_O	 <= handler_busy OR cmd_active OR new_cmd;

handle : process(CLK_I)		-- Output new Command and wait for reply
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			handler_busy	<= '0';
			CMD_ID_O		<= (others => '0');
			CMD_ARGS_O		<= (others => '0');
			NEW_CMD_O		<= '0';
			h_state			<= S_WAIT_FOR_CMD;
		else
			-- Defaults
			case h_state is
			when S_WAIT_FOR_CMD =>
				handler_busy <= '0';
				
				if (new_cmd = '1') then
					handler_busy 	<= '1';
					NEW_CMD_O		<= '1';
					CMD_ID_O		<= rx_id;
					
					args : for i in 0 to MAX_ARGS-1 loop
						CMD_ARGS_O((8*(i+1)-1) downto (8*i))	<= rx_args(i);
					end loop;
					
					h_state	<= S_WAIT_FOR_REPLY_ACK;
				end if;
				
			when S_WAIT_FOR_REPLY_ACK =>
				if (CMD_ACK_I = '1') then
					NEW_CMD_O	<= '0';
					h_state <= S_WAIT_FOR_REPLY_FINISH;
				end if;
				
			when S_WAIT_FOR_REPLY_FINISH =>
				if (reply_sent = '1') then
					h_state <= S_WAIT_FOR_CMD;
				end if;
			
			end case;
		end if;
	end if;
end process handle;

reply : process(CLK_I)		-- Take incoming reply and put chars into UART TX FIFO
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			reply_sent		<= '0';
			PUT_CHAR_O 		<= '0';
			r_state			<= S_WAIT_FOR_REPLY;
		else
			-- Defaults
			PUT_CHAR_O 		<= '0';
			REPLY_ACK_O		<= '0';
			reply_sent		<= '0';
			
			case r_state is
			when S_WAIT_FOR_REPLY =>
				TX_BUSY_O	<= '0';
				
				if (NEW_NACK_I = '1') then
					TX_BUSY_O 	<= '1';
					TX_CHAR_O	<= nack_char;
					PUT_CHAR_O	<= '1';
					r_state		<= S_SEND_ACK;
				
				elsif (NEW_REPLY_I = '1') then
					TX_BUSY_O 	<= '1';
					TX_CHAR_O 	<= start_char;
					PUT_CHAR_O	<= '1';
				
					tx_id		<= REPLY_ID_I;
					
					args_tx : for i in 0 to MAX_ARGS-1 loop
						tx_args(i)	<= REPLY_ARGS_I(((8*(i+1))-1) downto (8*i));
					end loop;
					
					tx_arg_n<= REPLY_ARGN_I;
					tx_arg	<= (others => '0');
					tx_nib	<= 1;
					r_state	<= S_SEND_ID;
					
					ack_reply <= NEW_ACK_I;
				
				elsif (NEW_ACK_I = '1') then
					TX_BUSY_O 	<= '1';
					TX_CHAR_O 	<= ack_char;
					PUT_CHAR_O	<= '1';
					r_state		<= S_SEND_ACK;
				end if;
					
			when S_SEND_ACK =>
				if (PUT_ACK_I = '1') then
					REPLY_ACK_O		<= '1';
					reply_sent		<= '1';
					r_state			<= S_WAIT_FOR_REPLY;
				end if;
					
			when S_SEND_ID =>
				if (PUT_ACK_I = '1') then
					TX_CHAR_O  <= tx_id;
					PUT_CHAR_O <= '1';
					r_state	  <= S_SEND_ARGS;
				end if;
				
			when S_SEND_ARGS =>
				if (tx_arg < tx_arg_n) then
					if (PUT_ACK_I = '1') then
						if (tx_nib = 1) then				-- Convert byte into two ASCII chars
							tx_nib <= 0;					-- Hi Nibble
							
							if tx_args(vec2int(tx_arg))(7 downto 4) < x"A" then							-- 0..9
								TX_CHAR_O <= "0011" & tx_args(vec2int(tx_arg))(7 downto 4);
							else																							-- A..F
								TX_CHAR_O <= "0100" & (tx_args(vec2int(tx_arg))(7 downto 4) - x"9");
							end if;
						else									-- Lo Nibble
							if tx_args(vec2int(tx_arg))(3 downto 0) < x"A" then							-- 0..9
								TX_CHAR_O <= "0011" & tx_args(vec2int(tx_arg))(3 downto 0);
							else																							-- A..F
								TX_CHAR_O <= "0100" & (tx_args(vec2int(tx_arg))(3 downto 0) - x"9");
							end if;
					
							tx_arg <= inc(tx_arg);
							tx_nib <= 1;
						end if;
						
						PUT_CHAR_O <= '1';
					end if;
				else
					r_state <= S_SEND_STOP;
				end if;
				
			when S_SEND_STOP =>
				if (PUT_ACK_I = '1') then
					TX_CHAR_O   <= stop_char;
					PUT_CHAR_O  <= '1';
					if (ack_reply = '1') then
						r_state <= S_SEND_END_ACK;
					else
						r_state <= S_WAIT_FOR_END_ACK;
					end if;
				end if;
				
			when S_SEND_END_ACK =>
				if (PUT_ACK_I = '1') then
					TX_CHAR_O 	<= ack_char;
					PUT_CHAR_O	<= '1';
					r_state		<= S_WAIT_FOR_END_ACK;
				end if;
				
			when S_WAIT_FOR_END_ACK =>
				if (PUT_ACK_I = '1') then
					REPLY_ACK_O	<= '1';
					reply_sent  <= '1';
					r_state		<= S_WAIT_FOR_REPLY;
				end if;
				
			end case;
		end if;
	end if;
end process reply;

end RTL;
