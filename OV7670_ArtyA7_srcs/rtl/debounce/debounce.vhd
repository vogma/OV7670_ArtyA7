----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 05.03.2021 18:46:17
-- Design Name: 
-- Module Name: debounce - Behavioral
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
LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY debounce IS
	PORT (
		clk : IN STD_LOGIC;
		btn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		edge : OUT STD_LOGIC_VECTOR(3 DOWNTO 0));
END debounce;

ARCHITECTURE Behavioral OF debounce IS
	SIGNAL c0, c1, c2 : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
BEGIN

	-- Synchronisation
	PROCESS (clk)
	BEGIN
		IF rising_edge(clk) THEN
			c0 <= btn;
			c1 <= c0;
			c2 <= c1;
		END IF;
	END PROCESS;

	-- Erkennung der fallenden Flanke (Tastendruck)
	edge <= c2 AND NOT c1;

END Behavioral;