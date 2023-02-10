LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.std_logic_unsigned.ALL;

ENTITY vga_testpattern IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        pxl_clk : IN STD_LOGIC;
        VGA_HS_O : OUT STD_LOGIC;
        VGA_VS_O : OUT STD_LOGIC;
        VGA_R : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_B : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_G : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        --frame_buffer signals
        addrb : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
        doutb : IN STD_LOGIC_VECTOR(11 DOWNTO 0) --pixel data
    );
END vga_testpattern;

ARCHITECTURE rtl OF vga_testpattern IS
    --***640x480@60Hz***--  Requires 25 MHz clock
    CONSTANT FRAME_WIDTH : NATURAL := 640;
    CONSTANT FRAME_HEIGHT : NATURAL := 480;

    CONSTANT H_FRONT_PORCH : NATURAL := 16; --H front porch width (pixels)
    CONSTANT H_SYNC_PULSE_WIDTH : NATURAL := 96; --H sync pulse width (pixels)
    CONSTANT H_TOTAL_LINE : NATURAL := 800; --H total period (pixels) 

    CONSTANT V_FRONT_PORCH : NATURAL := 10; --vertical front porch width (lines)
    CONSTANT V_SYNC_PULSE_WIDTH : NATURAL := 2; --vertical sync pulse width (lines)
    CONSTANT V_MAX_LINE : NATURAL := 525; --vertical total period (lines)

    CONSTANT H_POL : STD_LOGIC := '0';
    CONSTANT V_POL : STD_LOGIC := '0';

    SIGNAL bram_address_reg, bram_address_next : STD_LOGIC_VECTOR(18 DOWNTO 0) := (OTHERS => '0');

    --Moving Box constants
    CONSTANT BOX_WIDTH : NATURAL := 8;
    CONSTANT BOX_CLK_DIV : NATURAL := 1000000; --MAX=(2^25 - 1)

    CONSTANT BOX_X_MAX : NATURAL := (512 - BOX_WIDTH);
    CONSTANT BOX_Y_MAX : NATURAL := (FRAME_HEIGHT - BOX_WIDTH);

    CONSTANT BOX_X_MIN : NATURAL := 0;
    CONSTANT BOX_Y_MIN : NATURAL := 256;

    CONSTANT BOX_X_INIT : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"000";
    CONSTANT BOX_Y_INIT : STD_LOGIC_VECTOR(11 DOWNTO 0) := x"190"; --400

    SIGNAL active : STD_LOGIC;

    SIGNAL h_cntr_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL v_cntr_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

    SIGNAL h_sync_reg : STD_LOGIC := NOT(H_POL);
    SIGNAL v_sync_reg : STD_LOGIC := NOT(V_POL);

    SIGNAL h_sync_dly_reg : STD_LOGIC := NOT(H_POL);
    SIGNAL v_sync_dly_reg : STD_LOGIC := NOT(V_POL);

    SIGNAL vga_red_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_green_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL vga_blue_reg : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    SIGNAL vga_red : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_green : STD_LOGIC_VECTOR(3 DOWNTO 0);
    SIGNAL vga_blue : STD_LOGIC_VECTOR(3 DOWNTO 0);

    SIGNAL box_x_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := BOX_X_INIT;
    SIGNAL box_x_dir : STD_LOGIC := '1';
    SIGNAL box_y_reg : STD_LOGIC_VECTOR(11 DOWNTO 0) := BOX_Y_INIT;
    SIGNAL box_y_dir : STD_LOGIC := '1';
    SIGNAL box_cntr_reg : STD_LOGIC_VECTOR(24 DOWNTO 0) := (OTHERS => '0');

    SIGNAL update_box : STD_LOGIC;
    SIGNAL pixel_in_box : STD_LOGIC;

