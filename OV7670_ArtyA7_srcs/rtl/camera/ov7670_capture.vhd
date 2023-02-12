LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY ov7670_capture IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        config_finished : IN STD_LOGIC;

        --camera signals  
        ov7670_vsync : IN STD_LOGIC;
        ov7670_href : IN STD_LOGIC;
        ov7670_pclk : IN STD_LOGIC;
        ov7670_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        start : IN STD_LOGIC;
        frame_finished_o : OUT STD_LOGIC;
        pixel_data : OUT STD_LOGIC_VECTOR(15 DOWNTO 0);

        --frame_buffer signals
        wea : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        dina : OUT STD_LOGIC_VECTOR(11 DOWNTO 0);
        addra : OUT STD_LOGIC_VECTOR(18 DOWNTO 0)
    );
END ov7670_capture;

ARCHITECTURE rtl OF ov7670_capture IS

    TYPE state_type IS (
        idle, start_capturing, wait_for_new_frame, frame_finished, capture_line, capture_rgb_byte, write_to_bram
    );

    --registers
    SIGNAL vsync_reg, vsync_next : STD_LOGIC := '0';
    SIGNAL href_reg, href_next : STD_LOGIC := '0';
    SIGNAL pclk_reg, pclk_next : STD_LOGIC := '0';

    SIGNAL vsync_falling_edge, vsync_rising_edge : STD_LOGIC := '0';
    SIGNAL href_rising_edge, href_falling_edge : STD_LOGIC := '0';
    SIGNAL pclk_edge : STD_LOGIC := '0';

    SIGNAL frame_finished_reg, frame_finished_next : STD_LOGIC := '0';
    
    TYPE reg_type IS RECORD
        state : state_type;
        href_cnt : INTEGER RANGE 0 TO 500;
        rgb_reg : STD_LOGIC_VECTOR(15 DOWNTO 0);
        pixel_reg : INTEGER RANGE 0 TO 650;
        bram_address : unsigned(18 DOWNTO 0);
    END RECORD reg_type;

    CONSTANT INIT_REG_FILE : reg_type := (
        state => idle,
        href_cnt => 0,
        rgb_reg => (OTHERS => '0'),
        pixel_reg => 0,
        bram_address => (OTHERS => '0')
    );

    SIGNAL reg, reg_next : reg_type := INIT_REG_FILE;

BEGIN
    addra <= STD_LOGIC_VECTOR(reg.bram_address);

    vsync_next <= ov7670_vsync;
    vsync_falling_edge <= '1' WHEN vsync_reg = '1' AND ov7670_vsync = '0' ELSE
        '0'; --detect falling edge of external vsync signal (start of frame) 

    vsync_rising_edge <= '1' WHEN vsync_reg = '0' AND ov7670_vsync = '1' ELSE
        '0'; --detect rising edge of external vsync signal (end of frame) 

    href_next <= ov7670_href; --register external href signal from camera

    href_rising_edge <= '1' WHEN href_reg = '0' AND ov7670_href = '1' ELSE
        '0';
    href_falling_edge <= '1' WHEN href_reg = '1' AND ov7670_href = '0' ELSE
        '0';

    pclk_next <= ov7670_pclk;
    pclk_edge <= '1' WHEN pclk_reg = '0' AND ov7670_pclk = '1' ELSE --TODO can external pclk be directly used as a clk? 
        '0';

    sync : PROCESS (clk, rst)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN --TODO tie reset to pll lock? 
                reg <= INIT_REG_FILE;
                vsync_reg <= '0';
                pclk_reg <= '0';
                href_reg <= '0';
            ELSE
                reg <= reg_next;
                vsync_reg <= vsync_next;
                href_reg <= href_next;
                pclk_reg <= pclk_next;
            END IF;
        END IF;
    END PROCESS;

    comb : PROCESS (reg, ov7670_data, pclk_edge, href_rising_edge, start, vsync_falling_edge, vsync_rising_edge, config_finished)
    BEGIN
        reg_next <= reg;
        frame_finished_o <= '0'; --debug
        wea <= "0";
        dina <= (OTHERS => '0');
        CASE reg.state IS

            WHEN idle =>
                IF start = '1' AND config_finished = '1' THEN
                    reg_next.bram_address <= (OTHERS => '0');
                    reg_next.state <= wait_for_new_frame;
                END IF;

            WHEN wait_for_new_frame =>
                IF vsync_falling_edge = '1' THEN --new frame is about to start
                    reg_next.href_cnt <= 0;
                    reg_next.state <= start_capturing;
                END IF;

            WHEN start_capturing =>
                IF href_rising_edge = '1' THEN
                    reg_next.pixel_reg <= 0; -- new line: start with pixel position 0
                    reg_next.state <= capture_line;
                END IF;

            WHEN capture_line =>
                IF pclk_edge = '1' THEN

                    reg_next.rgb_reg(15 DOWNTO 8) <= ov7670_data; --capture first byte of pixel data
                    reg_next.state <= capture_rgb_byte;
                END IF;

            WHEN capture_rgb_byte =>
                IF pclk_edge = '1' THEN

                    reg_next.rgb_reg(7 DOWNTO 0) <= ov7670_data; --capture first byte of pixel data

                    reg_next.pixel_reg <= reg.pixel_reg + 1; --keep track of current pixel position in line

                    IF reg.pixel_reg = 639 THEN --line finished
                        reg_next.href_cnt <= reg.href_cnt + 1;

                        IF reg.href_cnt = 479 THEN
                            reg_next.state <= frame_finished; --frame finished
                        ELSE
                            reg_next.state <= start_capturing; -- wait for start of new line 
                        END IF;

                    ELSE
                        reg_next.state <= write_to_bram;
                    END IF;
                END IF;

            WHEN write_to_bram =>
                wea <= "1"; --write enable bram
                dina <= reg.rgb_reg(11 DOWNTO 0); --write 12 bit pixel value to bram
                reg_next.bram_address <= reg.bram_address + 1; --increment address register for next pixel
                reg_next.state <= capture_line; --capture next pixel

            WHEN frame_finished =>
                frame_finished_o <= '1';
                reg_next.rgb_reg <= (OTHERS => '0');
                reg_next.bram_address <= (OTHERS => '0');
                reg_next.state <= wait_for_new_frame;

            WHEN OTHERS => NULL;
        END CASE;
    END PROCESS;

    pixel_data <= reg.rgb_reg;

END ARCHITECTURE;