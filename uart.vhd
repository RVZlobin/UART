library ieee;
library WORK;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity m_counter is
	generic (
		N: INTEGER := 8;
		M: INTEGER := 162
	);
	port (
		clk: IN STD_LOGIC;
		reset: IN STD_LOGIC;
		max_tick: out STD_LOGIC;
		q: OUT STD_LOGIC_VECTOR(N - 1 downto 0)
	);
end m_counter;

architecture mod_m_cnter of m_counter is
	signal r_reg: UNSIGNED(N - 1 downto 0);
	signal r_next: UNSIGNED(N - 1 downto 0);
begin 
	q <= STD_LOGIC_VECTOR(r_reg); 
	r_next <= (others => '0') when r_reg = (M - 1) else r_reg + 1;
	max_tick <= '1' when r_reg = (M - 1) else '0'; 
	cnter_process: process (clk, reset)
	begin
		if (reset = '1') then
			r_reg <= (others => '0');
		elsif (clk'event and clk = '1') then
			r_reg <= r_next;
		end if;
	end process cnter_process;
end mod_m_cnter;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart is
	generic (
		N: INTEGER := 4;
		M: INTEGER := 10;
		DBIT: INTEGER := 8;
		SBIT: INTEGER := 2;
		SB_TICK: INTEGER := 16
	);
	port(
		clk: in STD_LOGIC := '0'; -- тактовый сигнал
		clk_uart: in STD_LOGIC := '0'; -- внешний тактовый сигнал БОД
		reset: in STD_LOGIC := '0'; -- сброс
		rx: in STD_LOGIC := '1'; -- Линия приемника (вывод FPGA)
		w_data: in STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => 'X'); --данные для передачи
		rx_clr_flag: in STD_LOGIC := '0'; -- данные с приемника обработаны (импульс подать когда все считали)
		tx_set_flag: in STD_LOGIC := '0'; -- данные для передачи установлены (импульс подать когда все выставили)
		tx: out STD_LOGIC := '1'; -- Линия передатчика (вывод FPGA)
		tx_next: out STD_LOGIC := '0'; -- импульс запроса следующих данных для передачи
		tx_empty: out STD_LOGIC := '1'; -- Передатчик пуст
		rx_empty: out STD_LOGIC := '1'; -- Приемник пуст
		r_data: out STD_LOGIC_VECTOR(DBIT - 1 downto 0):= (others => 'X') -- Принятые данные
	);
end uart;

architecture uart_impl of uart is

	component m_counter is
		generic (
			N: INTEGER := 4;
			M: INTEGER := 10
		);
		port (
			clk: IN STD_LOGIC;
			reset: IN STD_LOGIC;
			max_tick: out STD_LOGIC;
			q: OUT STD_LOGIC_VECTOR(N - 1 downto 0)
		);
	end component m_counter;
	
	component Buff is
		generic (
			DBIT: INTEGER := 8
		);
		port (
			clk: in STD_LOGIC;
			reset: in STD_LOGIC;
			clr_flag: in STD_LOGIC;
			set_flag: in STD_LOGIC;
			data_in: in STD_LOGIC_VECTOR(DBIT - 1 downto 0);
			data_out: out STD_LOGIC_VECTOR(DBIT - 1 downto 0);
			flag: out STD_LOGIC
		);
	end component Buff;
	
	component Transmitter  is
		generic (
			DBIT: INTEGER := 8;
			SBIT: INTEGER := 2;
			SB_TICK: INTEGER := 16
		);
		port (
			clk: in STD_LOGIC;
			reset: in STD_LOGIC;
			tx_start: in STD_LOGIC;
			s_tick: in STD_LOGIC;
			data_in: in STD_LOGIC_VECTOR(DBIT - 1 downto 0);
			tx_done_tick: out STD_LOGIC;
			tx: out STD_LOGIC
		);
	end component Transmitter;
	
	component Receiver is
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
	end component Receiver;
	
	signal wire_r_data: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => '0');
	signal wire_w_data: STD_LOGIC_VECTOR(DBIT - 1 downto 0) := (others => '0');
	signal baud_clk: STD_LOGIC := '0';
	signal wire_tx_done_tick: STD_LOGIC := '0';
	signal wire_rx_done_tick: STD_LOGIC := '0';
	signal wire_rx_empty: STD_LOGIC := '1';
	signal wire_tx_start: STD_LOGIC := '0';
	
begin
	tx_next <= wire_tx_done_tick after 10 ns;
	tx_empty <= not wire_tx_start after 10 ns;
	rx_empty <= not wire_rx_empty after 10 ns;
	
	baud_gener: m_counter
		generic map (
			N => N,
			M => M
		)
		port map(
			clk => clk,
			reset => reset,
			max_tick => baud_clk
		);
	
	
	tx_inst : Transmitter
		generic map (
			DBIT => DBIT,
			SBIT => SBIT,
			SB_TICK => SB_TICK
		)
		port map (
			clk => clk,
			reset => reset,
			tx_start => wire_tx_start,
			--s_tick => baud_clk,
			s_tick => clk_uart,
			data_in => wire_w_data,
			tx_done_tick => wire_tx_done_tick,
			tx => tx
		);
		
	rx_inst : Receiver
		generic map (
			DBIT => DBIT,
			SBIT => SBIT,
			SB_TICK => SB_TICK
		)
		port map (
			clk => clk,
			reset => reset,
			rx => rx,
			--s_tick => baud_clk,
			s_tick => clk_uart,
			rx_done_tick => wire_rx_done_tick,
			data_out => wire_r_data
		);
		
	tx_buff: Buff
		generic map (
			DBIT => DBIT
		)
		port map(
			clk => clk,
			reset => reset,
			clr_flag => wire_tx_done_tick,
			set_flag => tx_set_flag,
			data_in => w_data,
			data_out => wire_w_data,
			flag => wire_tx_start
		);
		
	rx_buff: Buff
		generic map(
			DBIT => DBIT
		)
		port map(
			clk => clk,
			reset => reset,
			clr_flag => rx_clr_flag,
			set_flag => wire_rx_done_tick,
			data_in => wire_r_data,
			data_out =>r_data,
			flag => wire_rx_empty
		);
		
end uart_impl;

configuration uart_cnf of uart is
	for uart_impl	
		for 
			tx_inst: Transmitter use entity work.Transmitter(uart_tx); 
		end for;
		for
			rx_inst : Receiver use entity work.Receiver(uart_rx);
		end for;
		for
			tx_buff: Buff use entity work.Buff(flag_buff);
		end for;
		for
			rx_buff: Buff use entity work.Buff(flag_buff);
		end for;
	end for;
end configuration uart_cnf;