library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use UNISIM.VCOMPONENTS.ALL;
use work.util.all;

entity ram_mux is
	Generic (
        DEPTH       : integer := 19;
        WIDTH       : integer := 8
    );
	Port (
		CLK_I    	: in    std_logic;
		RST_I  		: in    std_logic;
		
		CHANNEL_I	: in	std_logic := '0';
		
        RAM_nWE_O   : out   std_logic := '1';
        RAM_nCE_O   : out   std_logic := '1';
        RAM_nOE_O   : out   std_logic := '1';
        RAM_ADDR_O  : out   std_logic_vector(DEPTH-1 downto 0) := (others => '0');
        RAM_DATA_IO : inout std_logic_vector(WIDTH-1 downto 0);

		CH0_nWE_I   : in	std_logic;
        CH0_nCE_I   : in	std_logic;
        CH0_nOE_I   : in	std_logic;
		CH0_DIR_I	: in	std_logic;
        CH0_ADDR_I  : in	std_logic_vector(DEPTH-1 downto 0);
        CH0_DATA_I  : in	std_logic_vector(WIDTH-1 downto 0);
		CH0_DATA_O  : out	std_logic_vector(WIDTH-1 downto 0);

        CH1_nWE_I   : in	std_logic := '0';
        CH1_nCE_I   : in	std_logic := '0';
        CH1_nOE_I   : in	std_logic := '0';
		CH1_DIR_I	: in	std_logic := '1';
        CH1_ADDR_I  : in	std_logic_vector(DEPTH-1 downto 0) := (others => '0');
        CH1_DATA_I  : in	std_logic_vector(WIDTH-1 downto 0);
		CH1_DATA_O  : out	std_logic_vector(WIDTH-1 downto 0)
	);
end ram_mux;

architecture Behavioral of ram_mux is

signal RAM_DATA_O	: STD_LOGIC_VECTOR(WIDTH-1 downto 0);
signal RAM_DATA_I	: STD_LOGIC_VECTOR(WIDTH-1 downto 0);
signal RAM_DIR_I	: STD_LOGIC := '1';

begin

data_io : for i in 0 to WIDTH-1 generate
    data_io_i : IOBUF
	generic map (
		DRIVE		=> 12,
		IOSTANDARD	=> "DEFAULT",
		SLEW 		=> "FAST"
	)
    port map (
        O   => RAM_DATA_O(i),
        I   => RAM_DATA_I(i),
        T   => RAM_DIR_I,			-- 1 = input, 0 = output
        IO  => RAM_DATA_IO(i)
    );
end generate;

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        if (CHANNEL_I = '0') then
            RAM_nWE_O  	<= CH0_nWE_I;
			RAM_nCE_O	<= CH0_nCE_I;
			RAM_nOE_O	<= CH0_nOE_I;
			RAM_DIR_I	<= CH0_DIR_I;
			
			RAM_ADDR_O	<= CH0_ADDR_I;
			
			RAM_DATA_I	<= CH0_DATA_I;
			
			CH0_DATA_O	<= RAM_DATA_O;
			CH1_DATA_O	<= (others => '0');
        else
            RAM_nWE_O  	<= CH1_nWE_I;
			RAM_nCE_O	<= CH1_nCE_I;
			RAM_nOE_O	<= CH1_nOE_I;
			RAM_DIR_I	<= CH1_DIR_I;
			
			RAM_ADDR_O	<= CH1_ADDR_I;
			
			RAM_DATA_I	<= CH1_DATA_I;
			
			CH1_DATA_O	<= RAM_DATA_O;
			CH0_DATA_O	<= (others => '0');
        end if;
    end if;
end process;

end architecture;