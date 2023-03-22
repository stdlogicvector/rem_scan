library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity adc_mux is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
		CHANNEL_I	: in	STD_LOGIC := '0';

        DV_O        : out   STD_LOGIC := '0';
        DATA_O      : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

        DV_I        : in    STD_LOGIC;
        CH0_DATA_I  : in    STD_LOGIC_VECTOR(15 downto 0);
        CH1_DATA_I  : in    STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
	);
end adc_mux;

architecture Behavioral of adc_mux is

begin

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        DV_O <= DV_I;

        if (CHANNEL_I = '1') then
            DATA_O <= CH1_DATA_I;
        else
            DATA_O <= CH0_DATA_I;
        end if;

    end if;
end process;

end architecture;