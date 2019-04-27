library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Transmitter  is
	generic (
		DBIT: INTEGER := 8;
		SBIT: INTEGER := 2;
		SB_TICK: INTEGER := 16
	);
	port (
		clk: in STD_LOGIC := '0';
		reset: in STD_LOGIC := '0';
		tx_start: in STD_LOGIC := '0';
		s_tick: in STD_LOGIC := '0';
		data_in: in STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
		tx_done_tick: out STD_LOGIC := '0';
		tx: out STD_LOGIC := '1'
	);
end Transmitter;

architecture uart_tx of Transmitter is
	type state_type is (idle, start, data, stop);
	signal state_reg: state_type := idle;
	signal state_next: state_type := idle;
	signal tx_done_tick_reg: STD_LOGIC := '0';
	signal tx_done_tick_next: STD_LOGIC := '0';
	signal s_reg: UNSIGNED(3 downto 0) := (others => '0');
	signal s_next: UNSIGNED(3 downto 0) := (others => '0');
	signal n_reg: UNSIGNED(2 downto 0) := (others => '0');
	signal n_next: UNSIGNED(2 downto 0) := (others => '0');
	signal b_reg: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
	signal b_next: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X');
	signal tx_next: STD_LOGIC := '1';
	signal s_bits_reg: UNSIGNED (SBIT - 1 downto 0) := (others => 'X');
	signal s_bits_next: UNSIGNED (SBIT - 1 downto 0) := (others => 'X');
	
begin
	
	tx_done_tick <= tx_done_tick_reg;
	
	process (clk, reset) -- FSMD state and data regs.
	begin
		if (reset = '1') then
			state_reg <= idle;
			tx_done_tick_reg <= '0';
			s_reg <= (others => '0');
			n_reg <= (others => '0');
			b_reg <= (others => 'X');
			s_bits_reg <= (others => 'X');
			tx <= '1';
		elsif (rising_edge(clk)) then
			tx_done_tick_reg <= tx_done_tick_next;
			state_reg <= state_next;
			s_reg <= s_next;
			n_reg <= n_next;
			b_reg <= b_next;
			s_bits_reg <= s_bits_next;
			tx <= tx_next;
		end if;
	end process;
	
	process (reset, s_tick, tx_done_tick_reg, tx_start)
	begin
		if(reset = '1') then
			tx_done_tick_next <= '0';
			tx_next <= '1';
		elsif(tx_done_tick_reg = '1') then
			tx_done_tick_next <= '0';
		elsif(s_tick'event and s_tick = '1') then
			case state_reg is
				when idle =>
					if (tx_start = '1') then
						b_next <= data_in;
						state_next <= start;
						s_next <= (others => '0');
						s_bits_next <= (others => '0');
						tx_next <= '0';
					else
						tx_next <= '1';
					end if;
				when start =>
					if (s_reg = SB_TICK - 1) then
						state_next <= data;
						s_next <= (others => '0');
						n_next <= (others => '0');
					else
						s_next <= s_reg + 1;
					end if;
				when data =>
					tx_next <= b_reg(0);
					if (s_reg = SB_TICK - 1) then
						s_next <= (others => '0');
						b_next <= '0' & b_reg(DBIT - 1 downto 1);
						if (n_reg = (DBIT - 1)) then
							state_next <= stop;
						else
							n_next <= n_reg + 1;
						end if;
					else
						s_next <= s_reg + 1;
					end if;
				when stop =>
					tx_next <= '1';
					if (s_reg = (SB_TICK - 1)) then
						if(s_bits_reg = (SBIT - 1)) then
							state_next <= idle;
							tx_done_tick_next <= '1';
						else
							s_bits_next <= s_bits_reg + 1;
							s_next <= (others => '0');
						end if;
					else
						s_next <= s_reg + 1;
					end if;
			end case;			
		end if;
	end process;

end uart_tx;