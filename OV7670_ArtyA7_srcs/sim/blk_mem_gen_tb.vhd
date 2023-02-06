LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

USE std.textio.ALL;
USE std.env.finish;

ENTITY blk_mem_gen_tb IS
END blk_mem_gen_tb;

ARCHITECTURE sim OF blk_mem_gen_tb IS
    CONSTANT clk_hz : INTEGER := 100e6;
    CONSTANT clk_period : TIME := 1 sec / clk_hz;

    SIGNAL clk : STD_LOGIC := '1';
    SIGNAL rst : STD_LOGIC := '1';

    SIGNAL read_ena : STD_LOGIC := '0';
    SIGNAL write_ena : STD_LOGIC_VECTOR(0 DOWNTO 0) := (OTHERS => '0');
    SIGNAL addra : STD_LOGIC_VECTOR(9 DOWNTO 0) := (OTHERS => '0');
    SIGNAL dina : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');
    SIGNAL douta : STD_LOGIC_VECTOR(11 DOWNTO 0) := (OTHERS => '0');

    COMPONENT blk_mem_gen_0 IS
        PORT (
            clka : IN STD_LOGIC;
            ena : IN STD_LOGIC;
            wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
            addra : IN STD_LOGIC_VECTOR(9 DOWNTO 0);
            dina : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
            douta : OUT STD_LOGIC_VECTOR(11 DOWNTO 0)
        );
    END COMPONENT;

    COMPONENT blk_mem_axi IS
        PORT (
            rsta_busy : OUT STD_LOGIC;
            rstb_busy : OUT STD_LOGIC;
            s_aclk : IN STD_LOGIC; --clk
            s_aresetn : IN STD_LOGIC; --reset

            --Write address channels
            s_axi_awid : IN STD_LOGIC_VECTOR(3 DOWNTO 0);--Address ID, to identify multiple streams over a single channel
            s_axi_awaddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0);--Address of the first beat of the burst
            s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);--Number of beats inside the burst
            s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);--Size of each beat
            s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);--Type of the burst
            s_axi_awvalid : IN STD_LOGIC;--xVALID handshake signal
            s_axi_awready : OUT STD_LOGIC;--xREADY handshake signal

            --Write Data Channels
            s_axi_wdata : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --write data
            s_axi_wstrb : IN STD_LOGIC_VECTOR(3 DOWNTO 0);--Byte strobe, to indicate which bytes of the WDATA signal are valid
            s_axi_wlast : IN STD_LOGIC; --Last beat identifier
            s_axi_wvalid : IN STD_LOGIC;--xVALID handshake signal
            s_axi_wready : OUT STD_LOGIC;--xREADY handshake signal

            --write response channel
            s_axi_bid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); --Write response ID, to identify multiple streams over a single channel
            s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); --Write response, to specify the status of the burst
            s_axi_bvalid : OUT STD_LOGIC; --xVALID handshake signal
            s_axi_bready : IN STD_LOGIC; --xREADY handshake signal

            --read address channels
            s_axi_arid : IN STD_LOGIC_VECTOR(3 DOWNTO 0); --Address ID, to identify multiple streams over a single channel
            s_axi_araddr : IN STD_LOGIC_VECTOR(31 DOWNTO 0); --Address of the first beat of the burst
            s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0); --Number of beats inside the burst
            s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0); --Size of each beat
            s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0); --Type of the burst
            s_axi_arvalid : IN STD_LOGIC; --xVALID handshake signal
            s_axi_arready : OUT STD_LOGIC;--xREADY handshake signal

            --data read channel
            s_axi_rid : OUT STD_LOGIC_VECTOR(3 DOWNTO 0); --Data ID, to identify multiple streams over a single channel
            s_axi_rdata : OUT STD_LOGIC_VECTOR(31 DOWNTO 0); --read data
            s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0); -- Read response, to specify the status of the current RDATA signal
            s_axi_rlast : OUT STD_LOGIC; --Last beat identifier
            s_axi_rvalid : OUT STD_LOGIC; --Data ID, to identify multiple streams over a single channel
            s_axi_rready : IN STD_LOGIC --xREADY handshake signal
        );
    END COMPONENT;

    SIGNAL rsta_busy : STD_LOGIC;
    SIGNAL rstb_busy : STD_LOGIC;
    SIGNAL s_aclk : STD_LOGIC; --clk
    SIGNAL s_aresetn : STD_LOGIC; --reset

    --Write address channels
    SIGNAL s_axi_awid : STD_LOGIC_VECTOR(3 DOWNTO 0);--Address ID, to identify multiple streams over a single channel
    SIGNAL s_axi_awaddr : STD_LOGIC_VECTOR(31 DOWNTO 0);--Address of the first beat of the burst
    SIGNAL s_axi_awlen : STD_LOGIC_VECTOR(7 DOWNTO 0);--Number of beats inside the burst
    SIGNAL s_axi_awsize : STD_LOGIC_VECTOR(2 DOWNTO 0);--Size of each beat
    SIGNAL s_axi_awburst : STD_LOGIC_VECTOR(1 DOWNTO 0);--Type of the burst
    SIGNAL s_axi_awvalid : STD_LOGIC;--xVALID handshake signal
    SIGNAL s_axi_awready : STD_LOGIC;--xREADY handshake signal

    --Write Data Channels
    SIGNAL s_axi_wdata : STD_LOGIC_VECTOR(31 DOWNTO 0); --write data
    SIGNAL s_axi_wstrb : STD_LOGIC_VECTOR(3 DOWNTO 0);--Byte strobe, to indicate which bytes of the WDATA signal are valid
    SIGNAL s_axi_wlast : STD_LOGIC; --Last beat identifier
    SIGNAL s_axi_wvalid : STD_LOGIC;--xVALID handshake signal
    SIGNAL s_axi_wready : STD_LOGIC;--xREADY handshake signal

    --write response channel
    SIGNAL s_axi_bid : STD_LOGIC_VECTOR(3 DOWNTO 0); --Write response ID, to identify multiple streams over a single channel
    SIGNAL s_axi_bresp : STD_LOGIC_VECTOR(1 DOWNTO 0); --Write response, to specify the status of the burst
    SIGNAL s_axi_bvalid : STD_LOGIC; --xVALID handshake signal
    SIGNAL s_axi_bready : STD_LOGIC; --xREADY handshake signal

    --read address channels
    SIGNAL s_axi_arid : STD_LOGIC_VECTOR(3 DOWNTO 0); --Address ID, to identify multiple streams over a single channel
    SIGNAL s_axi_araddr : STD_LOGIC_VECTOR(31 DOWNTO 0); --Address of the first beat of the burst
    SIGNAL s_axi_arlen : STD_LOGIC_VECTOR(7 DOWNTO 0); --Number of beats inside the burst
    SIGNAL s_axi_arsize : STD_LOGIC_VECTOR(2 DOWNTO 0); --Size of each beat
    SIGNAL s_axi_arburst : STD_LOGIC_VECTOR(1 DOWNTO 0); --Type of the burst
    SIGNAL s_axi_arvalid : STD_LOGIC; --xVALID handshake signal
    SIGNAL s_axi_arready : STD_LOGIC;--xREADY handshake signal

    --data read channel
    SIGNAL s_axi_rid : STD_LOGIC_VECTOR(3 DOWNTO 0); --Data ID, to identify multiple streams over a single channel
    SIGNAL s_axi_rdata : STD_LOGIC_VECTOR(31 DOWNTO 0); --read data
    SIGNAL s_axi_rresp : STD_LOGIC_VECTOR(1 DOWNTO 0); -- Read response, to specify the status of the current RDATA signal
    SIGNAL s_axi_rlast : STD_LOGIC; --Last beat identifier
    SIGNAL s_axi_rvalid : STD_LOGIC; --Data ID, to identify multiple streams over a single channel
    SIGNAL s_axi_rready : STD_LOGIC; --xREADY handshake signal

BEGIN

    clk <= NOT clk AFTER clk_period / 2;

    DUT : blk_mem_gen_0
    PORT MAP(
        clka => clk,
        ena => '1',
        wea => write_ena,
        addra => addra,
        dina => dina,
        douta => douta
    );

    SEQUENCER_PROC : PROCESS
    BEGIN
        WAIT FOR clk_period * 2;

        rst <= '0';
        write_ena <= "1";
        addra <= "0000000001";
        dina <= "111101010011";
        WAIT FOR clk_period * 2;
        addra <= "0000000010";
        dina <= "111101011111";
        WAIT FOR clk_period * 2;
        addra <= "0000000011";
        dina <= "111101010000";
        WAIT FOR clk_period * 2;
        write_ena <= "0";
        WAIT FOR clk_period * 2;
        addra <= "0000000001";

        WAIT FOR clk_period * 8;
        addra <= "0000000010";
        WAIT FOR clk_period * 4;
        addra <= "0000000011";
        WAIT FOR clk_period * 100;
        finish;
    END PROCESS;

END ARCHITECTURE;