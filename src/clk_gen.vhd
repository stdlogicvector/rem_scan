library IEEE, UNISIM;
use IEEE.STD_LOGIC_1164.ALL;
use UNISIM.vcomponents.all;
use work.util.all;

entity clk_gen is
	Generic (
		CLK_IN_PERIOD	: real			:= 20.0;
		DIFF_CLK_IN		: boolean		:= false;
		BUF_CLK_IN		: boolean		:= false;
		CLKFB_MULT		: integer		:= 20;
		DIVCLK_DIVIDE	: integer		:= 1;           			-- Master division value (1-106)
		CLK_OUT_DIVIDE	: integer_vector(6 downto 0) := (others => 1)
	);
	Port (
		CLK_Ip		: in	STD_LOGIC;
		CLK_In		: in	STD_LOGIC := '0';
		
		LOCKED_O	: out	STD_LOGIC := '0';
		
		CLK0_O		: out	STD_LOGIC := '0';
		CLK1_O		: out	STD_LOGIC := '0';
		CLK2_O		: out	STD_LOGIC := '0';
		CLK3_O		: out	STD_LOGIC := '0';
		CLK4_O		: out	STD_LOGIC := '0';
		CLK5_O		: out	STD_LOGIC := '0'
	);
end clk_gen;

architecture Behavioral of clk_gen is

signal in_clk	: std_logic := '0';
signal fb_clk	: std_logic := '0';
signal fb_clk_b : std_logic := '0';

signal clk_out	: std_logic_vector(5 downto 0) := (others => '0');

begin

diff_buf : if DIFF_CLK_IN = TRUE generate
	diff : IBUFDS
	port map (
		I	=> CLK_Ip,
		IB	=> CLK_In,
		O	=> in_clk
	);
end generate;

no_diff_buf : if DIFF_CLK_IN = FALSE AND BUF_CLK_IN = TRUE generate
	buf : BUFG
	port map (
		I	=> CLK_Ip,
		O	=> in_clk
	);
end generate;

no_buf : if DIFF_CLK_IN = FALSE AND BUF_CLK_IN = FALSE generate
	in_clk <= CLK_Ip;
end generate;

pll : PLL_BASE
   generic map (
      BANDWIDTH				=> "OPTIMIZED",			-- "HIGH", "LOW" or "OPTIMIZED" 
      CLKFBOUT_MULT			=> CLKFB_MULT,			-- Multiply value for all CLKOUT clock outputs (1-64)
      CLKFBOUT_PHASE		=> 0.0,					-- Phase offset in degrees of the clock feedback output(0.0-360.0).
      CLKIN_PERIOD			=> CLK_IN_PERIOD,		-- Input clock period in ns to ps resolution (i.e. 33.333 is 30MHz).
      -- CLKOUT0_DIVIDE - CLKOUT5_DIVIDE: Divide amount for CLKOUT# clock output (1-128)
      CLKOUT0_DIVIDE		=> CLK_OUT_DIVIDE(0),
      CLKOUT1_DIVIDE		=> CLK_OUT_DIVIDE(1),
      CLKOUT2_DIVIDE		=> CLK_OUT_DIVIDE(2),
      CLKOUT3_DIVIDE		=> CLK_OUT_DIVIDE(3),
      CLKOUT4_DIVIDE		=> CLK_OUT_DIVIDE(4),
      CLKOUT5_DIVIDE		=> CLK_OUT_DIVIDE(5),
      -- CLKOUT0_DUTY_CYCLE - CLKOUT5_DUTY_CYCLE: Duty cycle for CLKOUT# clock output (0.01-0.99).
      CLKOUT0_DUTY_CYCLE	=> 0.5,
      CLKOUT1_DUTY_CYCLE	=> 0.5,
      CLKOUT2_DUTY_CYCLE	=> 0.5,
      CLKOUT3_DUTY_CYCLE	=> 0.5,
      CLKOUT4_DUTY_CYCLE	=> 0.5,
      CLKOUT5_DUTY_CYCLE	=> 0.5,
      -- CLKOUT0_PHASE - CLKOUT5_PHASE: Output phase relationship for CLKOUT# clock output (-360.0-360.0).
      CLKOUT0_PHASE			=> 0.0,
      CLKOUT1_PHASE			=> 0.0,
      CLKOUT2_PHASE			=> 0.0,
      CLKOUT3_PHASE			=> 0.0,
      CLKOUT4_PHASE			=> 0.0,
      CLKOUT5_PHASE			=> 0.0,
      CLK_FEEDBACK			=> "CLKFBOUT",          -- Clock source to drive CLKFBIN ("CLKFBOUT" or "CLKOUT0")
      COMPENSATION			=> "SYSTEM_SYNCHRONOUS",-- "SYSTEM_SYNCHRONOUS", "SOURCE_SYNCHRONOUS", "EXTERNAL" 
      DIVCLK_DIVIDE			=> DIVCLK_DIVIDE,		-- Division value for all output clocks (1-52)
      REF_JITTER			=> 0.1,                 -- Reference Clock Jitter in UI (0.000-0.999).
      RESET_ON_LOSS_OF_LOCK => FALSE        		-- Must be set to FALSE
   )
   port map (
      CLKFBOUT		=> fb_clk,
      CLKOUT0		=> clk_out(0),
      CLKOUT1		=> clk_out(1),
      CLKOUT2		=> clk_out(2),
      CLKOUT3		=> clk_out(3),
      CLKOUT4		=> clk_out(4),
      CLKOUT5		=> clk_out(5),
      LOCKED		=> LOCKED_O,
      CLKFBIN		=> fb_clk_b,
      CLKIN			=> in_clk,
      RST 			=> '0'
   );

fb_buf : BUFG
port map (
	I	=> fb_clk,
	O	=> fb_clk_b
);

buf0 : BUFG
port map (
	I	=> clk_out(0),
	O	=> CLK0_O
);

out1 : if CLK_OUT_DIVIDE(1) > 0 generate
	buf1 : BUFG
	port map (
		I	=> clk_out(1),
		O	=> CLK1_O
	);
end generate;

no_out1 : if CLK_OUT_DIVIDE(1) = 0 generate
	CLK1_O <= '0';
end generate;
	
out2 : if CLK_OUT_DIVIDE(2) > 0 generate
	buf : BUFG
	port map (
		I	=> clk_out(2),
		O	=> CLK2_O
	);
end generate;

no_out2 : if CLK_OUT_DIVIDE(2) = 0 generate
	CLK2_O <= '0';
end generate;

out3 : if CLK_OUT_DIVIDE(3) > 0 generate
	buf1: BUFG
	port map (
		I	=> clk_out(3),
		O	=> CLK3_O
	);
end generate;

no_out3 : if CLK_OUT_DIVIDE(3) = 0 generate
	CLK3_O <= '0';
end generate;

out4 : if CLK_OUT_DIVIDE(4) > 0 generate
	buf : BUFG
	port map (
		I	=> clk_out(4),
		O	=> CLK4_O
	);
end generate;

no_out4 : if CLK_OUT_DIVIDE(4) = 0 generate
	CLK4_O <= '0';
end generate;

out5 : if CLK_OUT_DIVIDE(5) > 0 generate
	buf : BUFG
	port map (
		I	=> clk_out(5),
		O	=> CLK5_O
	);
end generate;

no_out5 : if CLK_OUT_DIVIDE(5) = 0 generate
	CLK5_O <= '0';
end generate;
	
end Behavioral;

