LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

USE work.common_pkg.ALL;

ENTITY ov7670_configuration IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        edge : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        sda : INOUT STD_LOGIC;
        scl : INOUT STD_LOGIC;
        start : IN STD_LOGIC;
        done : OUT STD_LOGIC;
        ack_err : OUT STD_LOGIC;
        ov7670_reset : OUT STD_LOGIC;
        config_finished : OUT STD_LOGIC;
        reg_value : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END ov7670_configuration;

ARCHITECTURE Behavioral OF ov7670_configuration IS
    SIGNAL i2c_ena : STD_LOGIC := '0'; -- latch in command
    SIGNAL i2c_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0'); -- address of target slave
    SIGNAL i2c_rw : STD_LOGIC := '0';
    SIGNAL i2c_busy : STD_LOGIC := '0'; -- indicates transaction in progress
    SIGNAL i2c_rdata, i2c_wdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- data read from slave
    SIGNAL i2c_ack_err : STD_LOGIC := '0'; -- flag if improper acknowledge from slave

BEGIN

    ov7670_fsm : ENTITY work.ov7670_fsm(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            start => start,
            i2c_busy => i2c_busy,
            i2c_rdata => i2c_rdata,
            i2c_addr => i2c_addr,
            i2c_wdata => i2c_wdata,
            i2c_ena => i2c_ena,
            i2c_rw => i2c_rw,
            ov7670_reset => ov7670_reset,
            reg_value => reg_value,
            config_finished => config_finished,
            done => done
        );

    i2c_master : ENTITY work.i2c_master(logic) --i2c_master entity
        GENERIC MAP(
            input_clk => C_ARTY_A7_CLK_FREQ
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