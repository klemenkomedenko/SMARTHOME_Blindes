library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;


entity blinds is
    generic (
        --! Generic parameters can be added here if needed
        g_timer : integer := 100; --! Default timer value for timing operations
        g_dly_timer : integer := 50; --! Default timer value for delay operations
        N_BASE_ADDR : integer := 0 --! Base address for the blinds registers
    );
    port (
        i_clk   : in std_logic; --! Clock signal
        i_rst   : in std_logic; --! Reset signal
        i_beat  : in std_logic; --! Beat signal for timing operations

        i_addr  : in std_logic_vector(7 downto 0); --! Address bus for register access
        i_we    : in std_logic; --! Write enable signal for register access
        i_wdata : in std_logic_vector(7 downto 0); --! Write data bus for register access
        o_rdata : out std_logic_vector(7 downto 0); --! Read data bus for register access

        o_relay_up : out std_logic; --! Output signal to control the relay for opening
        o_relay_down : out std_logic --! Output signal to control the relay for closing

        
    );
end entity blinds;

architecture rtl of blinds is

    type t_fsm is (IDLE, --! Idle state, waiting for a command
                  WAIT_INIT, --! Blinds are initializing
                  FULLY_OPEN, --! Blinds are fully open
                  WANT_1s_OPEN, --! Blinds want to be open for 1 second
                  FULLY_CLOSED, --! Blinds are fully closed
                  WAIT_1s_CLOSED, --! Blinds want to be closed for 1 second
                  WAIT_CMD, --! Blinds are waiting for a command
                  UP_WAIT, --! Blinds are opening
                  UP_FULLY_OPEN, --! Blinds are fully open
                  UP_USER_OPEN, --! Blinds are opening by user command
                  UP_USER_STALL, --! Blinds are stalled while opening by user command
                  DOWN_WAIT, --! Blinds are closing
                  DOWN_FULLY_CLOSED, --! Blinds are fully closed
                  DOWN_USER_CLOSED, --! Blinds are closing by user command
                  DOWN_USER_STALL, --! Blinds are stopped while closing by user command
                  UP_FULLY_OPEN_NOT, --! Blinds are fully open but not initialized
                  UP_FULLY_CLOSED_NOT --! Blinds are fully closed but not initialized
                  ); --! Blinds are stopped
    signal s_fsm, r_fsm : t_fsm := IDLE;

    signal r_timer : unsigned(15 downto 0) := (others => '0'); --! Timer for timing operations
    signal s_timer : unsigned(15 downto 0) := (others => '0'); --! Timer for timing operations
    signal r_dly_timer : unsigned(15 downto 0) := (others => '0'); --! Timer for delay operations
    signal s_dly_timer : unsigned(15 downto 0) := (others => '0'); --! Timer for delay operations

    signal s_relay_up : std_logic := '0'; --! Signal to control the relay for opening
    signal r_relay_up : std_logic := '0'; --! Signal to control the relay for opening
    signal s_relay_down : std_logic := '0'; --! Signal to control the relay for closing
    signal r_relay_down : std_logic := '0'; --! Signal to control the relay for closing

    signal s_timer_limit : std_logic_vector(15 downto 0); --! Signal to hold the timer limit value from the register
    signal s_init_en : std_logic; --! Signal to hold the initialization enable value from the register
    signal s_up : std_logic; --! Signal to hold the up command value from the register
    signal s_down : std_logic; --! Signal to hold the down command value from the register

