LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY uart_tx_own IS
    GENERIC (
        g_CLKS_PER_BIT : INTEGER := 868 -- 100MHz / 115200 Baud
    );
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        i_start : IN STD_LOGIC;
        i_byte : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        o_serial : OUT STD_LOGIC;
        o_done : OUT STD_LOGIC
    );
END uart_tx_own;

ARCHITECTURE rtl OF uart_tx_own IS
    TYPE state_type IS (IDLE, START_BIT, DATA_BITS,
        STOP_BIT, CLEANUP);
    SIGNAL state_reg, state_next : state_type := IDLE;
    SIGNAL clk_cnt_reg, clk_cnt_next : INTEGER RANGE 0 TO g_CLKS_PER_BIT;
    SIGNAL byte_reg, byte_next : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL index_reg, index_next : INTEGER RANGE 0 TO 7 := 0;
    SIGNAL clk_tick : STD_LOGIC := '0';
    SIGNAL tx_serial_line : STD_LOGIC := '0';
    SIGNAL cnt_ena, cnt_rst : STD_LOGIC := '0';

BEGIN

    PROCESS (clk, rst)
    BEGIN
        IF rst = '1' THEN
            state_reg <= IDLE;
            clk_cnt_reg <= 0;
            byte_reg <= (OTHERS => '0');
            index_reg <= 0;
        ELSIF rising_edge(clk) THEN
            state_reg <= state_next;
            clk_cnt_reg <= clk_cnt_next;
            byte_reg <= byte_next;
            index_reg <= index_next;
        END IF;
    END PROCESS;

    clk_cnt_next <=
        0 WHEN (clk_cnt_reg = g_CLKS_PER_BIT - 1 AND cnt_ena = '1') OR cnt_rst = '1' ELSE
        clk_cnt_reg + 1 WHEN clk_cnt_reg < g_CLKS_PER_BIT AND cnt_ena = '1' ELSE
        clk_cnt_reg;

    clk_tick <= '1' WHEN clk_cnt_reg = g_CLKS_PER_BIT - 1 ELSE
        '0';

    PROCESS (state_reg, i_start, i_byte, clk_tick, tx_serial_line, index_reg, byte_reg)
    BEGIN
        state_next <= state_reg;
        index_next <= index_reg;
        cnt_ena <= '0';
        cnt_rst <= '0';
        o_done <= '0';
        tx_serial_line <= '1';
        byte_next <= byte_reg;
        CASE state_reg IS
            WHEN IDLE =>
                IF i_start = '1' THEN
                    state_next <= START_BIT;
                    byte_next <= i_byte;
                END IF;

            WHEN START_BIT => --pull serial low 
                cnt_ena <= '1';
                tx_serial_line <= '0';
                IF clk_tick = '1' THEN
                    cnt_rst <= '1';
                    state_next <= DATA_BITS;
                END IF;

            WHEN DATA_BITS =>
                cnt_ena <= '1';
                tx_serial_line <= byte_reg(index_reg);
                IF clk_tick = '1' THEN
                    cnt_rst <= '1';
                    IF index_reg < 7 THEN
                        index_next <= index_reg + 1;
                        state_next <= DATA_BITS;
                    ELSE
                        state_next <= STOP_BIT;
                    END IF;
                END IF;

            WHEN STOP_BIT =>
                cnt_ena <= '1';
                tx_serial_line <= '1';

                IF clk_tick = '1' THEN
                    cnt_rst <= '1';
                    state_next <= CLEANUP;
                END IF;
                --tx_serial_line <= '0';
            WHEN CLEANUP =>
                o_done <= '1';
                index_next <= 0;
                byte_next <= (OTHERS => '0');
                state_next <= IDLE;
        END CASE;
    END PROCESS;

    o_serial <= tx_serial_line;
END ARCHITECTURE;