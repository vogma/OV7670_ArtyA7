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
    CONSTANT vga_clk_hz : INTEGER := 25e6;

    CONSTANT clk_period : TIME := 1 sec / clk_hz;
    CONSTANT clk_period_pclk : TIME := 1 sec / pclk_hz;
    CONSTANT clk_period_vga_clk : TIME := 1 sec / vga_clk_hz;

    SIGNAL clk, ov7670_pclk, vga_clk : STD_LOGIC := '1';
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
    --vga signals
    SIGNAL vga_hsync : STD_LOGIC := '0';
    SIGNAL vga_vsync : STD_LOGIC := '0';
    SIGNAL vga_red : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_blue : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_green : STD_LOGIC_VECTOR (3 DOWNTO 0) := (OTHERS => '0');

    SIGNAL addrb : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');
    SIGNAL doutb : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_start : STD_LOGIC := '0';

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
    vga_clk <= NOT vga_clk AFTER clk_period_vga_clk / 2;

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
        clkb => vga_clk,
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
    vga : ENTITY work.vga_own(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            pxl_clk => vga_clk,
            VGA_HS_O => vga_hsync,
            VGA_VS_O => vga_vsync,
            VGA_R => vga_red,
            VGA_B => vga_blue,
            VGA_G => vga_green,
            start => vga_start,
            addrb => addrb,
            doutb => doutb
        );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';
        vga_start <= '0';
        start <= '1';
        WAIT FOR clk_period * 10;
        start <= '0';

        ov7670_vsync <= '0'; --start new frame

        WAIT FOR clk_period * 10;
        FOR i IN 1 TO 480 LOOP --count lines
            ov7670_href <= '1'; --start new line;

            FOR ii IN 1 TO 640 * 2 LOOP --send on line
                WAIT ON ov7670_pclk UNTIL rising_edge(ov7670_pclk);
            END LOOP;

            ov7670_href <= '0'; --end of line;
            WAIT FOR clk_period * 10;
        END LOOP;
        ov7670_vsync <= '1'; --end of frame
        WAIT FOR clk_period * 100;
        vga_start <= '1';

        WAIT ON ov7670_vsync UNTIL ov7670_vsync = '0';
        --finish;
    END PROCESS;

END ARCHITECTURE;