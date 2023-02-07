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
        ov7670_pclk : IN STD_LOGIC;
        ov7670_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        start : IN STD_LOGIC;
        start_href : IN STD_LOGIC;
        start_pclk : IN STD_LOGIC;
        frame_finished_o : OUT STD_LOGIC;
        pixel_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
        vsync_cnt_o : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        href_cnt_o : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        pclk_cnt_o : OUT unsigned(11 DOWNTO 0);

        --frame_buffer signals
        wea : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        dina : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        addra : OUT STD_LOGIC_VECTOR(18 DOWNTO 0)
    );
END ov7670_capture;

ARCHITECTURE rtl OF ov7670_capture IS

    TYPE state_type IS (
        idle, start_capturing, wait_for_new_frame, frame_finished, capture_line, capture_rgb_byte, write_to_bram
    );--idle, capture, wait_for_vsync, capture_href, wait_for_frame_start, wait_for_href, capture_pclk);

    --registers
    SIGNAL state_reg, state_next : state_type := idle;
    SIGNAL vsync_cnt_reg, vsync_cnt_next : INTEGER RANGE 0 TO 255 := 0;
    SIGNAL vsync_reg, vsync_next : STD_LOGIC := '0';
    SIGNAL href_reg, href_next : STD_LOGIC := '0';
    SIGNAL pclk_reg, pclk_next : STD_LOGIC := '0';
    SIGNAL clk_reg, clk_next : INTEGER RANGE 0 TO 100_000_000 := 0;
    SIGNAL href_cnt_reg, href_cnt_next : INTEGER RANGE 0 TO 500 := 0;
    SIGNAL pixel_reg, pixel_next : INTEGER RANGE 0 TO 650 := 0; --keeps track of current pixel positon in line (max 640)
    SIGNAL pclk_cnt_reg, pclk_cnt_next : unsigned(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL rgb_reg, rgb_next : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    SIGNAL vsync_falling_edge, vsync_rising_edge : STD_LOGIC := '0';
    SIGNAL href_rising_edge, href_falling_edge : STD_LOGIC := '0';
    SIGNAL pclk_edge : STD_LOGIC := '0';


    SIGNAL bram_address_reg, bram_address_next : unsigned(18 DOWNTO 0) := (OTHERS => '0');

BEGIN
    addra <= STD_LOGIC_VECTOR(bram_address_reg);

    vsync_next <= ov7670_vsync;
    vsync_falling_edge <= '1' WHEN vsync_reg = '1' AND ov7670_vsync = '0' ELSE
        '0'; --detect falling edge of external vsync signal (start of frame) 

    vsync_rising_edge <= '1' WHEN vsync_reg = '0' AND ov7670_vsync = '1' ELSE
        '0'; --detect rising edge of external vsync signal (end of frame) 

    href_next <= ov7670_href;
    href_rising_edge <= '1' WHEN href_reg = '0' AND ov7670_href = '1' ELSE
        '0';
    href_falling_edge <= '1' WHEN href_reg = '1' AND ov7670_href = '0' ELSE
        '0';

    pclk_next <= ov7670_pclk;
    pclk_edge <= '1' WHEN pclk_reg = '0' AND ov7670_pclk = '1' ELSE
        '0';

    sync : PROCESS (clk, rst)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state_reg <= idle;
                vsync_cnt_reg <= 0;
                vsync_reg <= '0';
                pclk_reg <= '0';
                pclk_cnt_reg <= (OTHERS => '0');
                clk_reg <= 0;
                bram_address_reg <= (OTHERS => '0');
                href_reg <= '0';
                href_cnt_reg <= 0;
                rgb_reg <= (OTHERS => '0');
                pixel_reg <= 0;
            ELSE
                vsync_cnt_reg <= vsync_cnt_next;
                state_reg <= state_next;
                clk_reg <= clk_next;
                vsync_reg <= vsync_next;
                href_reg <= href_next;
                rgb_reg <= rgb_next;
                bram_address_reg <= bram_address_next;
                pclk_reg <= pclk_next;
                pclk_cnt_reg <= pclk_cnt_next;
                href_cnt_reg <= href_cnt_next;
                pixel_reg <= pixel_next;
            END IF;
        END IF;
    END PROCESS;

    comb : PROCESS (state_reg, vsync_cnt_reg, bram_address_reg, ov7670_data, pixel_reg, rgb_reg, pclk_cnt_reg, clk_reg, start_href, pclk_edge, href_cnt_reg, href_rising_edge, start, vsync_falling_edge, vsync_rising_edge, config_finished)
    BEGIN
        state_next <= state_reg;
        vsync_cnt_next <= vsync_cnt_reg;
        clk_next <= clk_reg;
        href_cnt_next <= href_cnt_reg;
        pclk_cnt_next <= pclk_cnt_reg;
        rgb_next <= rgb_reg;
        pixel_next <= pixel_reg;
        bram_address_next <= bram_address_reg;
        frame_finished_o <= '0'; --debug
        wea <= "0";
        dina <= (OTHERS => '0');
        CASE state_reg IS

            WHEN idle =>
                IF start = '1' AND config_finished = '1' THEN
                    bram_address_next <= (OTHERS => '0');
                    state_next <= wait_for_new_frame;
                END IF;

            WHEN wait_for_new_frame =>
                IF vsync_falling_edge = '1' THEN --new frame is about to start
                    href_cnt_next <= 0;
                    state_next <= capture_line;
                END IF;

            WHEN start_capturing =>
                IF href_rising_edge = '1' THEN
                    pixel_next <= 0; -- new line: start with pixel position 0
                    state_next <= capture_line;
                END IF;

            WHEN capture_line =>
                IF pclk_edge = '1' THEN

                    --IF pixel_reg = 320 AND href_cnt_reg = 240 THEN --should be about the centre of the sensor
                    rgb_next(15 DOWNTO 8) <= ov7670_data; --capture first byte of pixel data
                    --END IF;
                    state_next <= capture_rgb_byte;
                END IF;

            WHEN capture_rgb_byte =>
                IF pclk_edge = '1' THEN

                    --debug: just save one pixel of the whole frame
                    --IF pixel_reg = 320 AND href_cnt_reg = 240 THEN --should be about the centre of the sensor
                    rgb_next(7 DOWNTO 0) <= ov7670_data; --capture first byte of pixel data
                    --END IF;

                    pixel_next <= pixel_reg + 1; --keep track of current pixel position in line

                    IF pixel_reg = 639 THEN --line finished
                        href_cnt_next <= href_cnt_reg + 1;

                        IF href_cnt_reg = 479 THEN
                            state_next <= frame_finished; --frame finished
                        ELSE
                            state_next <= start_capturing; -- wait for start of new line 
                        END IF;

                    ELSE
                        state_next <= write_to_bram;
                    END IF;
                END IF;

            WHEN write_to_bram =>
                wea <= "1";
                dina <= rgb_reg(11 DOWNTO 0);
                bram_address_next <= bram_address_reg + 1;
                state_next <= capture_line;

            WHEN frame_finished =>
                frame_finished_o <= '1';
                IF start = '1' THEN
                    rgb_next <= (OTHERS => '0');
                    state_next <= idle;
                END IF;

                -- WHEN idle =>
                --     IF start = '1' AND config_finished = '1' THEN
                --         vsync_cnt_next <= 0;
                --         state_next <= capture;
                --     ELSIF start_href = '1' AND config_finished = '1' THEN
                --         href_cnt_next <= 0;
                --         state_next <= wait_for_vsync; --need to wait for next frame (falling edge vsync)
                --     ELSIF start_pclk = '1' AND config_finished = '1' THEN
                --         pclk_cnt_next <= (OTHERS => '0');
                --         state_next <= wait_for_frame_start;
                --     END IF;

                -- WHEN capture =>

                --     IF vsync_falling_edge = '1' THEN
                --         vsync_cnt_next <= vsync_cnt_reg + 1;
                --     END IF;

                --     clk_next <= clk_reg + 1;
                --     IF clk_reg = 100_000_000 THEN
                --         clk_next <= 0;
                --         state_next <= idle;
                --     END IF;

                -- WHEN wait_for_vsync =>
                --     IF vsync_falling_edge = '1' THEN --new frame about to begin
                --         state_next <= capture_href;
                --     END IF;

                -- WHEN capture_href =>

                --     IF href_rising_edge = '1' THEN
                --         href_cnt_next <= href_cnt_reg + 1;
                --     END IF;

                --     IF vsync_rising_edge = '1' THEN --frame finished
                --         state_next <= idle;
                --     END IF;

                -- WHEN wait_for_frame_start => --we want to capture the number of pclks in one href line
                --     IF vsync_falling_edge = '1' THEN
                --         state_next <= wait_for_href;
                --     END IF;

                -- WHEN wait_for_href =>
                --     IF href_rising_edge = '1' THEN --line is beginning
                --         state_next <= capture_pclk;
                --     END IF;

                -- WHEN capture_pclk =>
                --     IF pclk_edge = '1' THEN
                --         pclk_cnt_next <= pclk_cnt_reg + 1;
                --     END IF;

                --     IF href_falling_edge = '1' THEN -- line is over
                --         state_next <= idle;
                --     END IF;

            WHEN OTHERS => NULL;
        END CASE;
    END PROCESS;

    vsync_cnt_o <= STD_LOGIC_VECTOR(to_unsigned(vsync_cnt_reg, vsync_cnt_o'length)); --output
    href_cnt_o <= STD_LOGIC_VECTOR(to_unsigned(href_cnt_reg, href_cnt_o'length)); --output
    pclk_cnt_o <= pclk_cnt_reg;
    pixel_data <= rgb_reg;

END ARCHITECTURE;