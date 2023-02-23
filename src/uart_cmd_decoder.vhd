library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.util.all;

entity uart_cmd_decoder is
	generic (
		DATA_BITS		: integer	:= 8;
		MAX_ARGS		: integer	:= 10
	);
	port (
		CLK_I			: in	std_logic;
		RESET_I			: in	std_logic;
	
		-- Control Connections
		BUSY_O			: out	std_logic := '0';
		
		NEW_CMD_I		: in	std_logic := '0';
		CMD_ACK_O 		: out	std_logic := '0';
		CMD_NACK_O		: out	std_logic := '0';
		CMD_ID_I		: in	std_logic_vector(DATA_BITS-1 downto 0);
		CMD_ARGS_I		: in	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0);
		
		NEW_ACK_O		: out	std_logic := '0';
		NEW_NACK_O		: out	std_logic := '0';
		NEW_DONE_O		: out	std_logic := '0';
		
		NEW_REPLY_O		: out	std_logic := '0';
		REPLY_ACK_I		: in	std_logic := '0';
		REPLY_ID_O		: out	std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
		REPLY_ARGS_O	: out	std_logic_vector((MAX_ARGS*DATA_BITS)-1 downto 0) := (others => '0');
		REPLY_ARGN_O	: out	std_logic_vector(clogb2(MAX_ARGS) - 1 downto 0) := (others => '0');
	
		-- Internal Registers
		REG_WRITE_O		: out	std_logic := '0';
		REG_ADDR_O		: out	std_logic_vector( 7 downto 0) := (others => '0');
		REG_DATA_O		: out	std_logic_vector(15 downto 0) := (others => '0');
		REG_DATA_I		: in	std_logic_vector(15 downto 0) := (others => '0');

		-- Scan
		SCAN_START_O	: out	std_logic := '0';
		SCAN_ABORT_O	: out	std_logic := '0';
		SCAN_BUSY_I		: in	std_logic := '0';

		LIVE_O			: out	std_logic := '0'
	);
end uart_cmd_decoder;

architecture RTL of uart_cmd_decoder is

constant ARG_NR_WIDTH	: integer := clogb2(MAX_ARGS);

-- Command IDs

constant READ_REG		: character := 'R';
constant WRITE_REG		: character := 'W';
constant START_SCAN		: character := 'S';
constant ABORT_SCAN		: character := 'X';
constant START_LIVE		: character := 'L';

--------------------------------------------------------------------------------

constant id_reg_read	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(READ_REG);
constant id_reg_write	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(WRITE_REG);
constant id_scan_start	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(START_SCAN);
constant id_scan_abort	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(ABORT_SCAN);
constant id_live_start	: std_logic_vector(DATA_BITS-1 downto 0) := char2vec(START_LIVE);

-- Control Signals

type std_logic_bus is array(natural range <>) of std_logic_vector(DATA_BITS-1 downto 0);

type state_t is (
S_IDLE,
S_CMD,
S_WAIT_FOR_START,
S_WAIT_FOR_END,
S_REPLY,
S_WAIT_FOR_REPLY
);

signal state : state_t := S_IDLE;

signal cmd_id		: std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal cmd_args		: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));
signal rpl_args		: std_logic_bus(MAX_ARGS-1 downto 0) := (others => (others => '0'));

begin

args : for i in 0 to MAX_ARGS-1 generate
	REPLY_ARGS_O((8*(i+1)-1) downto (8*i)) <= rpl_args(i);
end generate;

control : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state 		 <= S_IDLE;
			cmd_id		 <= (others => '0');
			
			rpl_args	 <= (others => (others => '0'));
			REPLY_ID_O	 <= (others => '0');
		else
			CMD_ACK_O	 	<= '0';
			CMD_NACK_O		<= '0';
			
			NEW_ACK_O	 	<= '0';
			NEW_NACK_O	 	<= '0';
			NEW_DONE_O		<= '0';
			NEW_REPLY_O	 	<= '0';
		
			SCAN_START_O	<= '0';
			SCAN_ABORT_O	<= '0';
			REG_WRITE_O 	<= '0';
	
			case (state) is
			when S_IDLE =>
				BUSY_O 		<= '0';

				if (NEW_CMD_I = '1') then
					BUSY_O 		<= '1';
					CMD_ACK_O	<= '1';
					cmd_id		<= CMD_ID_I;
					
					args : for i in 0 to MAX_ARGS-1 loop
						cmd_args(i) <= 	CMD_ARGS_I((8*(i+1)-1) downto (8*i));
					end loop;

					if (SCAN_BUSY_I = '0' OR CMD_ID_I = id_scan_abort) then	-- Ignore Commands if Scan is running
						state <= S_CMD;
					else
						CMD_NACK_O <= '1';
						state <= S_IDLE;
					end if;
				end if;
				
			when S_CMD =>
				REPLY_ID_O <= cmd_id;
				
				state <= S_WAIT_FOR_START;
				
				case cmd_id is
				when id_reg_read =>
					REG_ADDR_O <= cmd_args(0);
					REG_WRITE_O <= '0';
				
				when id_reg_write =>
					REG_ADDR_O  <= cmd_args(0);
					REG_DATA_O  <= cmd_args(1) & cmd_args(2);
					REG_WRITE_O <= '1';
					
				when id_scan_start =>
					SCAN_START_O <= '1';
					
				when id_scan_abort =>
					SCAN_ABORT_O <= '1';				
					LIVE_O		 <= '0';
				
				when id_live_start =>
					LIVE_O <= '1';
		
				when others =>
					NULL;
				end case;
				
			when S_WAIT_FOR_START =>
				case cmd_id is
				
				when id_scan_start =>
					if (SCAN_BUSY_I = '1') then
						state <= S_WAIT_FOR_END;
					end if;		
		
				when others =>
					state <= S_WAIT_FOR_END;
				end case;
				
			when S_WAIT_FOR_END =>
				case cmd_id is

				--when id_scan_start =>
				-- Don't wait for Scan to end, send reply immediately

				when id_scan_abort =>
					if (SCAN_BUSY_I = '0') then
						state <= S_REPLY;
					end if;
				
				when others =>
					state <= S_REPLY;
				end case;
-------------------------------------------------------------------------------			
			when S_REPLY =>
				case cmd_id is

				when id_reg_read =>
					NEW_REPLY_O		<= '1';
					rpl_args(0) 	<= REG_DATA_I(15 downto 8);
					rpl_args(1) 	<= REG_DATA_I( 7 downto 0);
					REPLY_ARGN_O	<= int2vec(2, ARG_NR_WIDTH);
			 
				when id_reg_write		|
					  id_scan_abort		|
					  id_live_start		=>
					NEW_ACK_O	<= '1';				
									
				when id_scan_start =>
					NEW_DONE_O	<= '1';

				when others =>
					NEW_NACK_O	<= '1';
				end case;
				
				state <= S_WAIT_FOR_REPLY;
				
			when S_WAIT_FOR_REPLY =>
				if (REPLY_ACK_I = '1') then
					state <= S_IDLE;
				end if;
		
			end case;
		end if;
	end if;
end process;

end architecture;