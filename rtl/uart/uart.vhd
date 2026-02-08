library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity uart is
    generic (
        g_CLK_FREQ    : integer := 30_000_000; --! Define clock frequency 30 MHz 
        g_BAUD_RATE   : integer := 1_000_000  --! BAUDRATE of UART protocole 1 Mbps
    );
    port (
        i_clk   : in std_logic; --! Clock input for synchronizing the UART operations, used to generate baud ticks and drive the FSMs for both receiving and transmitting data
        i_rst   : in std_logic; --! Reset signal for initializing the UART state machines and counters, active high
        
        i_rx    : in std_logic; --! Serial input for receiving data, connected to the RX line of the UART interface, used to sample incoming data bits for reception
        o_tx    : out std_logic; --! Serial output for transmitting data, connected to the TX line of the UART interface, driven low for start bit, then shifted out data bits, and driven high for stop bit

        o_rx_data  : out std_logic_vector(7 downto 0); --! Output for the received data byte, driven with the received data bits once a full byte has been received and validated
        o_rx_vld   : out std_logic; --! Signal to indicate that the received data byte is valid and can be read from o_rx_data, set when a full byte has been received and validated
        i_tx_data  : in std_logic_vector(7 downto 0); --! Input for the data byte to be transmitted, loaded into the transmit shift register when a transmission is initiated
        i_tx_start : in std_logic; --! Signal to start transmission of the data byte on i_tx_data, when asserted, the UART will begin transmitting the start bit followed by the data bits and stop bit
        o_tx_busy  : out std_logic --! Signal to indicate that a transmission is in progress, used to prevent new transmissions from starting until the current one is complete
    );
end entity uart;

architecture rtl of uart is

    constant c_BAUD_TICK_CNT : unsigned(31 downto 0) := to_unsigned((g_CLK_FREQ / g_BAUD_RATE), 32); --! Number of clock cycles per baud tick, used for timing the reception of bits
    constant c_BAUD_TICK_CNT_HALF : unsigned(31 downto 0) := to_unsigned(((g_CLK_FREQ / g_BAUD_RATE) / 2)+7, 32); --! Number of clock cycles for half a baud tick, used for sampling the middle of the bit period, adjusted by 7 cycles to account for processing delays
    signal s_rx_baud_tick : std_logic := '0'; --! Baud tick signal for receiving data, generated when r_rx_baud_cnt reaches c_BAUD_TICK_CNT_HALF
    signal r_rx_baud_cnt  : unsigned(31 downto 0); --! Counter for generating baud tick for receiving data

    signal r_rx_shift : std_logic_vector(7 downto 0) := (others => '0'); --! Shift register for receiving data bits
    signal s_rx_data_cnt : unsigned(2 downto 0) := (others => '0'); --! Count received data bits
    signal r_rx_data_cnt : unsigned(2 downto 0) := (others => '0'); --! Registered Count received data bits
    signal s_rx_data_store : std_logic_vector(7 downto 0) := (others => '0'); --! Register to store received data bits before output
    signal r_rx_data_store : std_logic_vector(7 downto 0) := (others => '0'); --! Register to store received data bits before output
    signal s_rx_vld : std_logic := '0'; --! Signal to indicate that received data is valid and can be output, set when a full byte has been received and validated
    signal r_rx_vld : std_logic := '0'; --! Signal to indicate that received data is valid and can be output, set when a full byte has been received and validated
    signal s_rx_start_bit : std_logic := '0'; --! Signal to indicate that a start bit has been detected, used to trigger the reception process

    type t_rx_fsm is (IDLE, --! RESET state, waiting for start bit
                      START, --! Start bit detected, waiting for data bits
                      DATA, --! Receiving data bits
                      STOP, --! Stop bit, validating received data
                      DONE, --! Data reception complete, output data and wait for next byte
                      ERROR); --! Error state, invalid start/stop bit, discard data
    signal s_rx_fsm, r_rx_fsm : t_rx_fsm := IDLE; --! FSM state for receiving data, r_rx_fsm is the internal state, s_rx_fsm is the synchronized state for output

    signal r_tx_baud_tick : std_logic := '0'; --! Baud tick signal for transmit data, generated when r_rx_baud_cnt reaches c_BAUD_TICK_CNT_HALF
    signal r_tx_baud_cnt  : unsigned(31 downto 0); --! Counter for generating baud tick for transmit data
    signal s_tx_data_cnt : unsigned(2 downto 0) := (others => '0'); --! Counter for received data bits, used to track how many bits have been received during the DATA state of the receive FSM
    signal r_tx_data_cnt : unsigned(2 downto 0) := (others => '0'); --! Counter for received data bits, used to track how many bits have been received during the DATA state of the receive FSM
    signal s_tx_data_store : std_logic_vector(7 downto 0) := (others => '0'); --! Register to store data bits to be transmitted, loaded with i_tx_data when transmission starts
    signal r_tx_data_store : std_logic_vector(7 downto 0) := (others => '0'); --! Register to store data bits to be transmitted, loaded with i_tx_data when transmission starts
    signal s_tx : std_logic := '1'; --! Output signal for transmitting data, driven low for start bit, then shifted out data bits, and driven high for stop bit    
    signal r_tx : std_logic := '1'; --! Output signal for transmitting data, driven low for start bit, then shifted out data bits, and driven high for stop bit    
    signal s_tx_busy : std_logic := '0'; --! Signal to indicate that transmission is in progress, used to prevent new transmissions from starting until the current one is complete    
    signal r_tx_busy : std_logic := '0'; --! Register Signal to indicate that transmission is in progress, used to prevent new transmissions from starting until the current one is complete    

    type t_tx_fsm is (TX_IDLE, --! Waiting for transmit start signal
                      TX_WAIT_START, --! Start signal received, waiting for baud tick to start transmission
                      TX_START_BIT, --! Transmitting start bit
                      TX_DATA, --! Transmitting data bits
                      TX_STOP_BIT); --! Transmitting stop bit
    signal s_tx_fsm, r_tx_fsm : t_tx_fsm := TX_IDLE; --! FSM state for transmitting data, r_tx_fsm is the internal state, s_tx_fsm is the synchronized state for output


