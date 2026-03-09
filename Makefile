
TOP := pe_tb

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

.PHONY: lint sim gls icestorm_icebreaker_gls icestorm_icebreaker_program icestorm_icebreaker_flash clean

lint:
	verilator lint/verilator.vlt -f rtl/rtl.f -f dv/dv.f --lint-only --top pe

sim:
	verilator lint/verilator.vlt --Mdir ${TOP}_$@_dir -f rtl/rtl.f -f dv/pre_synth.f -f dv/dv.f --binary -Wno-fatal --top ${TOP}
	./${TOP}_$@_dir/V${TOP} +verilator+rand+reset+2

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
	 *sim_dir *gls_dir \
	 dump.vcd dump.fst \
	 synth/build \
	 synth/yosys_generic/build \
	 synth/icestorm_icebreaker/build \
	 synth/vivado_basys3/build
