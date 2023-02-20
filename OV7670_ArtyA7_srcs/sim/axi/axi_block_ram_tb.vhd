LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY axi_block_ram_tb IS
END axi_block_ram_tb;

ARCHITECTURE sim OF axi_block_ram_tb IS

    CONSTANT clk_hz : INTEGER := 100e6;
    CONSTANT clk_period : TIME := 1 sec / clk_hz;

    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '0';

    COMPONENT blk_mem_gen_0 IS
        PORT (
            rsta_busy : OUT STD_LOGIC;
            rstb_busy : OUT STD_LOGIC;
            s_aclk : IN STD_LOGIC;
            s_aresetn : IN STD_LOGIC;

            --write address channel
            s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0); --Address ID, to identify multiple streams over a single channel
            s_axi_awaddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --Address of the first beat of the burst
            s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0); --Number of beats inside the burst
            s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0); --Size of each beat
            s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0); --Type of the burst
            s_axi_awvalid : IN STD_LOGIC; --xVALID handshake signal
            s_axi_awready : OUT STD_LOGIC; --xREADY handshake signal

            --write data channel
            s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --Write data
            s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);--Byte strobe, to indicate which bytes of the WDATA signal are valid
            s_axi_wlast : IN STD_LOGIC;--Last beat identifier
            s_axi_wvalid : IN STD_LOGIC; --xVALID handshake signal
            s_axi_wready : OUT STD_LOGIC;--xREADY handshake signal

            --write response channel
            s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_bvalid : OUT STD_LOGIC;
            s_axi_bready : IN STD_LOGIC;
            --read address channel 
            s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
            s_axi_araddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
            s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
            s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_arvalid : IN STD_LOGIC;
            s_axi_arready : OUT STD_LOGIC;

            --read data channel
            s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
            s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
            s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
            s_axi_rlast : OUT STD_LOGIC;
            s_axi_rvalid : OUT STD_LOGIC;
            s_axi_rready : IN STD_LOGIC
        );
    END COMPONENT;

    SIGNAL rsta_busy : STD_LOGIC := '0';
    SIGNAL rstb_busy : STD_LOGIC := '0';
    SIGNAL s_aclk : STD_LOGIC := '0';
    SIGNAL s_aresetn : STD_LOGIC := '0';
    SIGNAL s_axi_awid : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_awaddr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_awlen : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_awsize : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_awburst : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_awvalid : STD_LOGIC := '0';
    SIGNAL s_axi_awready : STD_LOGIC := '0';
    SIGNAL s_axi_wdata : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_wstrb : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_wlast : STD_LOGIC := '0';
    SIGNAL s_axi_wvalid : STD_LOGIC := '0';
    SIGNAL s_axi_wready : STD_LOGIC := '0';
    SIGNAL s_axi_bid : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_bresp : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_bvalid : STD_LOGIC := '0';
    SIGNAL s_axi_bready : STD_LOGIC := '0';
    SIGNAL s_axi_arid : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_araddr : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_arlen : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_arsize : STD_LOGIC_VECTOR(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_arburst : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_arvalid : STD_LOGIC := '0';
    SIGNAL s_axi_arready : STD_LOGIC := '0';
    SIGNAL s_axi_rid : STD_LOGIC_VECTOR(3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_rdata : STD_LOGIC_VECTOR(31 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_rresp : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '0');
    SIGNAL s_axi_rlast : STD_LOGIC := '0';
    SIGNAL s_axi_rvalid : STD_LOGIC := '0';
    SIGNAL s_axi_rready : STD_LOGIC := '0';

    SIGNAL write_data : INTEGER RANGE 0 TO 2_000_000 := 0;

BEGIN

    s_aclk <= clk;
    s_aresetn <= rst;

    IP : blk_mem_gen_0 PORT MAP(
        rsta_busy => rsta_busy,
        rstb_busy => rstb_busy,
        s_aclk => s_aclk,
        s_aresetn => s_aresetn,
        s_axi_awid => s_axi_awid,
        s_axi_awaddr => s_axi_awaddr,
        s_axi_awlen => s_axi_awlen,
        s_axi_awsize => s_axi_awsize,
        s_axi_awburst => s_axi_awburst,
        s_axi_awvalid => s_axi_awvalid,
        s_axi_awready => s_axi_awready,
        s_axi_wdata => s_axi_wdata,
        s_axi_wstrb => s_axi_wstrb,
        s_axi_wlast => s_axi_wlast,
        s_axi_wvalid => s_axi_wvalid,
        s_axi_wready => s_axi_wready,
        s_axi_bid => s_axi_bid,
        s_axi_bresp => s_axi_bresp,
        s_axi_bvalid => s_axi_bvalid,
        s_axi_bready => s_axi_bready,
        s_axi_arid => s_axi_arid,
        s_axi_araddr => s_axi_araddr,
        s_axi_arlen => s_axi_arlen,
        s_axi_arsize => s_axi_arsize,
        s_axi_arburst => s_axi_arburst,
        s_axi_arvalid => s_axi_arvalid,
        s_axi_arready => s_axi_arready,
        s_axi_rid => s_axi_rid,
        s_axi_rdata => s_axi_rdata,
        s_axi_rresp => s_axi_rresp,
        s_axi_rlast => s_axi_rlast,
        s_axi_rvalid => s_axi_rvalid,
        s_axi_rready => s_axi_rready
    );

    clk <= NOT clk AFTER clk_period / 2;

    s_axi_wdata <= STD_LOGIC_VECTOR(to_unsigned(write_data, s_axi_wdata'length));

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '1';

        s_axi_wstrb <= (OTHERS => '1'); --all bytes are valid

        WAIT ON s_axi_awready UNTIL s_axi_awready = '1';
        WAIT FOR clk_period * 2;

        s_axi_awvalid <= '1';

        WAIT FOR clk_period * 2;

        s_axi_awvalid <= '0';

        FOR i IN 0 TO 10 LOOP
            WAIT UNTIL rising_edge(clk);
            write_data <= write_data + 1;
        END LOOP;

        WAIT FOR clk_period * 2;
        write_data <= 1000;
        s_axi_wvalid <= '1';
        s_axi_wlast <= '1';
        s_axi_bready <= '1';
        WAIT FOR clk_period * 2;

        s_axi_wvalid <= '0';

        WAIT FOR clk_period * 10;
        s_axi_arvalid <= '1';
        s_axi_rready <= '1';
        WAIT FOR clk_period * 2;
        --s_axi_arvalid <= '0';
        WAIT FOR clk_period * 1000;
    END PROCESS;

END ARCHITECTURE;