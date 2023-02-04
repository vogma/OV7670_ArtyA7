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

    --53
    TYPE rom_type IS ARRAY (0 TO 76) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL register_config_rom : rom_type := (
        -- x"1204",
        -- x"1180",
        -- x"0C00",
        -- x"3E00",
        -- x"8C00",
        -- x"0400", --falsch 
        -- x"4010",
        -- x"3a04",
        -- x"1438",
        -- x"4fb3",
        -- x"50b3",
        -- x"5100",
        -- x"523d",
        -- x"53a7",
        -- x"54e4",
        -- x"589e",
        -- x"3dc0",
        -- x"1100",
        -- x"1711", --fehlt beim lesen aber wird korrekt geschrieben
        -- x"1861",
        -- x"32A4",
        -- x"1903",
        -- x"1A7b",
        -- x"030a",
        -- x"0e61",
        -- x"0f4b",
        -- x"1602",
        -- x"1e37",
        -- x"2102",
        -- x"2291",
        -- x"2907",
        -- x"330b",
        -- x"350b",
        -- x"371d",
        -- x"3871",
        -- x"392a",
        -- x"3c78",
        -- x"4d40",
        -- x"4e20",
        -- x"6900",
        -- x"6b4a",
        -- x"7410",
        -- x"8d4f",
        -- x"8e00",
        -- x"8f00",
        -- x"9000",
        -- x"9100",
        -- x"9600",
        -- x"9a00",
        -- x"b084",
        -- x"b10c",
        -- x"b20e",
        -- x"b382",
        -- x"b80a"
        --source https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
        x"12_04", --set output format to RGB
        x"15_20", --pclk will not toggle during horizontal blank
        x"40_d0", --RGB565	-- These are values scalped from https:--github.com/jonlwowski012/OV7670_NEXYS4_Verilog/blob/master/ov7670_registers_verilog.v
        x"12_04", -- COM7,     set RGB color output
        x"11_80", -- CLKRC     internal PLL matches input clock
        x"0C_00", -- COM3,     default settings
        x"3E_00", -- COM14,    no scaling, normal pclock
        x"04_00", -- COM1,     disable CCIR656
        x"40_d0", --COM15,     RGB565, full output range
        x"3a_04", --TSLB       set correct output data sequence (magic)
        x"14_18", --COM9       MAX AGC value x4 0001_1000
        x"4F_B3", --MTX1       all of these are magical matrix coefficients
        x"50_B3", --MTX2
        x"51_00", --MTX3
        x"52_3d", --MTX4
        x"53_A7", --MTX5
        x"54_E4", --MTX6
        x"58_9E", --MTXS
        x"3D_C0", --COM13      sets gamma enable, does not preserve reserved bits, may be wrong?
        x"17_14", --HSTART     start high 8 bits
        x"18_02", --HSTOP      stop high 8 bits --these kill the odd colored line
        x"32_80", --HREF       edge offset
        x"19_03", --VSTART     start high 8 bits
        x"1A_7B", --VSTOP      stop high 8 bits
        x"03_0A", --VREF       vsync edge offset
        x"0F_41", --COM6       reset timings
        x"1E_00", --MVFP       disable mirror / flip --might have magic value of 03
        x"33_0B", --CHLF       --magic value from the internet
        x"3C_78", --COM12      no HREF when VSYNC low
        x"69_00", --GFIX       fix gain control
        x"74_00", --REG74      Digital gain control
        x"B0_84", --RSVD       magic value from the internet *required* for good color
        x"B1_0c", --ABLC1
        x"B2_0e", --RSVD       more magic internet values
        x"B3_80", --THL_ST --begin mystery scaling numbers
        x"70_3a",
        x"71_35",
        x"72_11",
        x"73_f0",
        x"a2_02", --gamma curve values
        x"7a_20",
        x"7b_10",
        x"7c_1e",
        x"7d_35",
        x"7e_5a",
        x"7f_69",
        x"80_76",
        x"81_80",
        x"82_88",
        x"83_8f",
        x"84_96",
        x"85_a3",
        x"86_af",
        x"87_c4",
        x"88_d7",
        x"89_e8", --AGC and AEC
        x"13_e0", --COM8, disable AGC / AEC
        x"00_00", --set gain reg to 0 for AGC
        x"10_00", --set ARCJ reg to 0
        x"0d_40", --magic reserved bit for COM4
        x"14_18", --COM9, 4x gain + magic bit
        x"a5_05", -- BD50MAX
        x"ab_07", --DB60MAX
        x"24_95", --AGC upper limit
        x"25_33", --AGC lower limit
        x"26_e3", --AGC/AEC fast mode op region
        x"9f_78", --HAECC1
        x"a0_68", --HAECC2
        x"a1_03", --magic
        x"a6_d8", --HAECC3
        x"a7_d8", --HAECC4
        x"a8_f0", --HAECC5
        x"a9_90", --HAECC6
        x"aa_94", --HAECC7
        x"13_e5", --COM8, enable AGC / AEC
        x"1E_23", --Mirror Image
        x"69_06" --gain of RGB(manually adjusted)
    );

    --Signals
    SIGNAL reset_busy_cnt : STD_LOGIC := '0';
    CONSTANT I2C_READ : STD_LOGIC := '1';
    CONSTANT I2C_WRITE : STD_LOGIC := '0';
    CONSTANT OV7670_ADDR : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0100001";
    SIGNAL ov7670_reset_sig : STD_LOGIC := '1';
    SIGNAL busy_prev : STD_LOGIC := '0';
    SIGNAL register_config : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    --Registers
    SIGNAL state_reg, state_next : state_type := powerup;
    SIGNAL busy_reg, busy_next, i2c_busy_edge : STD_LOGIC := '0'; -- indicates transaction in progress
    SIGNAL led_reg, led_next : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL counter_reg, counter_next : INTEGER RANGE 0 TO 100000 := 0;
    SIGNAL wait_600ms_reg, wait_600ms_next : INTEGER RANGE 0 TO 60_000_000 := 0;
    SIGNAL i2c_ena_reg, i2c_ena_next : STD_LOGIC := '0';
    SIGNAL read_reg, read_next : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL done_reg, done_next : STD_LOGIC := '0';
    SIGNAL busy_cnt_reg, busy_cnt_next : INTEGER RANGE 0 TO 3 := 0;
    SIGNAL config_finished_reg, config_finished_next : STD_LOGIC := '0';
    SIGNAL rom_index, rom_index_next : INTEGER RANGE 0 TO register_config_rom'length := 0;
