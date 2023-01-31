library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity average is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;

        ENABLE_I    : in    STD_LOGIC;

        NUMBER_I    : in    STD_LOGIC_VECTOR( 3 downto 0);
        DELAY_I     : in    STD_LOGIC_VECTOR(15 downto 0);

        SAMPLE_I    : in	STD_LOGIC;
        DV_O        : out   STD_LOGIC := '0';
        DATA_O      : out   STD_LOGIC_VECTOR(15 downto 0) := (others => '0');

        SAMPLE_O    : out   STD_LOGIC := '0';
        DV_I        : in    STD_LOGIC;
        DATA_I      : in    STD_LOGIC_VECTOR(15 downto 0)
    );
end average;

architecture Behavioral of average is

type state_t is (
    S_IDLE,
    S_SAMPLE,
    S_DELAY,
    S_SHIFT
);

signal state    : state_t := S_IDLE;
signal timer    : std_logic_vector(15 downto 0) := (others => '0');

signal counter  : std_logic_vector( 3 downto 0) := (others => '0');
signal accu     : unsigned(31 downto 0) := (others => '0');

begin

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        DV_O     <= '0';
        SAMPLE_O <= '0';

        timer <= timer + '1';

        case (state) is
        when S_IDLE =>
            if (ENABLE_I = '1' AND SAMPLE_I = '1' AND NUMBER_I /= "0000") then
                state   <= S_SAMPLE;
                accu    <= (others => '0');
                timer   <= (others => '0');
                counter <= (others => '0');
            end if;

            SAMPLE_O <= SAMPLE_I;
            DV_O     <= DV_I;
            DATA_O   <= DATA_I;

        when S_SAMPLE =>
            if (DV_I = '1') then
                counter <= counter + '1';
                accu    <= accu + unsigned(DATA_I);
                state   <= S_DELAY;
            end if;

        when S_DELAY => 
            if (counter >= NUMBER_I) then
                state   <= S_SHIFT;
            else
                if (timer >= DELAY_I) then
                    SAMPLE_O <= '1';
                    timer    <= (others => '0');
                    state    <= S_SAMPLE;
                end if;
            end if;

        when S_SHIFT =>
            if (counter /= "0000") then
                counter <= counter - '1';
                accu <= '0' & accu(accu'high downto 1);
            else
                DV_O   <= '1';
                DATA_O <= accu(15 downto 0);
                state  <= S_IDLE;
            end if;

        end case;

    end if;
end process;

end architecture;