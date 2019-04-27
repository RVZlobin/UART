library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Buff is
	generic (
		DBIT: INTEGER := 8
	);
	port (
		clk: in STD_LOGIC := '0';
		reset: in STD_LOGIC := '0';
		clr_flag: in STD_LOGIC := '0';
		set_flag: in STD_LOGIC := '0';
		data_in: in STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
		data_out: out STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
		flag: out STD_LOGIC := '0'
	);
end Buff;

architecture flag_buff of Buff is
	signal buf_reg: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
	signal buf_next: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
	signal flag_reg: STD_LOGIC := '0';
	signal flag_next: STD_LOGIC := '0';
begin
	data_out <= buf_reg after 2 ns;
	flag <= flag_reg after 2 ns;
	
	process (clk, reset)
	begin
		if(reset = '1') then
			buf_reg <= (others => '0');
			flag_reg <= '0';
		elsif (rising_edge(clk)) then
			buf_reg <= buf_next;
			flag_reg <= flag_next;
		end if;
	end process;

	process(set_flag, clr_flag, reset)
	begin
		if (clr_flag = '1' or reset = '1') then
			flag_next <= '0';
			buf_next <= (others => '0');
		elsif (set_flag'event and set_flag = '1') then
			buf_next <= data_in;
			flag_next <= '1';
		end if;
	end process;
end flag_buff;