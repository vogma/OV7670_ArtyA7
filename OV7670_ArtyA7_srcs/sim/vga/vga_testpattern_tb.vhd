LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY vga_testpattern_tb IS
END vga_testpattern_tb;

ARCHITECTURE sim OF vga_testpattern_tb IS

    CONSTANT clk_hz : INTEGER := 25e6;
    CONSTANT clk_period : TIME := 1 sec / clk_hz;

    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';

    SIGNAL hsync : STD_LOGIC := '0';
    SIGNAL vsync : STD_LOGIC := '0';
    SIGNAL VGA_R : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VGA_B : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL VGA_G : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');

BEGIN

    clk <= NOT clk AFTER clk_period / 2;

    DUT : ENTITY work.vga_testpattern(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            pxl_clk => clk,
            VGA_HS_O => hsync,
            VGA_VS_O => vsync,
            VGA_R => VGA_R,
            VGA_G => VGA_G,
            VGA_B => VGA_B
        );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';

     

        --finish;
    END PROCESS;

END ARCHITECTURE;