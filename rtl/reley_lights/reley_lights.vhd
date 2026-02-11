library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity reley_lights is
    port (
        i_clk   : in std_logic;
        i_rst   : in std_logic;
        i_addr  : in std_logic_vector(7 downto 0); --! Address bus for register access
        i_we    : in std_logic; --! Write enable signal for register access
        i_wdata : in std_logic_vector(7 downto 0); --! Write data bus for register access
        o_rdata : out std_logic_vector(7 downto 0); --! Read data bus for register access
    
        o_on_off : out std_logic --! Output signal to control the on/off state of the relay
    );
end entity reley_lights;

architecture rtl of reley_lights is

    signal r_relay_state : std_logic := '0'; --! Internal signal to hold the current state of the relay

begin
  
    p_relay_state : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_relay_state <= '0'; --! Reset the relay state to off
        elsif rising_edge(i_clk) then
            if i_we = '1' and i_addr = x"00" and i_wdata(0) = '1' then --! Check for write enable and correct address
                r_relay_state <= not(r_relay_state); --! Update the relay state based on the least significant bit of the write data
            end if;
        end if;
    end process p_relay_state;

    o_rdata <= "0000000" & r_relay_state; --! Output the current state of the relay on the read data bus
    
    o_on_off <= r_relay_state; --! Output the current state of the relay
end architecture;