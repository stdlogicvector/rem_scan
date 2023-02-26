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
		RAM_MODE_B		: string	:= "NO_CHANGE";			-- Select "READ_FIRST", "WRITE_FIRST" or "NO_CHANGE"
		INIT_FILE 		: string	:= ""; 			   		-- Specify name/location of RAM initialization file if using one (leave blank if not)
		FILE_TYPE		: string	:= "NUMBER";			-- BINARY, VECTOR, NUMBER
		NUM_SEPARATOR	: character := ' ';
		NUM_BASE		: integer	:= 16
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

impure function initramfrom_num (filename : in string) return ram_t is                                                   
	FILE ram_file       : text;
	variable ram		: ram_t;    
	variable ramline 	: line;  
	variable str		: string(1 to 64);
	variable char		: character;
	variable int		: integer;
	variable ok 		: boolean := true;
	variable C, I		: integer;
begin                     
	file_open(ram_file, filename, READ_MODE);

	I := 0;
	while I < RAM_DEPTH loop
		if (not endfile(ram_file)) then
			readline (ram_file, ramline);
			str := (others => character'val(0)); 
			C := 1;

			read(ramline, char, ok);

			while ok AND C < str'length 
			loop
				if (char /= NUM_SEPARATOR)
				then
					str(C) := char;
					C := C + 1;
				else
					int := str2int(str(1 to C-1), NUM_BASE);
				
					ram(I) := int2vec(int, RAM_WIDTH);
	
					I := I + 1;

					str := (others => character'val(0)); 
					C := 1;
				end if;

				read(ramline, char, ok);

			end loop;
		else
			ram(I) := int2vec(0, RAM_WIDTH);
			I := I + 1;
		end if;
	end loop;          
	
	file_close(ram_file);
	
	return ram;                                                  
end function;

impure function initramfrom_binary (filename : in string) return ram_t is
	type char_file_t is file of character;
	file ramfile 	: char_file_t;
	variable char 	: character;
	variable byte 	: integer := 0;
	variable vector : std_logic_vector(RAM_WIDTH-1 downto 0) := (others => '0');
	variable ram 	: ram_t;
	variable i 		: integer;
begin
	i := 0;
	file_open(ramfile, filename, READ_MODE);
	
	--for i in ram_t'range loop
	while not endfile(ramfile) AND i < RAM_DEPTH loop
		for s in 0 to (RAM_WIDTH/8)-1 loop
			read(ramfile, char);
			byte := character'pos(char);
			vector((s+1)*8-1 downto s*8) := int2vec(byte, 8);
		end loop;
		
		ram(i) := int2vec(i, RAM_WIDTH); -- vector; 
		
		i := i + 1;
	end loop;
	
	file_close(ramfile);
	
	return ram;
end function;

impure function initramfrom_vector (filename : in string) return ram_t is
	file ramfile : text is in filename;
	variable ramline : line;
	variable ram : ram_t;
	variable bitvec : bit_vector(RAM_WIDTH-1 downto 0);
begin
    for i in ram_t'range loop
		if not endfile(ramfile) then
        	readline (ramfile, ramline);
        	read (ramline, bitvec);
		end if;
		
        ram(i) := to_stdlogicvector(bitvec);
		
    end loop;
    return ram;
end function;

impure function init_ram(filename : string) return ram_t is
begin
    if filename /= "" then
		case (FILE_TYPE) is
		when "BINARY"	=> return initramfrom_binary(filename);
		when "NUMBER"	=> return initramfrom_num(filename);
		when "VECTOR"	=> return initramfrom_vector(filename);
		when others		=> return (others => (others => '0'));
		end case;
    else
        return (others => (others => '0'));
    end if;
end;

shared variable ram_array : ram_t := init_ram(INIT_FILE);

--attribute RAM_STYLE : string;
--attribute RAM_STYLE of ram_array: signal is "BLOCK";

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