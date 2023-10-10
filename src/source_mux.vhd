library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity source_mux is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
		CHANNEL_I	: in	STD_LOGIC := '0';
		
        SAMPLE_I    : in	STD_LOGIC;
		SENT_I		: in	STD_LOGIC := '0';
        DV_O        : out   STD_LOGIC := '0';
        DATA_O      : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

        CH0_SAMPLE_O: out   STD_LOGIC := '0';
		CH0_SENT_O	: out	STD_LOGIC := '0';
        CH0_DV_I    : in    STD_LOGIC;
        CH0_DATA_I  : in    STD_LOGIC_VECTOR(15 downto 0);

        CH1_SAMPLE_O: out   STD_LOGIC := '0';
		CH1_SENT_O	: out	STD_LOGIC := '0';
        CH1_DV_I    : in    STD_LOGIC := '0';
        CH1_DATA_I  : in    STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
	);
end source_mux;

architecture Behavioral of source_mux is

begin

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        if (CHANNEL_I = '0') then
            CH0_SAMPLE_O <= SAMPLE_I;
            CH1_SAMPLE_O <= '0';
			
			CH0_SENT_O	<= SENT_I;
			CH1_SENT_O	<= '0';

            DV_O    <= CH0_DV_I;
            DATA_O  <= CH0_DATA_I;
        else
            CH1_SAMPLE_O <= SAMPLE_I;
            CH0_SAMPLE_O <= '0';
			
			CH1_SENT_O	<= SENT_I;
			CH0_SENT_O	<= '0';

            DV_O    <= CH1_DV_I;
            DATA_O  <= CH1_DATA_I;
        end if;
    end if;
end process;

end architecture;