BEGIN

    PROCESS (clk, rst)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state_reg <= idle;
                busy_reg <= '0';
                done_reg <= '0';
                rom_index <= 0;
                read_reg <= (OTHERS => '0');
                --led_reg <= (OTHERS => '0');
                counter_reg <= 0;
                wait_600ms_reg <= 0;
                i2c_ena_reg <= '0';
                config_finished_reg <= '0';
                busy_cnt_reg <= 0;
            ELSE
                state_reg <= state_next;
                read_reg <= read_next;
                busy_reg <= busy_next;
                --led_reg <= led_next;
                rom_index <= rom_index_next;
                counter_reg <= counter_next;
                config_finished_reg <= config_finished_next;
                i2c_ena_reg <= i2c_ena_next;
                done_reg <= done_next;
                wait_600ms_reg <= wait_600ms_next;
                busy_cnt_reg <= busy_cnt_next;
            END IF;
        END IF;
    END PROCESS;

    busy_cnt_next <= 0 WHEN reset_busy_cnt = '1' ELSE
        busy_cnt_reg + 1 WHEN i2c_busy_edge = '1' ELSE
        busy_cnt_reg;
    busy_next <= i2c_busy; --captures the current value of the busy signal in the busy_reg register
    i2c_busy_edge <= '1' WHEN (busy_reg = '0' AND i2c_busy = '1') ELSE
        '0'; --detects the rising_edge of the busy signal from the i2c_master
    i2c_addr <= OV7670_ADDR;

    reg_value <= read_reg;

    register_config <= register_config_rom(rom_index);

    i2c_ena <= i2c_ena_reg;
    done <= done_reg;

    config_finished <= config_finished_reg;

    ov7670_reset <= ov7670_reset_sig;

    PROCESS (state_reg, start, busy_cnt_reg, done_reg, config_finished_reg, wait_600ms_reg, read_reg, register_config, rom_index, i2c_rdata, i2c_ena_reg, counter_reg, i2c_busy, busy_prev)
    BEGIN
        i2c_rw <= '0';
        reset_busy_cnt <= '0';
        done_next <= done_reg;
        read_next <= read_reg;
        i2c_wdata <= (OTHERS => '0');
        i2c_ena_next <= i2c_ena_reg;
        state_next <= state_reg;
        --led_next <= led_reg;
        config_finished_next <= config_finished_reg;
        rom_index_next <= rom_index;
        --reg_value <= (OTHERS => '0');
        counter_next <= counter_reg;
        wait_600ms_next <= wait_600ms_reg;
        ov7670_reset_sig <= '1';

        CASE state_reg IS

            WHEN powerup => --wait 600ms for device to powerup 
                wait_600ms_next <= wait_600ms_reg + 1;
                IF wait_600ms_reg = 59_999_999 THEN
                    reset_busy_cnt <= '1';
                    state_next <= reset_device;
                END IF;

            WHEN idle =>
                IF start = '1' THEN
                    rom_index_next <= 0;
                    --led_next <= (OTHERS => '0');
                    config_finished_next <= '0';
                    state_next <= reset_device;
                END IF;

            WHEN reset_device =>

                wait_600ms_next <= wait_600ms_reg + 1;
                IF wait_600ms_reg < 30_000_000 THEN
                    ov7670_reset_sig <= '0'; --active low reset
                END IF;

                IF wait_600ms_reg = 59_999_999 THEN
                    state_next <= i2c_write_register; -- 600ms over
                    reset_busy_cnt <= '1';
                END IF;

            WHEN i2c_write_register =>
                --led_next(1) <= '1';
                CASE busy_cnt_reg IS
                    WHEN 0 =>
                        i2c_ena_next <= '1'; --start i2c transaction
                        i2c_rw <= I2C_WRITE;
                        i2c_wdata <= register_config(15 DOWNTO 8);-- register address
                        --i2c_wdata <= x"19"; --Register 4A
                    WHEN 1 =>
                        i2c_wdata <= register_config(7 DOWNTO 0);-- register value
                        --i2c_wdata <= x"4D";
                    WHEN 2 =>
                        i2c_ena_next <= '0';
                        IF i2c_busy = '0' THEN --i2c transaction completed 
                            reset_busy_cnt <= '1'; --reset busy_cnt register
                            counter_next <= 0;
                            state_next <= wait_between_tx;
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;

            WHEN wait_between_tx => -- waits for 1ms between write and read
                counter_next <= counter_reg + 1;
                IF counter_reg = 99999 THEN
                    counter_next <= 0;
                    IF rom_index < register_config_rom'length THEN
                        rom_index_next <= rom_index + 1;
                        state_next <= i2c_write_register;
                    ELSE
                        rom_index_next <= 0;
                        config_finished_next <= '1';
                        state_next <= i2c_write_read_register_address;
                    END IF;
                END IF;

            WHEN i2c_write_read_register_address =>
                --led_next(2) <= '1';
                CASE busy_cnt_reg IS
                    WHEN 0 =>
                        i2c_ena_next <= '1';
                        i2c_rw <= I2C_WRITE;
                        i2c_wdata <= register_config(15 DOWNTO 8);
                    WHEN 1 =>
                        --i2c_wdata <= x"4C";
                        i2c_ena_next <= '0';
                        IF i2c_busy = '0' THEN
                            counter_next <= 0;

                            state_next <= wait_1us;
                            reset_busy_cnt <= '1';
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;

            WHEN wait_1us => --wait 1us between write register address and read register value
                --led_next(3) <= '1';
                counter_next <= counter_reg + 1;
                IF counter_reg = 260 THEN
                    counter_next <= 0;
                    state_next <= i2c_read_reg;
                    reset_busy_cnt <= '1';
                END IF;

            WHEN i2c_read_reg =>
                CASE busy_cnt_reg IS
                    WHEN 0 =>
                        i2c_ena_next <= '1';
                        i2c_rw <= I2C_READ;
                    WHEN 1 =>
                        i2c_rw <= I2C_READ;
                        IF i2c_busy = '0' THEN
                            done_next <= '1';
                            read_next <= i2c_rdata;
                            i2c_ena_next <= '0';
                            state_next <= wait_1us_after_read;
                            reset_busy_cnt <= '1';
                        END IF;
                    WHEN OTHERS => NULL;
                END CASE;

            WHEN wait_1us_after_read => --wait 1us between write register address and read register value
                done_next <= '0';
                counter_next <= counter_reg + 1;

                IF counter_reg >= 100000 - 1 THEN
                    counter_next <= counter_reg;

                    IF rom_index < register_config_rom'length THEN
                        rom_index_next <= rom_index + 1;
                        reset_busy_cnt <= '1';
                        counter_next <= 0;
                        state_next <= i2c_write_read_register_address;
                    ELSE
                        counter_next <= 0;
                        state_next <= idle;
                    END IF;
                END IF;
            WHEN OTHERS =>
                state_next <= idle;
        END CASE;
    END PROCESS;
END ARCHITECTURE;