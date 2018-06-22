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
	shared variable bit_array: STD_LOGIC_VECTOR (SB_TICK - 1 downto 0) := (others => 'X');
	
begin
	data_out <= b_reg;
	
	process (clk, reset) --FSMD state and data regs.
	begin
		if (reset = '1') then
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
		end if;
	end process;
	
	-- next state logic
	process (reset, s_tick)
	begin
		if(reset = '1') then
			rx_done_tick <= '0';
			state_next <= idle;
			s_next <= (others => '0');
			n_next <= (others => '0');
			b_next <= (others => 'X');
		elsif(rising_edge(s_tick) and s_tick = '1') then
			rx_done_tick <= '0';
			case state_reg is
				when idle => 
					if (rx_reg = '0') then
						state_next <= start;
						bit_array(to_integer(s_reg)) := rx_reg;
						s_next <= s_reg + 1;
					end if;
				when start =>
					if (s_reg = SB_TICK - 1) then
						if(bit_array(7) = '0') then
							state_next <= data;
						else
							state_next <= idle;
						end if;
						bit_array := (others => 'X');
						s_next <= (others => '0');
						n_next <= (others => '0');
					else
						bit_array(to_integer(s_reg)) := rx_reg;
						s_next <= s_reg + 1;
					end if;
				when data =>
					if (s_reg = SB_TICK - 1) then
						s_next <= (others => '0');
						b_next <= bit_array(7) & b_reg(DBIT - 1 downto 1);
						bit_array := (others => 'X');
						if (n_reg = (DBIT - 1)) then
							state_next <= stop;
							n_next <= (others => '0');
						else
							n_next <= n_reg + 1;
						end if;
					else
						bit_array(to_integer(s_reg)) := rx_reg;
						s_next <= s_reg + 1;
					end if;
				when stop =>
					if (s_reg = (SB_TICK - 1)) then
						s_next <= (others => '0');
						if(s_bits_reg = (SBIT - 1)) then
							state_next <= idle;
							rx_done_tick <= '1';
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