library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.VCOMPONENTS.ALL;
use work.util.all;

entity sram is
    Generic (
        DEPTH       : integer := 19;
        WIDTH       : integer := 8
    );
	Port (
		CLK_I    	: IN    STD_LOGIC;
		RST_I  		: IN    STD_LOGIC;
		
        RAM_nWE_O   : OUT   STD_LOGIC := '1';
        RAM_nCE_O   : OUT   STD_LOGIC := '1';
        RAM_nOE_O   : OUT   STD_LOGIC := '1';
        RAM_ADDR_O  : OUT   STD_LOGIC_VECTOR(DEPTH-1 downto 0) := (others => '0');
        RAM_DATA_IO : INOUT STD_LOGIC_VECTOR(WIDTH-1 downto 0);
		
        A_WR_I      : IN    STD_LOGIC;
        A_ACK_O     : OUT   STD_LOGIC := '0';
        A_ADDR_I    : IN    STD_LOGIC_VECTOR(DEPTH-1 downto 0);
        A_DATA_I    : IN    STD_LOGIC_VECTOR(WIDTH-1 downto 0);

        B_RD_I      : IN  	STD_LOGIC;
        B_ADDR_I    : IN    STD_LOGIC_VECTOR(DEPTH-1 downto 0);
        B_DATA_O    : OUT   STD_LOGIC_VECTOR(WIDTH-1 downto 0)
	);
end sram;

architecture Behavioral of sram is

constant READ  : std_logic := '1';
constant WRITE : std_logic := '0';

signal RW : std_logic := READ;

signal R_DATA	: std_logic_vector(WIDTH-1 downto 0) := (others => '0');
signal W_DATA	: std_logic_vector(WIDTH-1 downto 0) := (others => '0');

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

data_io : for i in 0 to WIDTH-1 generate
    data_io_i : IOBUF
	generic map (
		DRIVE		=> 12,
		IOSTANDARD	=> "DEFAULT",
		SLEW 		=> "FAST"
	)
    port map (
        O   => R_DATA(i),
        I   => W_DATA(i),
        T   => RW,			-- 1 = input, 0 = output
        IO  => RAM_DATA_IO(i)
    );
end generate;

fifo : entity work.vga_fifo
port map (
	clk		=> CLK_I,
	rst		=> RST_I,
	
	din		=> A_ADDR_I & A_DATA_I,
	wr_en	=> A_WR_I,
	wr_ack	=> A_ACK_O,
	full	=> open,
	
	dout(WIDTH-1 downto 0)				=> F_DATA,
	dout(DEPTH+WIDTH-1 downto WIDTH)	=> F_ADDR,
	rd_en	=> F_READ,
	valid	=> F_VALID,
	empty	=> F_EMPTY	
);

-- Always selected
RAM_nCE_O <= RST_I;
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
			B_DATA_O	<= R_DATA;
			RAM_ADDR_O	<= B_ADDR_I;
			
			if (B_RD_I = '0') then
				state <= S_IDLE;
			end if;
		
		when S_WRITE_GET =>
			RAM_ADDR_O	<= F_ADDR;
			W_DATA		<= F_DATA;
			
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