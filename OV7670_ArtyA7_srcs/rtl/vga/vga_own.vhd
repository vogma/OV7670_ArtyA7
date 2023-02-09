LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY vga_own IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        pxl_clk : IN STD_LOGIC;
        VGA_HS_O : OUT STD_LOGIC;
        VGA_VS_O : OUT STD_LOGIC;
        VGA_R : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_B : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_G : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);

        start : IN STD_LOGIC;

        --frame_buffer signals
        addrb : OUT STD_LOGIC_VECTOR(18 DOWNTO 0);
        doutb : IN STD_LOGIC_VECTOR(11 DOWNTO 0) --pixel data
    );
END vga_own;

ARCHITECTURE rtl OF vga_own IS
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

    SIGNAL hsync_reg, hsync_next : INTEGER RANGE 0 TO H_TOTAL_LINE - 1 := 0;
    SIGNAL vsync_reg, vsync_next : INTEGER RANGE 0 TO V_MAX_LINE - 1 := 0;

    SIGNAL bram_address_reg, bram_address_next : unsigned(18 DOWNTO 0) := (OTHERS => '0');

    SIGNAL line_finished : STD_LOGIC := '0';
    SIGNAL frame_finished : STD_LOGIC := '0';
    -- Clock frequency 25.175 MHz
    -- Line  frequency 31469 Hz
    -- Field frequency 59.94 Hz
    -- One line:
    --   8 pixels front porch
    --  96 pixels horizontal sync
    --  40 pixels back porch
    --   8 pixels left border
    -- 640 pixels video
    --   8 pixels right border
    -- ---
    -- 800 pixels total per line 

    -- One field:
    --   2 lines front porch
    --   2 lines vertical sync
    --  25 lines back porch
    --   8 lines top border
    -- 480 lines video
    --   8 lines bottom border
    -- ---
    -- 525 lines total
BEGIN
    addrb <= STD_LOGIC_VECTOR(bram_address_reg);

    hsync_next <= 0 WHEN line_finished = '1' AND start = '1' ELSE
        hsync_reg + 1;

    line_finished <= '1' WHEN hsync_reg = H_TOTAL_LINE - 1 ELSE
        '0';

    VGA_HS_O <= '0' WHEN hsync_reg >= (H_FRONT_PORCH + FRAME_WIDTH) AND hsync_reg < (H_FRONT_PORCH + FRAME_WIDTH + H_SYNC_PULSE_WIDTH) ELSE
        '1'; --HSync Timing

    VGA_VS_O <= '0' WHEN vsync_reg >= (V_FRONT_PORCH + FRAME_HEIGHT) AND vsync_reg < (V_FRONT_PORCH + FRAME_HEIGHT + V_SYNC_PULSE_WIDTH) ELSE
        '1'; --VSync timing

    frame_finished <= '1' WHEN vsync_reg = V_MAX_LINE - 1 ELSE
        '0';

    vga_r <= doutb(11 DOWNTO 8);
    vga_g <= doutb(7 DOWNTO 4);
    vga_b <= doutb(3 DOWNTO 0);

    -- VGA_R <= "1111" WHEN hsync_reg >= 0 AND vsync_reg >= 0 AND hsync_reg < 10 AND vsync_reg < 10 ELSE --left upper corner
    --     "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= 0 AND hsync_reg < FRAME_WIDTH AND vsync_reg < 10 ELSE --right upper corner 
    --     "1111" WHEN hsync_reg >= 0 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < 10 AND vsync_reg < FRAME_HEIGHT ELSE --left lower corner 
    --     "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --right upper corner 
    --     "0000";

    -- VGA_B <= "1111" WHEN hsync_reg >= 0 AND vsync_reg >= 0 AND hsync_reg < 10 AND vsync_reg < 10 ELSE
    --     "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= 0 AND hsync_reg < FRAME_WIDTH AND vsync_reg < 10 ELSE
    --     "1111" WHEN hsync_reg >= 0 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < 10 AND vsync_reg < FRAME_HEIGHT ELSE --left lower corner #        "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --right upper corner 
    --     "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --right upper corner 

    --     "0000";

    -- VGA_G <= "1111" WHEN hsync_reg >= 0 AND vsync_reg >= 0 AND hsync_reg < 10 AND vsync_reg < 10 ELSE
    --     "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= 0 AND hsync_reg < 640 AND vsync_reg < 10 ELSE
    --     "1111" WHEN hsync_reg >= 0 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < 10 AND vsync_reg < FRAME_HEIGHT ELSE --left lower corner 
    --     "1111" WHEN hsync_reg >= FRAME_WIDTH - 10 AND vsync_reg >= FRAME_HEIGHT - 10 AND hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT ELSE --right upper corner 

    --     "0000";

    vsync_next <= 0 WHEN frame_finished = '1' AND start = '1' ELSE
        vsync_reg + 1 WHEN line_finished = '1' AND start = '1' ELSE
        vsync_reg;

    bram_address_next <= (OTHERS => '0') WHEN frame_finished = '1' AND start = '1' ELSE
        bram_address_reg + 1 WHEN hsync_reg < FRAME_WIDTH AND vsync_reg < FRAME_HEIGHT AND start = '1'ELSE
        bram_address_reg;

    PROCESS (pxl_clk)
    BEGIN
        IF rising_edge(pxl_clk) THEN
            hsync_reg <= hsync_next;
            vsync_reg <= vsync_next;
            bram_address_reg <= bram_address_next;
        END IF;
    END PROCESS;
END ARCHITECTURE;