BEGIN

    addrb <= bram_address_reg;

    bram_address_next <= (OTHERS => '0') WHEN (h_cntr_reg = (H_TOTAL_LINE - 1)) AND (v_cntr_reg = (V_MAX_LINE - 1)) ELSE
        bram_address_reg + 1 WHEN h_cntr_reg < FRAME_WIDTH AND v_cntr_reg < FRAME_HEIGHT ELSE
        bram_address_reg;

    PROCESS (pxl_clk)
    BEGIN
        IF rising_edge(pxl_clk) THEN
            bram_address_reg <= bram_address_next;
        END IF;
    END PROCESS;

    vga_red <= doutb(11 DOWNTO 8) WHEN active = '1' ELSE
        (OTHERS => '0');

    vga_blue <= doutb(3 DOWNTO 0) WHEN active = '1' ELSE
        (OTHERS => '0');

    vga_green <= doutb(7 DOWNTO 4) WHEN active = '1' ELSE
        (OTHERS => '0');

    ----------------------------------------------------
    -------         TEST PATTERN LOGIC           -------
    ----------------------------------------------------
    -- vga_red <= h_cntr_reg(5 DOWNTO 2) WHEN (active = '1' AND ((h_cntr_reg < 512 AND v_cntr_reg < 256) AND h_cntr_reg(8) = '1')) ELSE
    --     (OTHERS => '1') WHEN (active = '1' AND ((h_cntr_reg < 512 AND NOT(v_cntr_reg < 256)) AND NOT(pixel_in_box = '1'))) ELSE
    --     (OTHERS => '1') WHEN (active = '1' AND ((NOT(h_cntr_reg < 512) AND (v_cntr_reg(8) = '1' AND h_cntr_reg(3) = '1')) OR
    --     (NOT(h_cntr_reg < 512) AND (v_cntr_reg(8) = '0' AND v_cntr_reg(3) = '1')))) ELSE
    --     (OTHERS => '0');

    -- vga_blue <= h_cntr_reg(5 DOWNTO 2) WHEN (active = '1' AND ((h_cntr_reg < 512 AND v_cntr_reg < 256) AND h_cntr_reg(6) = '1')) ELSE
    --     (OTHERS => '1') WHEN (active = '1' AND ((h_cntr_reg < 512 AND NOT(v_cntr_reg < 256)) AND NOT(pixel_in_box = '1'))) ELSE
    --     (OTHERS => '1') WHEN (active = '1' AND ((NOT(h_cntr_reg < 512) AND (v_cntr_reg(8) = '1' AND h_cntr_reg(3) = '1')) OR
    --     (NOT(h_cntr_reg < 512) AND (v_cntr_reg(8) = '0' AND v_cntr_reg(3) = '1')))) ELSE
    --     (OTHERS => '0');

    -- vga_green <= h_cntr_reg(5 DOWNTO 2) WHEN (active = '1' AND ((h_cntr_reg < 512 AND v_cntr_reg < 256) AND h_cntr_reg(7) = '1')) ELSE
    --     (OTHERS => '1') WHEN (active = '1' AND ((h_cntr_reg < 512 AND NOT(v_cntr_reg < 256)) AND NOT(pixel_in_box = '1'))) ELSE
    --     (OTHERS => '1') WHEN (active = '1' AND ((NOT(h_cntr_reg < 512) AND (v_cntr_reg(8) = '1' AND h_cntr_reg(3) = '1')) OR
    --     (NOT(h_cntr_reg < 512) AND (v_cntr_reg(8) = '0' AND v_cntr_reg(3) = '1')))) ELSE
    --     (OTHERS => '0');
    ------------------------------------------------------
    -------         MOVING BOX LOGIC                ------
    ------------------------------------------------------
    PROCESS (pxl_clk)
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF (update_box = '1') THEN
                IF (box_x_dir = '1') THEN
                    box_x_reg <= box_x_reg + 1;
                ELSE
                    box_x_reg <= box_x_reg - 1;
                END IF;
                IF (box_y_dir = '1') THEN
                    box_y_reg <= box_y_reg + 1;
                ELSE
                    box_y_reg <= box_y_reg - 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pxl_clk)
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF (update_box = '1') THEN
                IF ((box_x_dir = '1' AND (box_x_reg = BOX_X_MAX - 1)) OR (box_x_dir = '0' AND (box_x_reg = BOX_X_MIN + 1))) THEN
                    box_x_dir <= NOT(box_x_dir);
                END IF;
                IF ((box_y_dir = '1' AND (box_y_reg = BOX_Y_MAX - 1)) OR (box_y_dir = '0' AND (box_y_reg = BOX_Y_MIN + 1))) THEN
                    box_y_dir <= NOT(box_y_dir);
                END IF;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pxl_clk)
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF (box_cntr_reg = (BOX_CLK_DIV - 1)) THEN
                box_cntr_reg <= (OTHERS => '0');
            ELSE
                box_cntr_reg <= box_cntr_reg + 1;
            END IF;
        END IF;
    END PROCESS;

    update_box <= '1' WHEN box_cntr_reg = (BOX_CLK_DIV - 1) ELSE
        '0';

    pixel_in_box <= '1' WHEN (((h_cntr_reg >= box_x_reg) AND (h_cntr_reg < (box_x_reg + BOX_WIDTH))) AND
        ((v_cntr_reg >= box_y_reg) AND (v_cntr_reg < (box_y_reg + BOX_WIDTH)))) ELSE
        '0';
    ------------------------------------------------------
    -------         SYNC GENERATION                 ------
    ------------------------------------------------------

    PROCESS (pxl_clk) --increment h_cntr_reg
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF (h_cntr_reg = (H_TOTAL_LINE - 1)) THEN -- counts to 800 and then wraps around
                h_cntr_reg <= (OTHERS => '0');
            ELSE
                h_cntr_reg <= h_cntr_reg + 1; -- index of current pixel in line
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pxl_clk) --increment v_cntr_reg
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF ((h_cntr_reg = (H_TOTAL_LINE - 1)) AND (v_cntr_reg = (V_MAX_LINE - 1))) THEN --wraps around when frame ends
                v_cntr_reg <= (OTHERS => '0');
            ELSIF (h_cntr_reg = (H_TOTAL_LINE - 1)) THEN --increments when line is finished
                v_cntr_reg <= v_cntr_reg + 1; --keeps track of current line in frame
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pxl_clk)
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF (h_cntr_reg >= (H_FRONT_PORCH + FRAME_WIDTH - 1)) AND (h_cntr_reg < (H_FRONT_PORCH + FRAME_WIDTH + H_SYNC_PULSE_WIDTH - 1)) THEN
                h_sync_reg <= H_POL; -- '0' if h_cntr_reg is greater or equal to 656 and lower than 752
            ELSE
                h_sync_reg <= NOT(H_POL); --'1'
            END IF;
        END IF;
    END PROCESS;

    PROCESS (pxl_clk)
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            IF (v_cntr_reg >= (V_FRONT_PORCH + FRAME_HEIGHT - 1)) AND (v_cntr_reg < (V_FRONT_PORCH + FRAME_HEIGHT + V_SYNC_PULSE_WIDTH - 1)) THEN
                v_sync_reg <= V_POL; --'0' if v_cntr_reg >= 490 and less than 492
            ELSE
                v_sync_reg <= NOT(V_POL); --'1'
            END IF;
        END IF;
    END PROCESS;

    active <= '1' WHEN ((h_cntr_reg < FRAME_WIDTH) AND (v_cntr_reg < FRAME_HEIGHT))ELSE
        '0';

    PROCESS (pxl_clk)
    BEGIN
        IF (rising_edge(pxl_clk)) THEN
            v_sync_dly_reg <= v_sync_reg;
            h_sync_dly_reg <= h_sync_reg;
            vga_red_reg <= vga_red;
            vga_green_reg <= vga_green;
            vga_blue_reg <= vga_blue;
        END IF;
    END PROCESS;

    VGA_HS_O <= h_sync_dly_reg;
    VGA_VS_O <= v_sync_dly_reg;
    VGA_R <= vga_red_reg;
    VGA_G <= vga_green_reg;
    VGA_B <= vga_blue_reg;
END ARCHITECTURE;