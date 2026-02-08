
# Entity: reg 
- **File**: reg.vhd

## Diagram
![Diagram](reg.svg "Diagram")
## Ports

| Port name  | Direction | Type                          | Description                  |
| ---------- | --------- | ----------------------------- | ---------------------------- |
| i_clk      | in        | std_logic                     | Clock signal                 |
| i_rst      | in        | std_logic                     | Reset signal, active high    |
| i_addr     | in        | std_logic_vector(7 downto 0)  | Input address bus            |
| i_we       | in        | std_logic                     | Input write enable signal    |
| i_wdata    | in        | std_logic_vector(7 downto 0)  | Input write data bus         |
| o_rdata    | out       | std_logic_vector(7 downto 0)  | Output read data bus         |
| o_init_dim | out       | std_logic_vector(15 downto 0) | Output initial dimming value |
| o_en_pwm   | out       | std_logic_vector(63 downto 0) | Output PWM enable signals    |
| o_inc_pwm  | out       | std_logic_vector(63 downto 0) | Output PWM increment signals |
| o_dec_pwm  | out       | std_logic_vector(63 downto 0) | Output PWM decrement signals |

## Signals

| Name       | Type                          | Description                        |
| ---------- | ----------------------------- | ---------------------------------- |
| r_init_dim | std_logic_vector(15 downto 0) | Register for initial dimming value |
| r_en_pwm   | std_logic_vector(63 downto 0) | Register for PWM enable signals    |
| r_inc_pwm  | std_logic_vector(63 downto 0) | Register for PWM enable signals    |
| r_dec_pwm  | std_logic_vector(63 downto 0) |                                    |

## Processes
- p_init_dim: ( i_clk, i_rst )
