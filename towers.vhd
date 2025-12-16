LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.STD_LOGIC_ARITH.ALL;
USE IEEE.STD_LOGIC_UNSIGNED.ALL;

ENTITY towers IS
    PORT (
        clk_in : IN STD_LOGIC; -- system clock
        VGA_red : OUT STD_LOGIC_VECTOR (3 DOWNTO 0); -- VGA outputs
        VGA_green : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_blue : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
        VGA_hsync : OUT STD_LOGIC;
        VGA_vsync : OUT STD_LOGIC;
        btnl : IN STD_LOGIC;
        btnr : IN STD_LOGIC;
        btn0 : IN STD_LOGIC;
        SEG7_anode : OUT STD_LOGIC_VECTOR (7 DOWNTO 0); 
        SEG7_seg : OUT STD_LOGIC_VECTOR (6 DOWNTO 0)
    ); 
END towers;

ARCHITECTURE Behavioral OF towers IS
    SIGNAL pxl_clk : STD_LOGIC := '0'; 
    -- internal signals to connect modules
    SIGNAL S_red, S_green, S_blue : STD_LOGIC; -- vector (3 downto 0);
    SIGNAL S_vsync : STD_LOGIC;
    SIGNAL S_pixel_row, S_pixel_col : STD_LOGIC_VECTOR (10 DOWNTO 0);
    SIGNAL arrowpos : STD_LOGIC_VECTOR (10 DOWNTO 0) := CONV_STD_LOGIC_VECTOR(400, 11); -- 9 downto 0
    SIGNAL count : STD_LOGIC_VECTOR (20 DOWNTO 0);
    SIGNAL counter: STD_LOGIC_VECTOR(15 DOWNTO 0);
    SIGNAL display : std_logic_vector (15 DOWNTO 0); -- value to be displayed
    SIGNAL led_mpx : STD_LOGIC_VECTOR (2 DOWNTO 0); 
    SIGNAL cnt: STD_LOGIC_VECTOR (15 DOWNTO 0);
    SIGNAL btnl_prev, btnr_prev : STD_LOGIC := '0';
    SIGNAL rod_index : INTEGER range 0 to 2 := 1; -- current rod index (0=left, 1=middle, 2=right)
    COMPONENT arrow IS
        PORT (
            v_sync : IN STD_LOGIC;
            pixel_row : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            pixel_col : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
            arrow_x : IN STD_LOGIC_VECTOR (10 DOWNTO 0);
            btn0 : IN STD_LOGIC;
            red : OUT STD_LOGIC;
            green : OUT STD_LOGIC;
            blue : OUT STD_LOGIC;
            counter: OUT STD_LOGIC_VECTOR(15 DOWNTO 0)
        );
    END COMPONENT;
    COMPONENT vga_sync IS
        PORT (
            pixel_clk : IN STD_LOGIC;
            red_in    : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            green_in  : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            blue_in   : IN STD_LOGIC_VECTOR (3 DOWNTO 0);
            red_out   : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            green_out : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            blue_out  : OUT STD_LOGIC_VECTOR (3 DOWNTO 0);
            hsync : OUT STD_LOGIC;
            vsync : OUT STD_LOGIC;
            pixel_row : OUT STD_LOGIC_VECTOR (10 DOWNTO 0);
            pixel_col : OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
        );
    END COMPONENT;
    COMPONENT clk_wiz_0 is
        PORT (
            clk_in1  : in std_logic;
            clk_out1 : out std_logic
        );
    END COMPONENT;

    
    SIGNAL S : STD_LOGIC_VECTOR (15 DOWNTO 0); 
    SIGNAL dig : STD_LOGIC_VECTOR (2 DOWNTO 0); 
    
BEGIN
    pos : PROCESS (clk_in) is
    BEGIN
        if rising_edge(clk_in) then
            IF (btnl = '1' and btnl_prev = '0' and rod_index > 0) THEN
                rod_index <= rod_index - 1;
            ELSIF (btnr = '1' and btnr_prev = '0' and rod_index < 2) THEN
                rod_index <= rod_index + 1;
            END IF;
            -- Snap arrow to rod center based on rod_index
            CASE rod_index IS
                WHEN 0 => arrowpos <= CONV_STD_LOGIC_VECTOR(200, 11); -- left rod
                WHEN 1 => arrowpos <= CONV_STD_LOGIC_VECTOR(400, 11); -- middle rod
                WHEN 2 => arrowpos <= CONV_STD_LOGIC_VECTOR(600, 11); -- right rod
                WHEN OTHERS => arrowpos <= CONV_STD_LOGIC_VECTOR(400, 11);
            END CASE;
            btnl_prev <= btnl;
            btnr_prev <= btnr;
        end if;
    END PROCESS;
    add_arrow : arrow
    PORT MAP(--instantiate arrow and ball component
        v_sync => S_vsync, 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        arrow_x => arrowpos, 
        btn0 => btn0,
        red => S_red, 
        green => S_green, 
        blue => S_blue,
        counter => cnt
    );
    
    vga_driver : vga_sync
    PORT MAP(  --instantiate vga_sync component
        pixel_clk => pxl_clk, 
        red_in => S_red & "000", 
        green_in => S_green & "000", 
        blue_in => S_blue & "000", 
        red_out => VGA_red, 
        green_out => VGA_green, 
        blue_out => VGA_blue, 
        pixel_row => S_pixel_row, 
        pixel_col => S_pixel_col, 
        hsync => VGA_hsync, 
        vsync => S_vsync
    );
    VGA_vsync <= S_vsync; --connect output vsync
        
    clk_wiz_0_inst : clk_wiz_0
    port map (
      clk_in1 => clk_in,
      clk_out1 => pxl_clk
    );
    
END Behavioral;
