create_clock -name core_clock -period 8 [get_ports clk_i]
set_input_delay -clock core_clock 2.0 [all_inputs]
set_output_delay -clock core_clock 2.0 [all_outputs]
set_input_delay -clock core_clock 0 [get_ports clk_i]

set_load 0.1 [all_outputs]
set_driving_cell -lib_cell sky130_fd_sc_hd__buf_2 [all_inputs]
