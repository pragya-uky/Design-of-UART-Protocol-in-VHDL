----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/17/2025 06:07:01 PM
-- Design Name: 
-- Module Name: TransmitterTop - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- TX_BAUD_DIVISOR_SEL				->   3 - 0 : baud divisor select
-- TX_CONTROL 								-> 			 8 : fifo tx_wr_en
--																		 4 : reset_tx
-- 																		 0 : TX_ENABLE
-- TX_STATUS									-> 			 8 : tx_fifo_full
--																		 4 : tx_fifo_almost_full
--																		 0 : tx_ongoing
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity TransmitterTop is
    Port ( 
						CLK 																		: in STD_LOGIC																			-- Connects to main clock
          ;	RESET 																	: in STD_LOGIC			
					; TX_DATA																	: in STD_LOGIC_VECTOR(7 downto 0)
					; TX_BAUD_DIVISOR_SEL											: in STD_LOGIC_VECTOR(3 downto 0)
					; TX_CONTROL															: in STD_LOGIC_VECTOR(31 downto 0) 									-- 31 downto 28 gets baud divisor
					; TX																			: out STD_LOGIC	
					; TX_STATUS																: out STD_LOGIC_VECTOR(31 downto 0)
				  );
end TransmitterTop;

architecture Behavioral of TransmitterTop is
type TX_STATES is (IDLE, DATA, STOP);
signal cur_state																		: TX_STATES;
signal tx_ongoing																		: std_logic;
signal tx_data_i																		: std_logic_vector(7 downto 0);
signal tx_o																					: std_logic;
signal tx_state																			: integer;
signal actual_tx_state															: TX_STATES;																				-- dbg
signal tx_fifo_out_ready_bk													: std_logic;																				-- Latch onto tx_fifo_out_ready till 
																																																				-- tx_clk catches up

--	tx_clk
signal tx_enable 																		: std_logic;
signal baud_divisor																	: unsigned(19 downto 0);
signal baud_counter 																: unsigned(19 downto 0);
signal tx_clk																				: std_logic;
signal tx_clk_bk																		: std_logic;

-- TX FIFO
signal reset_tx																			: std_logic;
signal tx_wr_en																			: std_logic;
signal tx_rd_en																			: std_logic;
signal tx_fifo_out																	: std_logic_vector(7 downto 0);
signal tx_fifo_full																	: std_logic;
signal tx_fifo_almost_full													:	std_logic;
signal tx_fifo_empty																: std_logic;																				-- Internal signal
signal tx_fifo_almost_empty													: std_logic;																				-- Internal signal	
signal tx_fifo_out_ready														: std_logic;
signal tx_ongoing_bk																: std_logic;																				-- Internal signal tied to main clk. 
																																																				-- Immediate update when tx begins	
																																																				-- tx_ongoing updates on tx_clk - slow
	
COMPONENT fifo_generator_0
  PORT (
			clk 																					: IN STD_LOGIC
    ;	srst 																					: IN STD_LOGIC
    ;	din 																					: IN STD_LOGIC_VECTOR(7 DOWNTO 0)
    ;	wr_en																					: IN STD_LOGIC
    ;	rd_en 																				: IN STD_LOGIC
    ;	dout 																					: OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    ;	full																					: OUT STD_LOGIC
		;	almost_full																		: OUT STD_LOGIC
    ;	empty 																				: OUT STD_LOGIC 
		;	almost_empty																	: OUT STD_LOGIC
  );
	
END COMPONENT;

begin


