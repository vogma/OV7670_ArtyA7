LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY top IS
    PORT (
        clk : IN STD_LOGIC;
        uart_txd_in : IN STD_LOGIC;
        scl : INOUT STD_LOGIC;
        sda : INOUT STD_LOGIC;
        ov7670_xclk : OUT STD_LOGIC;
        uart_rxd_out : OUT STD_LOGIC;
        btn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        led : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        ov7670_pwdn : OUT STD_LOGIC;
        ov7670_reset : OUT STD_LOGIC;
        sseg_o : OUT STD_LOGIC_VECTOR(6 DOWNTO 0);
        sseg_cs_o : OUT STD_LOGIC
    );
END top;

ARCHITECTURE rtl OF top IS
    --hallo
    SIGNAL rst : STD_LOGIC := '0';
    SIGNAL uart_start, uart_serial, uart_done_tx, uart_active : STD_LOGIC := '0';
    SIGNAL uart_byte_tx : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL edge : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');

    COMPONENT clk_wiz_0
        PORT (
            reset : IN STD_LOGIC;
            clk_in1 : IN STD_LOGIC;
            locked : OUT STD_LOGIC;
            clk_out1 : OUT STD_LOGIC;
            clk_out2 : OUT STD_LOGIC
        );
    END COMPONENT;

    SIGNAL clk50, clk25 : STD_LOGIC := '0';
BEGIN

    rst <= '0';

    --uart_start <= '1' WHEN edge(0) = '1' ELSE '0';

    --uart_byte_tx <= "01000001";

    --ov7670_reset <= '1'; -- Normal mode
    ov7670_pwdn <= '0'; -- Power device up

    clock_mccm : clk_wiz_0
    PORT MAP(
        clk_in1 => clk,
        clk_out1 => clk50,
        clk_out2 => clk25,
        reset => '0',
        locked => OPEN
    );

    ov7670_xclk <= clk25;

    SSEG_CONTROLLER : ENTITY work.sseg_controller(arch)
        PORT MAP(
            clk => clk,
            data_i => unsigned(uart_byte_tx),
            sseg_cs_o => sseg_cs_o,
            sseg_o => sseg_o
        );

    read_camera_reg : ENTITY work.read_camera_reg(Behavioral)
        PORT MAP(
            clk => clk,
            rst => rst,
            sda => sda,
            edge => edge,
            scl => scl,
            ov7670_reset => ov7670_reset,
            start => edge(0),
            ack_err => OPEN,
            done => uart_start,
            led => led,
            reg_value => uart_byte_tx
        );

    --led(2 downto 0) <= "000";

    EDGE_DETECT : ENTITY work.debounce(Behavioral) PORT MAP(
        clk => clk,
        btn => btn,
        edge => edge
        );
    UART_TX : ENTITY work.uart_tx_own(rtl)
        PORT MAP(
            clk => clk,
            rst => rst,
            i_start => uart_start,
            i_byte => uart_byte_tx,
            o_serial => uart_serial,
            o_done => uart_done_tx
        );

    uart_rxd_out <= uart_serial;

END ARCHITECTURE;