library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use STD.TEXTIO.ALL;
use WORK.UTIL.ALL;

entity ram is
	generic(
		-- Note :
		-- If the chosen width and depth values are low, Synthesis will infer Distributed RAM.
		RAM_WIDTH 		: integer	:= 16;   		    	-- RAM data width
		RAM_DEPTH 		: integer	:= 2048;		 		-- RAM depth (number of entries), should be a power of 2
		RAM_PERF		: string	:= "HIGH_PERFORMANCE";	-- Select "HIGH_PERFORMANCE" or "LOW_LATENCY" 
		RAM_MODE_A		: string	:= "NO_CHANGE";			-- Select "READ_FIRST", "WRITE_FIRST" or "NO_CHANGE"
		RAM_MODE_B		: string	:= "NO_CHANGE"			-- Select "READ_FIRST", "WRITE_FIRST" or "NO_CHANGE"
	);
	port(
		RESET_I		: in	std_logic := '0';
		
		A_CLK_I		: in	std_logic;
		A_ENA_I		: in	std_logic := '1';
		A_WEN_I		: in	std_logic := '0';
		A_ADDR_I	: in	std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);
		A_DATA_I	: in	std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
		A_DATA_O	: out	std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
		
		B_CLK_I		: in	std_logic;
		B_ENA_I		: in	std_logic := '1';
		B_WEN_I		: in	std_logic := '0';
		B_ADDR_I	: in	std_logic_vector((clogb2(RAM_DEPTH)-1) downto 0);
		B_DATA_I	: in	std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
		B_DATA_O	: out	std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0')
	);
end ram;

architecture Behavioral of ram is

type ram_t is array (0 to RAM_DEPTH-1) of std_logic_vector (RAM_WIDTH-1 downto 0);

shared variable ram_array : ram_t := (others => (others => '0'));

signal ram_data_a	: std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
signal ram_data_b	: std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
signal out_reg_a	: std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
signal out_reg_b	: std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');

begin

process(A_CLK_I)
begin
    if rising_edge(A_CLK_I)
	then
        if (A_ENA_I = '1')
		then
			if RAM_MODE_A = "READ_FIRST" then
				ram_data_a <= ram_array(vec2int(A_ADDR_I));
				if (A_WEN_I = '1') then	
					ram_array(vec2int(A_ADDR_I)) := A_DATA_I;
				end if;
			end if;
			
			if RAM_MODE_A = "WRITE_FIRST" then
				if (A_WEN_I = '1') then	
					ram_array(vec2int(A_ADDR_I)) := A_DATA_I;
					ram_data_a <= A_DATA_I;
				else
					ram_data_a <= ram_array(vec2int(A_ADDR_I));
				end if;
			end if;
			
			if RAM_MODE_A = "NO_CHANGE" then
				if (A_WEN_I = '1') then	
					ram_array(vec2int(A_ADDR_I)) := A_DATA_I;
				else
					ram_data_a <= ram_array(vec2int(A_ADDR_I));
				end if;
			end if;
        end if;
    end if;
end process;

process(B_CLK_I)
begin
    if rising_edge(B_CLK_I)
	then
        if (B_ENA_I = '1')
		then
			if RAM_MODE_B = "READ_FIRST" then
				ram_data_b <= ram_array(vec2int(B_ADDR_I));
				if (B_WEN_I = '1') then	
					ram_array(vec2int(B_ADDR_I)) := B_DATA_I;
				end if;
			end if;
			
			if RAM_MODE_B = "WRITE_FIRST" then
				if (B_WEN_I = '1') then	
					ram_array(vec2int(B_ADDR_I)) := B_DATA_I;
					ram_data_b <= B_DATA_I;
				else
					ram_data_b <= ram_array(vec2int(B_ADDR_I));
				end if;
			end if;
			
			if RAM_MODE_B = "NO_CHANGE" then
				if (B_WEN_I = '1') then	
					ram_array(vec2int(B_ADDR_I)) := B_DATA_I;
				else
					ram_data_b <= ram_array(vec2int(B_ADDR_I));
				end if;
			end if;
        end if;
    end if;
end process;

--  Following code generates LOW_LATENCY (no output register)
--  Following is a 1 clock cycle read latency at the cost of a longer clock-to-out timing

LOW_LATENCY : if RAM_PERF = "LOW_LATENCY" generate
	A_DATA_O <= ram_data_a;
    B_DATA_O <= ram_data_b;
end generate;

--  Following code generates HIGH_PERFORMANCE (use output register)
--  Following is a 2 clock cycle read latency with improved clock-to-out timing

HIGH_PERFORMANCE : if RAM_PERF = "HIGH_PERFORMANCE" generate
	process(A_CLK_I)
	begin
		if rising_edge(A_CLK_I)
		then
			if (RESET_I = '1')
			then
				out_reg_a <= (others => '0');
			elsif (A_ENA_I = '1')
			then
				out_reg_a <= ram_data_a;
			end if;
		end if;
	end process;
	
	process(B_CLK_I)
	begin
		if rising_edge(B_CLK_I)
		then
			if (RESET_I = '1')
			then
				out_reg_b <= (others => '0');
			elsif (B_ENA_I = '1')
			then
				out_reg_b <= ram_data_b;
			end if;
		end if;
	end process;

	A_DATA_O <= out_reg_a;
	B_DATA_O <= out_reg_b;
end generate;

end Behavioral;