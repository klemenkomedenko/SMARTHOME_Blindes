library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity beat is
    generic (
        g_CLK_FREQ : integer := 30000000; --! Define clock frequency 30 MHz
        g_BEAT_FREQ : integer := 1000 --! Define beat frequency 1 kHz
    );
    port (
        i_clk   : in std_logic;
        i_rst : in std_logic;

        o_beat : out std_logic
    );
end entity beat;

architecture rtl of beat is

    signal r_beat_cnt : unsigned(15 downto 0); --! Counter for generating beat signal
    signal r_beat : std_logic; --! Register for beat output signal

begin

    p_beat_cnt : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_beat_cnt <= (others => '0');
        elsif rising_edge(i_clk) then
            if (r_beat_cnt = to_unsigned(g_CLK_FREQ / g_BEAT_FREQ - 1, r_beat_cnt'length)) then
                r_beat_cnt <= (others => '0');
            else
                r_beat_cnt <= r_beat_cnt + 1;
            end if;
        end if;
    end process;

    p_beat : process(i_clk, i_rst)
    begin
        if (i_rst = '1') then
            r_beat <= '0';
        elsif rising_edge(i_clk) then
            if (r_beat_cnt = to_unsigned(g_CLK_FREQ / g_BEAT_FREQ - 1, r_beat_cnt'length)) then
                r_beat <= '1';
            else
                r_beat <= '0';
            end if;
        end if;
    end process;

    o_beat <= r_beat; -- Output the beat signal

    

end architecture;