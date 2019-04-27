library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Receiver is
	generic (
		DBIT: INTEGER := 8;
		SBIT: INTEGER := 2;
		SB_TICK: INTEGER := 16
	);
	port (
		clk: in STD_LOGIC;
		reset: in STD_LOGIC;
		rx: in STD_LOGIC;
		s_tick: in STD_LOGIC;
		rx_done_tick: out STD_LOGIC;
		data_out: out STD_LOGIC_VECTOR(DBIT - 1 downto 0)
	);
	type t_mass_lut is array (0 to 15) OF integer range 0 to 16;
	constant mass_cfg : t_mass_lut := (
			0, 1, 5, 8, 10, 12, 15, 16, 16, 15, 12, 10, 8, 5, 1, 0
		);
end Receiver;

architecture uart_rx of Receiver is
	type state_type is (idle, start, data, stop);
	signal state_reg, state_next: state_type;
	signal rx_reg: STD_LOGIC := '1';
	signal s_reg: UNSIGNED(3 downto 0);
	signal s_next: UNSIGNED(3 downto 0);
	signal n_reg: UNSIGNED(2 downto 0);
	signal n_next: UNSIGNED(2 downto 0);
	signal b_reg: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
	signal b_next: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
	signal s_bits_reg: UNSIGNED (SBIT - 1 downto 0) := (others => 'X');
	signal s_bits_next: UNSIGNED (SBIT - 1 downto 0) := (others => 'X');
	signal rx_done_tick_reg: STD_LOGIC;
	signal rx_done_tick_next: STD_LOGIC;
	shared variable bit_array: STD_LOGIC_VECTOR (SB_TICK - 1 downto 0) := (others => 'X');
	shared variable mass_one: INTEGER range 0 to SB_TICK * SB_TICK := 0;
	shared variable mass_zero: INTEGER range 0 to SB_TICK * SB_TICK := 0;
	
begin
	data_out <= b_reg;
	rx_done_tick <= rx_done_tick_reg;
	
	process (clk, reset) --FSMD state and data regs.
	begin
		if (reset = '1') then
			rx_done_tick_reg <= '0';
			state_reg <= idle;
			rx_reg <= '1';
			s_reg <= (others => '0');
			n_reg <= (others => '0');
			b_reg <= (others => '0');
			s_bits_reg <= (others => 'X');
		elsif (clk'event and clk='1') then
			state_reg <= state_next;
			rx_reg <= rx;
			s_reg <= s_next;
			n_reg <= n_next;
			b_reg <= b_next;
			s_bits_reg <= s_bits_next;
			rx_done_tick_reg <= rx_done_tick_next;
		end if;
	end process;
	
	-- next state logic
	process (reset, s_tick)
	begin
		if(reset = '1') then
			rx_done_tick_next <= '0';
			state_next <= idle;
			s_next <= (others => '0');
			n_next <= (others => '0');
			b_next <= (others => '0');
			s_bits_next <= (others => 'X');
			mass_one := 0;
			mass_zero := 0;
			bit_array := (others => 'X');
		elsif(rising_edge(s_tick) and s_tick = '1') then
			rx_done_tick_next <= '0';
			case state_reg is
				when idle => 
					if (rx_reg = '0') then
						state_next <= start;
						bit_array(to_integer(s_reg)) := rx_reg;
						mass_zero := mass_zero + mass_cfg(to_integer(s_reg));
						s_next <= s_reg + 1;
					end if;
				when start =>
					if (s_reg = SB_TICK - 1) then
						if(mass_zero > mass_one) then
							state_next <= data;
						else
							state_next <= idle;
						end if;
						mass_one := 0;
						mass_zero := 0;
						bit_array := (others => 'X');
						s_next <= (others => '0');
						n_next <= (others => '0');
					else
						bit_array(to_integer(s_reg)) := rx_reg;
						if(rx_reg = '1') then
							mass_one := mass_one + mass_cfg(to_integer(s_reg));
						elsif(rx_reg = '0') then
							mass_zero := mass_zero + mass_cfg(to_integer(s_reg));
						end if;
						s_next <= s_reg + 1;
					end if;
				when data =>
					if (s_reg = SB_TICK - 1) then
						s_next <= (others => '0');
						if(mass_zero > mass_one) then
							b_next <= '0' & b_reg(DBIT - 1 downto 1);
						else
							b_next <= '1' & b_reg(DBIT - 1 downto 1);
						end if;
						mass_one := 0;
						mass_zero := 0;
						bit_array := (others => 'X');
						if (n_reg = (DBIT - 1)) then
							state_next <= stop;
							n_next <= (others => '0');
						else
							n_next <= n_reg + 1;
						end if;
					else
						bit_array(to_integer(s_reg)) := rx_reg;
						if(rx_reg = '1') then
							mass_one := mass_one + mass_cfg(to_integer(s_reg));
						elsif(rx_reg = '0') then
							mass_zero := mass_zero + mass_cfg(to_integer(s_reg));
						end if;
						s_next <= s_reg + 1;
					end if;
				when stop =>
					if (s_reg = (SB_TICK - 1)) then
						s_next <= (others => '0');
						if(s_bits_reg = (SBIT - 1)) then
							state_next <= idle;
							rx_done_tick_next <= '1';
							s_bits_next <= (others => '0');
						else
							s_bits_next <= s_bits_reg + 1;
						end if;
					else
						s_next <= s_reg + 1;
					end if;
			end case;
		end if;	
	end process;
	
end uart_rx;