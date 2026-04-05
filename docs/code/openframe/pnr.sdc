#------------------------------------------#
# project_macro — PnR SDC
# Target: project_macro inside openframe_multiproject
#
# Clock: clk from green macro (left edge, clock buffer output)
# I/O:   GPIO signals through orange macro muxes
#
# Strategy: over-constrain during implementation so that the engine
# works aggressively to fix slew/cap violations before routing is
# finalised. The signoff.sdc relaxes back to realistic values.
#
# Key differences vs signoff.sdc:
#   max_transition : 0.75 ns  (vs 1.5 ns at signoff)
#   timing_derate  : ±7%      (vs ±5% at signoff)
#   clock_uncertainty: 0.15 ns (vs 0.10 ns at signoff)
#   clock_latency  : max=4.50, min=3.00 (slightly wider bounds)
#------------------------------------------#

# ----------------------------------------------------------------
# Clock
# ----------------------------------------------------------------
set clk_port clk
create_clock [get_ports $clk_port] -name clk -period 25
puts "\[INFO\]: Creating clock {clk} for port $clk_port with period: 25"

set_propagated_clock [get_clocks {clk}]

# Slightly more pessimistic uncertainty during PnR — accounts for
# CTS skew that has not yet been resolved at this stage
set_clock_uncertainty 0.15 [get_clocks {clk}]
puts "\[INFO\]: Setting clock uncertainty to: 0.15"

# Strict transition limit — forces the engine to aggressively insert
# buffers and resize cells to resolve slew violations during routing,
# so that signoff under the relaxed 1.5 ns limit is clean
set_max_transition 0.75 [current_design]
puts "\[INFO\]: Setting maximum transition to: 0.75"

# Maximum fanout
set_max_fanout 16 [current_design]
puts "\[INFO\]: Setting maximum fanout to: 16"

# Timing derate — 7% pessimism during PnR (vs 5% at signoff)
# Wider derate accounts for routing uncertainty before wires are final
set_timing_derate -early [expr {1 - 0.07}]
set_timing_derate -late  [expr {1 + 0.07}]
puts "\[INFO\]: Setting timing derate to: 7 %"

# ----------------------------------------------------------------
# Clock source latency
# Path: GPIO pad → green macro clock buffer → project_macro clk pin
# Slightly wider bounds than signoff to guard against pre-CTS
# optimisation seeing an overly optimistic clock path
# ----------------------------------------------------------------
set_clock_latency -source -max 4.50 [get_clocks {clk}]
set_clock_latency -source -min 3.00 [get_clocks {clk}]
puts "\[INFO\]: Setting clock latency max=4.50 min=3.00"

set_input_transition 0.80 [get_ports $clk_port]

# ----------------------------------------------------------------
# Reset and POR — half-cycle constraint
# ----------------------------------------------------------------
set_input_delay [expr {25 * 0.5}] -clock [get_clocks {clk}] [get_ports {reset_n}]
set_input_delay [expr {25 * 0.5}] -clock [get_clocks {clk}] [get_ports {por_n}]

# ----------------------------------------------------------------
# GPIO Input delays
# Same retrieved values as signoff — these are physical path delays
# through the orange macro and padframe; they do not change between
# PnR and signoff stages.
#   max=4.55 ns : pad input buffer + orange mux worst-case (SS corner)
#   min=1.26 ns : same path best-case (FF corner)
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
# Retrieved values — physical characterisation of orange macro output
#   max=0.38 ns : worst-case slew driving into project_macro input
#   min=0.05 ns : best-case (FF corner)
# ----------------------------------------------------------------
set_input_transition -max 0.38 [get_ports {gpio_bot_in[*]}]
set_input_transition -min 0.05 [get_ports {gpio_bot_in[*]}]
set_input_transition -max 0.38 [get_ports {gpio_rt_in[*]}]
set_input_transition -min 0.05 [get_ports {gpio_rt_in[*]}]
set_input_transition -max 0.38 [get_ports {gpio_top_in[*]}]
set_input_transition -min 0.05 [get_ports {gpio_top_in[*]}]

# ----------------------------------------------------------------
# GPIO Output delays
# Same retrieved values as signoff — physical path delays through the
# orange mux and pad output buffer. Constant across PnR and signoff.
#   gpio_out max=9.12, min=3.90
#   gpio_oeb max=9.32, min=2.34  (oeb tighter: gates the output driver)
#   gpio_dm  treated same as gpio_oeb
# ----------------------------------------------------------------
set out_ext_delay 0

# Bottom GPIOs
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
# Output loads — input capacitance of the orange macro mux
# ----------------------------------------------------------------
set_load 0.19 [all_outputs]
