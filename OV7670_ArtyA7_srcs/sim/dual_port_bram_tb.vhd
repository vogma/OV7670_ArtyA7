LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY dual_port_bram_tb IS
END dual_port_bram_tb;

ARCHITECTURE sim OF dual_port_bram_tb IS

    CONSTANT clk_hz : INTEGER := 100e6;
    CONSTANT clk_period : TIME := 1 sec / clk_hz;

    SIGNAL clk, clkb : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';

    COMPONENT blk_mem_gen_1 IS
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            clkb : IN STD_LOGIC;
            enb : IN STD_LOGIC;
            addrb : IN STD_LOGIC_VECTOR(18 DOWNTO 0);
            doutb : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
        );
    END COMPONENT;

    SIGNAL ena : STD_LOGIC := '0';
    SIGNAL wea : STD_LOGIC_VECTOR(0 DOWNTO 0) := (OTHERS => '0');
    SIGNAL addra : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dina : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL enb : STD_LOGIC := '0';
    SIGNAL addrb : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');
    SIGNAL doutb : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

BEGIN

    clk <= NOT clk AFTER clk_period / 2;
    clkb <= NOT clkb AFTER clk_period;

    DUT : blk_mem_gen_1
    PORT MAP(
        clka => clk,
        wea => wea,
        ena => '1',
        addra => addra,
        dina => dina,
        clkb => clkb,
        enb => enb,
        addrb => addrb,
        doutb => doutb
    );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';

        WAIT FOR clk_period * 10;
        wea <= "1";
        addra <= "0000000000000000000";
        dina <= "111100001010";
        WAIT FOR clk_period * 2;

        addra <= "0000000000000000001";
        dina <= "000111010111";
        WAIT FOR clk_period * 2;

        addra <= "0000000000000000010";
        dina <= "100001011110";
        WAIT FOR clk_period * 2;

        addra <= "0000000000000000011";
        dina <= "111100001010";

        WAIT UNTIL rising_edge(clkb);-- clk_period * 2; --change to read   
        addra <= "0000000000000000000";
        dina <= (OTHERS => '0');
        wea <= NOT wea;
        addrb <= "0000000000000000000";
        enb <= NOT enb;

        WAIT UNTIL rising_edge(clkb);-- clk_period * 2; --change to read   
        addrb <= "0000000000000000001";

        WAIT UNTIL rising_edge(clkb);-- clk_period * 2; --change to read   
        addrb <= "0000000000000000010";
        WAIT UNTIL rising_edge(clkb);-- clk_period * 2; --change to read   
        addrb <= "0000000000000000011";

        WAIT FOR clk_period * 100;
        finish;
    END PROCESS;

END ARCHITECTURE;