begin

    p_rx_shift : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_rx_shift <= (others => '0');
        elsif rising_edge(i_clk) then
            r_rx_shift <= r_rx_shift(6 downto 0) & i_rx;
        end if;
    end process p_rx_shift;

    p_rx_baud_cnt : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_rx_baud_cnt <= (others => '0');
        elsif rising_edge(i_clk) then
            if (r_rx_shift = x"00" and s_rx_start_bit = '1') then -- Start bit detected
                r_rx_baud_cnt <= c_BAUD_TICK_CNT + 3;
            else
                if r_rx_baud_cnt = to_unsigned(0, r_rx_baud_cnt'length) then
                    r_rx_baud_cnt <= c_BAUD_TICK_CNT - 1;
                else
                    r_rx_baud_cnt <= r_rx_baud_cnt - 1;
                end if;
            end if;
        end if;
    end process p_rx_baud_cnt;

    s_rx_baud_tick <= '1' when r_rx_baud_cnt = to_unsigned(0, r_rx_baud_cnt'length) else '0'; 

    p_rx_fsm_sync : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_rx_fsm <= IDLE;
        elsif rising_edge(i_clk) then
            r_rx_fsm <= s_rx_fsm; -- Register next-state into FSM state
        end if;
    end process p_rx_fsm_sync;

    p_rx_fsm : process(r_rx_fsm, s_rx_baud_tick, r_rx_shift, r_rx_data_cnt)
    begin
        s_rx_fsm <= r_rx_fsm; -- Update synchronized FSM state
        case r_rx_fsm is
            when IDLE =>
                s_rx_fsm <= START;

            when START =>
                if r_rx_shift = x"00" then
                    s_rx_fsm <= DATA;
                else 
                    s_rx_fsm <= START; -- If start bit is not valid, return to IDLE
                end if;

            when DATA =>
                if s_rx_baud_tick = '1' and r_rx_data_cnt = to_unsigned(7, r_rx_data_cnt'length) then
                    s_rx_fsm <= STOP; -- All data bits received, move to STOP state
                else 
                    s_rx_fsm <= DATA; -- Stay in DATA state until all bits are received
                end if;

            when STOP =>
                if s_rx_baud_tick = '1' then
                    if (r_rx_shift = x"FF") then -- Stop bit should be high
                        s_rx_fsm <= DONE; -- Output received data, move to START state for next byte
                    else
                        s_rx_fsm <= ERROR; -- Invalid stop bit, discard data
                    end if;
                end if;

            when ERROR =>
                s_rx_fsm <= START; -- Reset FSM on error

            when DONE =>
                s_rx_fsm <= START; -- Output received data, move to START state for next byte

            when others =>
                s_rx_fsm <= IDLE;
        end case;
    end process p_rx_fsm;
    
    p_rx_fsm_mux : process(r_rx_shift, r_rx_fsm, s_rx_baud_tick, r_rx_data_cnt)
    begin
        s_rx_data_cnt <= r_rx_data_cnt; -- Update synchronized data count
        s_rx_data_store <= r_rx_data_store; -- Update synchronized data store
        s_rx_vld <= '0'; -- Default to data not valid
        s_rx_start_bit <= '0'; -- Default to start bit not detected

        case r_rx_fsm is
            when IDLE =>

            when START =>
                s_rx_data_cnt <= (others => '0'); -- Reset data bit count at the start of reception
                s_rx_start_bit <= '1'; -- Indicate that a start bit has been detected

            when DATA =>
                if s_rx_baud_tick = '1' then
                    s_rx_data_cnt <= r_rx_data_cnt + 1; -- Increment data bit count on each baud tick
                    s_rx_data_store <= r_rx_shift(7) & r_rx_data_store(7 downto 1); -- Shift in received data bits into the data store
                else 
                    s_rx_data_cnt <= r_rx_data_cnt; -- Increment data bit count on each baud tick
                    s_rx_data_store <= r_rx_data_store; -- Shift in received data bits into the data store
                end if;

            when STOP =>

            when ERROR =>

            when DONE =>
                s_rx_vld <= '1'; -- Set data valid signal when a full byte has been received and validated

            when others =>
        end case;
    end process p_rx_fsm_mux;

    p_rx_fsm_output : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_rx_data_cnt <= (others => '0');
            r_rx_data_store <= (others => '0');
            r_rx_vld <= '0';
        elsif rising_edge(i_clk) then
            r_rx_data_cnt <= s_rx_data_cnt; -- Output the received data byte
            r_rx_data_store <= s_rx_data_store; -- Output the data valid signal
            r_rx_vld <= s_rx_vld; -- Output the data valid signal
        end if;
    end process p_rx_fsm_output;




 
    p_tx_baud_cnt : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_tx_baud_cnt <= (others => '0');
            r_tx_baud_tick <= '0';
        elsif rising_edge(i_clk) then
            if i_tx_start = '1' then
                r_tx_baud_cnt <= (others => '0');
                r_tx_baud_tick <= '0';
            else
                if r_tx_baud_cnt = c_BAUD_TICK_CNT - 1 then
                    r_tx_baud_cnt <= (others => '0');
                    r_tx_baud_tick <= '1'; -- Generate baud tick for transmit data
                else
                    r_tx_baud_cnt <= r_tx_baud_cnt + 1;
                    r_tx_baud_tick <= '0';
                end if;
            end if;
        end if;
    end process p_tx_baud_cnt;

    p_tx_fsm_sync : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_tx_fsm <= TX_IDLE;
        elsif rising_edge(i_clk) then
            r_tx_fsm <= s_tx_fsm; -- Synchronize FSM state to clock
        end if;
    end process p_tx_fsm_sync;


    p_tx_fsm : process(r_tx_fsm, r_tx_baud_tick, i_tx_start, r_tx_data_cnt)
    begin
        s_tx_fsm <= r_tx_fsm; -- Update synchronized FSM state
        case r_tx_fsm is
            when TX_IDLE =>
                s_tx_fsm <= TX_WAIT_START; -- Start signal received, wait for baud tick to start transmission

            when TX_WAIT_START =>
                if i_tx_start = '1' then
                    s_tx_fsm <= TX_START_BIT; -- Baud tick received, start transmitting data
                else 
                    s_tx_fsm <= TX_WAIT_START; -- Wait for baud tick to start transmission
                end if;

            when TX_START_BIT =>
                if r_tx_baud_tick = '1' then
                    s_tx_fsm <= TX_DATA; -- Start bit transmitted, move to DATA state to transmit data bits
                else 
                    s_tx_fsm <= TX_START_BIT; -- Transmit start bit until baud tick is received
                end if;

            when TX_DATA =>
                if r_tx_baud_tick = '1' then
                    if r_tx_data_cnt = to_unsigned(7, r_tx_data_cnt'length) then
                        s_tx_fsm <= TX_STOP_BIT; -- All data bits transmitted, move to STOP state to transmit stop bit
                    else 
                        s_tx_fsm <= TX_DATA; -- Transmit next data bit on each baud tick
                    end if;
                else 
                    s_tx_fsm <= TX_DATA; -- Transmit current data bit until baud tick is received
                end if;

            when TX_STOP_BIT =>
                if r_tx_baud_tick = '1' then
                    s_tx_fsm <= TX_IDLE; -- Stop bit transmitted, return to IDLE state for next transmission
                else 
                    s_tx_fsm <= TX_STOP_BIT; -- Transmit stop bit until baud tick is received
                end if;

            when others =>
                s_tx_fsm <= TX_IDLE;
        end case;
    end process p_tx_fsm;

    p_tx_fsm_mux : process(r_tx_fsm, r_tx_baud_tick, i_tx_start, i_tx_data, r_tx_data_cnt, r_tx_data_store)
    begin
        s_tx_data_store <= r_tx_data_store; -- Update synchronized data store
        s_tx_data_cnt <= r_tx_data_cnt;
        s_tx <= '1'; -- Default to idle state (line high)
        s_tx_busy <= '0'; -- Default to not busy

        case r_tx_fsm is
            when TX_IDLE =>

            when TX_WAIT_START =>
                s_tx_data_store <= i_tx_data; -- Load data to be transmitted into the data store when transmission starts

            when TX_START_BIT =>
                s_tx <= '0'; -- Transmit start bit (line low)
                s_tx_busy <= '1'; -- Indicate transmission is in progress
                s_tx_data_cnt <= (others => '0');

            when TX_DATA =>
                s_tx_busy <= '1'; -- Indicate transmission is in progress
                s_tx <= r_tx_data_store(0); -- Transmit the least significant bit of the data store on each baud tick
                if r_tx_baud_tick = '1' then
                    s_tx_data_store <= '0' & r_tx_data_store(7 downto 1); -- Shift out data bits from the data store on each baud tick
                    s_tx_data_cnt <= r_tx_data_cnt + 1; -- Increment data bit count on each baud tick
                else 
                    s_tx_data_store <= r_tx_data_store; -- Shift out data bits from the data store on each baud tick
                    s_tx_data_cnt <= r_tx_data_cnt; -- Shift out data bits from the data store on each baud tick
                end if;

            when TX_STOP_BIT =>
                s_tx_busy <= '1'; -- Indicate transmission is in progress
                s_tx <= '1'; -- Transmit stop bit (line high)

            when others =>
        end case;
    end process p_tx_fsm_mux;

    p_tx_fsm_output : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_tx_data_cnt <= (others => '0');
            r_tx_data_store <= (others => '0');
            r_tx <= '1';
            r_tx_busy <= '1';
        elsif rising_edge(i_clk) then
            r_tx_data_cnt <= s_tx_data_cnt; -- Output the data bit count for transmission
            r_tx_data_store <= s_tx_data_store; -- Output the data store for transmission
            r_tx <= s_tx; -- Output the transmit signal
            r_tx_busy <= s_tx_busy; -- Output the transmit busy signal
        end if;
    end process p_tx_fsm_output;

    o_tx <= r_tx; -- Drive the output transmit signal
    o_rx_data <= r_rx_data_store; -- Drive the output received data signal
    o_rx_vld <= r_rx_vld;
    o_tx_busy <= r_tx_busy; -- Drive the output transmit busy signal

end architecture;