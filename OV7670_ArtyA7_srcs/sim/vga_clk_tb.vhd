LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY vga_clk_tb IS
END vga_clk_tb;

ARCHITECTURE sim OF vga_clk_tb IS

    CONSTANT clk_hz : INTEGER := 100e6;
    CONSTANT clk_period : TIME := 1 sec / clk_hz;

    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';

    SIGNAL locked : STD_LOGIC := '0';

    COMPONENT vga_clk_gen IS
        PORT (
            clk_in1 : IN STD_LOGIC;
            reset : IN STD_LOGIC;
            clk_out1 : OUT STD_LOGIC;
            locked : OUT STD_LOGIC
        );
    END COMPONENT;

    SIGNAL vga_clk : STD_LOGIC := '0';
    SIGNAL vga_cnt, vga_next : INTEGER RANGE 0 TO 100 := 0;

BEGIN

    clk <= NOT clk AFTER clk_period / 2;

    DUT : vga_clk_gen
    PORT MAP(
        clk_in1 => clk,
        reset => '1',
        clk_out1 => vga_clk,
        locked => locked
    );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';

        WAIT FOR clk_period * 500;
    END PROCESS;

END ARCHITECTURE;