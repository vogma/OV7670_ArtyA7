LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.common_pkg.ALL;

ENTITY ov7670_fsm IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        start : IN STD_LOGIC;
        i2c_busy : IN STD_LOGIC;
        i2c_rdata : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        i2c_addr : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        i2c_wdata : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        i2c_ena : OUT STD_LOGIC;
        i2c_rw : OUT STD_LOGIC;
        ov7670_reset : OUT STD_LOGIC;
        reg_value : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        config_finished : OUT STD_LOGIC;
        done : OUT STD_LOGIC
    );
END ov7670_fsm;

ARCHITECTURE rtl OF ov7670_fsm IS

    --Type decleration
    TYPE state_type IS (powerup, idle, reset_device, i2c_write_register, wait_between_tx, i2c_write_read_register_address, wait_1us,
        i2c_read_reg, wait_1us_after_read);


    --Signals
    CONSTANT I2C_READ : STD_LOGIC := '1';
    CONSTANT I2C_WRITE : STD_LOGIC := '0';
    CONSTANT OV7670_ADDR : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0100001";

    CONSTANT CLK_CNT_600MS : INTEGER := (C_ARTY_A7_CLK_FREQ / 10) * 6;
    CONSTANT CLK_CNT_1MS : INTEGER := (C_ARTY_A7_CLK_FREQ / 1000);
    CONSTANT CLK_CNT_1US : INTEGER := (C_ARTY_A7_CLK_FREQ / 1_000_000);

    SIGNAL reset_busy_cnt : STD_LOGIC := '0';
    SIGNAL ov7670_reset_sig : STD_LOGIC := '1';
    SIGNAL busy_prev : STD_LOGIC := '0';
    SIGNAL register_config : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL i2c_busy_edge : STD_LOGIC := '0';

    TYPE reg_type IS RECORD
        state : state_type;
        counter : INTEGER RANGE 0 TO CLK_CNT_600MS;
        i2c_ena : STD_LOGIC;
        read : STD_LOGIC_VECTOR(7 DOWNTO 0);
        done : STD_LOGIC;
        config_finished : STD_LOGIC;
        rom_index : INTEGER RANGE 0 TO register_config_rom'length;
    END RECORD reg_type;

    TYPE i2c_reg_type IS RECORD
        busy : STD_LOGIC;
        busy_cnt : INTEGER RANGE 0 TO 3;
    END RECORD i2c_reg_type;

    CONSTANT INIT_REG_FILE : reg_type := (
        state => powerup,
        counter => 0,
        i2c_ena => '0',
        read => (OTHERS => '0'),
        done => '0',
        config_finished => '0',
        rom_index => 0
    );

    CONSTANT INIT_I2C_REGS : i2c_reg_type := (
        busy => '0',
        busy_cnt => 0
    );

    SIGNAL reg, reg_next : reg_type := INIT_REG_FILE;
    SIGNAL i2c_reg, i2c_next : i2c_reg_type := INIT_I2C_REGS;
