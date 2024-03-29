library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity sig_proc is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;
		
        SCALE_I     : in    STD_LOGIC := '0';
        INVERT_I    : in	STD_LOGIC := '0';
        SHIFT_I     : in	STD_LOGIC := '0';   
		
        OFFSET_I    : in    STD_LOGIC_VECTOR(15 downto 0) := x"8000";
        FACTOR_I    : in    STD_LOGIC_VECTOR( 7 downto 0) := x"10";

        DV_O        : out   STD_LOGIC := '0';
        DATA_O      : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

        DV_I        : in    STD_LOGIC;
        DATA_I      : in    STD_LOGIC_VECTOR(15 downto 0)
	);
end sig_proc;

architecture Behavioral of sig_proc is

    constant STEPS  : integer := 3;

    signal dv       : std_logic_vector(STEPS-1 downto 0);
    signal data     : array16_t(STEPS-1 downto 0);

    constant center	: unsigned(15 downto 0) := x"8000";

begin

process(CLK_I)
    variable s : integer := 0;
    variable p : unsigned(23 downto 0);
begin
    if rising_edge(CLK_I) then
        s := 0;

        dv <= dv(dv'high-1 downto 0) & DV_I;

        if (INVERT_I = '1') then
            data(s) <= NOT DATA_I;
        else
            data(s) <= DATA_I;
        end if;
        
        s := s + 1;

        if (SCALE_I = '1') then
            p := unsigned(data(s-1)) * unsigned(FACTOR_I);
            data(s) <= std_logic_vector(p(19 downto 4));
        else
            data(s) <= data(s-1);
        end if;

        s := s + 1;

        if (SHIFT_I = '1') then
            data(s) <= std_logic_vector(unsigned(data(s-1)) + unsigned(OFFSET_I));
        else
            data(s) <= data(s-1);
        end if;

    end if;
end process;

DATA_O  <= data(data'high);
DV_O    <= dv(dv'high);

end architecture;