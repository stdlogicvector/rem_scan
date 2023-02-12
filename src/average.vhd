library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.util.all;

entity average is
	Port (
		CLK_I 		: in	STD_LOGIC;
		RST_I 		: in	STD_LOGIC;

        ENABLE_I    : in    STD_LOGIC;
        ABORT_I     : in    STD_LOGIC;

        NUMBER_I    : in    STD_LOGIC_VECTOR( 7 downto 0);
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
    S_WAIT_FOR_DIV
);

signal state    : state_t := S_IDLE;
signal timer    : std_logic_vector(15 downto 0) := (others => '0');

signal number   : std_logic_vector( 7 downto 0) := (others => '0');
signal counter  : std_logic_vector( 7 downto 0) := (others => '0');
signal accu     : unsigned(23 downto 0) := (others => '0');
signal quotient : std_logic_vector(23 downto 0) := (others => '0');

signal div_dv   : std_logic;
signal div_rdy  : std_logic;

signal quot_dv  : std_logic;

begin

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        DV_O     <= '0';
        SAMPLE_O <= '0';

        div_dv <= '0';

        timer <= timer + '1';

        if (ABORT_I = '1') then
            state <= S_IDLE;
        end if;

        case (state) is
        when S_IDLE =>
            if (ENABLE_I = '1' AND SAMPLE_I = '1' AND number /= "0000") then
                state   <= S_SAMPLE;
                accu    <= (others => '0');
                timer   <= (others => '0');
                counter <= (others => '0');
            end if;

            number   <= NUMBER_I;
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
            if (counter >= number) then
                if (div_rdy = '1') then
                    div_dv  <= '1';
                    state   <= S_WAIT_FOR_DIV;
                end if;
            else
                if (timer >= DELAY_I) then
                    SAMPLE_O <= '1';
                    timer    <= (others => '0');
                    state    <= S_SAMPLE;
                end if;
            end if;

        when S_WAIT_FOR_DIV =>
            if (quot_dv = '1') then
                DV_O    <= '1';
                DATA_O  <= quotient(15 downto 0);

                state <= S_IDLE;
            end if;
        end case;

    end if;
end process;

div : entity work.divider(Unsigned_Pipelined)
generic map (
    DIVIDEND_WIDTH  => 24,
    DIVISOR_WIDTH   => 8,
    FRACTIONAL      => false,
    REMAINDER       => false
)
port map (
    CLK_I           => CLK_I,
    RST_I           => RST_I,

    DV_I            => div_dv,
    READY_O         => div_rdy,
    DIVIDEND_I      => std_logic_vector(accu),
    DIVISOR_I       => number,

    DV_O            => quot_dv,
    DIV_BY_ZERO_O   => open,
    OVERFLOW_O      => open,
    QUOTIENT_O      => quotient
);



end architecture;