----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/19/2025 02:12:51 PM
-- Design Name: 
-- Module Name: ReceiverTop - Behavioral
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
-- RX_BAUD_DIVISOR_SEL				->   3 - 0 : baud divisor select
-- RX_CONTROL 								-> 			 8 : fifo rx_rd_en
--																		 4 : reset_rx
-- 																		 0 : RX_ENABLE is TX_READY (tx_ongoing)
-- RX_STATUS									-> 			12 : rx_fifo_almost_full 
--																     8 : rx_fifo_empty
-- 																		 4 : rx_fifo_almost_empty
--																		 0 : rx_error
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

entity ReceiverTop is
		Port ( 
						CLK																			: in STD_LOGIC
					;	RESET 																	: in STD_LOGIC
					;	RX																			: in STD_LOGIC
					; RX_BAUD_DIVISOR_SEL											: in STD_LOGIC_VECTOR(3 downto 0)
					; RX_CONTROL															: in STD_LOGIC_VECTOR(31 downto 0)
					; RX_DATA																	: out STD_LOGIC_VECTOR(7 downto 0)
					; RX_STATUS																: out STD_LOGIC_VECTOR(31 downto 0)
					);
end ReceiverTop;

architecture Behavioral of ReceiverTop is
type RX_STATES is (IDLE, RECEIVING, STOP);
signal cur_state																		: RX_STATES;
signal rx_data_o																		: std_logic_vector(7 downto 0);
signal rx_ready_o																		: std_logic;
signal rx_state																			: integer;
signal sample_clk																		: std_logic; -- remove
signal sample_clk_bk																: std_logic; -- remove
signal rx_error																			: std_logic;
signal actual_state																	: RX_STATES; 																			-- for dbg

-- rx_clk
signal baud_divisor																	: unsigned(19 downto 0);
signal baud_counter 																: unsigned(19 downto 0);
signal rx_clk																				: std_logic;
signal rx_clk_bk																		: std_logic;
signal rx_clk_enable																: std_logic;

-- RX FIFO
signal reset_rx																			: std_logic;
signal rx_wr_en																			: std_logic;
signal rx_rd_en																			: std_logic;
signal rx_fifo_out																	: std_logic_vector(7 downto 0);
signal rx_fifo_full																	: std_logic;																			-- Internal Signals
signal rx_fifo_almost_full													: std_logic;																			-- Internal Signals
signal rx_fifo_empty																: std_logic;
signal rx_fifo_almost_empty													: std_logic;
signal rx_enable 																		: std_logic;

	
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
end component;
	
begin

	rx_fifo : fifo_generator_0
  PORT MAP (
			clk 																					=> CLK
    ,	srst 																					=> reset_rx
    ,	din 																					=> rx_data_o
    ,	wr_en 																				=> rx_wr_en
    ,	rd_en 																				=> rx_rd_en
    ,	dout 																					=> RX_DATA
    ,	full 																					=> rx_fifo_full
		, almost_full																		=> rx_fifo_almost_full
    ,	empty 																				=> rx_fifo_empty
		,	almost_empty																	=> rx_fifo_almost_empty
  );

	set_baud_divisor : process(RX_CONTROL(31 downto 28))
	begin
		case RX_BAUD_DIVISOR_SEL(3 downto 0) is
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
	
	RX_STATUS																			 		<= x"0000" & "000" & rx_fifo_almost_full &  "000" & rx_fifo_empty & "000" & rx_fifo_almost_empty & "000" & rx_error;
	rx_rd_en																					<= RX_CONTROL(8) and (not rx_fifo_empty); -- Only read if read is given and fifo not empty
	rx_enable																					<= RX_CONTROL(0);
		
	rx_clk_gen : process(CLK, RESET, RX_CONTROL)
	begin																
		if (RESET = '1' or rx_clk_enable = '0') then 
			rx_clk																				<= '0';																							-- rx clk starts on 0. 180 phase shift with tx clk
			rx_clk_bk																			<= '0';
			baud_counter																	<= (others => '0');
		elsif(rising_edge(CLK)) then 
			rx_clk_bk																			<= rx_clk;
			if (rx_clk_enable = '1') then 
				if (baud_counter >= baud_divisor) then 
					rx_clk																		<= not rx_clk;
					baud_counter															<= (others => '0');
				else
					baud_counter															<= baud_counter + 1;
				end if;
				
			end if;
		end if;
	end process;
	
	rx_fifo_wr_proc : process(CLK, RESET, RX_CONTROL, RX)
	begin
		if (RESET = '1') then 
			reset_rx																			<= '1';																							-- Reset fifo 
			rx_wr_en																			<= '0';
		elsif (rising_edge(CLK)) then 
			reset_rx																			<= RESET;	
			if (rx_ready_o = '0' or rx_fifo_almost_full = '1' or rx_fifo_full = '1') then 										-- don't receive if fifo full or nothing to receive
				rx_wr_en																		<= '0';
			else	
				rx_wr_en																		<= '1';
			end if;
		end if;
	end process;
	
	rx_proc	: process(CLK, RESET, RX, RX_CONTROL)
	begin 
		
		if (RESET = '1') then 
			cur_state																			<= IDLE;
			rx_error																			<= '0';
			rx_clk_enable																	<= '0';
			rx_ready_o																		<= '0';
		elsif(rising_edge(CLK)) then		
			if (cur_state = IDLE and RX = '0') then 																												-- rx clk starts as RX line is pulled down
				rx_clk_enable																<= '1';
			end if;
			
			if (rx_ready_o = '1') then 																																			-- Ensures data ready signal only available for
				rx_ready_o																	<= '0';																						-- one clock cycle. Helps to sync with FIFOs
			end if;
			
			actual_state																	<= cur_state; 																		-- for dbg
			case cur_state is 
				when IDLE =>
					rx_state																	<= 0;
					if(rx_clk = '1' and rx_clk_bk = '0') then
						if (rx_enable = '1' and RX = '0') then 
							rx_data_o															<= (others => '0');																-- Data kept till next tx begins
							cur_state															<= RECEIVING;
							rx_state															<= 1;
							rx_error															<= '0';
						elsif (rx_enable = '0' and RX = '0') then 																								-- Error if RX line pulled down when receiver not enabled
							rx_error															<= '1';
							rx_ready_o														<= '0';
						end if;
					end if;
				when RECEIVING =>
					if(rx_clk = '1' and rx_clk_bk = '0') then
						if (rx_state = 8) then 																																		-- Final bit received
							cur_state															<= STOP;																					
						end if;
																							
						rx_data_o																<= RX & rx_data_o(7 downto 1);										-- Shifting register
						rx_state																<= rx_state + 1;	
					end if;

				when STOP =>
					if(rx_clk = '1' and rx_clk_bk = '0') then
						if (RX = '1' and rx_state = 9) then 																											-- Stop bit
							cur_state															<= IDLE;
							rx_ready_o														<= '1';																						-- rx_ready_o asserted
							rx_state															<= 0;
							rx_clk_enable													<= '0';																						-- rx clk disabled
						elsif (RX = '0' and rx_state = 9) then 
							rx_error															<= '1';
							rx_ready_o														<= '0';
							cur_state															<= IDLE;
						end if;
					end if;
			end case;
		end if;
	end process;


end Behavioral;