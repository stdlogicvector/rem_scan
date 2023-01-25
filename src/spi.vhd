library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity spi_master is
	generic (
		SLAVES		: integer := 1;
		WIDTH 		: integer := 8
	);
	port (
		CLKDIV_I	: in	std_logic_vector(7 downto 0);
		CPOL		: in	std_logic;
		CPHA		: in	std_logic;
	
		CLK_I 		: in	std_logic;
		RST_I		: in	std_logic;
		
		SEND_I		: in	std_logic;
		CONT_I		: in	std_logic;
		KEEP_I		: in	std_logic := '0';
		BUSY_O		: out	std_logic := '0';
		SLAVE_I		: in	std_logic_vector(max(clogb2(SLAVES)-1, 0) downto 0);
		
		TX_I		: in	std_logic_vector((WIDTH-1) downto 0);
		RX_O		: out	std_logic_vector((WIDTH-1) downto 0) := (others => '0');
		
		CSN_O		: out 	std_logic_vector((SLAVES-1) downto 0) := (others => '1');
		SCK_O		: out	std_logic;
		MOSI_O		: out	std_logic;
		MISO_I		: in	std_logic
	);
end spi_master;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity spi_slave is
	generic (
		CPOL		: STD_LOGIC := '0';
		CPHA		: STD_LOGIC := '1';
		WIDTH		: INTEGER 	:= 16
	);
	port (
		CLK_I		: IN	STD_LOGIC;
		RST_I		: IN	STD_LOGIC;
		
		BUSY_O		: OUT	STD_LOGIC := '0';
		
		DV_I		: IN	STD_LOGIC := '1';
		TX_I		: IN	STD_LOGIC_VECTOR((WIDTH-1) downto 0);
		
		DV_O		: OUT	STD_LOGIC := '0';
		RX_O		: OUT	STD_LOGIC_VECTOR((WIDTH-1) downto 0) := (others => '0');
		
		CSn_I		: IN	STD_LOGIC;
		SCK_I		: IN 	STD_LOGIC;
		MOSI_I		: IN	STD_LOGIC;
		MISO_O		: OUT	STD_LOGIC := 'Z'
	);
end spi_slave;

architecture RTL of spi_slave is

signal sck_m			: std_logic := '0';

signal csn_s			: std_logic_vector(1 downto 0) := (others => '1');
signal sck_s			: std_logic_vector(1 downto 0) := (others => '0');
signal mosi_s			: std_logic_vector(1 downto 0) := (others => '0');

signal sck_falling_edge : STD_LOGIC := '0';
signal sck_rising_edge  : STD_LOGIC := '0';

signal frame_start 		: STD_LOGIC := '0';
signal frame_stop  		: STD_LOGIC := '0';

signal mode				: std_logic := '0';

signal rx_data 			: STD_LOGIC_VECTOR ((WIDTH-1) downto 0) := (others => '0');
signal tx_data 			: STD_LOGIC_VECTOR ((WIDTH-1) downto 0) := (others => '0');

signal bits 			: integer range 0 to WIDTH := 0;

begin
	
mode <= CPOL xor CPHA;
sck_m <= SCK_I when mode = '1' else not SCK_I;
	
sampling : process (CLK_I)
begin
	if falling_edge(CLK_I) then
		if (RST_I = '1') then
			csn_s 	<= (others => '1');
			sck_s 	<= (others => '0');
			mosi_s 	<= (others => '0');
		else
			csn_s 	<= csn_s(0)  & CSn_I;
			sck_s 	<= sck_s(0)  & sck_m;
			mosi_s 	<= mosi_s(0) & MOSI_I;
		
			if (csn_s(1 downto 0) = b"10") then frame_start <= '1'; else frame_start <= '0'; end if;
			if (csn_s(1 downto 0) = b"01") then frame_stop  <= '1'; else frame_stop  <= '0'; end if;
		
			if (sck_s(1 downto 0) = b"01") then sck_rising_edge  <= '1'; else sck_rising_edge  <= '0'; end if;
			if (sck_s(1 downto 0) = b"10") then sck_falling_edge <= '1'; else sck_falling_edge <= '0'; end if;
		end if;
	end if;
end process;	
	
