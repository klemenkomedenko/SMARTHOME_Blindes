library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity top is    
    generic (
        g_CLK_FREQ    : integer := 30_000_000; --! Define clock frequency 30 MHz 
        g_BAUD_RATE   : integer := 1_000_000;  --! BAUDRATE of UART protocole 1 Mbps
        g_BEAT_FREQ   : integer := 1_000;  --! Beat frequency for PWM timing control 1 kHz
        g_N_BLINDS     : integer := 11; --! Number of blinds in the system
        g_N_ON_OFF     : integer := 5; --! Number of blinds in the system
        g_timer : integer := 100; --! Default timer value for timing operations
        g_dly_timer : integer := 50 --! Default timer value for delay operations
    );
    port (
        i_rx : in std_logic; --! Input signal for UART reception, used to receive data from an external device such as a microcontroller or computer
        o_tx : out std_logic; --! Output signal for UART transmission, used to send data to an external device such as a microcontroller or computer

        o_relay_up : out std_logic_vector(g_N_BLINDS-1 downto 0); --! Output signal vector to control the up state of the blinds, each bit corresponds to a blind
        o_relay_down : out std_logic_vector(g_N_BLINDS-1 downto 0); --! Output signal vector to control the down state of the blinds, each bit corresponds to a blind

        o_on_off : out std_logic_vector(g_N_ON_OFF-1 downto 0) --! Output signal vector to control the on/off state of the relay lights, each bit corresponds to a relay light
        
    );
end entity top;

architecture rtl of top is

    signal s_clk_osc : std_logic; --! Signal for the output of the clock oscillator, which provides the base clock signal for the system
    signal s_clk_pll : std_logic;  --! Signal for the output of the PLL (Phase-Locked Loop), which is used to generate a stable and precise clock signal for the system based on the input from the clock oscillator
    signal s_clk_pll_lock : std_logic;  --! Signal indicating whether the PLL has achieved lock, which means it has stabilized and is providing a reliable clock signal
    signal r_rst : std_logic_vector(7 downto 0); --! Reset signal vector for different modules, each bit can be used to reset a specific module or group of modules

    signal s_rx_data : std_logic_vector(7 downto 0); --! Signal for UART received data
    signal s_tx_data : std_logic_vector(7 downto 0); --! Signal for UART transmited data
    signal s_rx_vld : std_logic;
    signal s_tx_start : std_logic;
    signal s_tx_busy : std_logic;

    signal s_addr : std_logic_vector(7 downto 0);
    signal s_we : std_logic;
    signal s_wdata : std_logic_vector(7 downto 0);
    signal s_rdata : std_logic_vector(7 downto 0);
    type t_rdata_array is array (0 to (g_N_BLINDS + g_N_ON_OFF)-1) of std_logic_vector(7 downto 0);
    signal s_rdata_array : t_rdata_array;

    signal s_init_dim : std_logic_vector(15 downto 0);
    signal s_en_pwm : std_logic_vector(63 downto 0);
    signal s_inc_pwm : std_logic_vector(63 downto 0);
    signal s_dec_pwm : std_logic_vector(63 downto 0);
    signal s_beat : std_logic;

    component clk_osc is
        port(
            hf_out_en_i: in std_logic;
            hf_clk_out_o: out std_logic
        );
    end component;

    component clk_pll is
        port(
            clki_i: in std_logic;
            clkop_o: out std_logic;
            lock_o: out std_logic
        );
    end component;

