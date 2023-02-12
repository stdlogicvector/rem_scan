library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
--use IEEE.STD_LOGIC_MISC.ALL;
use work.util.all;

entity divider is
	Generic (
		DIVIDEND_WIDTH	: integer := 16;
		DIVISOR_WIDTH	: integer := 16;
		FRACTIONAL_WIDTH: integer := 16;
		FRACTIONAL 		: boolean := false;
		REMAINDER		: boolean := false
	);
	Port (
		CLK_I			: in	std_logic;
		RST_I			: in	std_logic;
		
		DV_I			: in	std_logic;
		READY_O			: out	std_logic := '0';
		DIVIDEND_I		: in	std_logic_vector(DIVIDEND_WIDTH-1 downto 0);
		DIVISOR_I		: in	std_logic_vector(DIVISOR_WIDTH-1 downto 0);
		
		DV_O			: out	std_logic := '0';
		DIV_BY_ZERO_O	: out	std_logic := '0';
		OVERFLOW_O		: out	std_logic := '0';
		QUOTIENT_O		: out	std_logic_vector(DIVIDEND_WIDTH-1 downto 0) 	:= (others => '0');
		FRACTIONAL_O	: out	std_logic_vector(FRACTIONAL_WIDTH-1 downto 0)	:= (others => '0');
		REMAINDER_O		: out	std_logic_vector(DIVISOR_WIDTH-1 downto 0)		:= (others => '0')
	);
end divider;

architecture Unsigned_NonPipelined of divider is

--/* Resource Usage for DIVIDEND_WIDTH=16, DIVISOR_WIDTH=16, FRACTIONAL_WIDTH=8
--
--+---Adders : 
--	   3 Input     16 Bit       Adders := 1     
--	   2 Input      5 Bit       Adders := 1     
--+---Registers : 
--	               24 Bit    Registers := 2     
--	               16 Bit    Registers := 4     
--	                8 Bit    Registers := 1     
--	                5 Bit    Registers := 1     
--	                1 Bit    Registers := 4     
--+---Muxes : 
--	   2 Input     24 Bit        Muxes := 2     
--	   5 Input     24 Bit        Muxes := 2     
--	   2 Input     16 Bit        Muxes := 2     
--	   5 Input     16 Bit        Muxes := 1     
--	   5 Input      5 Bit        Muxes := 1     
--	   5 Input      3 Bit        Muxes := 1     
--	   2 Input      3 Bit        Muxes := 3     
--	   5 Input      1 Bit        Muxes := 9     
--	   2 Input      1 Bit        Muxes := 1 
--	   
--*/

type state_t is (S_IDLE, S_PREPARE, S_SHIFT, S_SUB, S_RESULT);
signal state	: state_t := S_IDLE;

type phase_t is (P_INTEGER, P_FRACTIONAL);
signal phase	: phase_t := P_INTEGER;

constant DIV_WIDTH	: integer := switch(FRACTIONAL, DIVIDEND_WIDTH+FRACTIONAL_WIDTH, DIVIDEND_WIDTH);

signal dividend : unsigned(DIV_WIDTH-1 downto 0) := (others => '0');
signal divisor	: unsigned(DIVIDEND_WIDTH-1 downto 0) := (others => '0');
signal quot 	: unsigned(DIV_WIDTH-1 downto 0) := (others => '0');
signal remn		: unsigned(DIVIDEND_WIDTH-1 downto 0) := (others => '0');

signal b		: integer range DIV_WIDTH downto 0 := 0;

begin

assert (DIV_WIDTH>DIVISOR_WIDTH) report "Dividend Width (+ Fractional Width) must be greater than or equal to Divisor Width." severity Error;

process(CLK_I)
variable difference : unsigned(DIVIDEND_WIDTH-1 downto 0);
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			state <= S_IDLE;
		end if;