process (CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			BUSY_O		<= '0';
			DV_O		<= '0';
			MISO_O		<= 'Z';
			
			tx_data	<= (others => '0');
			rx_data	<= (others => '0');
		else
			DV_O <= '0';

			if (frame_start = '1') then
				BUSY_O 		<= '1';
				--tx_data		<= TX_I;
				bits		<= 0;
			elsif (frame_stop = '1') then
				MISO_O		<= 'Z';
				BUSY_O 		<= '0';
			end if;
			
			if (sck_rising_edge = '1') then
				tx_data	<= tx_data(WIDTH-2 downto 0) & '0';
				MISO_O	<= tx_data(WIDTH-1);
			end if;
			
			if (sck_falling_edge = '1') then
				rx_data <= rx_data(WIDTH-2 downto 0) & mosi_s(1);
				bits 	<= bits + 1;
			end if;
			
			if (bits = WIDTH) then
				bits	<= 0;
				RX_O	<= rx_data;
				DV_O 	<= '1';
			end if;
			
			if (bits = 0 AND DV_I = '1') then
				tx_data <= TX_I;
			end if;
			
		end if;
	end if;
end process;	

end RTL;


architecture RTL of spi_master is

type state_t is (IDLE, KEEP, SEND, TRANSMIT, PAUSE);
signal state : state_t := IDLE;

signal sck_reg			: std_logic := '0';
signal csn_reg			: std_logic_vector((SLAVES-1) downto 0) := (others => '1');

signal cont_reg			: std_logic := '0';
signal clk_cnt			: std_logic_vector(7 downto 0) := (others => '0');
signal clk_edge			: std_logic := '0';

signal eol_bit			: integer range 0 to WIDTH*2 := 0;
signal bit_nr			: integer range 0 to WIDTH*2 + 1 := 0;

signal rx_data			: std_logic_vector((WIDTH-1) downto 0) := (others => '0');
signal tx_data			: std_logic_vector((WIDTH-1) downto 0) := (others => '0');

begin

SCK_O <= sck_reg;
CSN_O <= csn_reg;

process (CLK_I)
begin
	if (rising_edge(CLK_I)) then
		if (RST_I = '1') then
			BUSY_O	<= '1';
			MOSI_O	<= 'Z';
			csn_reg	<= (others => '1');
			rx_data	<= (others => '0');
			
			state 	<= IDLE;
		else
			case state is
			when IDLE =>
				BUSY_O 	<= '0';
				csn_reg <= (others => '1');
				MOSI_O	<= 'Z';
				cont_reg <= '0';
				
				if (SEND_I = '1') then
					state <= SEND;
				end if;
				
			when KEEP =>
				if (SEND_I = '1') then
					state <= SEND;
				end if;
				
			when SEND =>
					BUSY_O	<= '1';
					sck_reg	<= CPOL;
					clk_edge<= not CPHA;
					tx_data	<= TX_I;
					bit_nr	<= 0;
					eol_bit	<= WIDTH*2 + vec2int('0' & CPHA) - 1;
					
					state <= TRANSMIT;
					
					if (vec2int(CLKDIV_I) = 0) then
						clk_cnt	<= x"01";
					else
						clk_cnt	<= CLKDIV_I;
					end if;
			
			when TRANSMIT =>
				BUSY_O <= '1';
				csn_reg(vec2int(SLAVE_I))	<= '0';
				
				-- Divide Clock
				if (clk_cnt = CLKDIV_I) then
					clk_cnt 	<= x"01";
					clk_edge	<= not clk_edge;
					
					-- Count SPI bits
					if (bit_nr	= WIDTH*2 + 1) then
						bit_nr <= 0;
					else
						bit_nr <= bit_nr + 1;
					end if;
					
					-- Toggle SCK
					if (bit_nr <= WIDTH*2) AND (csn_reg(vec2int(SLAVE_I)) = '0') then
						sck_reg <= not sck_reg;
					end if;
					
					-- Receive Data
					if (clk_edge = '0') AND (bit_nr < eol_bit + 1) AND (csn_reg(vec2int(SLAVE_I)) = '0') then
						rx_data <= rx_data(WIDTH-2 downto 0) & MISO_I;
					end if;
					
					-- Transmit Data
					if (clk_edge = '1') AND (bit_nr < eol_bit) THEN
						MOSI_O		<= tx_data(WIDTH-1);
						tx_data 	<= tx_data(WIDTH-2 downto 0) & '0';
					end if;
					
					-- Last Bit, Continue?
					if (bit_nr = eol_bit) AND (CONT_I = '1') then
						tx_data	<= TX_I;
						bit_nr 	<= eol_bit - WIDTH*2 + 1;
						cont_reg <= '1';
					end if;
					
					-- End of Transaction but continue
					if (cont_reg = '1') then
						cont_reg <= '0';
						BUSY_O 	<= '0';
						RX_O 	<= rx_data;
					end if;
					
					-- End of Transaction
					if (bit_nr  = WIDTH*2 + 1) then
						--BUSY_O 	<= '0';
						csn_reg	<= (others => '1');
						MOSI_O	<= 'Z';
						RX_O	<= rx_data;
						
						state	<= PAUSE;
					else
						state	<= TRANSMIT;
					end if;
				else
					clk_cnt	<= inc(clk_cnt);
					state 	<= TRANSMIT;
				end if;
				
			when PAUSE =>
				if (clk_cnt = CLKDIV_I) then
					BUSY_O 	<= '0';
					if (KEEP_I = '0') then
						state	<= IDLE;
					else
						state	<= KEEP;
					end if;
				else
					clk_cnt	<= inc(clk_cnt);
					state 	<= PAUSE;
				end if;
			end case;
		end if;
	end if;
end process;

end RTL;