begin

    reg_blinds_inst : entity work.reg_blinds
    generic map (
        N_BASE_ADDR => N_BASE_ADDR
    )
    port map (
        i_clk => i_clk,
        i_rst => i_rst,
        i_addr => i_addr,
        i_we => i_we,
        i_wdata => i_wdata,
        o_rdata => o_rdata,
        o_timer_limit => s_timer_limit,
        o_init_en => s_init_en,
        o_up => s_up,
        o_down => s_down
    );


    p_fsm_synch : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_fsm <= IDLE;
        elsif rising_edge(i_clk) then
            r_fsm <= s_fsm;
        end if;
    end process p_fsm_synch;

    p_fsm : process(r_fsm, s_init_en, r_timer, r_dly_timer, s_up, s_down, i_beat)
    begin
        s_fsm <= r_fsm; --! Default assignment to hold the state
        case r_fsm is
            when IDLE =>
                s_fsm <= WAIT_INIT;

            when WAIT_INIT =>
                if (s_init_en = '1') then
                    s_fsm <= FULLY_OPEN;
                else
                    s_fsm <= WAIT_INIT; --! Stay in WAIT_INIT until enabled
                end if;

            when FULLY_OPEN =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_timer = to_unsigned(0, r_timer'length)) then
                        s_fsm <= WANT_1s_OPEN;
                    else
                        s_fsm <= FULLY_OPEN; --! Stay in FULLY_OPEN until timer expires
                    end if;
                end if;

            when WANT_1s_OPEN =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_dly_timer = to_unsigned(g_dly_timer+g_dly_timer, r_dly_timer'length)) then
                        s_fsm <= FULLY_CLOSED;
                    else
                        s_fsm <= WANT_1s_OPEN; --! Stay in WANT_1s_OPEN until delay timer expires
                    end if;
                end if;

            when FULLY_CLOSED =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_timer = unsigned(s_timer_limit)) then
                        s_fsm <= WAIT_1s_CLOSED;
                    else
                        s_fsm <= FULLY_CLOSED; --! Stay in FULLY_CLOSED until timer expires
                    end if;
                end if;

            when WAIT_1s_CLOSED =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_dly_timer = to_unsigned(g_dly_timer+g_dly_timer, r_dly_timer'length)) then
                        s_fsm <= WAIT_CMD;
                    else
                        s_fsm <= WAIT_1s_CLOSED; --! Stay in WAIT_1s_CLOSED until delay timer expires
                    end if;
                end if;

            when WAIT_CMD =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_up = '1') then
                        s_fsm <= UP_WAIT;
                    elsif (s_down = '1') then
                        s_fsm <= DOWN_WAIT;
                    else
                        s_fsm <= WAIT_CMD; --! Stay in WAIT_CMD until a command is received
                    end if;
                end if;

            when UP_WAIT =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_dly_timer = to_unsigned(g_dly_timer, r_dly_timer'length)) then
                        if (s_up = '1') then
                            s_fsm <= UP_USER_OPEN;
                        else
                            s_fsm <= UP_FULLY_OPEN;
                        end if;
                    else
                        s_fsm <= UP_WAIT; --! Stay in UP_WAIT until timer expires
                    end if;
                end if;

            when UP_FULLY_OPEN =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_timer = to_unsigned(0, r_timer'length)) then
                        s_fsm <= WAIT_1s_CLOSED;
                    else
                        if (s_up = '1' or s_down = '1') then
                            s_fsm <= UP_FULLY_OPEN_NOT;
                        else
                            s_fsm <= UP_FULLY_OPEN; --! Stay in UP_FULLY_OPEN until timer expires
                        end if;
                    end if;
                end if;

            when UP_FULLY_OPEN_NOT =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_up = '0' and s_down = '0') then
                        s_fsm <= WAIT_1s_CLOSED;
                    else
                        s_fsm <= UP_FULLY_OPEN_NOT; --! Stay in UP_FULLY_OPEN until user command is received
                    end if;
                end if; 

            when UP_USER_OPEN =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_up = '1') then
                        if (r_timer = to_unsigned(0, r_timer'length)) then
                            s_fsm <= UP_USER_STALL;
                        else
                            s_fsm <= UP_USER_OPEN; --! Stay in UP_USER_OPEN until timer expires
                        end if;
                    else
                        s_fsm <= WAIT_1s_CLOSED; --! If user releases the command, go back to UP_WAIT
                    end if; 
                end if;

            when UP_USER_STALL => 
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_up = '0') then
                        s_fsm <= WAIT_1s_CLOSED; 
                    else
                        s_fsm <= UP_USER_STALL; --! Stay in UP_USER_STALL until user releases the command
                    end if;
                end if;

            when DOWN_WAIT =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_dly_timer = to_unsigned(g_dly_timer, r_dly_timer'length)) then
                        if (s_down = '1') then
                            s_fsm <= DOWN_USER_CLOSED;
                        else
                            s_fsm <= DOWN_FULLY_CLOSED;
                        end if;
                    else
                        s_fsm <= DOWN_WAIT; --! Stay in DOWN_WAIT until timer expires
                    end if; 
                end if;

            when DOWN_FULLY_CLOSED =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (r_timer = unsigned(s_timer_limit)) then
                        s_fsm <= WAIT_1s_CLOSED;
                    else
                        if (s_up = '1' or s_down = '1') then
                            s_fsm <= UP_FULLY_CLOSED_NOT;
                        else
                            s_fsm <= DOWN_FULLY_CLOSED; --! Stay in DOWN_FULLY_CLOSED until timer expires
                        end if;
                    end if;
                end if;

            when UP_FULLY_CLOSED_NOT =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_up = '0' and s_down = '0') then
                        s_fsm <= WAIT_1s_CLOSED;
                    else
                        s_fsm <= UP_FULLY_CLOSED_NOT; --! Stay in UP_FULLY_CLOSED_NOT until user command is received
                    end if;
                end if; 

            when DOWN_USER_CLOSED =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_down = '1') then
                        if (r_timer = unsigned(s_timer_limit)) then
                            s_fsm <= DOWN_USER_STALL;
                        else
                            s_fsm <= DOWN_USER_CLOSED; --! Stay in DOWN_USER_CLOSED until timer expires
                        end if;
                    else
                        s_fsm <= WAIT_1s_CLOSED; --! If user releases the command, go back to WAIT_1s_CLOSED
                    end if; 
                end if;

            when DOWN_USER_STALL =>
                if (s_init_en = '0') then
                    s_fsm <= WAIT_INIT; --! If initialization is disabled, go back to WAIT_INIT
                else
                    if (s_down = '0') then
                        s_fsm <= WAIT_1s_CLOSED; 
                    else
                        s_fsm <= DOWN_USER_STALL; --! Stay in DOWN_USER_STALL until user releases the command
                    end if;
                end if;

            when others =>
                s_fsm <= IDLE; --! Default case to handle unexpected states

        end case;
    end process p_fsm;
    
    p_fsm_mux : process(r_fsm, i_beat, r_timer, r_dly_timer)
    begin
        s_timer <= r_timer; --! Default assignment to hold the timer value
        s_dly_timer <= (others => '0'); --! Default assignment to hold the delay
        s_relay_up <= '0'; --! Default assignment to hold the relay state
        s_relay_down <= '0'; --! Default assignment to hold the relay state

        case r_fsm is
            when IDLE =>

            when WAIT_INIT =>
                s_timer <= to_unsigned(g_timer, s_timer'length); --! Set timer for initialization (e.g., 300 cycles)

            when FULLY_OPEN =>
                if (i_beat = '1') then
                    s_timer <= r_timer - 1; --! Decrement timer in FULLY_OPEN state
                else
                    s_timer <= r_timer; --! Hold timer value when beat is not active
                end if;

            when WANT_1s_OPEN =>
                if (i_beat = '1') then
                    s_dly_timer <= r_dly_timer + 1; --! Increment delay timer in WANT_1s_OPEN state
                else
                    s_dly_timer <= r_dly_timer; --! Hold delay timer value when beat is not active
                end if;

            when FULLY_CLOSED =>
                if (i_beat = '1') then
                    s_timer <= r_timer + 1; --! Increment timer in FULLY_CLOSED state
                else
                    s_timer <= r_timer; --! Hold timer value when beat is not active
                end if;

            when WAIT_1s_CLOSED =>
                if (i_beat = '1') then
                    s_dly_timer <= r_dly_timer + 1; --! Increment delay timer in WAIT_1s_CLOSED state
                else
                    s_dly_timer <= r_dly_timer; --! Hold delay timer value when beat is not active
                end if;

            when WAIT_CMD =>

            when UP_WAIT =>
                if (i_beat = '1') then
                    s_dly_timer <= r_dly_timer + 1; --! Increment delay timer in UP_WAIT state
                else
                    s_dly_timer <= r_dly_timer; --! Hold delay timer value when beat is not active
                end if;
                s_relay_up <= '1'; --! Activate relay to open the blinds

            when UP_FULLY_OPEN =>
                if (i_beat = '1') then
                    s_timer <= r_timer - 1; --! Decrement timer in FULLY_OPEN state
                else
                    s_timer <= r_timer; --! Hold timer value when beat is not active
                end if;
                s_relay_up <= '1'; --! Activate relay to open the blinds

            when UP_FULLY_OPEN_NOT =>

            when UP_USER_OPEN =>
                if (i_beat = '1') then
                    s_timer <= r_timer - 1; --! Decrement timer in FULLY_OPEN state
                else
                    s_timer <= r_timer; --! Hold timer value when beat is not active
                end if;
                s_relay_up <= '1'; --! Activate relay to open the blinds

            when UP_USER_STALL =>

            when DOWN_WAIT =>
                if (i_beat = '1') then
                    s_dly_timer <= r_dly_timer + 1; --! Increment delay timer in DOWN_WAIT state
                else
                    s_dly_timer <= r_dly_timer; --! Hold delay timer value when beat is not active
                end if;
                s_relay_down <= '1'; --! Activate relay to close the blinds

            when DOWN_FULLY_CLOSED =>
                if (i_beat = '1') then
                    s_timer <= r_timer + 1; --! Increment timer in FULLY_CLOSED state
                else
                    s_timer <= r_timer; --! Hold timer value when beat is not active
                end if;
                s_relay_down <= '1'; --! Activate relay to close the blinds

            when UP_FULLY_CLOSED_NOT =>

            when DOWN_USER_CLOSED =>
                if (i_beat = '1') then
                    s_timer <= r_timer + 1; --! Increment timer in FULLY_CLOSED state
                else
                    s_timer <= r_timer; --! Hold timer value when beat is not active
                end if;
                s_relay_down <= '1'; --! Activate relay to close the blinds

            when DOWN_USER_STALL =>

            when others =>

            end case;
    end process p_fsm_mux;

    p_fsm_data_sync : process(i_clk, i_rst)
    begin
        if i_rst = '1' then
            r_timer <= (others => '0');
            r_dly_timer <= (others => '0');
            r_relay_up <= '0';
            r_relay_down <= '0';
        elsif rising_edge(i_clk) then
            r_timer <= s_timer;
            r_dly_timer <= s_dly_timer;
            r_relay_up <= s_relay_up;
            r_relay_down <= s_relay_down;
        end if;
    end process p_fsm_data_sync;

    o_relay_up <= r_relay_up;
    o_relay_down <= r_relay_down;
end architecture;