--		else
			DV_O <= '0';
			
			case (state) is
			when S_IDLE =>
				READY_O <= '1';
				
				if DV_I = '1' then
					state 	<= S_PREPARE;
					READY_O	<= '0';
				end if;
				
				-- Pad right = Multiply by FRACTIONAL_WIDTH
				dividend	<= unsigned(pad(-DIV_WIDTH, DIVIDEND_I));
				divisor 	<= unsigned(pad(DIVIDEND_WIDTH, DIVISOR_I));
				
			when S_PREPARE =>
				READY_O	<= '0';
				
				DIV_BY_ZERO_O	<= '0';
				OVERFLOW_O		<= '0';
				
				b		<= DIV_WIDTH;
				
				quot 	<= (others => '0');
				remn	<= (others => '0');
				
				state	<= S_SHIFT;
				
				if (divisor = 0) then
					quot			<= (others => '1');
					remn			<= (others => '1');
					DIV_BY_ZERO_O	<= '1';
					state			<= S_RESULT;
				elsif (divisor > dividend) then
					remn			<= dividend(DIVIDEND_WIDTH-1 downto 0);
					OVERFLOW_O		<= '1';
					state			<= S_RESULT;
				elsif (divisor = dividend) then
					quot 			<= (0 => '1', others => '0');
					state			<= S_RESULT;
				end if;

			when S_SHIFT =>
				READY_O	<= '0';
				
				if (remn(remn'high-1 downto 0) & dividend(dividend'high)) < divisor then
					b			<= b - 1;
					remn		<= remn(remn'high-1 downto 0) & dividend(dividend'high);
					dividend	<= dividend(dividend'high-1 downto 0) & '0';
				else
					state <= S_SUB;
				end if;
			
			when S_SUB =>
				READY_O	<= '0';
				
				if (b > 0) then
					remn		<= remn(remn'high-1 downto 0) & dividend(dividend'high);
					dividend	<= dividend(dividend'high-1 downto 0) & '0';
					
					difference	:= (remn(remn'high-1 downto 0) & dividend(dividend'high)) - divisor;
					
					if (difference(difference'high) = '0') then
						quot	<= quot(quot'high-1 downto 0) & '1';
						remn	<= difference;
					else
						quot	<= quot(quot'high-1 downto 0) & '0';
					end if;
					
					b <= b - 1;
				else
					state <= S_RESULT;
				end if;			
				
			when S_RESULT =>
				DV_O 	<= '1';
				
				QUOTIENT_O	<= std_logic_vector(quot(quot'high downto quot'high-DIVIDEND_WIDTH+1));
				REMAINDER_O	<= std_logic_vector(remn(DIVISOR_WIDTH-1 downto 0));
				
				if (FRACTIONAL = TRUE) then
					FRACTIONAL_O	<= std_logic_vector(quot(FRACTIONAL_WIDTH-1 downto 0));
				end if;
				
				state <= S_IDLE;

			end case;
--		end if;
	end if;
end process;

end architecture;

architecture Signed_Pipelined of divider is

--/*   Resource Usage for DIVIDEND_WIDTH=26, DIVISOR_WIDTH=10, FRACTIONAL_WIDTH=0
--
--+---Adders : 
--	   3 Input     27 Bit       Adders := 27    
--	   2 Input     26 Bit       Adders := 1     
--+---XORs : 
--	   2 Input      1 Bit         XORs := 1     
--+---Registers : 
--	               27 Bit    Registers := 53    
--	               26 Bit    Registers := 27    
--	               10 Bit    Registers := 1     
--	                1 Bit    Registers := 3     
--+---Muxes : 
--	   2 Input     27 Bit        Muxes := 27    
--	   2 Input     26 Bit        Muxes := 3     
--*/

constant DIV_WIDTH	: integer := switch(FRACTIONAL, DIVIDEND_WIDTH+FRACTIONAL_WIDTH, DIVIDEND_WIDTH);

function gen_r(ri : std_logic_vector(DIVIDEND_WIDTH downto 0);
			   qi : std_logic_vector(DIVIDEND_WIDTH downto 0);
			   di : std_logic_vector(DIVIDEND_WIDTH downto 0)
			  )
		return std_logic_vector is
begin
	if (ri(ri'high) = '1') then
		return std_logic_vector(unsigned(ri(ri'high-1 downto 0) & qi(qi'high)) + unsigned(di));
	else
		return std_logic_vector(unsigned(ri(ri'high-1 downto 0) & qi(qi'high)) - unsigned(di));
	end if;
end function;

function gen_q(qi : std_logic_vector(DIVIDEND_WIDTH downto 0);
			   ri : std_logic_vector(DIVIDEND_WIDTH downto 0)
			  )
		return std_logic_vector is
begin
	return qi(qi'high-1 downto 0) & (NOT ri(ri'high));
end function;
	
function assign_r(ri : std_logic_vector(DIVIDEND_WIDTH downto 0);
				  di : std_logic_vector(DIVIDEND_WIDTH downto 0)
				 )
		return std_logic_vector is
variable tmp : std_logic_vector(DIVIDEND_WIDTH downto 0);
begin
	if (ri(ri'high) = '1') then
		tmp := std_logic_vector(unsigned(ri) + unsigned(di));
	else
		tmp := ri;
	end if;
	
	return tmp(DIVIDEND_WIDTH-1 downto DIVIDEND_WIDTH-DIVISOR_WIDTH);
end function;

type q_pipe_t	is array(DIVIDEND_WIDTH downto 0) of std_logic_vector(DIVIDEND_WIDTH downto 0);
signal q_pipe	: q_pipe_t := (others => (others => '0'));

type r_pipe_t	is array(DIVIDEND_WIDTH+1 downto 0) of std_logic_vector(DIVIDEND_WIDTH downto 0);
signal r_pipe	: r_pipe_t := (others => (others => '0'));

type d_pipe_t	is array(DIVIDEND_WIDTH+1 downto 0) of std_logic_vector(DIVIDEND_WIDTH downto 0);
signal d_pipe	: d_pipe_t := (others => (others => '0'));

signal dsgn, qsgn		: std_logic_vector(DIVIDEND_WIDTH+1 downto 0) := (others => '0');
signal dv, ovf, dbz		: std_logic_vector(DIVIDEND_WIDTH+1 downto 0) := (others => '0');

begin

READY_O		<= '1';	-- Pipelined Architecture is always ready


dv(0)	<= DV_I;
qsgn(0)	<= DIVIDEND_I(DIVIDEND_I'high); 

process(DIVISOR_I(DIVISOR_I'high), DIVIDEND_I)
begin
	if (DIVIDEND_I(DIVIDEND_I'high) = '1') then			-- Negative ?
		q_pipe(0)	<= '0' & add(NOT DIVIDEND_I, 1);	-- Absolute Value
	else
		q_pipe(0)	<= '0' & DIVIDEND_I;
	end if;
end process;

r_pipe(0)	<= (others => '0');
dsgn(0)		<= DIVISOR_I(DIVISOR_I'high);

A : if (DIVISOR_WIDTH <= DIVIDEND_WIDTH) generate
	process(DIVISOR_I(DIVISOR_I'high), DIVISOR_I)
	begin
		if (DIVISOR_I(DIVISOR_I'high) = '1') then
			d_pipe(0)	<= '0' & pad(DIVIDEND_WIDTH, add(NOT DIVISOR_I, 1));
		else
			d_pipe(0)	<= '0' & pad(DIVIDEND_WIDTH, DIVISOR_I);
		end if;
	end process;
end generate;
	
B : if (DIVISOR_WIDTH > DIVIDEND_WIDTH) generate
	process(DIVISOR_I(DIVISOR_I'high), DIVISOR_I)
	begin
		if (DIVISOR_I(DIVISOR_I'high) = '1') then
			d_pipe(0)	<= '0' & pad(DIVIDEND_WIDTH, add(NOT DIVISOR_I(DIVISOR_WIDTH-1 downto DIVISOR_WIDTH-DIVIDEND_WIDTH), 1));
		else
			d_pipe(0)	<= '0' & DIVISOR_I(DIVISOR_WIDTH-1 downto DIVISOR_WIDTH-DIVIDEND_WIDTH);
		end if;
	end process;
end generate;

process(d_pipe(0), q_pipe(0))
begin
	if (d_pipe(0) > q_pipe(0)) then
		ovf(0)		<= '1';
	else
		ovf(0)		<= '0';
	end if;
end process;

dbz(0)		<= NOT or_reduce(DIVISOR_I);

process(CLK_I)
variable q	 : std_logic_vector(DIVIDEND_WIDTH downto 0) := (others => '0');
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			dv(dv'high downto 1)		<= (others => '0');
--			dbz(dbz'high downto 1)	<= (others => '0');
		end if;
--		else
			dv(dv'high downto 1)			<= dv(dv'high-1 downto 0);
			dbz(dbz'high downto 1)			<= dbz(dbz'high-1 downto 0);
			dsgn(dsgn'high downto 1)		<= dsgn(dsgn'high-1 downto 0);
			qsgn(qsgn'high downto 1)		<= qsgn(qsgn'high-1 downto 0);
			d_pipe(d_pipe'high downto 1) 	<= d_pipe(d_pipe'high-1 downto 0);
			
			for i in 1 to DIVIDEND_WIDTH+1 loop
				r_pipe(i) <= gen_r(r_pipe(i-1), q_pipe(i-1), d_pipe(i-1));
			end loop;
			
			for i in 1 to DIVIDEND_WIDTH loop
				q_pipe(i) <= gen_q(q_pipe(i-1), r_pipe(i));
			end loop;	
			
			q := gen_q(q_pipe(q_pipe'high), r_pipe(r_pipe'high));
			
			DV_O			<= dv(dv'high);
			DIV_BY_ZERO_O 	<= dbz(dbz'high);
			OVERFLOW_O		<= ovf(ovf'high);
			
			if (qsgn(qsgn'high) XOR dsgn(dsgn'high)) = '1' then				-- Different Sign of Dividend and Divisor
				QUOTIENT_O		<= add(NOT q(DIVIDEND_WIDTH-1 downto 0), 1);
			else
				QUOTIENT_O		<= q(DIVIDEND_WIDTH-1 downto 0);
			end if;
			
			if (REMAINDER = TRUE) then
				if (qsgn(qsgn'high) = '1') then
					REMAINDER_O		<= add(NOT assign_r(r_pipe(r_pipe'high), d_pipe(d_pipe'high)), 1);
				else
					REMAINDER_O		<= assign_r(r_pipe(r_pipe'high), d_pipe(d_pipe'high));
				end if;
			else	
				REMAINDER_O 	<= (others => '0');
			end if;
--		end if;
	end if;
end process;

end architecture;

architecture Unsigned_Pipelined of divider is

--/*
--  Resource Usage for DIVIDEND_WIDTH=28, DIVISOR_WIDTH=10, FRACTIONAL_WIDTH=0
--
--+---Adders : 
--	   3 Input     29 Bit       Adders := 29    
--+---Registers : 
--	               29 Bit    Registers := 57    
--	               28 Bit    Registers := 29    
--	               10 Bit    Registers := 1     
--	                1 Bit    Registers := 3     
--+---Muxes : 
--	   2 Input     29 Bit        Muxes := 29   
--	   
--*/

constant DIV_WIDTH	: integer := switch(FRACTIONAL, DIVIDEND_WIDTH+FRACTIONAL_WIDTH, DIVIDEND_WIDTH);

function gen_r(ri : std_logic_vector(DIVIDEND_WIDTH downto 0);
			   qi : std_logic_vector(DIVIDEND_WIDTH downto 0);
			   di : std_logic_vector(DIVIDEND_WIDTH downto 0)
			  )
		return std_logic_vector is
begin
	if (ri(ri'high) = '1') then
		return std_logic_vector(unsigned(ri(ri'high-1 downto 0) & qi(qi'high)) + unsigned(di));
	else
		return std_logic_vector(unsigned(ri(ri'high-1 downto 0) & qi(qi'high)) - unsigned(di));
	end if;
end function;

function gen_q(qi : std_logic_vector(DIVIDEND_WIDTH downto 0);
			   ri : std_logic_vector(DIVIDEND_WIDTH downto 0)
			  )
		return std_logic_vector is
begin
	return qi(qi'high-1 downto 0) & (NOT ri(ri'high));
end function;
	
function assign_r(ri : std_logic_vector(DIVIDEND_WIDTH downto 0);
				  di : std_logic_vector(DIVIDEND_WIDTH downto 0)
				 )
		return std_logic_vector is
variable tmp : std_logic_vector(DIVIDEND_WIDTH downto 0);
begin
	if (ri(ri'high) = '1') then
		tmp := std_logic_vector(unsigned(ri) + unsigned(di));
	else
		tmp := ri;
	end if;
	
	return tmp(DIVIDEND_WIDTH-1 downto DIVIDEND_WIDTH-DIVISOR_WIDTH);
end function;

type q_pipe_t	is array(DIVIDEND_WIDTH downto 0) of std_logic_vector(DIVIDEND_WIDTH downto 0);
signal q_pipe	: q_pipe_t := (others => (others => '0'));

type r_pipe_t	is array(DIVIDEND_WIDTH+1 downto 0) of std_logic_vector(DIVIDEND_WIDTH downto 0);
signal r_pipe	: r_pipe_t := (others => (others => '0'));

type d_pipe_t	is array(DIVIDEND_WIDTH+1 downto 0) of std_logic_vector(DIVIDEND_WIDTH downto 0);
signal d_pipe	: d_pipe_t := (others => (others => '0'));

signal dv, ovf, dbz : std_logic_vector(DIVIDEND_WIDTH+1 downto 0) := (others => '0');

begin

READY_O		<= '1';	-- Pipelined Architecture is always ready

dv(0)		<= DV_I;
q_pipe(0)	<= '0' & DIVIDEND_I;
r_pipe(0)	<= (others => '0');

A : if (DIVISOR_WIDTH <= DIVIDEND_WIDTH) generate
	d_pipe(0)	<= '0' & pad(DIVIDEND_WIDTH, DIVISOR_I);
end generate;

B : if (DIVISOR_WIDTH > DIVIDEND_WIDTH) generate
	d_pipe(0)	<= '0' & DIVISOR_I(DIVISOR_WIDTH-1 downto DIVISOR_WIDTH-DIVIDEND_WIDTH);
end generate;

process(d_pipe(0), q_pipe(0))
begin
	if (d_pipe(0) > q_pipe(0)) then
		ovf(0)		<= '1';
	else
		ovf(0)		<= '0';
	end if;
end process;

dbz(0)		<= NOT or_reduce(DIVISOR_I);

process(CLK_I)
	variable q	 : std_logic_vector(DIVIDEND_WIDTH downto 0) := (others => '0');
	begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			dv(dv'high downto 1)		<= (others => '0');
--			dbz(dbz'high downto 1)	<= (others => '0');
		end if;
--		else
			dv(dv'high downto 1)		<= dv(dv'high-1 downto 0);
			dbz(dbz'high downto 1)	<= dbz(dbz'high-1 downto 0);
			d_pipe(d_pipe'high downto 1) 		<= d_pipe(d_pipe'high-1 downto 0);
			
			for i in 1 to DIVIDEND_WIDTH+1 loop
				r_pipe(i) <= gen_r(r_pipe(i-1), q_pipe(i-1), d_pipe(i-1));
			end loop;
			
			for i in 1 to DIVIDEND_WIDTH loop
				q_pipe(i) <= gen_q(q_pipe(i-1), r_pipe(i));
			end loop;	
			
			q := gen_q(q_pipe(q_pipe'high), r_pipe(r_pipe'high));
			
			DV_O			<= dv(dv'high);
			DIV_BY_ZERO_O 	<= dbz(dbz'high);
			OVERFLOW_O		<= ovf(ovf'high);
			QUOTIENT_O		<= q(DIVIDEND_WIDTH-1 downto 0);
			
			if (REMAINDER = TRUE) then
				REMAINDER_O		<= assign_r(r_pipe(r_pipe'high), d_pipe(d_pipe'high));
			else	
				REMAINDER_O 	<= (others => '0');
			end if;
--		end if;
	end if;
end process;

end architecture;
