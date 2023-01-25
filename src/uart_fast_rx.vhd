library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

entity uart_fast_rx is
	generic (
		DIVIDER		: integer := 5;		
		DATA_BITS	: integer := 8;		-- 6, 7, 8, 9
		PARITY_BIT	: character := 'N';	-- N(one), O(dd), E(ven)
		STOP_BITS	: real := 1.0;			-- 1.0, 1.5, 2.0
		START_BIT	: std_logic := '0';
		ALIGNMENT	: boolean := false
	);
	port (
		RST_I		: in	STD_LOGIC;
		CLK_I		: in	STD_LOGIC;

		ENABLE_I	: in	STD_LOGIC := '1';
		
		RX_I		: in	STD_LOGIC := NOT START_BIT;
		
		RX_CHAR_O	: out	STD_LOGIC_VECTOR(DATA_BITS-1 downto 0) := (others => '0');
		RECV_O		: out	STD_LOGIC := '0';
		BUSY_O		: out	STD_LOGIC := '0';
		
		ERR_O		: out	STD_LOGIC := '0'
	);
end uart_fast_rx;

architecture RTL of uart_fast_rx is

type state_t is (
	ALIGN,
	WAIT_FOR_START,
	DATA,
	PARITY,
	STOP,
	OUTPUT
);
signal state : state_t := ALIGN;

signal dbit	: integer range 0 to DATA_BITS-1  := 0;
signal sbit	: integer range 0 to integer(ceil(STOP_BITS))-1  := 0;
signal char : std_logic_vector(DATA_BITS-1 downto 0) := (others => '0');
signal prty : std_logic := '0';

signal p	: std_logic := '0';

signal rx_sr    	: std_logic_vector(2 downto 0) := (others => '1');
signal rx_edge		: std_logic := '0';
signal counter		: integer range 0 to DIVIDER-1 := 0;
signal rx			: std_logic_vector(1 downto 0) := (others => NOT START_BIT);
signal strobe		: std_logic := '0';

begin

sync: process(CLK_I)
begin
    if rising_edge(CLK_I) then
        if (RST_I = '1') then
            rx_sr <= (others => NOT START_BIT);
        else
            rx_sr <= rx_sr(rx_sr'high-1 downto 0) & RX_I;            
        end if;
    end if;
end process;

rx_edge <= rx_sr(2) XOR rx_sr(1);	-- '1' when rising or falling edge on RX

sample : process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if RST_I = '1' then
			counter  <= 0;
			rx		 <= (others => NOT START_BIT);
		else
			if (counter = DIVIDER-1) OR
			    rx_edge = '1'						-- Sync to new Edge
			then
				counter <= 0;
			else
				counter	<= counter + 1;
			end if;
						
			if counter = 1 then						-- Sample 1 cy after edge
				rx(0)		<= rx_sr(rx_sr'high);
				rx(1) 	<= rx(0);
				strobe	<= '1';
			else
				rx(0)		<= rx(0);
				rx(1)		<= rx(1);
				strobe	<= '0';
			end if;
			
		end if;
	end if;
end process;

process(CLK_I)
begin
	if rising_edge(CLK_I) then
		if (RST_I = '1') then
			RECV_O		<= '0';
			RX_CHAR_O	<= (others => '0');
			dbit		<= 0;
			state		<= ALIGN;
		else
			ERR_O	<= '0';
			RECV_O	<= '0';
			
			if (strobe = '1') then
		
				case (state) is
			
				when ALIGN =>
					BUSY_O 		<= '0';
					
					if (ALIGNMENT = TRUE) then
						if (rx(0) = '1') then
							if (dbit = DATA_BITS/2) then
								dbit <= 0;
								state <= WAIT_FOR_START;
							else
								dbit <= dbit + 1;
							end if;
						else
							dbit <= 0;
						end if;
					else
						if (rx(0) = '1') then
							state <= WAIT_FOR_START;
						end if;
					end if;
				
				when WAIT_FOR_START =>
					--if (ENABLE_I = '1' AND rx = START_BIT) then					-- Startbit
					if (ENABLE_I = '1') then
						if (rx(1) /= START_BIT) AND (rx(0) = START_BIT) then
					
							BUSY_O <= '1';
							
							char <= (others => '0');
							prty <= '0';
							
							if (PARITY_BIT = 'E') then
								p <= '0';
							elsif (PARITY_BIT = 'O') then
								p <= '1';
							end if;
							
							state  <= DATA;
						end if;
					end if;
				
				when DATA =>
					char <= rx(0) & char(DATA_BITS-1 downto 1);
					p 	 <= p XOR rx(0);
					
					if (dbit = DATA_BITS-1) then
						dbit <= 0;
						if (PARITY_BIT /= 'N') then
							state <= PARITY;
						else
							state <= STOP;
						end if;
					else
						dbit <= dbit + 1;
					end if;
					
				when PARITY =>
					prty	<= rx(0);
					sbit	<= 0;
					state	<= STOP;
					
				when STOP =>
					if prty /= p then
						ERR_O <= '1';
					else
						ERR_O <= '0';
					end if; 
				
					if (sbit = integer(ceil(STOP_BITS))-1) then
						sbit	<= 0;
						state	<= OUTPUT;
					else
						sbit <= sbit + 1;
					end if;
				
				when OUTPUT =>
					RX_CHAR_O	<= char;
					RECV_O		<= '1';
					BUSY_O 		<= '0';
					
					if (ALIGNMENT = TRUE) then
						state <= ALIGN;
					else
						state <= WAIT_FOR_START;
					end if;
				
				end case;
			end if;
		end if;
	end if;
end process;

end RTL;
