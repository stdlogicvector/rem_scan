library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity testimg is
	Port (
		CLK_I		: IN STD_LOGIC;
		RST_I		: IN STD_LOGIC;
		
		SAMPLE_I	: IN STD_LOGIC;
        MODE_I      : IN STD_LOGIC_VECTOR(3 downto 0);

        ROW_I       : IN STD_LOGIC_VECTOR(15 downto 0);
        COL_I       : IN STD_LOGIC_VECTOR(15 downto 0);

        X_I         : IN STD_LOGIC_VECTOR(15 downto 0);
        Y_I         : IN STD_LOGIC_VECTOR(15 downto 0);

		DV_O 		: OUT STD_LOGIC := '0';
		DATA_O		: OUT STD_LOGIC_VECTOR (15 downto 0) := (others => '0')
	);
end testimg;

architecture Behavioral of testimg is

signal dv_delay : std_logic_vector(15 downto 0);

signal counter  : std_logic_vector(15 downto 0) := (others => '0');

begin
  
process(CLK_I)
begin
    if rising_edge(CLK_I) then
        
        dv_delay <= dv_delay(dv_delay'high-1 downto 0) & SAMPLE_I;
        DV_O <= dv_delay(dv_delay'high);

        if (SAMPLE_I = '1') then
            counter <= counter + '1';
        end if;

        case (MODE_I) is
            when x"0" =>
                DATA_O <= COL_I(7 downto 0) & ROW_I(7 downto 0);
            when x"1" =>
                DATA_O <= COL_I(7 downto 0) & ROW_I(15 downto 8);
            when x"2" =>
                DATA_O <= COL_I(15 downto 8) & ROW_I(7 downto 0);
            when x"3" =>
                DATA_O <= COL_I(15 downto 8) & ROW_I(15 downto 8);

            when x"4" =>
                DATA_O <= ROW_I(7 downto 0) & COL_I(7 downto 0);
            when x"5" =>
                DATA_O <= ROW_I(7 downto 0) & COL_I(15 downto 8);
            when x"6" =>
                DATA_O <= ROW_I(15 downto 8) & COL_I(7 downto 0);
            when x"7" =>
                DATA_O <= ROW_I(15 downto 8) & COL_I(15 downto 8);

            when x"8" =>
                DATA_O <= X_I(7 downto 0) & Y_I(7 downto 0);
            when x"9" =>
                DATA_O <= X_I(7 downto 0) & Y_I(15 downto 8);
            when x"A" =>
                DATA_O <= X_I(15 downto 8) & Y_I(7 downto 0);
            when x"B" =>
                DATA_O <= X_I(15 downto 8) & Y_I(15 downto 8);

            when x"C" =>
                DATA_O <= (others => counter(0));
            when x"D" =>
                DATA_O <= (15 => COL_I(3), 14 => ROW_I(3), 12 => COL_I(2), 11 => ROW_I(2), others => '0');
            when x"E" =>
                DATA_O <= (others => ROW_I(3));
            when x"F" =>
                DATA_O <= counter;

            when others =>
                DATA_O <= x"0000";

        end case;
    end if;
end process;

end architecture;