LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY top IS
    PORT (
        clk : IN STD_LOGIC;
        uart_txd_in : IN STD_LOGIC;
        scl : INOUT STD_LOGIC;
        sda : INOUT STD_LOGIC;
        ov7670_vsync : IN STD_LOGIC;
        ov7670_href : IN STD_LOGIC;
        ov7670_pclk : IN STD_LOGIC;
        ov7670_xclk : OUT STD_LOGIC;
        ov7670_data : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        uart_rxd_out : OUT STD_LOGIC;
        btn : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        sw : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
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

    COMPONENT clk_generator
        PORT (
            reset : IN STD_LOGIC;
            clk_in1 : IN STD_LOGIC;
            locked : OUT STD_LOGIC;
            o_clk_vga : OUT STD_LOGIC;
            o_xclk_ov7670 : OUT STD_LOGIC
        );
    END COMPONENT;

    SIGNAL sseg_byte : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL href_cnt : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL config_finished : STD_LOGIC := '0';

    SIGNAL buf1_vsync, buf2_vsync, buf1_href, buf2_href : STD_LOGIC := '0';
    SIGNAL buf1_pclk, buf2_pclk : STD_LOGIC := '0';
    SIGNAL buf1_data, buf2_data : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    SIGNAL vga_640x480_clk : STD_LOGIC := '0';
    SIGNAL xclk_ov7670 : STD_LOGIC := '0';

    SIGNAL pixel_data : STD_LOGIC_VECTOR(15 DOWNTO 0) := (OTHERS => '0');
    SIGNAL pixel_data_byte : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');

    SIGNAL pclk_cnt : unsigned(11 DOWNTO 0) := (OTHERS => '0'); --number of rising pclk edges between rising edge href and falling edge href
BEGIN

    --?? metastability of external signals
    PROCESS (clk)
    BEGIN
        IF rising_edge(clk) THEN
            buf1_vsync <= ov7670_vsync;
            buf2_vsync <= buf1_vsync;

            buf1_href <= ov7670_href;
            buf2_href <= buf1_href;

            buf1_pclk <= ov7670_pclk;
            buf2_pclk <= buf1_pclk;

            buf1_data <= ov7670_data;
            buf2_data <= buf1_data;
        END IF;
    END PROCESS;

    rst <= '0';

    ov7670_pwdn <= '0'; -- Power device up

    pixel_data_byte <= pixel_data(15 DOWNTO 8) WHEN sw(0) = '0' ELSE
        pixel_data(7 DOWNTO 0);

    --klappe zu 
    --39e9  00111 001111 01001

    --taschenlampe 
    --8c50  10110 101110 10111

    --weiß 
    --8e55 10001 110010 10101

    --rot
    --fb43  11111 011010 00011

    --gelb  
    --8ea7 10001 110101 00111
    
    --grün
    --47eb  01000 111111 01011  

    --blau 
    --441f 01000 100000 11111 --sieht gut aus


    clock_mccm : clk_generator
    PORT MAP(
        clk_in1 => clk,
        o_clk_vga => vga_640x480_clk,
        o_xclk_ov7670 => xclk_ov7670,
        reset => '0',
        locked => OPEN
    );

    ov7670_xclk <= xclk_ov7670;

    SSEG_CONTROLLER : ENTITY work.sseg_controller(arch)
        PORT MAP(
            clk => clk,
            --data_i => pclk_cnt(7 DOWNTO 0),
            --data_i => unsigned(sseg_byte),
            --data_i => unsigned(href_cnt(7 DOWNTO 0)),
            data_i => unsigned(pixel_data_byte),
            sseg_cs_o => sseg_cs_o,
            sseg_o => sseg_o
        );

    ov7670_configuration : ENTITY work.ov7670_configuration(Behavioral)
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
            config_finished => config_finished,
            reg_value => uart_byte_tx
        );

    --led(0) <= config_finished;
    --led(3 DOWNTO 1) <= "000";
    --led <= std_logic_vector(pclk_cnt(11 DOWNTO 8));
    led(2 DOWNTO 0) <= href_cnt(10 DOWNTO 8);

    ov7670_capture : ENTITY work.ov7670_capture(rtl) PORT MAP(
        clk => clk,
        rst => rst,
        config_finished => config_finished,
        ov7670_vsync => buf2_vsync,
        ov7670_href => buf2_href,
        ov7670_pclk => buf2_pclk,
        ov7670_data => buf2_data,
        frame_finished_o => led(3),
        pixel_data => pixel_data,
        start => edge(3),
        start_href => edge(2),
        start_pclk => edge(1),
        vsync_cnt_o => sseg_byte,
        href_cnt_o => href_cnt,
        pclk_cnt_o => pclk_cnt
        );

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