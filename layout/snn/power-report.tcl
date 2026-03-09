# Power Report Script for SNN-only PE Design
# Processes dump_snn.vcd

# Set PDK path for convenience
set pdk_base $::env(HOME)/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A

# Read technology LEF files (required for OpenROAD)
read_lef ${pdk_base}/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef ${pdk_base}/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# Read liberty file from SKY130 PDK
read_liberty ${pdk_base}/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Read the gate-level netlist
read_verilog runs/RUN_2026-03-09_00-03-46/final/pnl/pe_snn.pnl.v

# Link the design
link_design pe_snn

# Read SDC constraints
read_sdc config.sdc

# Generate power report for SNN-only PE
# Average power over entire simulation: 0 to 8260000 (8.26ms)
read_vcd ../../dump_snn.vcd -scope tb_pe_snn_random/dut/pe_snn_inst
report_power > report_power_snn.txt
puts "Generated report_power_snn.txt"
