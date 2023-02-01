LIBRARY ieee;

USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY hex_decoder IS
	PORT (
		input : IN unsigned(3 DOWNTO 0);
		display : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END hex_decoder;

ARCHITECTURE arch OF hex_decoder IS
	SIGNAL result : STD_LOGIC_VECTOR(6 DOWNTO 0);
BEGIN
	WITH input SELECT
		result <=
		"0111111" WHEN x"0",
		"0110000" WHEN x"1",
		"1011011" WHEN x"2",
		"1111001" WHEN x"3",
		"1110100" WHEN x"4",
		"1101101" WHEN x"5",
		"1101111" WHEN x"6",
		"0111000" WHEN x"7",
		"1111111" WHEN x"8",
		"1111101" WHEN x"9",
		"1111110" WHEN x"a",
		"1100111" WHEN x"b",
		"0001111" WHEN x"c",
		"1110011" WHEN x"d",
		"1001111" WHEN x"e",
		"1001110" WHEN x"f",
		(others => '0') WHEN others;
	-- "0000001" when x"9", --unten 
	-- "0000010" when x"a", --links unten
	-- "0000100" when x"b", -- links oben
	-- "0001000" when x"c", --oben
	-- "0010000" when x"d",--rechts oben 
	-- "0100000" when x"e", --rechts unten 
	-- "1000000" when x"f"; --mitte
	display <= result;
END arch;