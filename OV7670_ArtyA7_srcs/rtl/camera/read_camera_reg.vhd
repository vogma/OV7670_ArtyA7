LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

ENTITY read_camera_reg IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        edge : in std_logic_vector(3 downto 0);
        sda : INOUT STD_LOGIC;
        scl : INOUT STD_LOGIC;
        start : IN STD_LOGIC;
        done : OUT STD_LOGIC;
        ack_err : OUT STD_LOGIC;
        ov7670_reset : OUT STD_LOGIC;
        led : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        reg_value : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END read_camera_reg;

ARCHITECTURE Behavioral OF read_camera_reg IS

    TYPE state_type IS (IDLE, powerup, reset_device, i2c_write_register, wait_between_tx, i2c_write_read_register_address, wait_1us,
        i2c_read_reg,wait_1us_after_read);
    SIGNAL state_reg, state_next : state_type := IDLE;

    SIGNAL i2c_ena : STD_LOGIC := '0'; -- latch in command
    SIGNAL i2c_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0'); -- address of target slave
    SIGNAL i2c_rw : STD_LOGIC := '0';
    --data_wr   : in     std_logic_vector(7 downto 0);	-- data to write to slave
    SIGNAL i2c_busy, busy_reg, busy_next, i2c_busy_edge : STD_LOGIC := '0'; -- indicates transaction in progress
    SIGNAL i2c_rdata, i2c_wdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- data read from slave
    SIGNAL i2c_ack_err : STD_LOGIC := '0'; -- flag if improper acknowledge from slave
    CONSTANT camera_address : STD_LOGIC_VECTOR(6 DOWNTO 0) := "0100001";
    SIGNAL led_reg, led_next : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    SIGNAL counter_reg, counter_next : INTEGER RANGE 0 TO 100000 := 0;

    SIGNAL wait_600ms_reg, wait_600ms_next : INTEGER RANGE 0 TO 60_000_000 := 0;
    SIGNAL ov7670_reset_sig : STD_LOGIC := '1';

    SIGNAL i2c_ena_reg, i2c_ena_next : STD_LOGIC := '0';
    SIGNAL busy_prev : STD_LOGIC := '0';

    SIGNAL busy_cnt_reg, busy_cnt_next : INTEGER RANGE 0 TO 3 := 0;
    SIGNAL reset_busy_cnt : STD_LOGIC := '0';

    CONSTANT I2C_READ : STD_LOGIC := '1';
    CONSTANT I2C_WRITE : STD_LOGIC := '0';
    
    signal read_reg, read_next : std_logic_vector(7 downto 0) := (others=>'0');
        signal done_reg,done_next :std_logic := '0';

    TYPE rom_type IS ARRAY (0 TO 53) OF STD_LOGIC_VECTOR(15 DOWNTO 0);

    SIGNAL register_config : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');

    SIGNAL register_config_rom : rom_type := (
        x"1205",
        x"1100",
        x"0C00",
        x"3E00",
        x"8C00",
        x"0403", --falsch 
        x"4010",
        x"3a04",
        x"1438",
        x"4fb3",
        x"50b3",
        x"5100",
        x"523d",
        x"53a7",
        x"54e4",
        x"589e",
        x"3dc0",
        x"1100",
        x"1711", --fehlt beim lesen aber wird korrekt geschrieben
        x"1861",
        x"32A4",
        x"1903",
        x"1A7b",
        x"030a",
        x"0e61",
        x"0f4b",
        x"1602",
        x"1e37",
        x"2102",
        x"2291",
        x"2907",
        x"330b",
        x"350b",
        x"371d",
        x"3871",
        x"392a",
        x"3c78",
        x"4d40",
        x"4e20",
        x"6900",
        x"6b4a",
        x"7410",
        x"8d4f",
        x"8e00",
        x"8f00",
        x"9000",
        x"9100",
        x"9600",
        x"9a00",
        x"b084",
        x"b10c",
        x"b20e",
        x"b382",
        x"b80a"
    );
    
        SIGNAL rom_index, rom_index_next : INTEGER RANGE 0 TO register_config_rom'length := 0;

