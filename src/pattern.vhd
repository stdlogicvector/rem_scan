library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity pattern is
	Port (
		CLK_I		: in	STD_LOGIC;
		RST_I		: in	STD_LOGIC;
		
		START_I		: in	STD_LOGIC;
		ABORT_I		: in	STD_LOGIC;
		BUSY_O		: out	STD_LOGIC := '0';
		
		OFFSET_X_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		OFFSET_Y_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		
		STEPS_X_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		STEPS_Y_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		
		DELTA_X_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		DELTA_Y_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
	
		INI_DELAY_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		ROW_DELAY_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
		COL_DELAY_I	: in 	STD_LOGIC_VECTOR (15 downto 0);
			
		DV_O		: out	STD_LOGIC := '0';
		X_O			: out	STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		Y_O			: out	STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		MOVED_I		: in	STD_LOGIC;
		
		SAMPLE_O	: out	STD_LOGIC := '0';
		SAMPLED_I	: in	STD_LOGIC;
		
		ROW_O		: out	STD_LOGIC_VECTOR (15 downto 0) := (others => '0');
		COL_O		: out	STD_LOGIC_VECTOR (15 downto 0) := (others => '0')
	);
end pattern;

architecture Behavioral of pattern is

type state_t is (
	S_IDLE,
	S_INIT,
	S_INI_DELAY,
	S_COL,
	S_COL_DELAY,
	S_ROW,
	S_ROW_DELAY,
	S_SAMPLE,
	S_WAIT_FOR_SAMPLE,
	S_WAIT_FOR_MOVE,
	S_ABORT
);

signal state	: state_t := S_IDLE;
signal nstate	: state_t := S_IDLE;

signal x,y		: signed(15 downto 0) := (others => '0');
signal dx,dy	: signed(15 downto 0) := (others => '0');
signal ox,oy	: signed(15 downto 0) := (others => '0');

signal sx,sy	: std_logic_vector(15 downto 0) := (others => '0');
signal row,col	: std_logic_vector(15 downto 0) := (others => '0');

signal timer	: std_logic_vector(15 downto 0) := (others => '0');

begin

X_O	<= std_logic_vector(x);
Y_O	<= std_logic_vector(y);

process(CLK_I)
begin
	if rising_edge(CLK_I)
	then
		if (RST_I = '1')
		then
			state <= S_IDLE;
		else
			SAMPLE_O	<= '0';
			DV_O		<= '0';
			
			timer	<= timer + '1';
			
			if (ABORT_I = '1')
			then
				state <= S_ABORT;
			end if;
			
			case (state) is
			when S_IDLE	=>
				x <= (others => '0');
				y <= (others => '0');
			
				if (START_I = '1')
				then
					state		<= S_INIT;
					
					ox <= signed(OFFSET_X_I);
					oy <= signed(OFFSET_Y_I);
				
					dx <= signed(DELTA_X_I);
					dy <= signed(DELTA_Y_I);
				
					sx <= STEPS_X_I;
					sy <= STEPS_Y_I;
					
					BUSY_O	<= '1';
				else
					BUSY_O	<= '0';
				end if;
				
			when S_INIT =>
				x		<= ox;
				y		<= oy;
				DV_O	<= '1';
				
				timer <= (others => '0');
				
				state	<= S_WAIT_FOR_MOVE;
				nstate	<= S_INI_DELAY;
			
			when S_INI_DELAY =>
				if (timer >= INI_DELAY_I) 
				then
					state <= S_SAMPLE;
					timer <= (others => '0');
					
					row	<= (others => '0');
					col	<= (others => '0');
				end if;

			when S_SAMPLE =>
				SAMPLE_O	<= '1';
				ROW_O		<= row;
				COL_O		<= col;
				state 		<= S_WAIT_FOR_SAMPLE;
					
			when S_WAIT_FOR_SAMPLE =>
				if (SAMPLED_I = '1')
				then
					state <= S_ROW;
				end if;
					
			when S_WAIT_FOR_MOVE =>
				if (MOVED_I = '1') then
					state <= nstate;
				end if;
					
			when S_ROW =>
				x		<= x + dx;
				row		<= row + '1';
				
				DV_O	<= '1';
				
				state	<= S_WAIT_FOR_MOVE;
				nstate	<= S_ROW_DELAY;
				
			when S_ROW_DELAY =>
				if (row >= sx)
				then
					state <= S_COL;
				else
					if (timer >= ROW_DELAY_I) 
					then
						state <= S_SAMPLE;
						timer <= (others => '0');
					end if;
				end if;
				
			when S_COL =>
				x		<= ox;
				row		<= (others => '0');
				
				y		<= y + dy;
				col		<= col + '1';
				
				DV_O	<= '1';
				
				state	<= S_WAIT_FOR_MOVE;
				nstate	<= S_COL_DELAY;
				
			when S_COL_DELAY =>
				if (col >= sy)
				then
					x 		<= (others => '0');
					y 		<= (others => '0');
					
					DV_O	<= '1';
				
					state	<= S_WAIT_FOR_MOVE;
					nstate	<= S_IDLE;
				else
					if (timer >= COL_DELAY_I) 
					then
						state <= S_SAMPLE;
						timer <= (others => '0');
					end if;
				end if;
			
			when S_ABORT => 
				x 		<= (others => '0');
				y 		<= (others => '0');
					
				DV_O	<= '1';
				
				state	<= S_WAIT_FOR_MOVE;
				nstate	<= S_IDLE;
				
			end case;
		end if;
	end if;
end process;

end Behavioral;