BEGIN

    PROCESS (clk, rst)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                reg <= INIT_REG_FILE;
                i2c_reg <= INIT_I2C_REGS;
            ELSE
                reg <= reg_next;
                i2c_reg <= i2c_next;
            END IF;
        END IF;
    END PROCESS;

    PROCESS (reg, start, i2c_reg, register_config, i2c_rdata, i2c_busy, busy_prev)
    BEGIN
        reg_next <= reg;

        i2c_rw <= '0';
        reset_busy_cnt <= '0';
        i2c_wdata <= (OTHERS => '0');
        ov7670_reset_sig <= '1';
        CASE reg.state IS

            WHEN powerup => --wait 600ms for device to powerup 
                reg_next.counter <= reg.counter + 1;
                IF reg.counter = CLK_CNT_600MS - 1 THEN
                    reg_next.counter <= 0;
                    reset_busy_cnt <= '1';
                    reg_next.state <= reset_device;
                END IF;

            WHEN idle =>
                IF start = '1' THEN
                    reg_next.rom_index <= 0;
                    reg_next.config_finished <= '0';
                    reg_next.state <= reset_device;
                END IF;

            WHEN reset_device =>

                reg_next.counter <= reg.counter + 1;
                IF reg.counter < CLK_CNT_600MS / 2 THEN
                    ov7670_reset_sig <= '0'; --active low reset
                END IF;

                IF reg.counter = CLK_CNT_600MS THEN
                    reg_next.counter <= 0; --reset counter
                    reg_next.state <= i2c_write_register; -- 600ms over
                    reset_busy_cnt <= '1';
                END IF;

            WHEN i2c_write_register =>
                CASE i2c_reg.busy_cnt IS
                    WHEN 0 =>
                        reg_next.i2c_ena <= '1'; --start i2c transaction
                        i2c_rw <= I2C_WRITE;
                        i2c_wdata <= register_config(15 DOWNTO 8);-- register address
                    WHEN 1 =>
                        i2c_wdata <= register_config(7 DOWNTO 0);-- register value
                    WHEN 2 =>
                        reg_next.i2c_ena <= '0';
                        IF i2c_busy = '0' THEN --i2c transaction completed 
                            reset_busy_cnt <= '1'; --reset busy_cnt register
                            reg_next.state <= wait_between_tx;
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;

            WHEN wait_between_tx => -- waits for 1ms between write and read
                reg_next.counter <= reg.counter + 1;

                IF reg.counter = CLK_CNT_1MS - 1 THEN
                    reg_next.counter <= 0;
                    IF reg.rom_index < register_config_rom'length THEN
                        reg_next.rom_index <= reg.rom_index + 1;
                        reg_next.state <= i2c_write_register;
                    ELSE
                        reg_next.rom_index <= 0;
                        reg_next.config_finished <= '1';
                        reg_next.state <= i2c_write_read_register_address;
                    END IF;
                END IF;

            WHEN i2c_write_read_register_address =>
                CASE i2c_reg.busy_cnt IS
                    WHEN 0 =>
                        reg_next.i2c_ena <= '1';
                        i2c_rw <= I2C_WRITE;
                        i2c_wdata <= register_config(15 DOWNTO 8);
                    WHEN 1 =>
                        reg_next.i2c_ena <= '0';
                        IF i2c_busy = '0' THEN
                            reg_next.counter <= 0;

                            reg_next.state <= wait_1us;
                            reset_busy_cnt <= '1';
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;

            WHEN wait_1us => --wait 1us between write register address and read register value
                reg_next.counter <= reg.counter + 1;
                IF reg.counter = CLK_CNT_1US - 1 THEN
                    reg_next.counter <= 0;
                    reg_next.state <= i2c_read_reg;
                    reset_busy_cnt <= '1';
                END IF;

            WHEN i2c_read_reg =>
                CASE i2c_reg.busy_cnt IS
                    WHEN 0 =>
                        reg_next.i2c_ena <= '1';
                        i2c_rw <= I2C_READ;
                    WHEN 1 =>
                        i2c_rw <= I2C_READ;
                        IF i2c_busy = '0' THEN
                            reg_next.done <= '1';
                            reg_next.read <= i2c_rdata;
                            reg_next.i2c_ena <= '0';
                            reg_next.state <= wait_1us_after_read;
                            reset_busy_cnt <= '1';
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;

            WHEN wait_1us_after_read => --wait 1us between write register address and read register value
                reg_next.done <= '0';
                reg_next.counter <= reg.counter + 1;

                IF reg.counter >= CLK_CNT_1US - 1 THEN
                    reg_next.counter <= reg.counter;

                    IF reg.rom_index < register_config_rom'length THEN
                        reg_next.rom_index <= reg.rom_index + 1;
                        reset_busy_cnt <= '1';
                        reg_next.counter <= 0;
                        reg_next.state <= i2c_write_read_register_address;
                    ELSE
                        reg_next.counter <= 0;
                        reg_next.state <= idle;
                    END IF;
                END IF;
            WHEN OTHERS =>
                reg_next.state <= idle;
        END CASE;
    END PROCESS;

    i2c_next.busy_cnt <= 0 WHEN reset_busy_cnt = '1' ELSE
    i2c_reg.busy_cnt + 1 WHEN i2c_busy_edge = '1' ELSE
    i2c_reg.busy_cnt;

    i2c_next.busy <= i2c_busy; --captures the current value of the busy signal in the busy register
    i2c_busy_edge <= '1' WHEN (i2c_reg.busy = '0' AND i2c_busy = '1') ELSE
        '0'; --detects the rising_edge of the busy signal from the i2c_master
    i2c_addr <= OV7670_ADDR;

    reg_value <= reg.read;

    register_config <= register_config_rom(reg.rom_index);

    i2c_ena <= reg.i2c_ena;
    done <= reg.done;

    config_finished <= reg.config_finished;

    ov7670_reset <= ov7670_reset_sig;
END ARCHITECTURE;