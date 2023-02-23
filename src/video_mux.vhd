library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity video_mux is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
		CHANNEL_I	: in	STD_LOGIC := '0';

        SENT_O      : out   STD_LOGIC := '0';
        DV_I        : in    STD_LOGIC;
        DATA_I      : in    STD_LOGIC_VECTOR(15 downto 0);

        CH0_SENT_I  : in    STD_LOGIC;
        CH0_DV_O    : out   STD_LOGIC := '0';
        CH0_DATA_O  : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

        CH1_SENT_I  : in    STD_LOGIC := '0';
        CH1_DV_O    : out   STD_LOGIC := '0';
        CH1_DATA_O  : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
	);
end video_mux;

architecture Behavioral of video_mux is

begin

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        if (CHANNEL_I = '0') then
            SENT_O  <= CH0_SENT_I;

            CH0_DV_O    <= DV_I;
            CH0_DATA_O  <= DATA_I;

            CH1_DV_O    <= '0';
        else
            SENT_O      <= CH1_SENT_I;

            CH1_DV_O    <= DV_I;
            CH1_DATA_O  <= DATA_I;

            CH0_DV_O    <= '0';
        end if;
    end if;
end process;

end architecture;