BEGIN
    PROCESS (clk, rst)
    BEGIN
        IF rising_edge(clk) THEN
            IF rst = '1' THEN
                state_reg <= IDLE;
                busy_reg <= '0';
                done_reg <= '0';
                rom_index <= 0;
                read_reg <= (others => '0');
                led_reg <= (OTHERS => '0');
                counter_reg <= 0;
                wait_600ms_reg <= 0;
                i2c_ena_reg <= '0';
                busy_cnt_reg <= 0;
            ELSE
                state_reg <= state_next;
                read_reg <= read_next;
                busy_reg <= busy_next;
                led_reg <= led_next;
                rom_index <= rom_index_next;
                counter_reg <= counter_next;
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

    led <= led_reg;
    i2c_addr <= camera_address;
    
    reg_value <= read_reg;

    register_config <= register_config_rom(rom_index);

    i2c_ena <= i2c_ena_reg;
    done <= done_reg;

    ov7670_reset <= ov7670_reset_sig;
    PROCESS (state_reg, start, busy_cnt_reg,done_reg, wait_600ms_reg,read_reg,edge, register_config, rom_index, i2c_rdata, i2c_ena_reg, counter_reg, i2c_busy, led_reg, busy_prev)
    BEGIN
        i2c_rw <= '0';
        reset_busy_cnt <= '0';
        done_next <= done_reg;
        read_next <= read_reg;
        i2c_wdata <= (OTHERS => '0');
        i2c_ena_next <= i2c_ena_reg;
        state_next <= state_reg;
        led_next <= led_reg;
        rom_index_next <= rom_index;
        --reg_value <= (OTHERS => '0');
        counter_next <= counter_reg;
        wait_600ms_next <= wait_600ms_reg;
        ov7670_reset_sig <= '1';

        CASE state_reg IS
            WHEN IDLE =>
                IF start = '1' THEN
                    rom_index_next <= 0;
                    led_next <= (OTHERS => '0');

                    state_next <= powerup;
                END IF;

            WHEN powerup => --wait 600ms for device to powerup 
                state_next <= reset_device;

            WHEN reset_device =>

                wait_600ms_next <= wait_600ms_reg + 1;
                IF wait_600ms_reg < 30_000_000 THEN
                    ov7670_reset_sig <= '0'; --active low reset
                END IF;

                IF wait_600ms_reg = 59_999_999 THEN
                    state_next <= i2c_write_register;
                    reset_busy_cnt <= '1';
                END IF;

            WHEN i2c_write_register =>
                led_next(1) <= '1';
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
                        state_next <= i2c_write_read_register_address;
                    END IF;
                END IF;

            WHEN i2c_write_read_register_address =>
                led_next(2) <= '1';
                CASE busy_cnt_reg IS
                    WHEN 0 =>
                        i2c_ena_next <= '1';
                        i2c_rw <= I2C_WRITE;
                        i2c_wdata <= register_config(15 downto 8);
                    WHEN 1 =>
                        --i2c_wdata <= x"4C";
                        i2c_ena_next <= '0';
                        IF i2c_busy = '0' THEN
                            counter_next <= 0;

                            state_next <= wait_1us;
                            reset_busy_cnt <= '1';
                        END IF;
                    WHEN 2 => NULL;
                        --                            i2c_ena_next <= '0'; 
                        --                           if i2c_busy = '0' then 
                        --                            counter_next <= 0;
                        --                            state_next <= wait_1us;
                        --                            reset_busy_cnt <= '1';
                        --                           end if;
                    WHEN OTHERS => NULL;
                END CASE;
                
            WHEN wait_1us => --wait 1us between write register address and read register value
                led_next(3) <= '1';
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
                
                IF counter_reg >= 100000-1 THEN
                   counter_next <= counter_reg;
                  
                    if rom_index < register_config_rom'length  then 
                     rom_index_next <= rom_index + 1;
                     reset_busy_cnt <= '1';
                     counter_next <= 0;
                     state_next <= i2c_write_read_register_address;
                    else 
                    counter_next <= 0;
                        state_next <= IDLE;
                    end if;
                 
                 

                    
                END IF;
            WHEN OTHERS =>
                state_next <= IDLE;
        END CASE;

    END PROCESS;

    busy_next <= i2c_busy; --captures the current value of the busy signal in the busy_reg register
    i2c_busy_edge <= '1' WHEN (busy_reg = '0' AND i2c_busy = '1') ELSE
        '0'; --detects the rising_edge of the busy signal from the i2c_master

    i2c_master : ENTITY work.i2c_master(logic) --i2c_master entity
        GENERIC MAP(
            input_clk => 100_000_000
        )
        PORT MAP(
            clk => clk,
            reset_n => rst,
            ena => i2c_ena,
            addr => i2c_addr,
            rw => i2c_rw,
            data_wr => i2c_wdata,
            busy => i2c_busy,
            data_rd => i2c_rdata,
            ack_error => i2c_ack_err,
            sda => sda,
            scl => scl
        );

    ack_err <= i2c_ack_err;

END Behavioral;