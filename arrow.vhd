LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY arrow IS
    PORT (
        v_sync : IN STD_LOGIC;
        pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        arrow_x : IN STD_LOGIC_VECTOR (10 DOWNTO 0); -- current arrow x position
        btn0 : IN STD_LOGIC; 
        red : OUT STD_LOGIC;
        green : OUT STD_LOGIC;
        blue : OUT STD_LOGIC;
        counter: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
    );
END arrow;

ARCHITECTURE Behavioral OF arrow IS
    SIGNAL cnt : STD_LOGIC_VECTOR (15 DOWNTO 0) := (OTHERS => '0'); -- 16-bit counter for moves
    SIGNAL arrow_w : INTEGER := 15; 
    CONSTANT arrow_h : INTEGER := 10; 
    SIGNAL arrow_on : STD_LOGIC; -- indicates whether arrow at over current pixel position
    SIGNAL rod_on : STD_LOGIC; -- indicates whether rod at current pixel position
    SIGNAL block_on : STD_LOGIC; -- indicates whether block at current pixel position
    SIGNAL block_red, block_green, block_blue : STD_LOGIC; -- block colors
    SIGNAL counter_on : STD_LOGIC; -- indicates whether counter digit at current pixel position
    
    COMPONENT counter_display IS
        PORT (
            pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            count_value : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
            counter_on : OUT STD_LOGIC
        );
    END COMPONENT;

    -- BCD increment helper (cnt is stored as 4 BCD digits)
    FUNCTION bcd_inc(x : STD_LOGIC_VECTOR(15 DOWNTO 0)) RETURN STD_LOGIC_VECTOR IS
        VARIABLE r : STD_LOGIC_VECTOR(15 DOWNTO 0);
        VARIABLE carry : INTEGER := 1;
        VARIABLE digit : INTEGER;
        VARIABLE i : INTEGER;
    BEGIN
        r := x;
        FOR i IN 0 TO 3 LOOP
            digit := CONV_INTEGER(r((i*4)+3 DOWNTO (i*4)));
            IF carry = 1 THEN
                digit := digit + 1;
                IF digit = 10 THEN
                    digit := 0;
                    carry := 1;
                ELSE
                    carry := 0;
                END IF;
                r((i*4)+3 DOWNTO (i*4)) := CONV_STD_LOGIC_VECTOR(digit, 4);
            END IF;
        END LOOP;
        RETURN r;
    END FUNCTION;
    
    -- Block structure = 4 blocks with increasing widths
    TYPE block_array IS ARRAY (0 TO 3) OF INTEGER;
    CONSTANT block_widths : block_array := (30, 40, 50, 60); -- widths of blocks
    CONSTANT block_height : INTEGER := 20; -- height of each block
    
    -- rod: 0=left, 1=middle, 2=right
    TYPE block_pos IS RECORD
        rod : INTEGER range 0 to 2;
        stack_pos : INTEGER range 0 to 3;
    END RECORD;

    TYPE block_positions IS ARRAY (0 TO 3) OF block_pos;
    SIGNAL blocks : block_positions := (
        (rod => 0, stack_pos => 3), -- block 0 (smallest) on rod 0, top
        (rod => 0, stack_pos => 2), -- block 1 on rod 0, third
        (rod => 0, stack_pos => 1), -- block 2 on rod 0, second
        (rod => 0, stack_pos => 0)  -- block 3 (largest) on rod 0, bottom
    );
    
    SIGNAL selected_block : INTEGER range -1 to 3 := -1; -- -1 = none selected
    SIGNAL pending_counter_reset : STD_LOGIC := '0'; -- set after winning | clears on next BTN0 press
    SIGNAL btn0_prev : STD_LOGIC := '0';
    -- arrow vertical position
    CONSTANT arrow_y : STD_LOGIC_VECTOR(10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(60, 11);
 
    CONSTANT rod1_x : INTEGER := 200; 
    CONSTANT rod2_x : INTEGER := 400; 
    CONSTANT rod3_x : INTEGER := 600; 
    CONSTANT rod_width : INTEGER := 4; 
    CONSTANT rod_top_y : INTEGER := 150; -- top of rod
    CONSTANT rod_bottom_y : INTEGER := 450; -- bottom of rod
    CONSTANT base_height : INTEGER := 10; -- height of base rectangle
    CONSTANT base_width : INTEGER := 80; -- width of base rectangle
BEGIN
    -- CONFIGURE COLORS
    red <= arrow_on OR block_red OR counter_on OR (NOT arrow_on AND NOT rod_on AND NOT block_on AND NOT counter_on); -- arrow is red, blocks have colors, counter is red, background is white
    green <= block_green OR (NOT arrow_on AND NOT rod_on AND NOT block_on AND NOT counter_on); -- blocks have colors, background is white
    blue <= rod_on OR block_blue OR (NOT arrow_on AND NOT rod_on AND NOT block_on AND NOT counter_on); -- rods and blocks are blue, background is white


    roddraw : PROCESS (pixel_row, pixel_col) IS
        VARIABLE col_i : INTEGER;
        VARIABLE row_i : INTEGER;
    BEGIN
        rod_on <= '0'; -- default OFF
        
        col_i := CONV_INTEGER(pixel_col);
        row_i := CONV_INTEGER(pixel_row);
        
        -- Draw rod 1 (left)
        IF (col_i >= rod1_x - rod_width/2) AND (col_i <= rod1_x + rod_width/2) AND
           (row_i >= rod_top_y) AND (row_i <= rod_bottom_y) THEN
            rod_on <= '1';
        -- Draw base rectangle for rod 1
        ELSIF (col_i >= rod1_x - base_width/2) AND (col_i <= rod1_x + base_width/2) AND
              (row_i >= rod_bottom_y) AND (row_i <= rod_bottom_y + base_height) THEN
            rod_on <= '1';
        -- Draw rod 2 (middle)
        ELSIF (col_i >= rod2_x - rod_width/2) AND (col_i <= rod2_x + rod_width/2) AND
              (row_i >= rod_top_y) AND (row_i <= rod_bottom_y) THEN
            rod_on <= '1';
        -- Draw base rectangle for rod 2
        ELSIF (col_i >= rod2_x - base_width/2) AND (col_i <= rod2_x + base_width/2) AND
              (row_i >= rod_bottom_y) AND (row_i <= rod_bottom_y + base_height) THEN
            rod_on <= '1';
        -- Draw rod 3 (right)
        ELSIF (col_i >= rod3_x - rod_width/2) AND (col_i <= rod3_x + rod_width/2) AND
              (row_i >= rod_top_y) AND (row_i <= rod_bottom_y) THEN
            rod_on <= '1';
        -- Draw base rectangle for rod 3
        ELSIF (col_i >= rod3_x - base_width/2) AND (col_i <= rod3_x + base_width/2) AND
              (row_i >= rod_bottom_y) AND (row_i <= rod_bottom_y + base_height) THEN
            rod_on <= '1';
        END IF;
    END PROCESS;
    -- process to draw arrow
    -- set arrow_on if current pixel address is covered by arrow position
    arrowdraw : PROCESS (arrow_x, pixel_row, pixel_col) IS
        VARIABLE col_i   : INTEGER;
        VARIABLE row_i   : INTEGER;
        VARIABLE ax_i    : INTEGER;
        VARIABLE ay_i    : INTEGER;
        VARIABLE level   : INTEGER;
        VARIABLE height  : INTEGER;
        VARIABLE half_w  : INTEGER;
    BEGIN
        arrow_on <= '0';  -- default OFF

        col_i := CONV_INTEGER(pixel_col);
        row_i := CONV_INTEGER(pixel_row);
        ax_i  := CONV_INTEGER(arrow_x);
        ay_i  := CONV_INTEGER(arrow_y);

        -- total height of the triangle
        height := 2 * arrow_h;

        -- only consider rows in the vertical range of the arrow
        IF (row_i >= ay_i - arrow_h) AND (row_i <= ay_i + arrow_h) THEN

            -- level = 0 at the top, increasing as you go down the triangle
            level := row_i - (ay_i - arrow_h);  -- 0...height

            -- slowly decrease half width from arrow_w at top to 0 at bottom
            half_w := arrow_w - (arrow_w * level) / height;

            -- check horizontal distance from the arrow center
            IF (col_i >= ax_i - half_w) AND (col_i <= ax_i + half_w) THEN
                arrow_on <= '1';
            END IF;
        END IF;
    END PROCESS;
    -- Process to handle block selection and dropping
    block_control : PROCESS IS
        VARIABLE current_rod : INTEGER range 0 to 2;
        VARIABLE top_block_idx : INTEGER range -1 to 3;
        VARIABLE top_stack_pos : INTEGER range -1 to 3;
        VARIABLE i : INTEGER;
        VARIABLE new_blocks : block_positions;
    BEGIN
        WAIT UNTIL rising_edge(v_sync);
        
        new_blocks := blocks;
        
        -- Get current rod from arrow_x
        IF CONV_INTEGER(arrow_x) = 200 THEN
            current_rod := 0;
        ELSIF CONV_INTEGER(arrow_x) = 400 THEN
            current_rod := 1;
        ELSE
            current_rod := 2;
        END IF;
        
        -- Handle BTN0 press
        IF btn0 = '1' AND btn0_prev = '0' THEN
            -- After a win reset wait for the first BTN0 press to reset the counter
            IF pending_counter_reset = '1' THEN
                cnt <= (OTHERS => '0');
                pending_counter_reset <= '0';
            END IF;

            IF selected_block = -1 THEN
                -- Pick up top block from current rod
                top_block_idx := -1;
                top_stack_pos := -1;
                FOR i IN 0 TO 3 LOOP
                    IF new_blocks(i).rod = current_rod AND new_blocks(i).stack_pos > top_stack_pos THEN
                        top_block_idx := i;
                        top_stack_pos := new_blocks(i).stack_pos;
                    END IF;
                END LOOP;
                IF top_block_idx >= 0 THEN
                    selected_block <= top_block_idx;
                END IF;
            ELSE
                -- Drop selected block on current rod
                -- Find top block on current rod
                top_block_idx := -1;
                top_stack_pos := -1;
                FOR i IN 0 TO 3 LOOP
                    IF i /= selected_block AND new_blocks(i).rod = current_rod AND new_blocks(i).stack_pos > top_stack_pos THEN
                        top_block_idx := i;
                        top_stack_pos := new_blocks(i).stack_pos;
                    END IF;
                END LOOP;
                -- Check if drop is valid. Selected block must be smaller than top block or rod is empty
                IF top_block_idx = -1 OR block_widths(selected_block) < block_widths(top_block_idx) THEN
                    -- Valid drop: place block on top
                    new_blocks(selected_block).rod := current_rod;
                    new_blocks(selected_block).stack_pos := top_stack_pos + 1;
                    selected_block <= -1;
                    -- Increment move counter (BCD)
                    cnt <= bcd_inc(cnt);
                END IF;
            END IF;
        END IF;

        -- If all blocks are on the 3rd rod reset game state
        IF (new_blocks(0).rod = 2) AND (new_blocks(1).rod = 2) AND (new_blocks(2).rod = 2) AND (new_blocks(3).rod = 2) THEN
            new_blocks := (
                (rod => 0, stack_pos => 3), -- block 0 on rod 0, top
                (rod => 0, stack_pos => 2), -- block 1 on rod 0, third
                (rod => 0, stack_pos => 1), -- block 2 on rod 0, second
                (rod => 0, stack_pos => 0)  -- block 3 on rod 0, bottom
            );
            selected_block <= -1;
            pending_counter_reset <= '1';
        END IF;
        
        blocks <= new_blocks;
        btn0_prev <= btn0;
    END PROCESS;
    
    -- Process to draw blocks
    blockdraw : PROCESS (pixel_row, pixel_col, arrow_x, blocks, selected_block) IS
        VARIABLE col_i, row_i : INTEGER;
        VARIABLE block_x, block_y : INTEGER;
        VARIABLE i : INTEGER;
        VARIABLE rod_x : INTEGER;
        VARIABLE current_block_on : STD_LOGIC;
    BEGIN
        block_on <= '0';
        block_red <= '0';
        block_green <= '0';
        block_blue <= '0';
        
        col_i := CONV_INTEGER(pixel_col);
        row_i := CONV_INTEGER(pixel_row);
        
        -- Draw all blocks
        FOR i IN 0 TO 3 LOOP
            current_block_on := '0';
            
            IF i = selected_block THEN
                -- Selected block follows arrow | positioned between arrow and rod top
                block_x := CONV_INTEGER(arrow_x);
                block_y := (CONV_INTEGER(arrow_y) + rod_top_y) / 2;
            ELSE
                -- Block on rod
                CASE blocks(i).rod IS
                    WHEN 0 => rod_x := rod1_x;
                    WHEN 1 => rod_x := rod2_x;
                    WHEN 2 => rod_x := rod3_x;
                    WHEN OTHERS => rod_x := rod1_x;
                END CASE;
                block_x := rod_x;
                block_y := rod_bottom_y - (blocks(i).stack_pos + 1) * block_height;
            END IF;
            
            -- Draw block rectangle
            IF (col_i >= block_x - block_widths(i)/2) AND (col_i <= block_x + block_widths(i)/2) AND
               (row_i >= block_y - block_height/2) AND (row_i <= block_y + block_height/2) THEN
                current_block_on := '1';
                block_on <= '1';
                
                -- Assign colors
                CASE i IS
                    WHEN 0 => block_red <= '1'; -- red
                    WHEN 1 => block_green <= '1'; -- green
                    WHEN 2 => block_blue <= '1'; -- blue
                    WHEN 3 => block_red <= '1'; block_green <= '1'; -- yellow
                    WHEN OTHERS => block_red <= '1';
                END CASE;
                EXIT; 
            END IF;
        END LOOP;
    END PROCESS;
    
    -- Instantiate counter component
    counter_inst : counter_display
    PORT MAP (
        pixel_row => pixel_row,
        pixel_col => pixel_col,
        count_value => cnt,
        counter_on => counter_on
    );
    
    counter <= cnt;
END Behavioral;