transcript on

# Questa/ModelSim do-file to compile and run UART testbench
# Run from Questa GUI console: do questa_uart_tb.do
# Or from command line: vsim -do rtl/uart/questa_uart_tb.do

# Make paths robust to where the do-file is invoked from
set script_dir [file dirname [info script]]
cd $script_dir

# Clean + create work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile DUT + TB
# Use -2008 for modern syntax support; TB itself avoids std.env/to_hstring
vcom -2008 -work work uart.vhd
vcom -2008 -work work uart_tb.vhd

# Launch simulation
vsim -voptargs=+acc work.uart_tb

# Waves (adjust as you like)
quietly WaveActivateNextPane {} 0
add wave -divider {Clocks/Reset}
add wave sim:/uart_tb/clk
add wave sim:/uart_tb/rst

add wave -divider {UART Lines}
add wave sim:/uart_tb/rx
add wave sim:/uart_tb/tx

add wave -divider {DUT Interface}
add wave -hex sim:/uart_tb/rx_data
add wave sim:/uart_tb/rx_vld
add wave -hex sim:/uart_tb/tx_data
add wave sim:/uart_tb/tx_start
add wave sim:/uart_tb/tx_busy

add wave -divider {Monitors}
add wave -hex sim:/uart_tb/tx_mon_data
add wave sim:/uart_tb/tx_mon_vld
add wave -hex sim:/uart_tb/rx_line_mon_data
add wave sim:/uart_tb/rx_line_mon_vld

# Run until TB finishes (it ends with a wait; so stop on "UART TB PASSED" in transcript)
run 10000ns

# If you prefer auto-exit, uncomment the next line and replace the TB's final 'wait;' with an 'assert false severity failure;'
# quit -f
