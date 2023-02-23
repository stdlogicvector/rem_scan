library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.VCOMPONENTS.ALL;
use work.util.all;

entity vga is
	Port (
		CLK_I    	: IN STD_LOGIC;
		RST_I  		: IN STD_LOGIC;
		
        ADDR_O      : OUT STD_LOGIC_VECTOR(16 downto 0) := (others => '0');
        DATA_I      : IN  STD_LOGIC_VECTOR(7 downto 0);
		
        HSYNC_O     : OUT STD_LOGIC := '1';
        VSYNC_O     : OUT STD_LOGIC := '1';
        GRAY_O      : OUT STD_LOGIC_VECTOR(7 downto 0) := (others => '0')
	);
end vga;

architecture Behavioral of vga is
    
    constant h_visible  : integer := 800;    
    constant h_front    : integer := 56;
    constant h_sync     : integer := 120;
    constant h_back     : integer := 64;
    constant h_count    : integer := h_visible + h_front + h_sync + h_back - 1;

    constant v_visible  : integer := 600;    
    constant v_front    : integer := 37;
    constant v_sync     : integer := 6;
    constant v_back     : integer := 23;
    constant v_count    : integer := v_visible + v_front + v_sync + v_back - 1;

    constant pixels     : integer := h_visible * v_visible - 1;

    signal h        : integer range 0 to h_count := 0;
    signal v        : integer range 0 to v_count := 0;

    signal r,c      : std_logic := '0';

    signal col      : integer range 0 to h_visible-1 := 0;
    signal row      : integer range 0 to v_visible-1 := 0;

    signal hsync    : std_logic_vector(3 downto 0) := (others => '0');
    signal vsync    : std_logic_vector(3 downto 0) := (others => '0');

begin

HSYNC_O <= hsync(hsync'high);
VSYNC_O <= vsync(vsync'high);

process(CLK_I)
begin
    if rising_edge(CLK_I) then
        if (RST_I = '1') then
            h <= 0;
            v <= 0;
        else
            hsync(hsync'high downto 1) <= hsync(hsync'high-1 downto 0);
            vsync(vsync'high downto 1) <= vsync(vsync'high-1 downto 0);

            ADDR_O  <= int2vec(row + col, 17);

            h <= h + 1;

            if (h = h_count) then
                h <= 0;
                v <= v + 1;
                
                col <= 0;
                r   <= not r;

                if (r = '1') then           -- Every second screen row advance one row in RAM
                    row <= row + h_visible/2;
                end if;

            end if;

            if (v = v_count) then
                v <= 0;

                row <= 0;
                r   <= '0';
                c   <= '0';
            end if;

            if  (v < v_visible)
            and (h < h_visible)
            then
                c <= not c;

                if (c = '1') then   -- Every second screen pixel advance one pixel in RAM
                    col <= col + 1;
                end if;

                GRAY_O  <= DATA_I;
            else
                GRAY_O <= (others => '0');
            end if;

            if  (h >= (h_visible + h_front))
            and (h < (h_visible + h_front + h_sync))
            then
                hsync(0) <= '0';
            else
                hsync(0) <= '1';
            end if;

            if  (v >= (v_visible + v_front))
            and (v < (v_visible + v_front + v_sync))
            then
                vsync(0) <= '0';
            else
                vsync(0) <= '1';
            end if;

        end if;
    end if;
end process;

end architecture;
