LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY counter_display IS
    PORT (
        pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        count_value : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
        counter_on : OUT STD_LOGIC
    );
END counter_display;

ARCHITECTURE Behavioral OF counter_display IS
    -- Function to convert BCD digit to 7-segment pattern
    -- Pattern order: abcdefg where bit 6=a, bit 5=b, bit 4=c, bit 3=d, bit 2=e, bit 1=f, bit 0=g
    FUNCTION leddec(digit : INTEGER) RETURN STD_LOGIC_VECTOR IS
    BEGIN
        CASE digit IS
            WHEN 0 => RETURN "1111110"; -- segments: a,b,c,d,e,f (g off)
            WHEN 1 => RETURN "0110000"; -- segments: b,c
            WHEN 2 => RETURN "1101101"; -- segments: a,b,d,e,g
            WHEN 3 => RETURN "1111001"; -- segments: a,b,c,d,g
            WHEN 4 => RETURN "0110011"; -- segments: b,c,f,g
            WHEN 5 => RETURN "1011011"; -- segments: a,c,d,f,g
            WHEN 6 => RETURN "1011111"; -- segments: a,c,d,e,f,g
            WHEN 7 => RETURN "1110000"; -- segments: a,b,c
            WHEN 8 => RETURN "1111111"; -- all segments
            WHEN 9 => RETURN "1111011"; -- segments: a,b,c,d,f,g
            WHEN OTHERS => RETURN "0000000";
        END CASE;
    END FUNCTION;
BEGIN
    counterdraw : PROCESS (pixel_row, pixel_col, count_value) IS
        VARIABLE col_i, row_i : INTEGER;
        CONSTANT digit_width : INTEGER := 10;
        CONSTANT digit_height : INTEGER := 14;
        CONSTANT seg_thickness : INTEGER := 2;
        CONSTANT start_x : INTEGER := 750; -- top right
        CONSTANT start_y : INTEGER := 20;
        VARIABLE digit_val : INTEGER;
        VARIABLE digit_idx : INTEGER;
        VARIABLE seg_pattern : STD_LOGIC_VECTOR(6 DOWNTO 0); -- 7 segments: a,b,c,d,e,f,g
        VARIABLE x_in_digit, y_in_digit : INTEGER;
        VARIABLE seg_on : STD_LOGIC;
    BEGIN
        counter_on <= '0';
        col_i := CONV_INTEGER(pixel_col);
        row_i := CONV_INTEGER(pixel_row);
        
        -- Check if in the counter display area
        IF col_i >= start_x - (5 * digit_width) AND col_i < start_x AND
           row_i >= start_y AND row_i < start_y + digit_height THEN
            
            -- Determine which digit
            digit_idx := (start_x - col_i - 1) / digit_width;
            IF digit_idx < 5 THEN
                x_in_digit := (start_x - col_i - 1) MOD digit_width;
                y_in_digit := row_i - start_y;

                x_in_digit := (digit_width - 1) - x_in_digit;
                
                -- Extract BCD digit value from counter
                -- Map digits right-to-left
                CASE digit_idx IS
                    WHEN 0 => digit_val := CONV_INTEGER(count_value(3 DOWNTO 0));  -- rightmost
                    WHEN 1 => digit_val := CONV_INTEGER(count_value(7 DOWNTO 4));
                    WHEN 2 => digit_val := CONV_INTEGER(count_value(11 DOWNTO 8));
                    WHEN 3 => digit_val := CONV_INTEGER(count_value(15 DOWNTO 12)); -- leftmost
                    WHEN 4 => digit_val := 0; -- leading zero
                    WHEN OTHERS => digit_val := 0;
                END CASE;
                
                -- Get 7-segment pattern from leddec function
                seg_pattern := leddec(digit_val);
                
                -- Render segments
                seg_on := '0';
                -- Segment a (top horizontal)
                IF seg_pattern(6) = '1' AND x_in_digit >= 1 AND x_in_digit <= 8 AND y_in_digit >= 0 AND y_in_digit < seg_thickness THEN
                    seg_on := '1';
                -- Segment b (top right vertical)
                ELSIF seg_pattern(5) = '1' AND x_in_digit >= 8 AND x_in_digit < digit_width AND y_in_digit >= 1 AND y_in_digit <= 6 THEN
                    seg_on := '1';
                -- Segment c (bottom right vertical)
                ELSIF seg_pattern(4) = '1' AND x_in_digit >= 8 AND x_in_digit < digit_width AND y_in_digit >= 8 AND y_in_digit < digit_height THEN
                    seg_on := '1';
                -- Segment d (bottom horizontal)
                ELSIF seg_pattern(3) = '1' AND x_in_digit >= 1 AND x_in_digit <= 8 AND y_in_digit >= digit_height - seg_thickness AND y_in_digit < digit_height THEN
                    seg_on := '1';
                -- Segment e (bottom left vertical)
                ELSIF seg_pattern(2) = '1' AND x_in_digit >= 0 AND x_in_digit < seg_thickness AND y_in_digit >= 8 AND y_in_digit < digit_height THEN
                    seg_on := '1';
                -- Segment f (top left vertical)
                ELSIF seg_pattern(1) = '1' AND x_in_digit >= 0 AND x_in_digit < seg_thickness AND y_in_digit >= 1 AND y_in_digit <= 6 THEN
                    seg_on := '1';
                -- Segment g (middle horizontal)
                ELSIF seg_pattern(0) = '1' AND x_in_digit >= 1 AND x_in_digit <= 8 AND y_in_digit >= 6 AND y_in_digit < 8 THEN
                    seg_on := '1';
                END IF;
                
                IF seg_on = '1' THEN
                    counter_on <= '1';
                END IF;
            END IF;
        END IF;
    END PROCESS;
END Behavioral;

