#------------------------------------------#
# project_macro — Signoff SDC
# Target: project_macro inside openframe_multiproject
#
# Clock: clk from green macro (left edge, clock buffer output)
# I/O:   GPIO signals through orange macro muxes
#
# Retrieved constraint values are taken from the OpenFrame base SDC:
#   gpio_in  max=4.55  min=1.26  (pad → orange mux → project_macro input)
#   gpio_out max=9.12  min=3.90
#   gpio_oeb max=9.32  min=2.34
#   input transition max=0.38 min=0.05
#   output load 0.19 pF
#
# These values represent the measured/extracted delays of the complete
# physical path through the OpenFrame padframe and orange mux macros.
# They are NOT arbitrary — they come from extraction of the actual
# padframe and orange macro routing in the base SDC of the repo.
#------------------------------------------#

# ----------------------------------------------------------------
# Clock
# ----------------------------------------------------------------
set clk_port clk
create_clock [get_ports $clk_port] -name clk -period 25
puts "\[INFO\]: Creating clock {clk} for port $clk_port with period: 25"

set_propagated_clock [get_clocks {clk}]
set_clock_uncertainty 0.10 [get_clocks {clk}]
puts "\[INFO\]: Setting clock uncertainty to: 0.10"

# Maximum transition — library characterisation boundary (signoff)
set_max_transition 1.5 [current_design]
puts "\[INFO\]: Setting maximum transition to: 1.5"

# Maximum fanout
set_max_fanout 16 [current_design]
puts "\[INFO\]: Setting maximum fanout to: 16"

# Timing derate — 5% pessimism for signoff
set_timing_derate -early [expr {1 - 0.05}]
set_timing_derate -late  [expr {1 + 0.05}]
puts "\[INFO\]: Setting timing derate to: 5 %"

# Clock source latency
# Path: GPIO pad → green macro clock buffer → project_macro clk pin
# Estimated from green macro cell characterisation: ~3.1 ns min, ~4.35 ns max
set_clock_latency -source -max 4.35 [get_clocks {clk}]
set_clock_latency -source -min 3.10 [get_clocks {clk}]
puts "\[INFO\]: Setting clock latency max=4.35 min=3.10"

set_input_transition 0.80 [get_ports $clk_port]

# ----------------------------------------------------------------
# Reset and POR — half-cycle constraint (synchronous assertion)
# ----------------------------------------------------------------
set_input_delay [expr {25 * 0.5}] -clock [get_clocks {clk}] [get_ports {reset_n}]
set_input_delay [expr {25 * 0.5}] -clock [get_clocks {clk}] [get_ports {por_n}]

# ----------------------------------------------------------------
# GPIO Input delays
# Retrieved values: max=4.55 ns, min=1.26 ns
#
# Physical interpretation:
#   The input path is: GPIO pad → orange macro mux → project_macro pin
#   4.55 ns max = pad input buffer delay + orange mux worst-case path
#   1.26 ns min = same path under best-case (FF corner, low temp, high V)
#   These values were extracted from the actual orange macro and padframe
#   routing in the OpenFrame multiproject physical implementation.
# ----------------------------------------------------------------
set in_ext_delay 0

# Bottom GPIOs (15 signals → right pads via bottom orange macro)
set_input_delay -max [expr {$in_ext_delay + 4.55}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_in[*]}]
set_input_delay -min [expr {$in_ext_delay + 1.26}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_in[*]}]

# Right GPIOs (9 signals → top pads via right orange macro)
set_input_delay -max [expr {$in_ext_delay + 4.55}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_in[*]}]
set_input_delay -min [expr {$in_ext_delay + 1.26}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_in[*]}]

# Top GPIOs (14 signals → left pads via top orange macro)
set_input_delay -max [expr {$in_ext_delay + 4.55}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_in[*]}]
set_input_delay -min [expr {$in_ext_delay + 1.26}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_in[*]}]

# ----------------------------------------------------------------
# Input transitions
# Retrieved values: max=0.38 ns, min=0.05 ns
# Physical interpretation:
#   The orange macro output drive is characterised for sky130 GPIO pads.
#   0.38 ns is the worst-case slew of the orange mux output driving into
#   the project_macro input. 0.05 ns is the best-case (FF corner).
# ----------------------------------------------------------------
set_input_transition -max 0.38 [get_ports {gpio_bot_in[*]}]
set_input_transition -min 0.05 [get_ports {gpio_bot_in[*]}]
set_input_transition -max 0.38 [get_ports {gpio_rt_in[*]}]
set_input_transition -min 0.05 [get_ports {gpio_rt_in[*]}]
set_input_transition -max 0.38 [get_ports {gpio_top_in[*]}]
set_input_transition -min 0.05 [get_ports {gpio_top_in[*]}]

# ----------------------------------------------------------------
# GPIO Output delays
# Retrieved values:
#   gpio_out max=9.12, min=3.90
#   gpio_oeb max=9.32, min=2.34
#
# Physical interpretation:
#   The output path is: project_macro pin → orange macro mux → GPIO pad output buffer
#   9.12/9.32 ns max = total downstream combinational path through the orange
#   mux and pad output buffer at worst case (SS corner).
#   The oeb path (9.32 ns) is slightly tighter than the data path because
#   oeb gates the output driver — if it arrives late, the data appears
#   glitched at the pad. A slightly larger required time prevents this.
# ----------------------------------------------------------------
set out_ext_delay 0

# Bottom GPIOs — data and enable outputs
set_output_delay -max [expr {$out_ext_delay + 9.12}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_out[*]}]
set_output_delay -min [expr {$out_ext_delay + 3.90}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_out[*]}]
set_output_delay -max [expr {$out_ext_delay + 9.32}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_oeb[*]}]
set_output_delay -min [expr {$out_ext_delay + 2.34}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_oeb[*]}]
set_output_delay -max [expr {$out_ext_delay + 9.12}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_dm[*]}]
set_output_delay -min [expr {$out_ext_delay + 2.34}] \
    -clock [get_clocks {clk}] [get_ports {gpio_bot_dm[*]}]

# Right GPIOs
set_output_delay -max [expr {$out_ext_delay + 9.12}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_out[*]}]
set_output_delay -min [expr {$out_ext_delay + 3.90}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_out[*]}]
set_output_delay -max [expr {$out_ext_delay + 9.32}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_oeb[*]}]
set_output_delay -min [expr {$out_ext_delay + 2.34}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_oeb[*]}]
set_output_delay -max [expr {$out_ext_delay + 9.12}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_dm[*]}]
set_output_delay -min [expr {$out_ext_delay + 2.34}] \
    -clock [get_clocks {clk}] [get_ports {gpio_rt_dm[*]}]

# Top GPIOs
set_output_delay -max [expr {$out_ext_delay + 9.12}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_out[*]}]
set_output_delay -min [expr {$out_ext_delay + 3.90}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_out[*]}]
set_output_delay -max [expr {$out_ext_delay + 9.32}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_oeb[*]}]
set_output_delay -min [expr {$out_ext_delay + 2.34}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_oeb[*]}]
set_output_delay -max [expr {$out_ext_delay + 9.12}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_dm[*]}]
set_output_delay -min [expr {$out_ext_delay + 2.34}] \
    -clock [get_clocks {clk}] [get_ports {gpio_top_dm[*]}]

# ----------------------------------------------------------------
# Output loads
# Retrieved value: 0.19 pF
# This models the input capacitance of the orange macro mux that
# captures the project_macro output signals.
# ----------------------------------------------------------------
set_load 0.19 [all_outputs]
