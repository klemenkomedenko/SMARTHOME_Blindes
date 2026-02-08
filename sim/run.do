

# Questa/ModelSim do-file to compile and run UART testbench
# Run from Questa GUI console: do questa_uart_tb.do
# Or from command line: vsim -do rtl/uart/questa_uart_tb.do

# Make paths robust to where the do-file is invoked from
#set script_dir [file dirname [info script]]
#cd $script_dir

# Clean + create work library
if {[file exists work]} {
    vdel -lib work -all
}
vlib work
vmap work work

# Compile DUT + TB
# Use -2008 for modern syntax support; TB itself avoids std.env/to_hstring
vcom -2008 -work work ../rtl/uart/uart.vhd
vcom -2008 -work work ../rtl/pwm/pwm.vhd
vcom -2008 -work work ../rtl/pwm/beat.vhd
vcom -2008 -work work ../rtl/registers/reg.vhd
vcom -2008 -work work ../rtl/arbiter/arbiter.vhd
vcom -2008 -work work ../rtl/top.vhd
vlog top_tb.v


# Launch simulation
vsim -voptargs=+acc work.top_tb

log -r *

# Run until TB finishes (it ends with a wait; so stop on "UART TB PASSED" in transcript)
run -all

# If you prefer auto-exit, uncomment the next line and replace the TB's final 'wait;' with an 'assert false severity failure;'
# quit -f
