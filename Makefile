
TOP := tb_pe_ann_random

export BASEJUMP_STL_DIR := $(abspath third_party/basejump_stl)
export YOSYS_DATDIR := $(shell yosys-config --datdir)
export SKY130_LIB:="$(HOME)/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib"

RTL := $(shell \
 BASEJUMP_STL_DIR=$(BASEJUMP_STL_DIR) \
 python3 misc/convert_filelist.py Makefile rtl/rtl.f \
)

SV2V_ARGS := $(shell \
 BASEJUMP_STL_DIR=$(BASEJUMP_STL_DIR) \
 python3 misc/convert_filelist.py sv2v rtl/rtl.f \
)

.PHONY: lint sim gls gls-hybrid-ann gls-hybrid-snn gls-ann gls-snn gls-all icestorm_icebreaker_gls icestorm_icebreaker_program icestorm_icebreaker_flash clean

lint:
	verilator lint/verilator.vlt -f rtl/rtl.f -f dv/dv.f --lint-only --top array

sim:
	verilator lint/verilator.vlt --Mdir ${TOP}_$@_dir -f rtl/rtl.f -f dv/dv.f --binary -Wno-fatal --top ${TOP}
	./${TOP}_$@_dir/V${TOP} +verilator+rand+reset+2

# Sky130 PDK paths (used by all GLS targets)
SKY130_PDK_PATH := $(HOME)/.ciel/ciel/sky130/versions/0fe599b2afb6708d281543108caf8310912f54af/sky130A
SKY130_CELLS := $(SKY130_PDK_PATH)/libs.ref/sky130_fd_sc_hd/verilog/sky130_fd_sc_hd.v
SKY130_PRIMS := $(SKY130_PDK_PATH)/libs.ref/sky130_fd_sc_hd/verilog/primitives.v

# Generic GLS target (uses TOP variable from line 2)
gls:
	$(eval LATEST_RUN := $(shell ls -dt ./layout/hybrid/runs/RUN_* 2>/dev/null | head -1))
	@echo "Using OpenLane run: $(LATEST_RUN)"
	@echo "Using testbench: $(TOP)"
	verilator lint/verilator.vlt \
		--Mdir ${TOP}_gls_dir \
		-I${BASEJUMP_STL_DIR}/bsg_misc \
		${BASEJUMP_STL_DIR}/bsg_misc/bsg_counter_up_down.sv \
		rtl/config_pkg.sv \
		-f dv/dv_gls.f \
		--binary \
		-Wno-fatal \
		--timing \
		$(LATEST_RUN)/final/nl/pe.nl.v \
		$(SKY130_CELLS) \
		$(SKY130_PRIMS) \
		-DGATE_LEVEL_SIM \
		--top ${TOP}
	./${TOP}_gls_dir/V${TOP} +verilator+rand+reset+2

# GLS target: Hybrid PE with ANN testbench
gls-hybrid-ann:
	$(eval LATEST_RUN := $(shell ls -dt ./layout/hybrid/runs/RUN_* 2>/dev/null | head -1))
	@echo "=== Building GLS: Hybrid PE with ANN testbench ==="
	@echo "Using OpenLane run: $(LATEST_RUN)"
	verilator lint/verilator.vlt \
		--Mdir gls_hybrid_ann_dir \
		-I${BASEJUMP_STL_DIR}/bsg_misc \
		${BASEJUMP_STL_DIR}/bsg_misc/bsg_counter_up_down.sv \
		rtl/config_pkg.sv \
		-f dv/dv_gls.f \
		--binary \
		-Wno-fatal \
		--timing \
		$(LATEST_RUN)/final/nl/pe.nl.v \
		$(SKY130_CELLS) \
		$(SKY130_PRIMS) \
		-DGATE_LEVEL_SIM \
		-DDUMP_FILE=\"dump_hybrid_ann.vcd\" \
		--top tb_pe_ann_random
	@echo "=== Running simulation ==="
	./gls_hybrid_ann_dir/Vtb_pe_ann_random +verilator+rand+reset+2
	@echo "=== Output: dump_hybrid_ann.vcd ==="

# GLS target: Hybrid PE with SNN testbench
gls-hybrid-snn:
	$(eval LATEST_RUN := $(shell ls -dt ./layout/hybrid/runs/RUN_* 2>/dev/null | head -1))
	@echo "=== Building GLS: Hybrid PE with SNN testbench ==="
	@echo "Using OpenLane run: $(LATEST_RUN)"
	verilator lint/verilator.vlt \
		--Mdir gls_hybrid_snn_dir \
		-I${BASEJUMP_STL_DIR}/bsg_misc \
		${BASEJUMP_STL_DIR}/bsg_misc/bsg_counter_up_down.sv \
		rtl/config_pkg.sv \
		-f dv/dv_gls.f \
		--binary \
		-Wno-fatal \
		--timing \
		$(LATEST_RUN)/final/nl/pe.nl.v \
		$(SKY130_CELLS) \
		$(SKY130_PRIMS) \
		-DGATE_LEVEL_SIM \
		-DDUMP_FILE=\"dump_hybrid_snn.vcd\" \
		--top tb_pe_snn_random
	@echo "=== Running simulation ==="
	./gls_hybrid_snn_dir/Vtb_pe_snn_random +verilator+rand+reset+2
	@echo "=== Output: dump_hybrid_snn.vcd ==="

