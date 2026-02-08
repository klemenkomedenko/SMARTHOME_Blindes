library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity uart_tb is
end entity;

architecture sim of uart_tb is
    constant c_CLK_FREQ  : integer := 20_000_000;
    constant c_BAUD_RATE : integer := 1_000_000;

    constant c_CLK_PERIOD : time := 1 sec / c_CLK_FREQ;
    constant c_BIT_PERIOD : time := 1 sec / c_BAUD_RATE;

    signal clk : std_logic := '0';
    signal rst : std_logic := '1';

    signal rx : std_logic := '1';
    signal tx : std_logic;

    signal rx_data : std_logic_vector(7 downto 0);
    signal rx_vld  : std_logic;

    signal tx_data  : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_start : std_logic := '0';
    signal tx_busy  : std_logic;

    -- Monitor outputs
    signal tx_mon_vld  : std_logic := '0';
    signal tx_mon_data : std_logic_vector(7 downto 0) := (others => '0');

    signal rx_line_mon_vld  : std_logic := '0';
    signal rx_line_mon_data : std_logic_vector(7 downto 0) := (others => '0');

    function hex_nibble_to_char(n : std_logic_vector(3 downto 0)) return character is
    begin
        case n is
            when "0000" => return '0';
            when "0001" => return '1';
            when "0010" => return '2';
            when "0011" => return '3';
            when "0100" => return '4';
            when "0101" => return '5';
            when "0110" => return '6';
            when "0111" => return '7';
            when "1000" => return '8';
            when "1001" => return '9';
            when "1010" => return 'A';
            when "1011" => return 'B';
            when "1100" => return 'C';
            when "1101" => return 'D';
            when "1110" => return 'E';
            when "1111" => return 'F';
            when others => return 'X';
        end case;
    end function;

    function byte_to_hex(b : std_logic_vector(7 downto 0)) return string is
        variable s : string(1 to 2);
    begin
        s(1) := hex_nibble_to_char(b(7 downto 4));
        s(2) := hex_nibble_to_char(b(3 downto 0));
        return s;
    end function;

    procedure uart_send_byte(
        signal line_out : out std_logic;
        constant data   : in  std_logic_vector(7 downto 0);
        constant bit_t  : in  time
    ) is
    begin
        -- Start bit
        line_out <= '0';
        wait for bit_t;

        -- Data bits (LSB first)
        for i in 0 to 7 loop
            line_out <= data(i);
            wait for bit_t;
        end loop;

        -- Stop bit
        line_out <= '1';
        wait for bit_t;
    end procedure;

    procedure uart_capture_byte(
        signal line_in : in std_logic;
        variable data  : out std_logic_vector(7 downto 0);
        constant bit_t : in time;
        constant name  : in string
    ) is
        variable tmp : std_logic_vector(7 downto 0);
    begin
        -- Wait for start bit
        wait until line_in = '0';
        wait for bit_t/2;

        if line_in /= '0' then
            report name & ": start-bit glitch" severity warning;
        end if;

        -- Sample data bits in the middle of each bit
        for i in 0 to 7 loop
            wait for bit_t;
            tmp(i) := line_in;
        end loop;

        -- Stop bit
        wait for bit_t;
        if line_in /= '1' then
            report name & ": stop-bit invalid" severity warning;
        end if;

        data := tmp;
        report name & " byte=0x" & byte_to_hex(tmp);
    end procedure;

begin

    -- Clock generation
    clk <= not clk after c_CLK_PERIOD/2;

    -- DUT
    dut : entity work.uart
        generic map (
            g_CLK_FREQ  => c_CLK_FREQ,
            g_BAUD_RATE => c_BAUD_RATE
        )
        port map (
            i_clk      => clk,
            i_rst      => rst,
            i_rx       => tx,
            o_tx       => tx,
            o_rx_data  => rx_data,
            o_rx_vld   => rx_vld,
            i_tx_data  => tx_data,
            i_tx_start => tx_start,
            o_tx_busy  => tx_busy
        );

    -- Serial line monitors (decodes wire-level UART into bytes)
    p_tx_monitor : process
        variable b : std_logic_vector(7 downto 0);
    begin
        tx_mon_vld <= '0';
        wait until rst = '0';
        wait for 5*c_BIT_PERIOD;

        loop
            uart_capture_byte(tx, b, c_BIT_PERIOD, "TX_MON");
            tx_mon_data <= b;
            tx_mon_vld  <= '1';
            wait until rising_edge(clk);
            tx_mon_vld  <= '0';
        end loop;
    end process;

    p_rx_line_monitor : process
        variable b : std_logic_vector(7 downto 0);
    begin
        rx_line_mon_vld <= '0';
        wait until rst = '0';
        wait for 5*c_BIT_PERIOD;

        loop
            uart_capture_byte(rx, b, c_BIT_PERIOD, "RX_LINE_MON");
            rx_line_mon_data <= b;
            rx_line_mon_vld  <= '1';
            wait until rising_edge(clk);
            rx_line_mon_vld  <= '0';
        end loop;
    end process;

    -- Main stimulus + self-checks
    p_stim : process
        constant c_rx1 : std_logic_vector(7 downto 0) := x"55";
        constant c_rx2 : std_logic_vector(7 downto 0) := x"A3";
        constant c_tx1 : std_logic_vector(7 downto 0) := x"C1";
        constant c_tx2 : std_logic_vector(7 downto 0) := x"3E";
    begin
        -- Reset
        rst <= '1';
        rx  <= '1';
        tx_start <= '0';
        wait for 20*c_CLK_PERIOD;
        rst <= '0';
        wait for 20*c_CLK_PERIOD;

        -- -- RX path test: drive serial RX line, expect o_rx_vld + correct o_rx_data
        -- uart_send_byte(rx, c_rx1, c_BIT_PERIOD);
        -- wait until rx_vld = '1';
        -- assert rx_data = c_rx1
        --     report "RX mismatch (1): got 0x" & byte_to_hex(rx_data) & " exp 0x" & byte_to_hex(c_rx1)
        --     severity error;

        -- uart_send_byte(rx, c_rx2, c_BIT_PERIOD);
        -- wait until rx_vld = '1';
        -- assert rx_data = c_rx2
        --     report "RX mismatch (2): got 0x" & byte_to_hex(rx_data) & " exp 0x" & byte_to_hex(c_rx2)
        --     severity error;

        -- TX path test: request transmit and decode on the TX line monitor
        tx_data <= c_rx1;
        wait until rising_edge(clk);
        tx_start <= '1';
        wait until rising_edge(clk);
        tx_start <= '0';

        wait until tx_busy = '1';
        wait until tx_busy = '0';

        wait;
    end process;

end architecture;
