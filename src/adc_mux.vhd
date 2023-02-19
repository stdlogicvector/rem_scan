library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity adc_mux is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
		CHANNEL_I	: in	STD_LOGIC := '0';
        INVERT_I    : in	STD_LOGIC := '0';
        SHIFT_I     : in	STD_LOGIC := '0';   
		
        OFFSET_I    : in    STD_LOGIC_VECTOR(15 downto 0) := x"8000";

        DV_O        : out   STD_LOGIC := '0';
        DATA_O      : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

        DV_I        : in    STD_LOGIC;
        CH0_DATA_I  : in    STD_LOGIC_VECTOR(15 downto 0);
        CH1_DATA_I  : in    STD_LOGIC_VECTOR(15 downto 0) := (others => '0')
	);
end adc_mux;

architecture Behavioral of adc_mux is

    signal dv       : std_logic_vector(2 downto 0);
    signal data     : array16_t(2 downto 0);

    constant center	: unsigned(15 downto 0) := x"8000";

begin

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        
        dv <= dv(dv'high-1 downto 0) & DV_I;
        
        if (CHANNEL_I = '1') then
            data(0) <= CH1_DATA_I;
        else
            data(0) <= CH0_DATA_I;
        end if;

        if (INVERT_I = '1') then
            data(1) <= NOT data(0);
        else
            data(1) <= data(0);
        end if;
        
        if (SHIFT_I = '1') then
            data(2) <= std_logic_vector(unsigned(data(1)) + unsigned(OFFSET_I));
        else
            data(2) <= data(1);
        end if;

    end if;
end process;

DATA_O  <= data(data'high);
DV_O    <= dv(dv'high);

end architecture;