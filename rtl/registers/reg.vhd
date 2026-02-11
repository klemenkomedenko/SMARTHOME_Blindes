library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity reg_blinds is
    generic (
        N_BASE_ADDR : integer := 8 --! Number of blinds
    );
    port (
        i_clk   : in std_logic;
        i_rst   : in std_logic;
        
        i_addr  : in std_logic_vector(7 downto 0);
        i_we    : in std_logic;
        i_wdata : in std_logic_vector(7 downto 0);
        o_rdata : out std_logic_vector(7 downto 0);

        o_timer_limit : out std_logic_vector(15 downto 0);
        o_init_en   : out std_logic;
        o_up : out std_logic;
        o_down : out std_logic

        
    );
end entity reg_blinds;

architecture rtl of reg_blinds is

    signal r_timer_limit : std_logic_vector(15 downto 0);
    signal r_init_en : std_logic;
    signal r_up : std_logic;
    signal r_down : std_logic;
begin

    
    p_timer_limit : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_timer_limit <= (others => '0');
        elsif rising_edge(i_clk) then
            if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+0, i_addr'length))) then
                r_timer_limit(7 downto 0) <= i_wdata;
                r_timer_limit(15 downto 8) <= r_timer_limit(15 downto 8);
            elsif (i_we = '1' and i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+1, i_addr'length))) then
                r_timer_limit(15 downto 8) <= i_wdata;
                r_timer_limit(7 downto 0) <= r_timer_limit(7 downto 0);
            else
                r_timer_limit <= r_timer_limit;
            end if;
        end if;
    end process;

    p_init_en : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_init_en <= '0';
        elsif rising_edge(i_clk) then
            if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+2, i_addr'length))) then
                r_init_en <= i_wdata(0);
            else
                r_init_en <= r_init_en;
            end if;
        end if;
    end process;

    p_up : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_up <= '0';
        elsif rising_edge(i_clk) then
            if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+3, i_addr'length))) then
                r_up <= i_wdata(0);
            else
                r_up <= r_up;
            end if;
        end if;
    end process;

    p_down : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_down <= '0';
        elsif rising_edge(i_clk) then
            if (i_we = '1' and i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+4, i_addr'length))) then
                r_down <= i_wdata(0);
            else
                r_down <= r_down;
            end if;
        end if;
    end process;

    o_rdata <= r_timer_limit(7 downto 0) when i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+0, i_addr'length)) else
               r_timer_limit(15 downto 8) when i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+1, i_addr'length)) else
               "0000000" & r_init_en when i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+2, i_addr'length)) else
               "0000000" & r_up when i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+3, i_addr'length)) else
               "0000000" & r_down when i_addr = std_logic_vector(to_unsigned(N_BASE_ADDR+4, i_addr'length)) else
               (others => '0');

    o_timer_limit <= r_timer_limit;
    o_init_en <= r_init_en;
    o_up <= r_up;
    o_down <= r_down;
end architecture;
