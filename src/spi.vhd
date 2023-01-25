library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity spi_master is
	generic (
		SLAVES	: INTEGER := 1;		-- Number of Slaves
		WIDTH 	: INTEGER := 24		-- Data WIDTH
	);
	port (
		CLK_I 	: IN	STD_LOGIC;
		RST_I		: IN	STD_LOGIC;
		
		SEND_I	: IN	STD_LOGIC;
		CONT_I	: IN	STD_LOGIC;
		BUSY_O	: OUT	STD_LOGIC;
		CPOL_I	: IN	STD_LOGIC;
		CPHA_I	: IN	STD_LOGIC;
		
		CLKDIV_I	: IN	STD_LOGIC_VECTOR(7 downto 0);
		SLAVE_I	: IN	STD_LOGIC_VECTOR((SLAVES-1) downto 0);
		
		TX_I	 	: IN	STD_LOGIC_VECTOR((WIDTH-1) downto 0);
		RX_O		: OUT	STD_LOGIC_VECTOR((WIDTH-1) downto 0);
		
		CSn_O		: OUT STD_LOGIC_VECTOR((SLAVES-1) downto 0);
		SCK_O		: OUT STD_LOGIC;
		MOSI_O	: OUT	STD_LOGIC;
		MISO_I	: IN	STD_LOGIC
	);
end spi_master;

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;

entity spi_slave is
	generic (
		CPOL		: STD_LOGIC := '0';
		CPHA		: STD_LOGIC := '1';
		WIDTH		: INTEGER 	:= 8
	);
	port (
		CLK_I		: IN	STD_LOGIC;
		RST_I		: IN	STD_LOGIC;
		
		BUSY_O	: OUT	STD_LOGIC := '0';
		RECV_O	: OUT	STD_LOGIC := '0';
		
		TX_I		: IN	STD_LOGIC_VECTOR((WIDTH-1) downto 0);
		RX_O		: OUT	STD_LOGIC_VECTOR((WIDTH-1) downto 0) := (others => '0');
		
		CSn_O		: IN	STD_LOGIC;
		SCK_O		: IN 	STD_LOGIC;
		MOSI_O	: IN	STD_LOGIC;
		MISO_I	: OUT	STD_LOGIC := 'Z'
	);
end spi_slave;

architecture RTL of spi_slave is

signal sck_m	: std_logic;

signal csn_s	: std_logic_vector(1 downto 0) := (others => '1');
signal sck_s	: std_logic_vector(1 downto 0) := (others => '0');
signal mosi_s	: std_logic_vector(1 downto 0) := (others => '0');

signal sck_falling_edge : STD_LOGIC := '0';
signal sck_rising_edge  : STD_LOGIC := '0';

signal frame_start : STD_LOGIC := '0';
signal frame_stop  : STD_LOGIC := '0';

signal mode		: std_logic;

signal rx_data : STD_LOGIC_VECTOR ((WIDTH-1) downto 0) := (others => '0');
signal tx_data : STD_LOGIC_VECTOR ((WIDTH-1) downto 0) := (others => '0');

signal bits : integer range 0 to WIDTH := 0;

begin
	
mode  <= CPOL xor CPHA;
sck_m <= SCK_O when mode = '1' else not SCK_O;
	
sampling : process (CLK_I)
begin
	if falling_edge(CLK_I) then
		if (RST_I = '1') then
			csn_s 	<= (others => '1');
			sck_s 	<= (others => '0');
			mosi_s 	<= (others => '0');
		else
			csn_s 	<= csn_s(0)  & CSn_O;
			sck_s 	<= sck_s(0)  & sck_m;
			mosi_s 	<= mosi_s(0) & MOSI_O;
		
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
			BUSY_O	<= '0';
			RECV_O	<= '0';
			MISO_I	<= 'Z';
			
			tx_data	<= (others => '0');
			rx_data	<= (others => '0');
		else
			RECV_O <= '0';

			if (frame_start = '1') then
				BUSY_O	<= '1';
				tx_data	<= TX_I;
				bits		<= 0;
			elsif (frame_stop = '1') then
				BUSY_O 	<= '0';
			end if;
			
			if (sck_rising_edge = '1') then
				tx_data	<= tx_data(WIDTH-2 downto 0) & '0';
				MISO_I	<= tx_data(WIDTH-1);
			end if;
			
			if (sck_falling_edge = '1') then
				rx_data	<= rx_data(WIDTH-2 downto 0) & mosi_s(1);
				bits	 	<= bits + 1;
			end if;
			
			if (bits = WIDTH) then
				bits		<= 0;
				tx_data  <= TX_I;
				RX_O		<= rx_data;
				RECV_O 	<= '1';
			end if;
			
		end if;
	end if;
