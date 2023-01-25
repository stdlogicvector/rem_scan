LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
 
ENTITY pattern_tb IS
END pattern_tb;
 
ARCHITECTURE behavior OF pattern_tb IS 
   signal clk100		: std_logic := '0';
   signal reset		: std_logic := '1';
	
   signal pat_scan	: std_logic := '0';
	signal pat_busy	: std_logic;
		
   signal pat_offset_x : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_offset_y : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_steps_x : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_steps_y : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_delta_x : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_delta_y : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_ini_dly : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_row_dly : std_logic_vector(15 downto 0) := (others => '0');
   signal pat_col_dly : std_logic_vector(15 downto 0) := (others => '0');

   signal pat_dv		: std_logic;
   signal pat_x		: std_logic_vector(15 downto 0);
   signal pat_y		: std_logic_vector(15 downto 0);
   signal pat_sample	: std_logic;
   signal pat_row		: std_logic_vector(15 downto 0);
   signal pat_col		: std_logic_vector(15 downto 0);

	signal adc_sampled	: std_logic := '0';

   constant clk_period : time := 10 ns;
 
BEGIN

	pattern : entity work.pattern 
	PORT MAP (
		CLK_I 		=> clk100,
		RST_I 		=> reset,
		
		START_I 	=> pat_scan,
		ABORT_I		=> '0',
		BUSY_O 		=> pat_busy,
		
		OFFSET_X_I	=> pat_offset_x,
		OFFSET_Y_I	=> pat_offset_y,
		STEPS_X_I	=> pat_steps_x,
		STEPS_Y_I	=> pat_steps_y,
		DELTA_X_I	=> pat_delta_x,
		DELTA_Y_I	=> pat_delta_y,
		
		INI_DELAY_I	=> pat_ini_dly,
		ROW_DELAY_I	=> pat_row_dly,
		COL_DELAY_I	=> pat_col_dly,
		
		DV_O		=> pat_dv,
		X_O			=> pat_x,
		Y_O			=> pat_y,
		
		SAMPLE_O	=> pat_sample,
		SAMPLED_I	=> adc_sampled,
		ROW_O		=> pat_row,
		COL_O		=> pat_col
	);

   clk : process
   begin
		clk100 <= '0';
		wait for clk_period/2;
		clk100 <= '1';
		wait for clk_period/2;
   end process;
 
	sim : process
   begin		
      reset <= '1';
      wait for clk_period*10;
		reset <= '0';
		
		wait for clk_period*5;
		
		pat_offset_x <= x"0000";
		pat_offset_y <= x"0000";
		
		pat_steps_x	 <= x"000A";
		pat_steps_y	 <= x"000A";
		
		pat_delta_x	 <= x"0064";
		pat_delta_y	 <= x"0064";
		
		pat_ini_dly  <= x"0100";
		pat_row_dly  <= x"0010";
		pat_col_dly  <= x"0020";

	   wait for clk_period*10;

		pat_scan <= '1';
		wait until pat_busy = '1';
		pat_scan <= '0';

      wait;
   end process;

	adc_dummy : process
	begin
		wait until pat_sample = '1';
		wait for 50ns;
		adc_sampled <= '1';
		wait for clk_period;
		adc_sampled <= '0';
	end process;

END;
