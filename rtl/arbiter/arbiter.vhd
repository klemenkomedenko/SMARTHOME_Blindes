library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity arbiter is
    port (
        i_clk : in std_logic; --! Clock signal
        i_rst : in std_logic; --! Reset signal, active high
 
        o_addr : out std_logic_vector(7 downto 0); --! Output address bus
        o_we : out std_logic; --! Output write enable signal
        o_wdata : out std_logic_vector(7 downto 0); --! Output write data bus
        i_rdata : in std_logic_vector(7 downto 0); --! Input read data bus

        i_uart_rx_data : in std_logic_vector(7 downto 0); --! Input UART received data bus
        i_uart_rx_vld : in std_logic; --! Input UART received data valid signal

        o_uart_tx_data : out std_logic_vector(7 downto 0); --! Output UART transmit data bus
        o_uart_tx_vld : out std_logic; --! Output UART transmit data valid signal
        i_uart_tx_busy : in std_logic --! Input UART transmit busy signal
        
    );
end entity arbiter;

architecture rtl of arbiter is

    type t_arb_fsm is (IDLE, --! Idle state, waiting for UART data
                      WAIT_CMD, --! Waiting for command from UART
                      WADDR, --! Writing address to memory
                      WLEN, --! Setting write enable signal
                      WDATA, --! Writing data to memory
                      WEOP, --! Ending write operation
                      RADDR, --! Writing address to memory
                      RLEN, --! Setting read enable signal
                      RRPLY, --! Replying with read data to UART
                      RDATA, --! Reading data from memory
                      WAIT_BUSY_ACT, --! Waiting for UART to be ready for next byte
                      WAIT_BUSY, --! Waiting for UART to be ready for next byte
                      REOP, --! Ending read operation
                      REOP_WAIT_BUSY_ACT, --! Waiting for UART to be ready for next byte
                      REOP_WAIT_BUSY --! Waiting for UART to be ready for next byte
                      ); --! Writing data to memory
    signal s_arb_fsm, r_arb_fsm : t_arb_fsm := IDLE;

    signal s_wdata_cnt : unsigned(7 downto 0); --! Counter for number of bytes written
    signal r_wdata_cnt : unsigned(7 downto 0); --! Register Counter for number of bytes written
    signal r_wdata_len : unsigned(7 downto 0); --! Register for number of bytes to write
    signal s_wdata_len : unsigned(7 downto 0); --! Counter for number of bytes to write
    signal r_rdata_cnt : unsigned(7 downto 0); --! Register Counter for number of bytes read
    signal s_rdata_cnt : unsigned(7 downto 0); --! Counter for number of bytes read
    signal r_rdata_len : unsigned(7 downto 0); --! Register for number of bytes to read
    signal s_rdata_len : unsigned(7 downto 0); --! Counter for number of bytes to read
    signal r_uart_tx_busy : std_logic; --! Register for UART transmit busy signal
    signal s_fe_uart_tx_busy : std_logic; --! Signal for edge detection of UART transmit busy signal

    signal s_addr : unsigned(7 downto 0); --! Signal for output address bus
    signal r_addr : unsigned(7 downto 0); --! Signal for output address bus
    signal s_we : std_logic; --! Signal for output write enable

    signal s_uart_tx_data : std_logic_vector(7 downto 0); --! Signal for output UART transmit data bus
    signal s_uart_tx_vld : std_logic; --! Signal for output UART transmit valid signal