end process;	

end RTL;

architecture RTL of spi_master is

type state_t is (IDLE, TRANSMIT);
signal state : state_t := IDLE;

signal sck_reg			: std_logic := '0';
signal csn_reg			: std_logic_vector((SLAVES-1) downto 0) := (others => '1');

signal cont_reg		: std_logic;
signal slave_reg		: std_logic_vector((SLAVES-1) downto 0) := (others => '0');
signal clk_div_reg	: std_logic_vector(7 downto 0) := (others => '0');
signal clk_cnt			: std_logic_vector(7 downto 0) := (others => '0');
signal clk_edge		: std_logic;

signal last_bit		: integer range 0 to WIDTH*2 := 0;
signal bit_nr			: integer range 0 to WIDTH*2 + 1 := 0;

signal rx_data			: std_logic_vector((WIDTH-1) downto 0) := (others => '0');
signal tx_data			: std_logic_vector((WIDTH-1) downto 0) := (others => '0');

signal busy				: std_logic := '0';
constant ones 			: STD_LOGIC_VECTOR((SLAVES-1) downto 0) := (others => '1');

begin

SCK_O <= sck_reg;
CSn_O <= csn_reg;
BUSY_O <= busy;

process (CLK_I, RST_I)
begin
	if (rising_edge(CLK_I)) then
		if (RST_I = '1') then
			busy		<= '1';
			csn_reg	<=	(others => '1');
			MOSI_O	<= 'Z';
			rx_data	<= (others => '0');
			
			state 	<= IDLE;
		else
			case state is
			when IDLE =>
				busy 		<= '0';
				csn_reg 	<=	(others => '1');
				MOSI_O	<= 'Z';
				cont_reg <= '0';
				
				if (SEND_I = '1') then
					busy		<= '1';
					slave_reg <= SLAVE_I;
					sck_reg	<= CPOL_I;
					clk_edge <= not CPHA_I;
					tx_data	<= TX_I;
					bit_nr	<= 0;
					last_bit	<= WIDTH*2 + conv_integer(CPHA_I) - 1;
					
					state		<= TRANSMIT;
					
					if (CLKDIV_I = 0) then
						clk_div_reg <= x"01";
						clk_cnt		<= x"01";
					else
						clk_div_reg <= CLKDIV_I;
						clk_cnt		<= CLKDIV_I;
					end if;
				end if;
			
			when TRANSMIT =>
				busy		<= '1';
				csn_reg	<= NOT slave_reg;
				
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
					
					-- Toggle SCK_O
					if (bit_nr <= WIDTH*2) AND (csn_reg /= ones) then
						sck_reg <= not sck_reg;
					end if;
					
					-- Receive Data
					if (clk_edge = '0') AND (bit_nr < last_bit + 1) AND (csn_reg /= ones) then
						rx_data <= rx_data(WIDTH-2 downto 0) & MISO_I;
					end if;
					
					-- Transmit Data
					if (clk_edge = '1') AND (bit_nr < last_bit) THEN
						MOSI_O	<= tx_data(WIDTH-1);
						tx_data 	<= tx_data(WIDTH-2 downto 0) & '0';
					end if;
					
					-- Last Bit, Continue?
					if (bit_nr = last_bit) AND (CONT_I = '1') then
						tx_data	<= TX_I;
						bit_nr 	<= last_bit - WIDTH*2 + 1;
						cont_reg <= '1';
					end if;
					
					-- End of Transaction but continue
					if (cont_reg = '1') then
						cont_reg <= '0';
						busy	 	<= '0';
						RX_O 		<= rx_data;
					end if;
					
					-- End of Transaction
					if (bit_nr  = WIDTH*2 + 1) AND (CONT_I = '0') then
						busy	 		<= '0';
						csn_reg		<= (others => '1');
						MOSI_O		<= 'Z';
						RX_O			<= rx_data;
						
						state		<= IDLE;
					else
						state 	<= TRANSMIT;
					end if;
				else
					clk_cnt	<= clk_cnt + '1';
					state 	<= TRANSMIT;
				end if;
			end case;
		end if;
	end if;
end process;

end RTL;

