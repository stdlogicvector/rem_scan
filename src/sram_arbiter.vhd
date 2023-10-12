library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.util.all;

entity sram_arbiter is
    Generic (
        DEPTH       : integer := 19;
        WIDTH       : integer := 8
    );
	Port (
		CLK_I    	: in    std_logic;
		RST_I  		: in    std_logic;
		
        RAM_nWE_O   : out   std_logic := '1';
        RAM_nCE_O   : out   std_logic := '1';
        RAM_nOE_O   : out   std_logic := '1';
		RAM_DIR_O	: out	std_logic := '1';
        RAM_ADDR_O  : out   std_logic_vector(DEPTH-1 downto 0) := (others => '0');
		RAM_DATA_O	: out	std_logic_vector(WIDTH-1 downto 0) := (others => '0');
		RAM_DATA_I	: in	std_logic_vector(WIDTH-1 downto 0);
		
        A_WR_I      : in    std_logic;
        A_ACK_O     : out   std_logic := '0';
		A_FULL_O    : out   std_logic := '0';
        A_ADDR_I    : in    std_logic_vector(DEPTH-1 downto 0);
        A_DATA_I    : in    std_logic_vector(WIDTH-1 downto 0);

        B_RD_I      : in  	std_logic;
        B_ADDR_I    : in    std_logic_vector(DEPTH-1 downto 0);
        B_DATA_O    : out   std_logic_vector(WIDTH-1 downto 0)
	);
end sram_arbiter;

architecture Behavioral of sram_arbiter is

constant READ  : std_logic := '1';
constant WRITE : std_logic := '0';

signal RW : std_logic := READ;

signal F_DATA	: std_logic_vector(WIDTH-1 downto 0) := (others => '0');
signal F_ADDR	: std_logic_vector(DEPTH-1 downto 0) := (others => '0');
signal F_READ 	: std_logic := '0';
signal F_VALID	: std_logic := '0';
signal F_EMPTY	: std_logic := '0';

type state_t is (
	S_IDLE,
	S_READ,
	S_WRITE_GET,
	S_WRITE
);

signal state	: state_t := S_IDLE;

begin

fifo : entity work.vga_fifo
port map (
	clk		=> CLK_I,
	rst		=> RST_I,
	
	din		=> A_ADDR_I & A_DATA_I,
	wr_en	=> A_WR_I,
	wr_ack	=> A_ACK_O,
	full	=> A_FULL_O,
	
	dout(WIDTH-1 downto 0)				=> F_DATA,
	dout(DEPTH+WIDTH-1 downto WIDTH)	=> F_ADDR,
	rd_en	=> F_READ,
	valid	=> F_VALID,
	empty	=> F_EMPTY	
);


RAM_DIR_O <= RW;
RAM_nCE_O <= RST_I;		-- Always selected
RAM_nOE_O <= not RW;	-- Outputs enabled = 0

process(CLK_I)
begin
    if rising_edge(CLK_I) then
		F_READ <= '0';
		RAM_nWE_O <= '1';
	
		case (state) is
		when S_IDLE =>
			if (B_RD_I = '1') then
				state <= S_READ;
				RW <= READ;
			elsif (F_EMPTY = '0') then
				F_READ <= '1';
				state <= S_WRITE_GET;
				RW <= WRITE;
			end if;
			
		when S_READ =>
			B_DATA_O	<= RAM_DATA_I;
			RAM_ADDR_O	<= B_ADDR_I;
			
			if (B_RD_I = '0') then
				state <= S_IDLE;
			end if;
		
		when S_WRITE_GET =>
			RAM_ADDR_O	<= F_ADDR;
			RAM_DATA_O	<= F_DATA;
			
			if (F_VALID = '1') then
				state <= S_WRITE;
			end if;
			
		when S_WRITE =>
			RAM_nWE_O <= '0';
			state <= S_IDLE;
			
		end case;
    end if;
end process;

end architecture;