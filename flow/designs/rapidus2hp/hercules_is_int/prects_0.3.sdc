source $::env(PLATFORM_DIR)/util.tcl

#set sdc_version 2.1
set sdc_version 1.4
current_design hercules_is_int

set clk_period 370

convert_time_value clk_period

set_max_fanout 32 [current_design]
set_load [convert_cap_value 10] [all_outputs]
set_max_capacitance [convert_cap_value 10] [all_inputs]

create_clock -name "clk" -add -period $clk_period \
  -waveform [list 0.0 [expr { 0.5 * $clk_period }]] [get_ports clk]

set_clock_latency $clk_period clk

### Setup input delay is set to 20% of CT
set_input_delay 0.150 -clock clk [all_inputs]
set_output_delay 0.050 -clock clk [all_outputs]
