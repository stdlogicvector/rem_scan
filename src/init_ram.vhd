library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.VCOMPONENTS.ALL;
use work.util.all;

entity init_ram is
	Generic (
        DEPTH       : integer := 19;
        WIDTH       : integer := 8;
		ADDRESS		: integer := 16#80000#;
		SIZE		: integer := 800*600/4
    );
	Port (
		CLK_I			: in	std_logic;
		RST_I			: in	std_logic;
		
		INIT_I			: in	std_logic := '0';
		DONE_O			: out	std_logic := '0';
		
		RAM_nWE_O   	: out   std_logic := '1';
        RAM_nCE_O   	: out   std_logic := '1';
        RAM_nOE_O   	: out   std_logic := '1';
		RAM_DIR_O		: out	std_logic := '1';
        RAM_ADDR_O  	: out   std_logic_vector(DEPTH-1 downto 0) := (others => '0');
		RAM_DATA_O		: out	std_logic_vector(WIDTH-1 downto 0) := (others => '0');
		RAM_DATA_I		: in	std_logic_vector(WIDTH-1 downto 0);
		
		FL_NEW_CMD_O	: out	std_logic := '0';
		FL_CMD_O		: out	std_logic_vector(7 downto 0) := (others => '0');
		FL_NEW_DATA_O	: out	std_logic := '0';
		FL_DATA_O		: out	std_logic_vector(31 downto 0) := (others => '0');
		
		FL_RTR_O		: out	std_logic := '0';
		FL_RTS_I		: in	std_logic := '0';
		FL_BUSY_I		: in	std_logic := '0';
		
		FL_NEW_DATA_I	: in	std_logic := '0';
		FL_DATA_I		: in	std_logic_vector(31 downto 0) := (others => '0')
	);
end init_ram;

architecture Behavioral of init_ram is

type state_t is (
	S_INIT,
	S_SET_ADDR,
	S_SET_SIZE,
	S_READ,
	S_WRITE_PUT,
	S_WRITE,
	S_DONE
);

signal state	: state_t := S_INIT;

signal flash_data	: std_logic_vector(31 downto 0) := (others => '0');
signal byte			: integer range 0 to 3 := 0;

signal ram_addr		: std_logic_vector(DEPTH-1 downto 0) := (others => '0');

begin

RAM_DIR_O <= '0';		-- Always writing
RAM_nCE_O <= RST_I;		-- Always selected
RAM_nOE_O <= '1';		-- Outputs not enabled when writing

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		RAM_nWE_O 		<= '1';
		
		FL_NEW_CMD_O	<= '0';
		FL_NEW_DATA_O	<= '0';
		FL_RTR_O		<= '0';
		DONE_O			<= '0';
		
		case (state) is
		when S_INIT =>
			if (FL_BUSY_I = '0') then
				FL_NEW_CMD_O<= '1';
				FL_CMD_O	<= x"AD";
				FL_DATA_O	<= int2vec(ADDRESS, 32);
				
				state <= S_SET_ADDR;
			end if;
			
		when S_SET_ADDR =>
			if (FL_BUSY_I = '0') then
				FL_NEW_CMD_O<= '1';
				FL_CMD_O	<= x"DC";
				FL_DATA_O	<= int2vec(SIZE, 32);
			
				state <= S_SET_SIZE;
			end if;
			
		when S_SET_SIZE =>
			if (FL_BUSY_I = '0') then
				FL_NEW_CMD_O<= '1';
				FL_CMD_O	<= x"03";
				FL_DATA_O	<= (others => '0');
			
				state <= S_READ;
			end if;
			
		when S_READ => 
			FL_RTR_O <= '1';
			
			if (FL_NEW_DATA_I = '1') then
				flash_data <= FL_DATA_I;
				state <= S_WRITE_PUT;
			elsif (FL_BUSY_I = '0') then
				state <= S_DONE;
			end if;
			
		when S_WRITE_PUT =>
			RAM_ADDR_O	<= ram_addr;
			
			case (byte) is
			when 0 => RAM_DATA_O	<= flash_data( 7 downto  0);
			when 1 => RAM_DATA_O	<= flash_data(15 downto  8);
			when 2 => RAM_DATA_O	<= flash_data(23 downto 16);
			when 3 => RAM_DATA_O	<= flash_data(31 downto 24);
			end case;
			
			state <= S_WRITE;
			
		when S_WRITE =>
			RAM_nWE_O <= '0';
		
			ram_addr <= inc(ram_addr);
			
			if (byte < 3) then
				byte <= byte + 1;
				state <= S_WRITE_PUT;
			else
				byte <= 0;
				state <= S_READ;
			end if;
				
		when S_DONE =>
			DONE_O <= '1';

			if (INIT_I = '1') then
				state <= S_INIT;
			end if;
			
		end case;
	
	end if;
end process;


end Behavioral;

