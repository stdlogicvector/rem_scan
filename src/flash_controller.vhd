library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity flash_controller is
	Generic (
		CLK_MHZ		: real := 100.0;
		SIMULATION	: boolean := false
	);
	Port (
		CLK_I		: in	std_logic;
		RESET_I		: in	std_logic;
		
		nCS_O		: out	std_logic := '1';
		SCK_O		: out	std_logic := '0';
		DQ_I		: in	std_logic;
		DQ_O		: out	std_logic;
		DIR_O		: out	std_logic := '0';
		
		NEW_CMD_I	: in	std_logic;
		CMD_I		: in	std_logic_vector( 7 downto 0);
		NEW_DATA_I	: in  	std_logic;
		DATA_I		: in	std_logic_vector(31 downto 0);
		
		RTR_I		: in	std_logic := '0';		-- Control is Ready to Receive
		RTS_O		: out	std_logic := '0';		-- Flash is Ready to Send
		BUSY_O		: out	std_logic := '0';
		
		NEW_DATA_O	: out	std_logic := '0';
		DATA_O		: out	std_logic_vector(31 downto 0) := (others => '0')
	);
end flash_controller;

architecture RTL of flash_controller is

-- FLASH OpCodes
constant NOP	: std_logic_vector (7 downto 0) := x"FF";	-- no command to execute

constant ID		: std_logic_vector (7 downto 0) := x"9F";	-- read ID

constant WREN	: std_logic_vector (7 downto 0) := x"06";	-- write enable
constant WRDI	: std_logic_vector (7 downto 0) := x"04";	-- write disable

constant RDSR1	: std_logic_vector (7 downto 0) := x"05";	-- read status reg1
constant RDSR2	: std_logic_vector (7 downto 0) := x"07";	-- read status reg2
constant RDCR	: std_logic_vector (7 downto 0) := x"35";	-- read config reg
constant WRSR	: std_logic_vector (7 downto 0) := x"01";	-- write stat. reg
constant RES	: std_logic_vector (7 downto 0) := x"AB";	-- Read signature

constant RD		: std_logic_vector (7 downto 0) := x"03";	-- read
constant PP		: std_logic_vector (7 downto 0) := x"02";	-- page program
constant SE		: std_logic_vector (7 downto 0) := x"D8";	-- sector erase
constant BE		: std_logic_vector (7 downto 0) := x"C7";	-- bulk erase

constant ADDR	: std_logic_vector (7 downto 0) := x"AD";	-- internal command to set address
constant PKTS	: std_logic_vector (7 downto 0) := x"DC";	-- internal command to set byte count

-- SPI
constant SPI_FREQ	: real := 25.0000;  -- MHz
constant DIV_COUNT	: integer := integer(round(CLK_MHZ / (SPI_FREQ * 2.0)))-1;
signal clk_cnt		: integer range 0 to DIV_COUNT;
signal spi_clk		: std_logic := '1';
signal clk_falling	: std_logic := '0';
signal clk_rising 	: std_logic := '0';
 
signal tx_reg		: std_logic_vector(31 downto 0) := (others => '1');
signal rx_reg		: std_logic_vector(31 downto 0) := (others => '1');
signal tx_cnt		: std_logic_vector( 4 downto 0) := (others => '0');
signal rx_cnt		: std_logic_vector( 4 downto 0) := (others => '0');

signal tx_start   	: std_logic := '0';
signal rx_start		: std_logic := '0';

signal tx_sreg		: std_logic_vector(31 downto 0) := (others => '1');
signal rx_sreg		: std_logic_vector(31 downto 0) := (others => '1');
signal tx_scnt		: std_logic_vector( 4 downto 0) := (others => '0');
signal rx_scnt		: std_logic_vector( 4 downto 0) := (others => '0');

signal tx_finish  	: std_logic := '0';
signal rx_finish  	: std_logic := '0';

type state_t is
(
	PAUSE,
	IDLE, SYNC, FINISH,
	TX_CMD,		TX_CMD_WAIT,
	TX_ADDR,	TX_ADDR_WAIT,
	TX_DATA,	TX_WAIT, WAIT_FOR_TX_DATA,
--	TX_DUMMY,	TX_DUMMY_WAIT,
	RX_DATA,	RX_WAIT, WAIT_FOR_RX_DATA
);

signal state : state_t := PAUSE;

