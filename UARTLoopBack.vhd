----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 02/01/2025 11:21:49 PM
-- Design Name: 
-- Module Name: UARTLoopBack - Behavioral
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
-- 
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

entity UARTLoopBack is
    Port ( CLK : in STD_LOGIC;
           RESET : in STD_LOGIC;
           TX : out STD_LOGIC;
           RX : in STD_LOGIC);
end UARTLoopBack;

architecture Behavioral of UARTLoopBack is

component UARTTop is
			Port ( 
							CLK																		: in STD_LOGIC
						; RESET 																: in STD_LOGIC 
						; BAUD_DIVISOR_SEL											: in STD_LOGIC_VECTOR(3 downto 0)
						; TX_CONTROL														: in STD_LOGIC_VECTOR(31 downto 0)
						; RX_CONTROL														: in STD_LOGIC_VECTOR(31 downto 0)
						; TX_DATA																: in STD_LOGIC_VECTOR(7 downto 0)
						; RX 																		: in STD_LOGIC
						;	TX																		: out STD_LOGIC
						; RX_DATA 															: out STD_LOGIC_VECTOR(7 downto 0)
						; TX_STATUS															: out STD_LOGIC_VECTOR(31 downto 0)
						; RX_STATUS															: out STD_LOGIC_VECTOR(31 downto 0)
						);
end component;

TYPE STATES is (S0, S1, S2, S3);
signal fsm_state																		: STATES;
signal baud_divisor_sel															: std_logic_vector(3 downto 0);
signal tx_control																		: std_logic_vector(31 downto 0);
signal tx_status  																	: std_logic_vector(31 downto 0);
signal rx_control																		: std_logic_vector(31 downto 0);
signal rx_status																		: std_logic_vector(31 downto 0);
signal tx_data 																			: std_logic_vector(7 downto 0);
signal rx_data 																			: std_logic_vector(7 downto 0);
signal generated_reset															: std_logic := '1'; 
signal reset_delay_counter													: Unsigned(15 downto 0) := (others => '0');

begin
	
		inst_uart : UARTTop
			Port map( 
							CLK																		=> CLK
						, RESET 																=> generated_reset
						, BAUD_DIVISOR_SEL											=> baud_divisor_sel
						, TX_CONTROL														=> tx_control
						, RX_CONTROL														=> rx_control
						, TX_DATA																=> tx_data
						, RX 																		=> RX
						,	TX																		=> TX
						, RX_DATA 															=> rx_data
						, TX_STATUS															=> tx_status
						, RX_STATUS															=> rx_status
						);
	
		baud_divisor_sel																<= x"a";
		tx_control(0)																		<= '1';
		rx_control(0)																		<= '1';
			
		
		reset_gen : process(CLK)
		begin
			if (rising_edge(CLK)) then 
				if (reset_delay_counter = x"1000") then 
					generated_reset														<= '0';
				else
					generated_reset 													<= '1';
					reset_delay_counter												<= reset_delay_counter + 1;
				end if;
			end if;
		end process;

		loopback_proc : process(CLK, generated_reset) 
		begin 
			if (generated_reset = '1') then 
				fsm_state																		<= S0;
				rx_control(8)																<= '0';
				tx_control(8)																<= '0';
			elsif (rising_edge(CLK)) then 
				case fsm_state is 
					when S0 =>
						if (rx_status(8) = '0') then 
							rx_control(8)													<= '1';
							fsm_state															<= S1;
						end if;	
					when S1 =>
						rx_control(8) 													<= '0';
						fsm_state																<= S2;
					when S2 =>
						if (tx_status(4) = '0') then 	
							tx_data																<= rx_data;
							tx_control(8) 												<= '1';
							fsm_state															<= S3;
						end if;
					when S3 =>
						tx_control(8)														<= '0';
						fsm_state																<= S0;
				end case;
			end if;
		end process;

end Behavioral;