# GLS target: ANN-only PE
gls-ann:
	$(eval LATEST_RUN := $(shell ls -dt ./layout/ann/runs/RUN_* 2>/dev/null | head -1))
	@echo "=== Building GLS: ANN-only PE ==="
	@echo "Using OpenLane run: $(LATEST_RUN)"
	verilator lint/verilator.vlt \
		--Mdir gls_ann_dir \
		-I${BASEJUMP_STL_DIR}/bsg_misc \
		${BASEJUMP_STL_DIR}/bsg_misc/bsg_counter_up_down.sv \
		rtl/config_pkg.sv \
		-f dv/dv_gls.f \
		dv/pe_ann_wrapper.v \
		--binary \
		-Wno-fatal \
		--timing \
		$(LATEST_RUN)/final/nl/pe_ann.nl.v \
		$(SKY130_CELLS) \
		$(SKY130_PRIMS) \
		-DGATE_LEVEL_SIM \
		-DDUMP_FILE=\"dump_ann.vcd\" \
		--top tb_pe_ann_random
	@echo "=== Running simulation ==="
	./gls_ann_dir/Vtb_pe_ann_random +verilator+rand+reset+2
	@echo "=== Output: dump_ann.vcd ==="

# GLS target: SNN-only PE
gls-snn:
	$(eval LATEST_RUN := $(shell ls -dt ./layout/snn/runs/RUN_* 2>/dev/null | head -1))
	@echo "=== Building GLS: SNN-only PE ==="
	@echo "Using OpenLane run: $(LATEST_RUN)"
	verilator lint/verilator.vlt \
		--Mdir gls_snn_dir \
		-I${BASEJUMP_STL_DIR}/bsg_misc \
		${BASEJUMP_STL_DIR}/bsg_misc/bsg_counter_up_down.sv \
		rtl/config_pkg.sv \
		-f dv/dv_gls.f \
		dv/pe_snn_wrapper.v \
		--binary \
		-Wno-fatal \
		--timing \
		$(LATEST_RUN)/final/nl/pe_snn.nl.v \
		$(SKY130_CELLS) \
		$(SKY130_PRIMS) \
		-DGATE_LEVEL_SIM \
		-DDUMP_FILE=\"dump_snn.vcd\" \
		--top tb_pe_snn_random
	@echo "=== Running simulation ==="
	./gls_snn_dir/Vtb_pe_snn_random +verilator+rand+reset+2
	@echo "=== Output: dump_snn.vcd ==="

# Master target: Run all GLS simulations
gls-all: gls-hybrid-ann gls-hybrid-snn gls-ann gls-snn
	@echo ""
	@echo "=== All GLS simulations complete ==="
	@echo "Generated dump files:"
	@ls -lh dump_hybrid_ann.vcd dump_hybrid_snn.vcd dump_ann.vcd dump_snn.vcd 2>/dev/null || echo "Some dump files missing"

sky130_synth: synth/build/rtl.sv2v.v synth/synth_pe.ys .env
	@set -a && . ./.env && set +a && \
	 sed "s|\$$::env(SKY130_LIB)|$${SKY130_LIB}|g" synth/synth_pe.ys > synth/build/synth_pe_expanded.ys && \
	 sed "s|\$$::env(SKY130_LIB)|$${SKY130_LIB}|g" synth/synth_pe_ann.ys > synth/build/synth_pe_ann_expanded.ys && \
	 sed "s|\$$::env(SKY130_LIB)|$${SKY130_LIB}|g" synth/synth_pe_snn.ys > synth/build/synth_pe_snn_expanded.ys && \
	 yosys -s synth/build/synth_pe_expanded.ys
	 yosys -s synth/build/synth_pe_ann_expanded.ys
	 yosys -s synth/build/synth_pe_snn_expanded.ys

synth/build/rtl.sv2v.v: ${RTL} rtl/rtl.f
	mkdir -p $(dir $@)
	sv2v ${SV2V_ARGS} -w $@ -DSYNTHESIS

clean:
	rm -rf \
	 *.memh *.memb \
	 *sim_dir *gls_dir gls_*_dir \
	 dump.vcd dump.fst dump_*.fst dump_*.vcd \
	 synth/build \
	 synth/yosys_generic/build \
	 synth/icestorm_icebreaker/build \
	 synth/vivado_basys3/build
