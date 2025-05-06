----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 01/20/2025 12:35:39 PM
-- Design Name: 
-- Module Name: UARTTop - Behavioral
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
-- UARTTop -------------------------------------------------------
-- Use BAUD_DIVISOR_SEL to select baud rate using the following key:
-- case BAUD_DIVISOR_SEL(3 downto 0) is
--         when x"1"     			=> baud_divisor <= x"05161";  --    2400
--         when x"2"     			=> baud_divisor <= x"028b0";  --    4800
--         when x"3"     			=> baud_divisor <= x"01458";  --    9600
--         when x"4"     			=> baud_divisor <= x"00d90";  --   14400
--         when x"5"     			=> baud_divisor <= x"00a2c";  --   19200
--         when x"6"     			=> baud_divisor <= x"006c8";  --   28800
--         when x"7"     			=> baud_divisor <= x"00516";  --   38400 
--         when x"8"     			=> baud_divisor <= x"00364";  --   57600
--         when x"9"     			=> baud_divisor <= x"0028b";  --   76800
--         when x"a"     			=> baud_divisor <= x"001b2";  --  115200
--         when x"b"     			=> baud_divisor <= x"000d9";  --  230400
--         when x"c"     			=> baud_divisor <= x"0006c";  --  460800
--         when x"d"     			=> baud_divisor <= x"00036";  --  921600
--         when others   			=> baud_divisor <= x"001b2";  --  115200 (default)
-- end case;
------------------------------------------------------------------
-- Transmitter ---------------------------------------------------
-- TX_BAUD_DIVISOR_SEL				->   3 - 0 : baud divisor select
-- TX_CONTROL 								-> 			 8 : fifo tx_wr_en
--																		 4 : reset_tx
-- 																		 0 : TX_ENABLE
-- TX_STATUS									-> 			 8 : tx_fifo_full
--																		 4 : tx_fifo_almost_full
--																		 0 : tx_ongoing
------------------------------------------------------------------
-- Receiver ------------------------------------------------------
-- RX_BAUD_DIVISOR_SEL				->   3 - 0 : baud divisor select
-- RX_CONTROL 								-> 			 8 : fifo rx_rd_en
--																		 4 : reset_rx
-- 																		 0 : RX_ENABLE is TX_READY (tx_ongoing)
-- RX_STATUS									-> 			12 : rx_fifo_almost_full 
--																     8 : rx_fifo_empty
-- 																		 4 : rx_fifo_almost_empty
--																		 0 : rx_error
------------------------------------------------------------------
-- General Info and Guidelines:  
-- 		Stop transmission once rx_fifo_almost_full is high
--		rx_control_reg(8) <= not rx_status_reg(8) ensures we won't read from empty rx_fifo
-- 		rx_control(0) ie rx_enable must be set high with assertion of tx_control(0) ie tx_enable (or when data is being fed into RX port)
------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity UARTTop is
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
end UARTTop;

architecture Behavioral of UARTTop is
signal baud_divisor_sel_reg													: std_logic_vector(3 downto 0);

-- For TransmitterTop
signal tx_data_i																		: std_logic_vector(7 downto 0);
signal tx_control_reg																: std_logic_vector(31 downto 0);
signal tx_status_reg																: std_logic_vector(31 downto 0);											
signal tx_o																					: std_logic;											-- Output bit stream. 
signal rx_i																					: std_logic;											-- RX input


-- For ReceiverTop
signal rx_data_o																		: std_logic_vector(7 downto 0);
signal rx_control_reg																: std_logic_vector(31 downto 0);
signal rx_status_reg																: std_logic_vector(31 downto 0);



-- Transmitter
component TransmitterTop is
    Port ( 
						CLK 																		: in STD_LOGIC																			-- Connects to main clock
          ;	RESET 																	: in STD_LOGIC			
					; TX_DATA																	: in STD_LOGIC_VECTOR(7 downto 0)
					; TX_BAUD_DIVISOR_SEL											: in STD_LOGIC_VECTOR(3 downto 0)
					; TX_CONTROL															: in STD_LOGIC_VECTOR(31 downto 0) 									-- 31 downto 28 gets baud divisor
					; TX																			: out STD_LOGIC	
					; TX_STATUS																: out STD_LOGIC_VECTOR(31 downto 0)
				  );
end component;

-- Receiver 

component ReceiverTop is
		Port ( 
						CLK																			: in STD_LOGIC
					;	RESET 																	: in STD_LOGIC
					;	RX																			: in STD_LOGIC
					; RX_BAUD_DIVISOR_SEL											: in STD_LOGIC_VECTOR(3 downto 0)
					; RX_CONTROL															: in STD_LOGIC_VECTOR(31 downto 0)
					; RX_DATA																	: out STD_LOGIC_VECTOR(7 downto 0)
					; RX_STATUS																: out STD_LOGIC_VECTOR(31 downto 0)
					);
end component;

begin
	RX_STATUS																					<= rx_status_reg;
	TX_STATUS																					<= tx_status_reg;
	tx_control_reg																		<= TX_CONTROL(31 downto 0);
	rx_control_reg							 											<= RX_CONTROL(31 downto 0);
	tx_data_i																					<= TX_DATA;
	RX_DATA                                           <= rx_data_o;
	TX																								<= tx_o;															-- TX of UARTTop
	rx_i																							<= RX;																-- RX of UARTTop
	baud_divisor_sel_reg															<= BAUD_DIVISOR_SEL;
							
	inst_Tx	: TransmitterTop
		port map( 
					  		CLK 																=> CLK 
					  	,	RESET 															=> RESET  
					  	, TX_DATA															=> tx_data_i
							, TX_BAUD_DIVISOR_SEL									=> baud_divisor_sel_reg
					  	, TX_CONTROL													=> tx_control_reg
					  	, TX																	=> tx_o																-- TX of TransmitterTop
					  	, TX_STATUS														=> tx_status_reg 
					  	); 
							
	inst_Rx : ReceiverTop
		port map ( 
								CLK																	=> CLK
							,	RESET 															=> RESET
							,	RX																	=> rx_i																-- RX of ReceiverTop
							,	RX_BAUD_DIVISOR_SEL									=> baud_divisor_sel_reg
							, RX_CONTROL													=> rx_control_reg
							, RX_DATA															=> rx_data_o
							, RX_STATUS														=> rx_status_reg
							);
							
	-- check rx status and if not empty, rd one rx_data_o, and throw into tx module

end Behavioral;
