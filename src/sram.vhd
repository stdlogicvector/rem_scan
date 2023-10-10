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

        B_DV_O      : OUT   STD_LOGIC := '0';
        B_ADDR_I    : IN    STD_LOGIC_VECTOR(DEPTH-1 downto 0);
        B_DATA_O    : OUT   STD_LOGIC_VECTOR(WIDTH-1 downto 0)
	);
end sram;

architecture Behavioral of sram is

constant READ  : std_logic := '1';
constant WRITE : std_logic := '0';

signal RW : std_logic := READ;

signal A_DATA : std_logic_vector(WIDTH-1 downto 0);
signal B_DATA : std_logic_vector(WIDTH-1 downto 0);

signal A_WR : std_logic := '0';

begin

data_io : for i in 0 to WIDTH-1 generate
    data_io_i : IOBUF
	generic map (
		DRIVE		=> 12,
		IOSTANDARD	=> "DEFAULT",
		SLEW 		=> "FAST"
	)
    port map (
        O   => B_DATA(i),
        I   => A_DATA_I(i),
        T   => RW,			-- 1 = input, 0 = output
        IO  => RAM_DATA_IO(i)
    );
end generate;

-- Always selected
RAM_nCE_O <= RST_I;

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        RW <= not RW;

        if (RW = READ) then             				-- Next Cycle will be write
			B_DATA_O	<= B_DATA;
			B_DV_O		<= '1';          				-- Valid Data on Read Port
		
            RAM_ADDR_O	<= A_ADDR_I;     				-- Output Write Address
            RAM_nWE_O	<= not (A_WR_I OR A_WR);   		-- Write Enable = low for writing
            RAM_nOE_O	<= '1';          				-- Disable Outputs for Writing
            A_ACK_O		<= A_WR_I OR A_WR; 				-- Acknowledge Write Request
        else                            				-- Next Cycle will be read
			B_DV_O		<= '0';          				-- No Valid Data on Read Port			
		
            RAM_ADDR_O	<= B_ADDR_I;     				-- Output Read Address
			RAM_nWE_O	<= '1';			 				-- Write Enable = low for writing
            RAM_nOE_O	<= '0';          				-- Enable Outputs for Reading
            A_ACK_O		<= '0';          				-- No Write Ack


			A_WR		<= A_WR_I;
        end if;
    end if;
end process;

end architecture;