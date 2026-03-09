`timescale 1ns/1ps
// =============================================================================
// tb_snn_ppa.sv — SNN-mode PPA Testbench
//
// Purpose: Generate realistic switching activity for power/area analysis of
//          the PE running exclusively in SNN (SAC) mode.
//
// Operation:
//   - snn_i = 1 throughout → multiplier clock-gated (en_ann=0, gated_clk=0)
//   - Mimics one full Bishop "Token-Time Bundle" timestep per 8 cycles:
//       Cycles 0-3  (integrate): cell_select_i cycles 0→3, process=0
//                                a_i[0] = spike (25% rate via LFSR)
//                                b_i[7:0] = weight for that synapse
//       Cycles 4-7  (process):  cell_select_i cycles 0→3, process=1
//                                threshold comparison, fired_o, cell reset
//   - Spike rate ~25%: models sparse SNN activation (key PPA advantage vs ANN)
//   - Runs N_TIMESTEPS × 8 cycles for stable power averaging
//
// PPA Usage (Vivado Tcl):
//   open_saif snn_ppa.saif
//   log_saif [get_objects -r /tb_snn_ppa/*]
//   run (N_TIMESTEPS*8) * 10ns
//   close_saif
//   read_saif snn_ppa.saif -strip_path tb_snn_ppa/dut
//   report_power -file results/Power_SNN.rpt
// =============================================================================

module tb_snn_ppa;

  // ── Parameters ─────────────────────────────────────────────────────────────
  localparam int MULT_STAGES  = 3;
  localparam int I_W          = 8;
  localparam int O_W          = 32;
  localparam int TW           = O_W / I_W;      // 4  — cells per accumulator
  localparam int TW_WIDTH     = $clog2(TW);      // 2
  localparam int CLK_PERIOD   = 10;              // 100 MHz — matches constraints.xdc
  localparam int N_TIMESTEPS  = 250;             // 250 × 8 = 2000 cycles total
  // Spike probability: LFSR bit[1:0] == 2'b01 → ~25% rate
  localparam logic [1:0] SPIKE_PATTERN = 2'b01;

  // ── DUT signals ────────────────────────────────────────────────────────────
  logic                clk_i;
  logic                rst_ni;
  logic                snn_i;
  logic [TW_WIDTH-1:0] cell_select_i;
  logic [I_W-1:0]      v_thresh_i;
  logic [I_W-1:0]      weight_i;
  logic [I_W-1:0]      a_i;
  logic [I_W-1:0]      a_o;
  logic [O_W:0]        b_i;
  logic [O_W:0]        b_o;
  logic                fired_o;

  // ── DUT ────────────────────────────────────────────────────────────────────
  pe #(
    .MULT_STAGES(MULT_STAGES),
    .I_W        (I_W),
    .O_W        (O_W)
  ) dut (
    .clk_i        (clk_i),
    .rst_ni       (rst_ni),
    .snn_i        (snn_i),
    .cell_select_i(cell_select_i),
    .v_thresh_i   (v_thresh_i),
    .weight_i     (weight_i),
    .a_i          (a_i),
    .a_o          (a_o),
    .b_i          (b_i),
    .b_o          (b_o),
    .fired_o      (fired_o)
  );

  // ── Clock ──────────────────────────────────────────────────────────────────
  initial clk_i = 0;
  always #(CLK_PERIOD/2) clk_i = ~clk_i;

  // ── 8-bit Galois LFSR ──────────────────────────────────────────────────────
  logic [7:0] lfsr;
  function automatic logic [7:0] lfsr_next(input logic [7:0] s);
    return {s[6:0], s[7] ^ s[5] ^ s[4] ^ s[3]};
  endfunction

  // Helper: pack b_i bundle
  function automatic logic [O_W:0] make_b(
    input logic           process,
    input logic [I_W-1:0] weight
  );
    logic [O_W:0] v = '0;
    v[O_W]     = process;
    v[I_W-1:0] = weight;
    return v;
  endfunction

  // ── Stimulus ───────────────────────────────────────────────────────────────
  initial begin
    $dumpfile("tb_snn_ppa.vcd");
    $dumpvars(0, tb_snn_ppa);

    // Initialise
    rst_ni        = 0;
    snn_i         = 1;      // SNN mode throughout — multiplier clock-gated
    cell_select_i = '0;
    v_thresh_i    = 8'h40;  // threshold = 64 (moderate, fires occasionally)
    weight_i      = 8'h00;  // unused in SNN path (weight comes via b_i)
    a_i           = '0;
    b_i           = '0;
    lfsr          = 8'hD4;  // non-zero seed

    @(posedge clk_i); @(posedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);

    // ── Timestep loop ────────────────────────────────────────────────────────
    // Each iteration models one complete SNN timestep for a 4-cell neuron:
    //   Phase A (integrate, 4 cycles): accumulate incoming spikes into cells
    //   Phase B (process,  4 cycles): check threshold, reset fired cells
    //
    // This is the core compute pattern from Bishop's dense SAC core.
    repeat (N_TIMESTEPS) begin

      // ── Phase A: Integrate (4 cycles, one per cell) ─────────────────────
      for (int c = 0; c < TW; c++) begin
        @(posedge clk_i);
        lfsr          = lfsr_next(lfsr);
        cell_select_i = TW_WIDTH'(c);
        // ~25% spike rate: fires when lower 2 bits match SPIKE_PATTERN
        a_i           = (lfsr[1:0] == SPIKE_PATTERN) ? 8'h01 : 8'h00;
        // Weight varies per synapse (LFSR-driven, different per cell)
        b_i           = make_b(1'b0, lfsr);
      end

      // ── Phase B: Process (4 cycles, one per cell) ───────────────────────
      for (int c = 0; c < TW; c++) begin
        @(posedge clk_i);
        lfsr          = lfsr_next(lfsr);
        cell_select_i = TW_WIDTH'(c);
        a_i           = 8'h00;
        // process=1: threshold check — incoming weight = 0 for cell_select=0,
        // prev_cell_val for others (handled inside pe.sv combinational logic)
        b_i           = make_b(1'b1, 8'h00);
      end

    end

    $display("[SNN PPA] Stimulus complete — %0d timesteps (%0d cycles) at 100 MHz",
             N_TIMESTEPS, N_TIMESTEPS * 8);
    $finish;
  end

  // ── Watchdog ───────────────────────────────────────────────────────────────
  initial begin
    #((N_TIMESTEPS * 8 + 100) * CLK_PERIOD);
    $display("TIMEOUT");
    $finish;
  end

endmodule
