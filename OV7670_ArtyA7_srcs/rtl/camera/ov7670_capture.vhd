LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY ov7670_capture IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        config_finished : IN STD_LOGIC;
        ov7670_vsync : IN STD_LOGIC;
        ov7670_href : IN STD_LOGIC;
        start : IN STD_LOGIC;
        start_href : IN STD_LOGIC;
        vsync_cnt_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        href_cnt_o : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
    );
END ov7670_capture;

ARCHITECTURE rtl OF ov7670_capture IS

    TYPE state_type IS (idle, capture, wait_for_vsync, capture_href);

    --registers
    SIGNAL state_reg, state_next : state_type := idle;
    SIGNAL vsync_cnt_reg, vsync_cnt_next : INTEGER RANGE 0 TO 255 := 0;
    SIGNAL vsync_reg, vsync_next : STD_LOGIC := '0';
    SIGNAL href_reg, href_next : STD_LOGIC := '0';
    SIGNAL clk_reg, clk_next : INTEGER RANGE 0 TO 100_000_000 := 0;
    SIGNAL href_cnt_reg, href_cnt_next : INTEGER RANGE 0 TO 500 := 0;

    SIGNAL vsync_falling_edge, vsync_rising_edge : STD_LOGIC := '0';
    SIGNAL href_edge : STD_LOGIC := '0';

BEGIN
    vsync_next <= ov7670_vsync;
    vsync_falling_edge <= '1' WHEN vsync_reg = '1' AND ov7670_vsync = '0' ELSE
        '0'; --detect falling edge of external vsync signal (start of frame) 

    vsync_rising_edge <= '1' WHEN vsync_reg = '0' AND ov7670_vsync = '1' ELSE
        '0'; --detect rising edge of external vsync signal (end of frame) 

    href_next <= ov7670_href;
    href_edge <= '1' WHEN href_reg = '0' AND ov7670_href = '1' ELSE
        '0';

    sync : PROCESS (clk, rst)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state_reg <= idle;
                vsync_cnt_reg <= 0;
                vsync_reg <= '0';
                clk_reg <= 0;
                href_reg <= '0';
                href_cnt_reg <= 0;
            ELSE
                vsync_cnt_reg <= vsync_cnt_next;
                state_reg <= state_next;
                clk_reg <= clk_next;
                vsync_reg <= vsync_next;
                href_reg <= href_next;
                href_cnt_reg <= href_cnt_next;
            END IF;
        END IF;
    END PROCESS;

    comb : PROCESS (state_reg, vsync_cnt_reg, clk_reg,start_href, href_cnt_reg, href_edge, start, vsync_falling_edge, vsync_rising_edge, config_finished)
    BEGIN
        state_next <= state_reg;
        vsync_cnt_next <= vsync_cnt_reg;
        clk_next <= clk_reg;
        href_cnt_next <= href_cnt_reg;

        CASE state_reg IS

            WHEN idle =>
                IF start = '1' AND config_finished = '1' THEN
                    vsync_cnt_next <= 0;
                    state_next <= capture;
                ELSIF start_href = '1' AND config_finished = '1' THEN
                    href_cnt_next <= 0;
                    state_next <= wait_for_vsync; --need to wait for next frame (falling edge vsync)
                END IF;

            WHEN capture =>

                IF vsync_falling_edge = '1' THEN
                    vsync_cnt_next <= vsync_cnt_reg + 1;
                END IF;

                clk_next <= clk_reg + 1;
                IF clk_reg = 100_000_000 THEN
                    clk_next <= 0;
                    state_next <= idle;
                END IF;

            WHEN wait_for_vsync =>
                IF vsync_falling_edge = '1' THEN --new frame about to begin
                    state_next <= capture_href;
                END IF;

            WHEN capture_href =>

                IF href_edge = '1' THEN
                    href_cnt_next <= href_cnt_reg + 1;
                END IF;

                IF vsync_rising_edge = '1' THEN --frame finished
                    state_next <= idle;
                END IF;

            WHEN OTHERS => NULL;
        END CASE;
    END PROCESS;

    vsync_cnt_o <= STD_LOGIC_VECTOR(to_unsigned(vsync_cnt_reg, vsync_cnt_o'length)); --output
    href_cnt_o <= STD_LOGIC_VECTOR(to_unsigned(href_cnt_reg, href_cnt_o'length)); --output

END ARCHITECTURE;