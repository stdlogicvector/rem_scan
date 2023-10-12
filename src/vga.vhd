library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.util.all;

entity vga is
	Port (
		CLK_I    	: IN	STD_LOGIC;
		RST_I  		: IN	STD_LOGIC;
		
        ENABLE_I 	: IN	STD_LOGIC := '0';
		SCALE_I		: IN	STD_LOGIC_VECTOR(1 downto 0) := "00";
		
		READ_O		: OUT	STD_LOGIC := '0';
        ADDR_O      : OUT	STD_LOGIC_VECTOR(18 downto 0) := (others => '0');
        DATA_I      : IN	STD_LOGIC_VECTOR(7 downto 0);
		
        HSYNC_O     : OUT	STD_LOGIC := '1';
        VSYNC_O     : OUT	STD_LOGIC := '1';
        GRAY_O      : OUT	STD_LOGIC_VECTOR(7 downto 0) := (others => '0')
	);
end vga;

architecture Behavioral of vga is
    
	constant MAX_SCALE	: integer := 4;
	
--    constant scale      : integer := 1;
    constant delay      : integer := 3;

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
	
	signal row_width : integer range 0 to h_visible := h_visible;
	
	signal scale	: integer range 0 to MAX_SCALE-1 := 0;
	
	signal dv		: std_logic := '0';

    signal h        : integer range 0 to h_count := 0;
    signal v        : integer range 0 to v_count := 0;

	signal rc_max	: integer range 0 to 2**(MAX_SCALE-1) := 0;
    signal r,c      : integer range 0 to 2**(MAX_SCALE-1) := 0;

    signal col      : integer range 0 to (h_visible)-1 := 0;
    signal row      : integer range 0 to (v_visible*h_visible)-1 := 0;

    signal hsync    : std_logic_vector(delay-1 downto 0) := (others => '0');
    signal vsync    : std_logic_vector(delay-1 downto 0) := (others => '0');
    signal enable   : std_logic_vector(delay-1 downto 0) := (others => '0');

    signal data     : std_logic_vector(7 downto 0) := (others => '0');

begin

HSYNC_O <= hsync(hsync'high);
VSYNC_O <= vsync(vsync'high);
GRAY_O  <= DATA_I when enable(enable'high) = '1' else (others => '0');
READ_O	<= hsync(hsync'high);

process(CLK_I)
begin
    if rising_edge(CLK_I) then
		hsync(hsync'high downto 1) <= hsync(hsync'high-1 downto 0);
		vsync(vsync'high downto 1) <= vsync(vsync'high-1 downto 0);
		enable(enable'high downto 1) <= enable(enable'high-1 downto 0);

		ADDR_O  <= int2vec(row + col, 19);

		case (scale) is
			when 0 => row_width <= h_visible / 1;	rc_max <= 0;
			when 1 => row_width <= h_visible / 2;	rc_max <= 1;
			when 2 => row_width <= h_visible / 4;	rc_max <= 3;
			when 3 => row_width <= h_visible / 8;	rc_max <= 7;
		end case;

		if (ENABLE_I = '1') then
			dv <= not dv;	-- Divide Clock by 2
		else
			h <= 0;
			v <= 0;
			row <= 0;
			col <= 0;
		end if;

		if (dv = '1') then
			h <= h + 1;
		end if;

		if (h = h_count) then
			h <= 0;
			v <= v + 1;
			
			col <= 0;

			if (r = rc_max) then           -- Every nth screen row advance one row in RAM
				r <= 0;
				row <= row + row_width;
			else
				r <= r + 1;
			end if;

		end if;

		if (v = v_count) then
			v <= 0;

			row <= 0;
			r   <= 0;
			
			if (scale > 0) then
				c   <= 1;
			end if;
		end if;

		if  (v < v_visible)
		and (h < h_visible)
		then
			if (dv = '1') then
				if (c = rc_max) then           -- Every nth screen pixel advance one pixel in RAM
					c <= 0;
					col <= col + 1;
				else
					c <= c + 1;
				end if;
			end if;

			enable(0)  <= '1';
		else
			enable(0)  <= '0';
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
			
			scale <= vec2int(SCALE_I);
		else
			vsync(0) <= '1';
		end if;

    end if;
end process;

end architecture;
