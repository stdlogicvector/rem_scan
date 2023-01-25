library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity tb_adc is
	Port (
		CNV_I	: in	STD_LOGIC := '0';
		SCK_I	: in	STD_LOGIC;
		SD0_O	: out	STD_LOGIC;
		SD1_O	: out	STD_LOGIC
	);
end tb_adc;

architecture Simulation of tb_adc is

signal ch0 		: std_logic_vector(15 downto 0) := x"0000";
signal ch1 		: std_logic_vector(15 downto 0) := x"0000";

begin

ADC : process
variable b : integer := 0;
begin
	SD0_O	<= '1';
	SD1_O	<= '1';

	wait until rising_edge(CNV_I);

	ch0 <= random_vec(0, 2**16-1, 16);
	ch1 <= random_vec(0, 2**16-1, 16);
	
	wait for 643 ns;	-- Conversion Time
	
	SD0_O <= '0';
	
	wait for 74 ns;
	
	SD1_O <= '0';
	
	for b in 15 downto 0 loop
		wait until falling_edge(SCK_I);
		wait for 9.5 ns;
		SD0_O <= ch0(b);
		SD1_O <= ch1(b);
	end loop;

	wait for 20 ns;

end process;

end Simulation;

