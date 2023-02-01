LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;

PACKAGE common_pkg IS
    CONSTANT C_ARTY_A7_CLK_FREQ : INTEGER := 100e6;
    FUNCTION to_string (a : STD_LOGIC_VECTOR) RETURN STRING;
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