LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE work.common_pkg.ALL;

ENTITY sccb_master IS
    PORT (
        clk : IN STD_LOGIC;
        rst : IN STD_LOGIC;
        sda : INOUT STD_LOGIC;
        scl : INOUT STD_LOGIC;
        tx_start : IN STD_LOGIC; --start sccb transaction
        tx_done : OUT STD_LOGIC;
        rw : IN STD_LOGIC; --read=0 write=1
        reg_address : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        reg_value : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        read_data : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)

    );
END sccb_master;

ARCHITECTURE rtl OF sccb_master IS

    SIGNAL i2c_ena : STD_LOGIC := '0'; -- latch in command
    SIGNAL i2c_addr : STD_LOGIC_VECTOR(6 DOWNTO 0) := (OTHERS => '0'); -- address of target slave
    SIGNAL i2c_rw : STD_LOGIC := '0';
    SIGNAL i2c_busy : STD_LOGIC := '0'; -- indicates transaction in progress
    SIGNAL i2c_rdata, i2c_wdata : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0'); -- data read from slave
    SIGNAL i2c_ack_err : STD_LOGIC := '0'; -- flag if improper acknowledge from slave
BEGIN

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

END ARCHITECTURE;