LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY ov7670_capture_tb IS
END ov7670_capture_tb;

ARCHITECTURE sim OF ov7670_capture_tb IS

    CONSTANT clk_hz : INTEGER := 100e6;
    CONSTANT pclk_hz : INTEGER := 24e6;
    CONSTANT clk_period : TIME := 1 sec / clk_hz;
    CONSTANT clk_period_pclk : TIME := 1 sec / pclk_hz;
    SIGNAL clk, ov7670_pclk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';

    SIGNAL config_finished : STD_LOGIC := '0';
    SIGNAL ov7670_vsync : STD_LOGIC := '1';
    SIGNAL ov7670_href : STD_LOGIC := '0';
    SIGNAL ov7670_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL start : STD_LOGIC := '0';
    SIGNAL start_href : STD_LOGIC := '0';
    SIGNAL start_pclk : STD_LOGIC := '0';
    SIGNAL frame_finished_o : STD_LOGIC := '0';
    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vsync_cnt_o : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_cnt_o : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pclk_cnt_o : unsigned(11 DOWNTO 0) := (OTHERS => '0');

    --frame_buffer signals
    SIGNAL wea : STD_LOGIC_VECTOR(0 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dina : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL addra : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');

    SIGNAL pclk_cnt_reg, pclk_cnt_next : INTEGER RANGE 0 TO 640 * 2 := 0;
    SIGNAL href_reg, href_next : INTEGER RANGE 0 TO 480 := 0;

    SIGNAL addrb : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');
    SIGNAL doutb : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

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

BEGIN
    clk <= NOT clk AFTER clk_period / 2;
    ov7670_pclk <= NOT ov7670_pclk AFTER clk_period_pclk / 2;

    PROCESS (ov7670_pclk)
    BEGIN
        IF rising_edge(ov7670_pclk) THEN
            ov7670_data <= STD_LOGIC_VECTOR(unsigned(ov7670_data) + 1);
        END IF;
    END PROCESS;

    frame_buffer : blk_mem_gen_1
    PORT MAP(
        clka => clk,
        wea => wea,
        ena => '1',
        addra => addra,
        dina => dina,
        clkb => clk,
        enb => '1',
        addrb => addrb,
        doutb => doutb
    );

    DUT : ENTITY work.ov7670_capture(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            config_finished => '1',
            ov7670_vsync => ov7670_vsync,
            ov7670_href => ov7670_href,
            ov7670_pclk => ov7670_pclk,
            ov7670_data => ov7670_data,
            start => start,
            start_href => '0',
            start_pclk => '0',
            frame_finished_o => frame_finished_o,
            pixel_data => pixel_data,
            vsync_cnt_o => OPEN,
            wea => wea,
            dina => dina,
            addra => addra
        );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';

        start <= '1';
        WAIT FOR clk_period * 10;
        ov7670_vsync <= '0'; --start new frame

        WAIT FOR clk_period * 10;
        ov7670_href <= '1'; --start new line;
        WAIT FOR clk_period * 100;

        addrb <= "0000000000000000001";
        WAIT FOR clk_period * 2;
        addrb <= "0000000000000000010";
        WAIT FOR clk_period * 2;
        addrb <= "0000000000000000011";
        WAIT FOR clk_period * 2;
        addrb <= "0000000000000000100";
        WAIT FOR clk_period * 2;

        finish;
    END PROCESS;

END ARCHITECTURE;