begin

    u_clk_osc : clk_osc port map(
        hf_out_en_i=> '1',
        hf_clk_out_o=> s_clk_osc
    );

    u_clk_pll : clk_pll port map(
        clki_i=> s_clk_osc,
        clkop_o=> s_clk_pll,
        lock_o=> s_clk_pll_lock
    );

    p_rst : process(s_clk_pll, s_clk_pll_lock)
    begin
        if s_clk_pll_lock = '0' then
            r_rst <= (others => '1');
        elsif rising_edge(s_clk_pll) then
            r_rst <= r_rst(r_rst'high - 1 downto 0) &'0';
        end if;
    end process;

    uart_inst : entity work.uart
    generic map (
        g_CLK_FREQ => g_CLK_FREQ,
        g_BAUD_RATE => g_BAUD_RATE
    )
    port map (
        i_clk => s_clk_pll,
        i_rst => r_rst(r_rst'high),
        i_rx => i_rx,
        o_tx => o_tx,
        o_rx_data => s_rx_data,
        o_rx_vld => s_rx_vld,
        i_tx_data => s_tx_data,
        i_tx_start => s_tx_start,
        o_tx_busy => s_tx_busy
    );

    arbiter_inst : entity work.arbiter
    port map (
        i_clk => s_clk_pll,
        i_rst => r_rst(r_rst'high),
        o_addr => s_addr,
        o_we => s_we,
        o_wdata => s_wdata,
        i_rdata => s_rdata,
        i_uart_rx_data => s_rx_data,
        i_uart_rx_vld => s_rx_vld,
        o_uart_tx_data => s_tx_data,
        o_uart_tx_vld => s_tx_start,
        i_uart_tx_busy => s_tx_busy
    );



    gen_blinds : for i in 0 to g_N_BLINDS-1 generate
        blinds_inst : entity work.blinds
        generic map (
            g_timer => g_timer,
            g_dly_timer => g_dly_timer,
            N_BASE_ADDR => i*5
        )
        port map (
            i_clk => s_clk_pll,
            i_rst => r_rst(r_rst'high),
            i_beat => s_beat,
            i_addr => s_addr,
            i_we => s_we,
            i_wdata => s_wdata,
            o_rdata => s_rdata_array(i),
            o_relay_up => o_relay_up(i),
            o_relay_down => o_relay_down(i)
        );
    end generate;

    gen_on_off : for i in 0 to g_N_ON_OFF-1 generate

    reley_lights_inst : entity work.reley_lights
        generic map (
            g_BASE_ADDR => (g_N_BLINDS * 5) + i
        )
        port map (
            i_clk => s_clk_pll,
            i_rst => r_rst(r_rst'high),
            i_addr => s_addr,
            i_we => s_we,
            i_wdata => s_wdata,
            o_rdata => s_rdata_array(i + g_N_BLINDS),
            o_on_off => o_on_off(i)
        );

    end generate;


    s_rdata <= s_rdata_array(0) when s_addr >= std_logic_vector(to_unsigned(0, 8)) and s_addr < std_logic_vector(to_unsigned(5, 8)) else
               s_rdata_array(1) when s_addr >= std_logic_vector(to_unsigned(5, 8)) and s_addr < std_logic_vector(to_unsigned(10, 8)) else
               s_rdata_array(2) when s_addr >= std_logic_vector(to_unsigned(10, 8)) and s_addr < std_logic_vector(to_unsigned(15, 8)) else
               s_rdata_array(3) when s_addr >= std_logic_vector(to_unsigned(15, 8)) and s_addr < std_logic_vector(to_unsigned(20, 8)) else
               s_rdata_array(4) when s_addr >= std_logic_vector(to_unsigned(20, 8)) and s_addr < std_logic_vector(to_unsigned(25, 8)) else
               s_rdata_array(5) when s_addr >= std_logic_vector(to_unsigned(25, 8)) and s_addr < std_logic_vector(to_unsigned(30, 8)) else
               s_rdata_array(6) when s_addr >= std_logic_vector(to_unsigned(30, 8)) and s_addr < std_logic_vector(to_unsigned(35, 8)) else
               s_rdata_array(7) when s_addr >= std_logic_vector(to_unsigned(35, 8)) and s_addr < std_logic_vector(to_unsigned(40, 8)) else
               s_rdata_array(8) when s_addr >= std_logic_vector(to_unsigned(40, 8)) and s_addr < std_logic_vector(to_unsigned(45, 8)) else
               s_rdata_array(9) when s_addr >= std_logic_vector(to_unsigned(45, 8)) and s_addr < std_logic_vector(to_unsigned(50, 8)) else
               s_rdata_array(10) when s_addr >= std_logic_vector(to_unsigned(50, 8)) and s_addr < std_logic_vector(to_unsigned(55, 8)) else
               s_rdata_array(11) when s_addr = std_logic_vector(to_unsigned(55, 8)) else
               s_rdata_array(12) when s_addr = std_logic_vector(to_unsigned(56, 8)) else
               s_rdata_array(13) when s_addr = std_logic_vector(to_unsigned(57, 8)) else
               s_rdata_array(14) when s_addr = std_logic_vector(to_unsigned(58, 8)) else
               s_rdata_array(15) when s_addr = std_logic_vector(to_unsigned(59, 8)) else
               (others => '0');

    beat_inst : entity work.beat
    generic map (
        g_CLK_FREQ => g_CLK_FREQ,
        g_BEAT_FREQ => g_BEAT_FREQ
    )
    port map (
        i_clk => s_clk_pll,
        i_rst => r_rst(r_rst'high),
        o_beat => s_beat
    );



end architecture rtl;