begin

    p_uart_tx_busy : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_uart_tx_busy <= '0';
        elsif rising_edge(i_clk) then
            r_uart_tx_busy <= i_uart_tx_busy;
        end if;
    end process;
 
    s_fe_uart_tx_busy <= r_uart_tx_busy and not(i_uart_tx_busy);

    p_arb_fsm_sync : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_arb_fsm <= IDLE;
        elsif rising_edge(i_clk) then
            r_arb_fsm <= s_arb_fsm;
        end if;
    end process;

    p_arb_fsm : process(r_arb_fsm, i_uart_rx_vld, i_uart_rx_data, i_rdata, i_uart_tx_busy, r_wdata_cnt, r_wdata_len, r_rdata_cnt, r_rdata_len, i_uart_tx_busy)
    begin
        s_arb_fsm <= r_arb_fsm;
        case r_arb_fsm is
            when IDLE =>
                s_arb_fsm <= WAIT_CMD;

            when WAIT_CMD =>
                if i_uart_rx_data = x"4B" and i_uart_rx_vld = '1' then
                    s_arb_fsm <= WADDR;
                elsif i_uart_rx_data = x"B4" and i_uart_rx_vld = '1' then
                    s_arb_fsm <= RADDR;
                else
                    s_arb_fsm <= WAIT_CMD;
                end if;

            when WADDR =>
                if (i_uart_rx_vld = '1') then
                    s_arb_fsm <= WLEN;
                else
                    s_arb_fsm <= WADDR;
                end if;

            when WLEN =>
                if (i_uart_rx_vld = '1') then
                    s_arb_fsm <= WDATA;
                else
                    s_arb_fsm <= WLEN;
                end if;

            when WDATA =>
                if (i_uart_rx_vld = '1' and r_wdata_cnt = r_wdata_len) then
                    s_arb_fsm <= WEOP;
                else
                    s_arb_fsm <= WDATA;
                end if;

            when WEOP =>
                if (i_uart_rx_vld = '1') then
                    s_arb_fsm <= WAIT_CMD;
                else
                    s_arb_fsm <= WEOP;
                end if;

            when RADDR =>
                if (i_uart_rx_vld = '1') then
                    s_arb_fsm <= RLEN;
                else
                    s_arb_fsm <= RADDR;
                end if;

            when RLEN =>
                if (i_uart_rx_vld = '1') then
                    s_arb_fsm <= RRPLY;
                else
                    s_arb_fsm <= RLEN;
                end if;

            when RRPLY =>
                s_arb_fsm <= WAIT_BUSY_ACT;

            when WAIT_BUSY_ACT =>
                if i_uart_tx_busy = '1' then
                    s_arb_fsm <= WAIT_BUSY;
                else
                    s_arb_fsm <= WAIT_BUSY_ACT;
                end if;

            when WAIT_BUSY => 
                if (i_uart_tx_busy = '0') then
                    if (r_rdata_cnt = r_rdata_len) then
                        s_arb_fsm <= REOP;
                    else
                        s_arb_fsm <= RDATA;
                    end if;
                else
                    s_arb_fsm <= WAIT_BUSY;
                end if;

            when RDATA =>
                s_arb_fsm <= WAIT_BUSY_ACT;


            when REOP =>
                if i_uart_tx_busy = '1' then
                    s_arb_fsm <= REOP_WAIT_BUSY_ACT;
                else
                    s_arb_fsm <= REOP;
                end if;
            
            when REOP_WAIT_BUSY_ACT =>
                if i_uart_tx_busy = '1' then
                    s_arb_fsm <= REOP_WAIT_BUSY;
                else
                    s_arb_fsm <= REOP_WAIT_BUSY_ACT;
                end if;

            when REOP_WAIT_BUSY =>
                if i_uart_tx_busy = '0' then
                    s_arb_fsm <= WAIT_CMD;
                else
                    s_arb_fsm <= REOP_WAIT_BUSY;
                end if;

            when others =>
                s_arb_fsm <= IDLE;
        end case;
    end process;

    p_arb_fsm_mux : process(r_arb_fsm, i_uart_rx_vld, i_uart_rx_data, i_rdata, i_uart_tx_busy, r_wdata_cnt, r_wdata_len,
                            r_rdata_cnt, r_rdata_len, r_addr, i_rdata)
    begin
        s_wdata_len <= r_wdata_len;
        s_wdata_cnt <= r_wdata_cnt;
        s_rdata_len <= r_rdata_len;
        s_rdata_cnt <= r_rdata_cnt;
        s_addr <= r_addr;
        s_we <= '0';
        s_uart_tx_data <= (others => '0');
        s_uart_tx_vld <= '0';

        case r_arb_fsm is
            when IDLE =>

            when WAIT_CMD =>

            when WADDR =>
                s_addr <= unsigned(i_uart_rx_data);

            when WLEN =>
                s_wdata_cnt <= (others => '0');
                s_wdata_len <= unsigned(i_uart_rx_data);

            when WDATA =>
                if (i_uart_rx_vld = '1') then
                    s_wdata_cnt <= r_wdata_cnt + 1;
                    s_addr <= r_addr + 1;
                    s_we <= '1';
                else 
                    s_wdata_cnt <= r_wdata_cnt;
                    s_addr <= r_addr;
                    s_we <= '0';
                end if;

            when WEOP =>

            when RADDR =>
                s_addr <= unsigned(i_uart_rx_data);

            when RLEN =>
                s_rdata_len <= unsigned(i_uart_rx_data) + 1;
                
            when RRPLY =>
                s_rdata_cnt <= (others => '0');
                s_uart_tx_data <= x"87";
                s_uart_tx_vld <= '1';

            when WAIT_BUSY_ACT =>

            when WAIT_BUSY => 

            when RDATA =>
                s_rdata_cnt <= r_rdata_cnt + 1;
                s_uart_tx_data <= i_rdata;
                s_uart_tx_vld <= '1';

            when REOP =>
                s_rdata_cnt <= (others => '0');
                s_uart_tx_data <= x"6D";
                s_uart_tx_vld <= '1';

            when REOP_WAIT_BUSY_ACT =>

            when REOP_WAIT_BUSY =>

        end case;
    end process;

    p_arb_fsm_output : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
             r_wdata_cnt <= (others => '0');
             r_wdata_len <= (others => '0');
             r_rdata_cnt <= (others => '0');
             r_rdata_len <= (others => '0');
             r_addr <= (others => '0');
        elsif rising_edge(i_clk) then
             r_wdata_cnt <= s_wdata_cnt;
             r_wdata_len <= s_wdata_len;
             r_rdata_cnt <= s_rdata_cnt;
             r_rdata_len <= s_rdata_len;
             r_addr <= s_addr;
        end if;
    end process;

    o_addr <= std_logic_vector(r_addr);
    o_we <= s_we;
    o_wdata <= i_uart_rx_data;

    o_uart_tx_data <= s_uart_tx_data;
    o_uart_tx_vld <= s_uart_tx_vld;


end architecture;