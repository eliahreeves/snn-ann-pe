dv/dv_pkg.sv
dv/tb_pe_ann_random.sv
dv/tb_pe_snn_random.sv

dv/pe_tb.sv

dv/dpi/example_dpi.c

--timing
-j 0
-Wall
--assert
--trace
--trace-structs
--main-top-name "-"

// Run with +verilator+rand+reset+2
--x-assign unique
--x-initial unique

-Werror-IMPLICIT
-Werror-USERERROR
-Werror-LATCH

// Required for some compilers
-CFLAGS -std=c++20
