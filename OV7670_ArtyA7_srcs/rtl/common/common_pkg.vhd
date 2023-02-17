LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE common_pkg IS
    CONSTANT C_ARTY_A7_CLK_FREQ : INTEGER := 100e6;
    FUNCTION to_string (a : STD_LOGIC_VECTOR) RETURN STRING;

    TYPE rom_type IS ARRAY (0 TO 77) OF STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL register_config_rom : rom_type := (
        --source https://github.com/AngeloJacobo/FPGA_OV7670_Camera_Interface/blob/main/src/camera_interface.v
        x"12_04", --set output format to RGB
        x"15_20", --pclk will not toggle during horizontal blank
        x"40_d0", --RGB565

        --RGB444 
        x"8C_02",

        --x"6b4a", --PLL control input clock x4
        -- x"3E12", --PCLK divider by 4
        x"11_01",
        x"6B_4A",

        x"12_04", -- COM7,     set RGB color output
        --x"11_80", -- CLKRC     internal PLL matches input clock
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
        --x"1E_23", --Mirror Image
        x"69_06" --gain of RGB(manually adjusted)
        -- x"71_B5" --test pattern
    );
END PACKAGE;

PACKAGE BODY common_pkg IS
    FUNCTION to_string (a : STD_LOGIC_VECTOR) RETURN STRING IS
        VARIABLE b : STRING (1 TO a'length) := (OTHERS => NUL);
        VARIABLE stri : INTEGER := 1;
    BEGIN
        FOR i IN a'RANGE LOOP
            b(stri) := STD_LOGIC'image(a((i)))(2);
            stri := stri + 1;
        END LOOP;
        RETURN b;
    END FUNCTION;

END common_pkg;