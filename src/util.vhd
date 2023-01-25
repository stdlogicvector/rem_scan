library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use IEEE.MATH_REAL.ALL;

package Util is

	---------------------------------------------------------------------------------------------
	-- attributes
	---------------------------------------------------------------------------------------------

--	attribute clock_signal		: string;	-- " {yes | no}";
--	attribute ram_style			: string;	-- " {block | distributed | registers}";
--	attribute rom_style			: string;	-- " {block | distributed | registers}";
--	attribute ASYNC_REG 		: string;	-- " {TRUE  | FALSE}";
	
	---------------------------------------------------------------------------------------------
	-- constants
	---------------------------------------------------------------------------------------------

	shared variable RAND_SEED1		: integer := 123;
	shared variable RAND_SEED2		: integer := 345;
	
	constant RISING					: std_logic_vector(1 downto 0) := "01";
	constant FALLING				: std_logic_vector(1 downto 0) := "10";
	
	---------------------------------------------------------------------------------------------
	-- types
	---------------------------------------------------------------------------------------------
	
	type integer_vector is array(natural range <>) of integer;
	type boolean_vector is array(natural range <>) of boolean;
	type real_vector    is array(natural range <>) of real;
	--type vectorarray_t is array(natural range <>) of std_logic_vector;
		
	type array32_t	is array(natural range <>) of std_logic_vector(31 downto 0);
	type array20_t	is array(natural range <>) of std_logic_vector(19 downto 0);
	type array16_t	is array(natural range <>) of std_logic_vector(15 downto 0);
	type array12_t	is array(natural range <>) of std_logic_vector(11 downto 0);
	type array10_t	is array(natural range <>) of std_logic_vector(9 downto 0);
	type array9_t	is array(natural range <>) of std_logic_vector(8 downto 0);
	type array8_t	is array(natural range <>) of std_logic_vector(7 downto 0);
	type array4_t	is array(natural range <>) of std_logic_vector(3 downto 0);
	
	---------------------------------------------------------------------------------------------
	-- Simulation Helpers
	---------------------------------------------------------------------------------------------

	function format_time(t : time; u : string) return string;

	procedure wait_until(t : time);

	procedure uart_getc(signal c : out std_logic_vector(7 downto 0); signal rx : in std_logic; baudrate : integer);
	procedure uart_putc(char : std_logic_vector(7 downto 0); signal tx : out std_logic; baudrate : integer);
	procedure uart_puts(str  : string; signal tx : out std_logic; baudrate : integer);

	function time2clks(t : time; f : integer) return integer;
	
	procedure pulse(idle: std_logic; mark: std_logic; len: time; signal sig : out std_logic);
	procedure clock(MHz : real; offset : time := 0ns; signal clk : out std_logic);
	procedure clock_diff(MHz : real; signal clk_p, clk_n : out std_logic);
	
	---------------------------------------------------------------------------------------------
	-- Conversions
	---------------------------------------------------------------------------------------------

	function str2int(x_str : string; radix : positive range 2 to 36 := 10) return integer;

	function real2fixed(r : real; l, u : integer) return std_logic_vector;
	function char2vec(c : character) return std_logic_vector;
	function char2vec(c : character; l : integer) return std_logic_vector;
	function int2vec(i : integer; l : integer) return std_logic_vector;
	function sint2vec(i : integer; l : integer) return std_logic_vector;
	
	function str2vec(s : string) return std_logic_vector;
	function vec2int(v : std_logic_vector) return integer;
	function svec2int(v : std_logic_vector) return integer;
	function vec2int(v : std_logic) return integer;
	
	function vec2str(v: std_logic_vector) return string;
	function svec2str(v: std_logic_vector) return string;
	
	function bit2vec(b: std_logic; l : integer) return std_logic_vector;
	
	function bool2bit(b: boolean) return std_logic;
	function bool2bit(b: boolean_vector) return std_logic_vector;
	
	function ip2vec(f0, f1, f2, f3 : integer range 0 to 255) return std_logic_vector;
	function mac2vec(m0, m1, m2, m3, m4, m5 : std_logic_vector(7 downto 0)) return std_logic_vector;
	
	function to_hstring(v : std_logic_vector) return string;
	function to_hchar(i : unsigned) return character;

	---------------------------------------------------------------------------------------------
	-- Math Helpers
	---------------------------------------------------------------------------------------------

	pure function clogb2 (depth : natural) return integer;
	pure function bits(n : integer) return integer;
	pure function ispowerof2(n : integer) return boolean;
	pure function div_ceil(a : natural; b : positive) return natural;

	pure function sum(v : integer_vector) return integer;
	pure function sum(v : integer_vector; upto: integer) return integer;
		
	function inc(v : std_logic_vector) return std_logic_vector;
	function dec(v : std_logic_vector) return std_logic_vector;
	
	pure function qabs(v: std_logic_vector) return std_logic_vector;
	
	function add(v : std_logic_vector; i : integer) return std_logic_vector;
	function add(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector;
	function add(v : std_logic_vector; i : integer; l : integer) return std_logic_vector;
	function sub(v : std_logic_vector; i : integer) return std_logic_vector;
	function sub(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector;
	function sub(v : std_logic_vector; i : integer; l : integer) return std_logic_vector;
	
	impure function random_int(min, max : integer) return integer;
	impure function random_real(min, max : real) return real;
	impure function random_vec(min, max : integer; l: integer) return std_logic_vector;
	impure function random_time(min, max : time; unit : time := ns) return time;

	function max(l, r: integer) return integer;
	function min(l, r: integer) return integer;

	---------------------------------------------------------------------------------------------
	-- Vector Helpers
	---------------------------------------------------------------------------------------------

	pure function bit_reverse(v : std_logic_vector) return std_logic_vector;
	pure function byte_reverse(v : std_logic_vector) return std_logic_vector;
	pure function word_reverse(v: std_logic_vector) return std_logic_vector;
	
	pure function nibble(vec : std_logic_vector; index : integer) return std_logic_vector;
	pure function byte(vec : std_logic_vector; index : integer) return std_logic_vector;
	
	pure function zero_resize(v : std_logic_vector; width : natural) return std_logic_vector;
	pure function sign_resize(v : std_logic_vector; width : natural) return std_logic_vector;
	
	pure function zero_resize_u(v : std_logic_vector; width : natural) return unsigned;
	pure function sign_resize_s(v : std_logic_vector; width : natural) return signed;
	
	pure function zero_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector;
	pure function sign_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector;
		
	pure function or_reduce(v : std_logic_vector) return std_logic;
	pure function and_reduce(v : std_logic_vector) return std_logic;
	
	pure function pad(l : integer; v: std_logic_vector) return std_logic_vector;
	pure function pad(l : integer; v: unsigned) return unsigned;
		
	function fill(width : natural; v : std_logic) return std_logic_vector;
	function fill(width : natural; v : std_logic_vector) return std_logic_vector;
	
	---------------------------------------------------------------------------------------------
	---------------------------------------------------------------------------------------------
	
	function switch(c : boolean; t : integer; f : integer) return integer;
	function switch(c : boolean; t : string; f : string) return string;
	function switch(c : boolean; t : std_logic_vector; f : std_logic_vector) return std_logic_vector;
	procedure log(msg: string);
	
end Util;

package body Util is

--function format_time(t : time; u : string(1 to 2)) return string
function format_time(t : time; u : string) return string
is
	variable r : real;
begin
	case (u(1 to 2)) is
	when "ps" => r := real(t / 1 ps);
	when "ns" => r := real(t / 1 ns);
	when "us" => r := real(t / 1 us);
	when "ms" => r := real(t / 1 ms); 
	when others => r := real(t / 1 ps);
	end case;
	
	return real'image(r/1000.0) & " " & u;
	
--	return time'image(t);
end function;

procedure wait_until(t : time) is
begin
	while (true) loop
		wait for 1ns;
		exit when now >= t;
	end loop;
end procedure;

procedure uart_puts(str : string; signal tx : out std_logic; baudrate : integer)
is
	variable c : integer;
begin
	for c in 1 to str'length loop
		uart_putc(char2vec(str(c)), tx, baudrate);
	end loop;
end procedure;

procedure uart_putc(char : std_logic_vector(7 downto 0); signal tx : out std_logic; baudrate : integer)
is
	constant BITTIME	: time := (1000000.0 / real(baudrate)) * 1 us;
begin
	-- Startbit
	tx <= '0';
	wait for BITTIME;
	
	-- Databits
	for i in 0 to 7 loop
		tx <= char(i);
		wait for BITTIME;
	end loop;
	
	-- Stopbit
	tx <= '1';
	
	wait for BITTIME * 2;
end procedure;

procedure uart_getc(signal c : out std_logic_vector(7 downto 0); signal rx : in std_logic; baudrate : integer) 
is
	constant BITTIME	: time := (1000000.0 / real(baudrate)) * 1 us;
	variable tmp		: std_logic_vector(7 downto 0) := x"00"; 
begin
	wait until rx = '0';			-- Start Bit
	tmp := x"00";
	wait for BITTIME * 1.5;			-- Center of First Bit
	
	for i in 0 to 7 loop
		tmp(i) := rx;				-- 8 Databits
		wait for BITTIME;
	end loop;
	
	if (rx = '0') then
		wait until rx = '1';		-- Stop Bit
	end if;

	c <= tmp;
end procedure;

function switch(c : boolean; t : integer; f : integer) return integer is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : string; f : string) return string is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

function switch(c : boolean; t : std_logic_vector; f : std_logic_vector) return std_logic_vector is
begin
	if (c = true) then
		return t;
	else
		return f;
	end if;
end function;

procedure log(msg: string) is
begin
	--report format_time(now, "us") & " : " & msg severity note;
	assert false report msg severity note;
end procedure;

procedure pulse(idle: std_logic; mark: std_logic; len: time; signal sig : out std_logic) is
begin
	sig <= mark;
	wait for len;
	sig <= idle;
end procedure pulse;

procedure clock(MHz : real; offset : time := 0ns; signal clk : out std_logic) is
begin
	clk <= '0';
	wait for 1.0us / MHz;
	wait for offset;
	loop
		wait for 0.5us / MHz;
		clk <= '0';
		wait for 0.5us / MHz;
		clk <= '1';
	end loop;
end procedure clock;

procedure clock_diff(MHz : real; signal clk_p, clk_n : out std_logic) is
begin
	clk_p <= '0';
	clk_n <= '1';
	wait for 1.0us / MHz;
	loop
		wait for 0.5us / MHz;
		clk_p <= '0';
		clk_n <= '1';
		wait for 0.5us / MHz;
		clk_p <= '1';
		clk_n <= '0';
	end loop;
end procedure clock_diff;

pure function pad(l : integer; v: std_logic_vector) return std_logic_vector
is
	variable h : integer := v'length;
	variable padded : std_logic_vector(abs(l)-1 downto 0) := (others => '0');
begin
	if (abs(l) <= h) then
		return v;
	end if;

	if (0 < l) then
		padded(h-1 downto 0) := v(v'high downto v'low);				-- Pad left
	elsif (l < 0) then
		padded(abs(l)-1 downto abs(l)-h) := v(v'high downto v'low);	-- Pad right
	end if;
	
	return padded;
end function;

pure function pad(l : integer; v: unsigned) return unsigned
is
	variable h : integer := v'length;
	variable padded : unsigned(abs(l)-1 downto 0) := (others => '0');
begin
	if (abs(l) <= h) then
		return v;
	end if;

	if (l > 0) then
		padded(h-1 downto 0) := v(v'high downto v'low);				-- Pad left
	elsif (l < 0) then
		padded(abs(l)-1 downto abs(l)-h) := v(v'high downto v'low);	-- Pad right
	end if;
	
	return padded;
end function;

function fill(width : natural; v : std_logic) return std_logic_vector
is
	variable Z : std_logic_vector(width-1 downto 0) := (others => v);
begin
	return Z;
end function;

function fill(width : natural; v : std_logic_vector) return std_logic_vector
is
	variable l : integer := v'length;
	variable Z : std_logic_vector(width-1 downto 0) := (others => '0');
begin
	assert width mod v'length = 0 report "fill: Width of result must be evenly divisible by length of fillpattern." severity failure;
	
	for i in 0 to (width / l)-1 loop
		Z((i+1)*l-1 downto i*l) := v;
	end loop;
	
	return Z;
end function;

pure function clogb2(depth : natural) return integer is
begin
	return integer(ceil(log2(real(depth))));
end function;

pure function nibble(vec : std_logic_vector; index : integer) return std_logic_vector is
begin
	return vec((index * 4 + 3) downto (index * 4));
end function;

pure function byte(vec : std_logic_vector; index : integer) return std_logic_vector is
	variable i : std_logic_vector(vec'high downto 0);
	variable r : std_logic_vector(7 downto 0);
begin
	i := vec;
	r := i((index * 8 + 7) downto (index * 8));
	return r;
end function;

pure function zero_resize(v : std_logic_vector; width : natural) return std_logic_vector is
begin
	return std_logic_vector(resize(unsigned(v), width));
end function;

pure function zero_resize_u(v : std_logic_vector; width : natural) return unsigned is
begin
	return resize(unsigned(v), width);
end function;

pure function sign_resize(v : std_logic_vector; width : natural) return std_logic_vector is
begin
	return std_logic_vector(resize(signed(v), width));
end function;

pure function sign_resize_s(v : std_logic_vector; width : natural) return signed is
begin
	return resize(signed(v), width);
end function;

pure function zero_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector is
begin
	return std_logic_vector(shift_right(unsigned(v), steps));
end function;

pure function sign_shift_right(v : std_logic_vector; steps : natural) return std_logic_vector is
begin
	return std_logic_vector(shift_right(signed(v), steps));
end function;

pure function or_reduce(v : std_logic_vector) return std_logic is
begin
	if v /= fill(v'length, '0') then
		return '1';
	else
		return '0';
	end if;
end function;

pure function and_reduce(v : std_logic_vector) return std_logic is
begin
	if v /= fill(v'length, '1') then
		return '0';
	else
		return '1';
	end if;
end function;

pure function bit_reverse(v : std_logic_vector) return std_logic_vector is
	variable r : std_logic_vector(v'high downto v'low);
begin
	for I in 0 to v'high-v'low loop
		r(v'high-I) := v(v'low+I);
	end loop;	
	
	return r;
end function bit_reverse;

pure function byte_reverse(v : std_logic_vector) return std_logic_vector is
	variable r : std_logic_vector(v'high downto v'low);
	variable b : integer;
begin
	assert v'length mod 8 = 0 report "Vector length must be a multiple of 8 for byte_reverse()" severity error;

	b := v'length/8;
	
	for I in 0 to b-1 loop
		r(v'high - (I*8) downto v'high - ((I+1)*8)+1) := v(v'low + ((I+1)*8)-1 downto v'low + I*8);
	end loop;	
	
	return r;
end function byte_reverse;

pure function word_reverse(v: std_logic_vector) return std_logic_vector is
	variable r : std_logic_vector(v'high downto v'low);
variable b : integer;
begin
	assert v'length mod 16 = 0 report "Vector length must be a multiple of 16 for word_reverse()" severity error;
	
	b := v'length/16;
	
	for I in 0 to b-1 loop
		r(v'high - (I*16) downto v'high - ((I+1)*16)+1) := v(v'low + ((I+1)*16)-1 downto v'low + I*16);
	end loop;	
	
	return r;
end function word_reverse;

function ip2vec(f0, f1, f2, f3 : integer range 0 to 255) return std_logic_vector is
	variable vec : std_logic_vector(31 downto 0);
begin
	vec( 7 downto  0) := int2vec(f0, 8);
	vec(15 downto  8) := int2vec(f1, 8);
	vec(23 downto 16) := int2vec(f2, 8);
	vec(31 downto 24) := int2vec(f3, 8);

	return vec;
end function ip2vec;

function mac2vec(m0, m1, m2, m3, m4, m5 : std_logic_vector(7 downto 0)) return std_logic_vector is
	variable vec : std_logic_vector(47 downto 0);
begin
	vec( 7 downto  0) := m0;
	vec(15 downto  8) := m1;
	vec(23 downto 16) := m2;
	vec(31 downto 24) := m3;
	vec(39 downto 32) := m4;
	vec(47 downto 40) := m5;

	return vec;
end function mac2vec;

function to_hstring(v : std_logic_vector) return string is
	variable value	: std_logic_vector(4*div_ceil(v'length, 4) - 1 downto 0);
	variable digit	: std_logic_vector(3 downto 0);
	variable result	: string(1 to 4) := "    ";--(1 to div_ceil(v'length, 4));
	variable j		: natural;
begin
	value := zero_resize(v, value'length);
	j	  := 0;
	
	for i in result'reverse_range loop
		digit       := value((j * 4) + 3 downto (j * 4));
		result(i)   := to_hchar(unsigned(digit));
		j           := j + 1;
	end loop;
	
	return result;
end to_hstring;

function to_hchar(i : unsigned) return character is
	constant hex : string(1 to 16) := "0123456789ABCDEF";
begin
	if (i < 16) then
		return hex(to_integer(i) + 1);
	else
		return 'X';
	end if;
end to_hchar;

function real2fixed(r : real; l, u : integer) return std_logic_vector is
	variable i : integer;
begin
	i := integer(round(r * real(2**u)));
	return std_logic_vector(to_signed(i, l+u));
end function real2fixed;

function time2clks(t : time; f : integer) return integer is
	variable p : time;
	variable c : integer;
begin
	p := (1000000000.0 / real(f)) * 1 ns;
	c := integer(round(real(t / p)));

	return c;
end function time2clks;

function char2vec(c : character) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(character'pos(c), 8));
end function char2vec;

function char2vec(c : character; l : integer) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(character'pos(c), l));
end function char2vec;

function str2vec(s : string) return std_logic_vector is
	variable v : std_logic_vector(s'length*8-1 downto 0);
begin
--	for I in 1 to s'length loop
--		v(I*8-1 downto (I-1)*8) := char2vec(s(I));
--	end loop;	
	
	for I in 0 to s'length-1 loop
		v((I+1)*8-1 downto (I)*8) := char2vec(s(s'length-I));
	end loop;	

	return v;
end function str2vec;

function vec2str(v: std_logic_vector) return string is
begin
	return integer'image(vec2int(v));
end function;

function svec2str(v: std_logic_vector) return string is
begin
	return integer'image(svec2int(v));
end function;

function bit2vec(b: std_logic; l : integer) return std_logic_vector is
	variable v : std_logic_vector(l-1 downto 0);
begin
	v := (others => b);
	return v;
end function bit2vec;

function vec2int(v : std_logic_vector) return integer is
begin
	return to_integer(unsigned(v));
end function vec2int;

function bool2bit(b: boolean) return std_logic is
begin
	if b = true then
		return '1';
	else
		return '0';
	end if;	
end function bool2bit;

function bool2bit(b: boolean_vector) return std_logic_vector is
variable v : std_logic_vector(b'high downto b'low) := (others => '0');
begin
	for i in b'low to b'high loop
		if b(i) = true
		then
			v(i) := '1';
		else
			v(i) := '0';
		end if;
	end loop;
	
	return v;
end function bool2bit;

function svec2int(v : std_logic_vector) return integer is
begin
	return to_integer(signed(v));
end function svec2int;

function vec2int(v : std_logic) return integer is
begin
	if v = '1' then
		return 1;
	else
		return 0;
	end if;
end function vec2int;

function int2vec(i : integer; l : integer) return std_logic_vector is
begin
	return std_logic_vector(to_unsigned(i, l));
end function int2vec;

function sint2vec(i : integer; l : integer) return std_logic_vector is
begin
	return std_logic_vector(to_signed(i, l));
end function sint2vec;

function inc(v : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v) + 1, v'length);
end function inc;

function dec(v : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v) - 1, v'length);
end function dec;

pure function qabs(v: std_logic_vector) return std_logic_vector is
begin
	return '0' & (v(v'high-1 downto v'low) XOR fill(v'length-1, v(v'high)));
end function qabs;

function add(v : std_logic_vector; i : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) + i, v'length);
end function add;

function add(v : std_logic_vector; i : integer; l : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) + i, l);
end function add;

function add(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v1) + vec2int(v2), max(v1'length, v2'length));
end function add;

function sub(v : std_logic_vector; i : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) - i, v'length);
end function sub;

function sub(v1 : std_logic_vector; v2 : std_logic_vector) return std_logic_vector is
begin
	return int2vec(vec2int(v1) - vec2int(v2), max(v1'length, v2'length));
end function sub;

function sub(v : std_logic_vector; i : integer; l : integer) return std_logic_vector is
begin
	return int2vec(vec2int(v) - i, l);
end function sub;

impure function random_int(min, max : integer) return integer is
	variable r : real;
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	return integer(round(r * real(max - min + 1) + real(min) - 0.5));
end function random_int;

impure function random_real(min, max : real) return real is
	variable r : real;
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	return r * (max - min) + min;
end function random_real;

impure function random_vec(min, max : integer; l : integer) return std_logic_vector is
	variable r : real;
	variable vec : std_logic_vector(l - 1 downto 0);
begin
 	for i in vec'range loop
    	uniform(RAND_SEED1, RAND_SEED2, r);
    	vec(i) := '1' when r > 0.5 else '0';
  	end loop;
  	
 	return vec;
end function random_vec;

impure function random_time(min, max : time; unit : time := ns) return time is
  variable r, r_scaled, min_real, max_real : real;
begin
	uniform(RAND_SEED1, RAND_SEED2, r);
	
	min_real := real(min / unit);
	max_real := real(max / unit);
	r_scaled := r * (max_real - min_real) + min_real;
	
	return real(r_scaled) * unit;
end function;

pure function bits(n : integer) return integer is
begin
	return integer(ceil(log2(real(n))));
end bits;

pure function ispowerof2(n : integer) return boolean is
variable v,v1,z : std_logic_vector(bits(n)-1 downto 0);
begin
	v  := int2vec(n  , bits(n));
	v1 := int2vec(n-1, bits(n));
	z  := int2vec(0  , bits(n));
	
	if (v AND v1) = z then
		return true;
	else
		return false;
	end if;
end ispowerof2;

pure function div_ceil(a : natural; b : positive) return natural is
begin
	return (a + (b - 1)) / b;
end div_ceil;

pure function sum(v : integer_vector) return integer is
variable s : integer := 0;
begin
	for i in 0 to v'length-1 loop
		s := s + v(v'left + i);
	end loop;
	
	return s;
end sum;

pure function sum(v : integer_vector; upto: integer) return integer is
variable s : integer := 0;
begin
	if upto < 0 then
		return 0;
	end if;
		
	for i in 0 to min(upto, v'length-1) loop
		s := s + v(v'left + i);
	end loop;
	
	return s;
end sum;

function max(l, r: integer) return integer is
begin
	if l > r then
		return l;
	else
		return r;
	end if;
end;

function min(l, r: integer) return integer is
begin
	if l < r then
		return l;
	else
		return r;
	end if;
end;

function str2int(x_str : string; radix : positive range 2 to 36 := 10) return integer is
    constant STR_LEN          : integer := x_str'length;
    
    variable chr_val          : integer;
    variable ret_int          : integer := 0;
    variable do_mult          : boolean := true;
    variable power            : integer := 0;
begin

for i in STR_LEN downto 1 loop
  case x_str(i) is
	when '0'       =>   chr_val := 0;
	when '1'       =>   chr_val := 1;
	when '2'       =>   chr_val := 2;
	when '3'       =>   chr_val := 3;
	when '4'       =>   chr_val := 4;
	when '5'       =>   chr_val := 5;
	when '6'       =>   chr_val := 6;
	when '7'       =>   chr_val := 7;
	when '8'       =>   chr_val := 8;
	when '9'       =>   chr_val := 9;
	when 'A' | 'a' =>   chr_val := 10;
	when 'B' | 'b' =>   chr_val := 11;
	when 'C' | 'c' =>   chr_val := 12;
	when 'D' | 'd' =>   chr_val := 13;
	when 'E' | 'e' =>   chr_val := 14;
	when 'F' | 'f' =>   chr_val := 15;
	when 'G' | 'g' =>   chr_val := 16;
	when 'H' | 'h' =>   chr_val := 17;
	when 'I' | 'i' =>   chr_val := 18;
	when 'J' | 'j' =>   chr_val := 19;
	when 'K' | 'k' =>   chr_val := 20;
	when 'L' | 'l' =>   chr_val := 21;
	when 'M' | 'm' =>   chr_val := 22;
	when 'N' | 'n' =>   chr_val := 23;
	when 'O' | 'o' =>   chr_val := 24;
	when 'P' | 'p' =>   chr_val := 25;
	when 'Q' | 'q' =>   chr_val := 26;
	when 'R' | 'r' =>   chr_val := 27;
	when 'S' | 's' =>   chr_val := 28;
	when 'T' | 't' =>   chr_val := 29;
	when 'U' | 'u' =>   chr_val := 30;
	when 'V' | 'v' =>   chr_val := 31;
	when 'W' | 'w' =>   chr_val := 32;
	when 'X' | 'x' =>   chr_val := 33;
	when 'Y' | 'y' =>   chr_val := 34;
	when 'Z' | 'z' =>   chr_val := 35;                           
	when '-' =>   
	  if i /= 1 then
		report "Minus sign must be at the front of the string" severity failure;
	  else
		ret_int           := 0 - ret_int;
		chr_val           := 0;
		do_mult           := false;    --Minus sign - do not do any number manipulation
	  end if;
				 
	when others => report "Illegal character for conversion from string to integer" severity failure;
  end case;
  
  if chr_val >= radix then report "Illegal character at this radix" severity failure; end if;
	
  if do_mult then
	ret_int               := ret_int + (chr_val * (radix**power));
  end if;
	
  power                   := power + 1;
	  
end loop;

return ret_int;

end function;

end Util;