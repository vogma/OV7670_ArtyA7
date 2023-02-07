LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY vga_own_tb IS
END vga_own_tb;

ARCHITECTURE sim OF vga_own_tb IS

    CONSTANT pxclk_hz : INTEGER := 25e6;
    CONSTANT clk_period : TIME := 1 sec / pxclk_hz;

    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';

    SIGNAL hsync : STD_LOGIC := '0';
    SIGNAL vsync : STD_LOGIC := '0';
    SIGNAL vga_red : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_blue : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_green : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');

BEGIN

    clk <= NOT clk AFTER clk_period / 2;

    DUT : ENTITY work.vga_own(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            pxl_clk => clk,
            VGA_HS_O => hsync,
            VGA_VS_O => vsync,
            VGA_R => vga_red,
            VGA_B => vga_blue,
            VGA_G => vga_green

        );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';

        WAIT FOR clk_period * 10;



    END PROCESS;

END ARCHITECTURE;