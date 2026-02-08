library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity reg is
    port (
        i_clk  : in std_logic; --! Clock signal
        i_rst  : in std_logic; --! Reset signal, active high

        i_addr : in std_logic_vector(7 downto 0); --! Input address bus
        i_we   : in std_logic; --! Input write enable signal
        i_wdata : in std_logic_vector(7 downto 0); --! Input write data bus
        o_rdata : out std_logic_vector(7 downto 0); --! Output read data bus

        o_init_dim : out std_logic_vector(15 downto 0); --! Output initial dimming value
        o_en_pwm : out std_logic_vector(63 downto 0); --! Output PWM enable signals
        o_inc_pwm : out std_logic_vector(63 downto 0); --! Output PWM increment signals
        o_dec_pwm : out std_logic_vector(63 downto 0) --! Output PWM decrement signals
    );
end entity reg;

architecture rtl of reg is

    signal r_init_dim : std_logic_vector(15 downto 0); --! Register for initial dimming value
    signal r_en_pwm : std_logic_vector(63 downto 0); --! Register for PWM enable signals
    signal r_inc_pwm : std_logic_vector(63 downto 0); --! Register for PWM enable signals
    signal r_dec_pwm : std_logic_vector(63 downto 0); --! Register for PWM enable signals
    

begin
 
    -- addr 0 and 1: initial dimming value
    p_init_dim : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_init_dim <= (others => '0');
        elsif rising_edge(i_clk) then
            if (i_we = '1' and i_addr = x"00") then
                r_init_dim(7 downto 0) <= i_wdata;
                r_init_dim(15 downto 8) <= r_init_dim(15 downto 8);
            elsif (i_we = '1' and i_addr = x"01") then
                r_init_dim(15 downto 8) <= i_wdata;
                r_init_dim(7 downto 0) <= r_init_dim(7 downto 0);
            else
                r_init_dim <= r_init_dim;
            end if;
        end if;
    end process;

    -- addr 2 to 9: PWM enable signals
    gen_en_pwm : for i in 0 to 7 generate
        p_en_pwm : process(i_clk, i_rst)
        begin
            if (i_rst = '1') then
                r_en_pwm(((i+1)*8)-1 downto (i*8)) <= (others => '0');
            elsif rising_edge(i_clk) then
                if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(i+2, i_addr'length))) then
                    r_en_pwm(((i+1)*8)-1 downto (i*8)) <= i_wdata xor r_en_pwm(((i+1)*8)-1 downto (i*8));
                else
                    r_en_pwm(((i+1)*8)-1 downto (i*8)) <= r_en_pwm(((i+1)*8)-1 downto (i*8));
                end if;
            end if;
        end process;
    end generate;

    -- addr 10 to 17: PWM enable signals
    gen_inc_pwm : for i in 0 to 7 generate
        p_inc_pwm : process(i_clk, i_rst)
        begin
            if (i_rst = '1') then
                r_inc_pwm(((i+1)*8)-1 downto (i*8)) <= (others => '0');
            elsif rising_edge(i_clk) then
                if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(i+10, i_addr'length))) then
                    r_inc_pwm(((i+1)*8)-1 downto (i*8)) <= i_wdata;
                else
                    r_inc_pwm(((i+1)*8)-1 downto (i*8)) <= (others => '0');
                end if;
            end if;
        end process;
    end generate;

    -- addr 18 to 25: PWM enable signals
    gen_dec_pwm : for i in 0 to 7 generate
        p_dec_pwm : process(i_clk, i_rst)
        begin
            if (i_rst = '1') then
                r_dec_pwm(((i+1)*8)-1 downto (i*8)) <= (others => '0');
            elsif rising_edge(i_clk) then
                if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(i+18, i_addr'length))) then
                    r_dec_pwm(((i+1)*8)-1 downto (i*8)) <= i_wdata;
                else
                    r_dec_pwm(((i+1)*8)-1 downto (i*8)) <= (others => '0');
                end if;
            end if;
        end process;
    end generate;

    o_init_dim <= r_init_dim;
    o_en_pwm <= r_en_pwm;
    o_inc_pwm <= r_inc_pwm;
    o_dec_pwm <= r_dec_pwm;

    o_rdata <= r_init_dim(7 downto 0) when i_addr = x"00" else
               r_init_dim(15 downto 8) when i_addr = x"01" else
               r_en_pwm(((to_integer(unsigned(i_addr)) - 2 + 1)*8)-1 downto ((to_integer(unsigned(i_addr)) - 2)*8)) when (i_addr >= x"02" and i_addr <= x"09") else
               r_inc_pwm(((to_integer(unsigned(i_addr)) - 10 + 1)*8)-1 downto ((to_integer(unsigned(i_addr)) - 10)*8)) when (i_addr >= x"0A" and i_addr <= x"11") else
               r_dec_pwm(((to_integer(unsigned(i_addr)) - 18 + 1)*8)-1 downto ((to_integer(unsigned(i_addr)) - 18)*8)) when (i_addr >= x"12" and i_addr <= x"19") else
               (others => '0');

end architecture;