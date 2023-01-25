library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity tb_dac is
	Port (
		nCS_I	: in	STD_LOGIC := '1';
		SCK_I	: in	STD_LOGIC;
		MISO_O	: out	STD_LOGIC := 'Z';
		MOSI_I	: in	STD_LOGIC;
		nLOAD_I	: in	STD_LOGIC := '0';
		nCLR_I	: in	STD_LOGIC := '0'
	);
end tb_dac;

architecture Simulation of tb_dac is

constant center 	: std_logic_vector(15 downto 0) := x"8000";

signal cmd			: std_logic_vector(23 downto 0) := x"000000";
signal ch0,ch1 		: std_logic_vector(15 downto 0) := x"0000";

signal x,y	 		: std_logic_vector(15 downto 0) := x"0000";

begin

DAC_SPI: process
variable b : integer := 0;
begin
	wait until falling_edge(nCS_I);
	
	cmd <= (others => '0');
	
	-- Shift in data from SPI
	for b in 23 downto 0 loop
		wait until falling_edge(SCK_I);
		cmd <= cmd(cmd'high - 1 downto 0) & MOSI_I;
	end loop;
	
	wait until rising_edge(nCS_I);
	
	if (cmd(23 downto 22) = "00") then
		if (cmd(21 downto 19) = "000") then
			if (cmd(18 downto 16) = "000") then
				ch0 <= cmd(15 downto 0);
			elsif (cmd(18 downto 16) = "010") then
				ch1 <= cmd(15 downto 0);
			end if;
		end if;
	end if;
end process;

DAC : process
begin
	wait until falling_edge(nLOAD_I);
	
	x <= std_logic_vector(not(signed(ch0) - signed(center)));
	y <= std_logic_vector(not(signed(ch1) - signed(center)));
	
end process;

end Simulation;