constant MAX_DELAY	: integer := switch(SIMULATION, 2**5-1, 2**15-1);	-- 2**15 = Approx 300us Delay at 100MHz
signal delay		: integer range 0 to MAX_DELAY := 0;	

type tstate_t is
(
	IDLE, TRANSFER, WAIT1
);

signal tx_state, rx_state : tstate_t := IDLE;

signal command		: std_logic_vector( 7 downto 0) := NOP;
signal address 		: std_logic_vector(23 downto 0) := (others => '0');
signal pkt_cnt		: std_logic_vector(23 downto 0) := (others => '0');
signal pkt_scnt		: std_logic_vector(23 downto 0) := (others => '0');

signal ack  : std_logic := '0';

signal sclk_reset	: STD_LOGIC_VECTOR(5 downto 0) := "111110";

begin

BUSY_O 	<= '1' when (state /= IDLE) else NEW_CMD_I;
DIR_O 	<= '1' when (tx_state /= IDLE) else '0';
DQ_O	<= tx_sreg(31);

fsm : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			state 	<= PAUSE;		-- Wait for Flash to become ready
			nCS_O	<= '1';
		else
			NEW_DATA_O		<= '0';
			RTS_O			<= '0';
			tx_start		<= '0';
			rx_start		<= '0';
			
			case (state) is
			when PAUSE =>
				nCS_O	<= '1';
				
				if delay = MAX_DELAY then
					state <= IDLE;
				else
					delay <= delay + 1;
				end if;
			
			when IDLE =>
				nCS_O	<= '1';
				
				if (NEW_CMD_I = '1') then
					case (CMD_I) is
					when ADDR =>
						address <= DATA_I(23 downto 0);
						state	<= SYNC;
					when PKTS =>
						pkt_cnt <= DATA_I(23 downto 0);
						state	<= SYNC;
					when others =>
						command	<= CMD_I;
						state	<= TX_CMD;
--						nCS_O	<= '0';
					end case;
				end if;
				
			when TX_CMD =>
				nCS_O		<= '0';
				
				pkt_scnt	<= pkt_cnt;	
				tx_reg		<= command & x"FFFFFF";			-- 8bit Command + 3 Dummybytes
				tx_cnt		<= int2vec(8-1, 5);
				tx_start	<= '1';
				state		<= TX_CMD_WAIT;
								
			when TX_CMD_WAIT =>

				if (tx_finish = '1') then
					case (command) is
					when WREN	|
						 WRDI	|
						 BE		=> state <= FINISH;		-- One Byte Commands
					when ID 	|
						 RDSR1	|
						 RDSR2	|
						 RDCR 	=> state <= RX_DATA;	-- Read Data after Command
					when WRSR 	=> state <= TX_DATA;	-- Write Data after Command
					when SE 	|
						 PP 	|
						 RES	|
						 RD		=> state <= TX_ADDR;	-- Write Address after Command
					when others => state <= FINISH;
					end case;
				end if;
				
			when TX_ADDR =>
				tx_reg		<= address & x"FF";				-- 24bit Address + Dummybyte
				tx_start	<= '1';
				tx_cnt		<= int2vec(24-1, 5);
				state 		<= TX_ADDR_WAIT;
								
			when TX_ADDR_WAIT =>
				if (tx_finish = '1') then
					case (command) is
					when RES	=> state <= RX_DATA;
					when PP 	=> RTS_O <= '1'; state <= WAIT_FOR_TX_DATA;
					when RD		=> state <= RX_DATA;
					when others => state <= FINISH;
					end case;
				end if;
			
--			when TX_DUMMY =>
--				tx_reg 		<= (others => '1');
--				tx_cnt 		<= int2vec(10-1, 4);	-- 10 Dummy Cycles
--				tx_start	<= '1';
--				state		<= TX_DUMMY_WAIT;
				
