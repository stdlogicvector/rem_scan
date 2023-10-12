library IEEE, UNISIM;
use UNISIM.VComponents.all;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.MATH_REAL.ALL;
use work.util.all;

entity flash_wrapper is
	Generic (
		CLK_MHZ		: real := 100.0;
		SIMULATION	: boolean := false
	);
	Port (
		CLK_I		: in	std_logic;
		RESET_I		: in	std_logic;
		
		nCS_O		: out	std_logic := '1';
		DQ_IO		: inout	std_logic_vector(3 downto 0);
		
		NEW_CMD_I	: in	std_logic;
		CMD_I		: in	std_logic_vector ( 7 downto 0);
		NEW_DATA_I	: in  	std_logic;
		DATA_I		: in	std_logic_vector (31 downto 0);
		
		RTR_I		: in	std_logic := '0';		-- Control is Ready to Receive
		RTS_O		: out	std_logic := '0';		-- Flash is Ready to Send
		BUSY_O		: out	std_logic := '0';
		
		NEW_DATA_O	: out	std_logic := '0';
		DATA_O		: out	std_logic_vector (31 downto 0) := (others => '0')
	);
end flash_wrapper;

architecture RTL of flash_wrapper is

signal cs_i		: std_logic;
signal sck_i	: std_logic;
signal data_in	: std_logic;
signal data_out	: std_logic;
signal dir		: std_logic;

signal dq_dummy	: std_logic_vector(2 downto 0);

begin

flash : entity work.flash_controller
generic map (
	CLK_MHZ			=> CLK_MHZ,
	SIMULATION		=> SIMULATION
)
port map (
	CLK_I			=> CLK_I,
	RESET_I			=> RESET_I,
	
	nCS_O			=> cs_i,
	SCK_O			=> sck_i,
	DQ_I			=> data_in,
	DQ_O			=> data_out,
	DIR_O			=> dir,
	
	NEW_CMD_I		=> NEW_CMD_I,
	CMD_I			=> CMD_I,
	NEW_DATA_I		=> NEW_DATA_I,
	DATA_I			=> DATA_I,
	
	RTR_I			=> RTR_I,
	RTS_O			=> RTS_O,
	BUSY_O			=> BUSY_O,
	
	NEW_DATA_O		=> NEW_DATA_O,
	DATA_O			=> DATA_O
);

nCS_O 	<= 'Z' when cs_i = '1' else '0';	-- Has external Pullup

flashdq0 : IOBUF
generic map (
	DRIVE => 12,
	SLEW => "SLOW"
)
port map (
	IO	=> DQ_IO(0),
	O 	=> dq_dummy(0),			-- Buffer output
	I	=> data_out,    		-- Buffer input
	T	=> NOT dir    			-- 3-state enable input, high=input, low=output 
);

flashdq1 : IOBUF
generic map (
	DRIVE => 12,
	SLEW => "SLOW"
)
port map (
	IO	=> DQ_IO(1),
	O 	=> data_in,				-- Buffer output
	I	=> '0',   				-- Buffer input
	T	=> NOT dir   			-- 3-state enable input, high=input, low=output 
);

flashdq2 : IOBUF
generic map (
	DRIVE => 12,
	SLEW => "SLOW"
)
port map (
	IO	=> DQ_IO(2),
	O 	=> dq_dummy(1),			-- Buffer output
	I	=> '1',   				-- Buffer input
	T	=> '1' 			   		-- 3-state enable input, high=input, low=output 
);

flashdq3 : IOBUF				-- !RESET Signal on Flash
generic map (
	DRIVE => 12,
	SLEW => "SLOW"
)
port map (
	IO	=> DQ_IO(3),
	O 	=> dq_dummy(2),			-- Buffer output
	I	=> '1',   				-- Buffer input
	T	=> '1'    				-- 3-state enable input, high=input, low=output 
);

cfg_pins : STARTUP_SPARTAN6
port map (
  CFGCLK	=> open,		-- 1-bit output: Configuration logic main clock output.
  CFGMCLK	=> open,		-- 1-bit output: Configuration internal oscillator clock output.
  EOS		=> open,		-- 1-bit output: Active high output signal indicates the End Of Configuration.
  CLK		=> sck_i,		-- 1-bit input: User startup-clock input
  GSR		=> '0',			-- 1-bit input: Global Set/Reset input (GSR cannot be used for the port name)
  GTS		=> '0',			-- 1-bit input: Global 3-state input (GTS cannot be used for the port name)
  KEYCLEARB	=> '0'			-- 1-bit input: Clear AES Decrypter Key input from Battery-Backed RAM (BBRAM)
);

end architecture;