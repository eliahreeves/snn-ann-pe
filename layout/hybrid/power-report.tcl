# Set PDK path for convenience
set pdk_base $::env(HOME)/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A

# Read technology LEF files (required for OpenROAD)
read_lef ${pdk_base}/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef ${pdk_base}/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef

# Read liberty file from SKY130 PDK
read_liberty ${pdk_base}/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# Read the gate-level netlist
read_verilog runs/RUN_2026-03-09_00-50-40/final/pnl/pe.pnl.v

# Link the design
link_design pe

# Read SDC constraints
read_sdc config.sdc

# Generate power report for hybrid ANN mode
# Average power over entire simulation: 0 to 8036000 (8.036ms)
read_vcd ../../dump_hybrid_ann.vcd -scope tb_pe_ann_random/dut
report_power > report_power_hybrid_ann.txt
puts "Generated report_power_hybrid_ann.txt"

# Reset power activities and generate report for hybrid SNN mode
# Average power over entire simulation: 0 to 8260000 (8.26ms)
read_vcd ../../dump_hybrid_snn.vcd -scope tb_pe_snn_random/dut
report_power > report_power_hybrid_snn.txt
puts "Generated report_power_hybrid_snn.txt"