--			when TX_DUMMY_WAIT =>	
--				if (tx_finish = '1') then
--					ack 	<= '1';
--					state	<= RX_DATA;
--				end if;
			
			when RX_DATA =>
				if (RTR_I = '1') then
					rx_cnt		<= int2vec(32-1,5);
					rx_start	<= '1';

					state		<= RX_WAIT;
				end if;
				
			when RX_WAIT =>
				if (rx_finish = '1') then
					NEW_DATA_O	<= '1';
					DATA_O		<= rx_reg;
					pkt_scnt	<= pkt_scnt - '1';
					state		<= WAIT_FOR_RX_DATA;
				end if;
				
			when WAIT_FOR_RX_DATA =>
				if (command /= RD OR pkt_scnt = 0) then
					state <= FINISH;	
				else										-- Continue Reading
					state <= RX_DATA;
				end if;
			
			when WAIT_FOR_TX_DATA =>
				if (command /= PP OR pkt_scnt = 0) then
					state	<= FINISH;	
				elsif (NEW_DATA_I = '1') then
					tx_reg	<= DATA_I;
					state	<= TX_DATA;						-- Continue Writing			
				end if;
		
			when TX_DATA =>
				tx_start	<= '1';
				tx_cnt		<= int2vec(32-1, 5);
				state		<= TX_WAIT;
				
			when TX_WAIT =>
				if (tx_finish = '1') then
					RTS_O		<= '1';
					pkt_scnt	<= pkt_scnt - '1';
					state		<= WAIT_FOR_TX_DATA;
				end if;
			
			when SYNC =>
				state	<= FINISH;	
			
			when FINISH =>
				nCS_O	<= '1';
				state	<= IDLE;
	
			end case;
		end if;
	end if;
end process fsm;

spi_tx : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			tx_state <= IDLE;
			tx_sreg	<= (others => '1');
			tx_scnt	<= (others => '0');
		else
			tx_finish <= '0';
			
			case (tx_state) is			
			when IDLE =>
				if (tx_start = '1') then
					tx_sreg		<= tx_reg;
					tx_scnt		<= tx_cnt;
					tx_state	<= TRANSFER;
				end if;
				
			when TRANSFER =>
				if (clk_falling = '1') then
					if (tx_scnt > "00000") then
						tx_scnt <= tx_scnt - '1';
						tx_sreg <= tx_sreg(30 downto 0) & "1";
					else
						tx_state <= WAIT1;
					end if;
				end if;
				
			when WAIT1 =>
				tx_finish	<= '1';
				tx_state	<= IDLE;
				
			end case;
		end if;
	end if;
end process spi_tx;

spi_rx : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			rx_state	<= IDLE;
			rx_sreg		<= (others => '1');
			rx_scnt		<= (others => '0');
		else
			rx_finish <= '0';
			
			case (rx_state) is
			when IDLE =>
				if (rx_start = '1') then
					rx_sreg		<= (others => '0');
					rx_scnt		<= rx_cnt;
					rx_state	<= TRANSFER;
				end if;
			
			when TRANSFER =>
				if (clk_rising = '1') then
					rx_sreg <= rx_sreg(30 downto 0) & DQ_I;
					
					if (rx_scnt > "00000") then
						rx_scnt  <= rx_scnt - '1';
					else
						rx_state <= WAIT1;
					end if;
				end if;
			
			when WAIT1 =>
				rx_reg		<= rx_sreg;
				rx_finish	<= '1';
				rx_state	<= IDLE;
				
			end case;
		end if;
	end if;
end process spi_rx;

SCK_O	<= spi_clk;

-- SPI Clock Generator
spi_divider : process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RESET_I = '1') then
			clk_cnt		<= 0;
			clk_falling	<= '0';
			clk_rising 	<= '0';
			spi_clk		<= '1';
			sclk_reset	<= "111110"; -- Toggle Clock a few times to reach idle-low after STARTUPE2 block
		else
			clk_falling	<= '0';
			clk_rising	<= '0';
			
			if (rx_state = TRANSFER OR tx_state = TRANSFER OR spi_clk = '1' OR sclk_reset(sclk_reset'high) = '1') then
				if (clk_cnt = DIV_COUNT) then
					if (sclk_reset(sclk_reset'high) = '1') then
						sclk_reset(sclk_reset'high downto 1) <= sclk_reset(sclk_reset'high-1 downto 0);
					end if;
				
					clk_cnt 	<= 0;
					spi_clk 	<= NOT spi_clk;
					
					if (spi_clk = '0') then
						clk_rising	<= '1';	-- was 0, changes to 1
						clk_falling	<= '0';	-- was 1, changes to 0
					else
						clk_rising	<= '0';
						clk_falling	<= '1'; 
					end if;
				else
					clk_cnt 	<= clk_cnt + 1;
				end if;
			else
				spi_clk <= '0';
				clk_cnt <= 0;
			end if;
		end if;
	end if;
end process spi_divider;

end RTL;