tx_fifo : fifo_generator_0
  PORT MAP (
			clk 																					=> CLK
    ,	srst 																					=> reset_tx
    ,	din 																					=> TX_DATA
    ,	wr_en 																				=> tx_wr_en
    ,	rd_en 																				=> tx_rd_en
    ,	dout 																					=> tx_fifo_out
    ,	full 																					=> tx_fifo_full
		, almost_full																		=> tx_fifo_almost_full
    ,	empty 																				=> tx_fifo_empty
		,	almost_empty																	=> tx_fifo_almost_empty
  );

	set_baud_divisor : process(TX_CONTROL(31 downto 28))
  begin
    case TX_BAUD_DIVISOR_SEL(3 downto 0) is
        when x"1"                           				=> baud_divisor <= x"05161";  --    2400
        when x"2"                           				=> baud_divisor <= x"028b0";  --    4800
        when x"3"                           				=> baud_divisor <= x"01458";  --    9600
        when x"4"                           				=> baud_divisor <= x"00d90";  --   14400
        when x"5"                           				=> baud_divisor <= x"00a2c";  --   19200
        when x"6"                           				=> baud_divisor <= x"006c8";  --   28800
        when x"7"                           				=> baud_divisor <= x"00516";  --   38400 
        when x"8"                           				=> baud_divisor <= x"00364";  --   57600
        when x"9"                           				=> baud_divisor <= x"0028b";  --   76800
        when x"a"                           				=> baud_divisor <= x"001b2";  --  115200
        when x"b"                           				=> baud_divisor <= x"000d9";  --  230400
        when x"c"                           				=> baud_divisor <= x"0006c";  --  460800
        when x"d"                           				=> baud_divisor <= x"00036";  --  921600
        when others                         				=> baud_divisor <= x"001b2";  --  115200 (default)
    end case;
  end process;
	
	
	TX_STATUS																			 		<= x"00000" & "000" & tx_fifo_full & "000" & tx_fifo_almost_full & "000" & tx_ongoing;
	tx_wr_en																					<= TX_CONTROL(8); --and (not tx_fifo_almost_full);


	
	tx_clock_gen : process(CLK, RESET, TX_CONTROL) 
	begin
		if (RESET = '1') then 
			baud_counter																	<= (others => '0');
			tx_clk																				<= '0';
			tx_clk_bk 																		<= '0';
		elsif(rising_edge(CLK)) then 
			tx_clk_bk																			<= tx_clk;
			if (baud_counter >= baud_divisor) then 
				tx_clk																			<= not tx_clk;
				baud_counter																<= (others => '0');
			else 
				baud_counter																<= baud_counter + 1;
			end if;
		end if;
	end process;
	
	tx_fifo_proc : process(CLK, RESET, TX_CONTROL, TX_DATA)
	begin
		if (RESET = '1') then 
			reset_tx																			<= '1';																						-- Reset fifo and transmission
			tx_rd_en																			<= '0';
			tx_fifo_out_ready 														<= '0';
			tx_ongoing_bk																	<= '0';
		elsif (rising_edge(CLK)) then 
			reset_tx																			<= RESET;
			if (tx_fifo_empty = '1' or tx_enable = '0' or tx_ongoing_bk = '1' or tx_ongoing = '1') then 	 	-- MAYBE tx_fifo_almost_empty
				tx_rd_en																		<= '0';
			else 																																														
				tx_rd_en																		<= '1';
				tx_ongoing_bk																<= '1';																						-- prevents rd_en reasserting till tx_ongoing is asserted on slow tx clk
			end if;
			
			if (cur_state = STOP) then 
				tx_ongoing_bk																<= '0';
			end if;
			
			if (tx_rd_en = '1') then 
				tx_fifo_out_ready														<= '1';																						-- fifo out ready one clock cycle after rd_en is given
			else 
				tx_fifo_out_ready														<= '0';																						-- deasserted after one clock cycle
			end if;
			
		end if;
	end process;
	
	
	tx_proc : process (CLK, RESET, TX_CONTROL, tx_clk, tx_clk_bk)
	begin
		actual_tx_state																	<= cur_state;
		if (RESET = '1') then 
			tx_ongoing																		<= '0';
			cur_state																			<= IDLE;
			tx_data_i																			<= (others => '0');
			tx_o																					<= '1';	
			tx_state 																			<= 0;
			tx_fifo_out_ready_bk													<= '0';
		elsif(rising_edge(CLK)) then 																																				
			TX																						<= tx_o;
			tx_enable																			<= TX_CONTROL(0);
			
			if (tx_fifo_out_ready = '1') then 
				tx_fifo_out_ready_bk												<= '1';																							-- Latches onto fifo_out_ready till tx actually begins
			end if;
			
				case cur_state is
					when IDLE =>
						tx_ongoing															<= '0';
						tx_o																		<= '1';																							-- No transmission. Back here for stop bit
						tx_state																<= 0;
						if(tx_clk = '1' and tx_clk_bk = '0') then
							if (tx_fifo_out_ready_bk = '1') then 
								cur_state														<= DATA;
								tx_ongoing													<= '1';																							-- Transmission begins
								tx_o																<= '0';
								tx_data_i														<= tx_fifo_out;																			-- Copy tx data into vector
								tx_state														<= 1;
								tx_fifo_out_ready_bk								<= '0';
							end if;
						end if;
						
					when DATA =>
						if(tx_clk = '1' and tx_clk_bk = '0') then
							if (tx_state = 8) then 																																		-- STOP condition
								cur_state 													<= STOP;	
								tx_state														<= 0;
								tx_o																<= '1';
							end if;	
							
							tx_o																	<= tx_data_i(0);
							tx_data_i															<= '0' & tx_data_i (7 downto 1);
							tx_state															<= tx_state + 1;
						end if;
						
					when STOP =>
						if(tx_clk = '1' and tx_clk_bk = '0') then
							tx_o																	<= '1';																							-- Stop bit
							cur_state															<= IDLE;	
							tx_ongoing														<= '0';	-- Since we use this output to pull down TX_ENABLE, we need this here. if it's in IDLE, this will never become
																														-- 0 as it will constantly satisfy the if condition there
						end if;
				end case;
		end if;
	end process;
	


end Behavioral;
