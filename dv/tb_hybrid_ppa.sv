`timescale 1ns/1ps
// =============================================================================
// tb_hybrid_ppa.sv — Hybrid-mode PPA Testbench
//
// Purpose: Measure switching activity and power of the hybrid PE as it
//          alternates between ANN and SNN operation — the key use case
//          for PPA overhead comparison.
//
// Operation:
//   Repeats N_EPOCHS epochs. Each epoch = ANN_CYCLES of ANN + one full SNN
//   timestep (TW*2 = 8 cycles). This mirrors a realistic deployment where the
//   same chip switches between workloads:
//
//     [ANN phase]  snn_i=0, multiplier active, LFSR-driven MAC stream
//     [SNN phase]  snn_i=1, multiplier clock-gated, spike integrate+process
//
//   Key metric: the overhead of the hybrid mux/clock-gate logic should
//   appear as ΔPower = P_Hybrid − P_ANN_only (from tb_ann_ppa) in ANN mode,
//   and as ΔPower = P_Hybrid − P_SNN_only (from tb_snn_ppa) in SNN mode.
//
//   Total cycles = N_EPOCHS × (ANN_CYCLES + TW*2)
//               = 200     × (     8      +   8  ) = 3200 cycles
//
// PPA Usage (Vivado Tcl):
//   open_saif hybrid_ppa.saif
//   log_saif [get_objects -r /tb_hybrid_ppa/*]
//   run 3200 * 10ns
//   close_saif
//   read_saif hybrid_ppa.saif -strip_path tb_hybrid_ppa/dut
//   report_power -file results/Power_Hybrid.rpt
// =============================================================================

module tb_hybrid_ppa;

  // ── Parameters ─────────────────────────────────────────────────────────────
  localparam int MULT_STAGES = 3;
  localparam int I_W         = 8;
  localparam int O_W         = 32;
  localparam int TW          = O_W / I_W;   // 4
  localparam int TW_WIDTH    = $clog2(TW);  // 2
  localparam int CLK_PERIOD  = 10;          // 100 MHz — matches constraints.xdc
  localparam int N_EPOCHS    = 200;         // number of ANN→SNN switch cycles
  localparam int ANN_CYCLES  = 8;           // ANN cycles per epoch (≥ MULT_STAGES+1)

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

  // ── LFSR ───────────────────────────────────────────────────────────────────
  logic [7:0] lfsr_a, lfsr_w, lfsr_s;

  function automatic logic [7:0] lfsr_next(input logic [7:0] s);
    return {s[6:0], s[7] ^ s[5] ^ s[4] ^ s[3]};
  endfunction

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
    $dumpfile("tb_hybrid_ppa.vcd");
    $dumpvars(0, tb_hybrid_ppa);

    // Initialise
    rst_ni        = 0;
    snn_i         = 0;
    cell_select_i = '0;
    v_thresh_i    = 8'h40;
    weight_i      = 8'h00;
    a_i           = '0;
    b_i           = '0;
    lfsr_a        = 8'hA3;
    lfsr_w        = 8'h5C;
    lfsr_s        = 8'hD4;

    @(posedge clk_i); @(posedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);

    // ── Epoch loop ───────────────────────────────────────────────────────────
    repeat (N_EPOCHS) begin

      // ════════════════════════════════════════════════════════════════════
      // ANN phase — snn_i=0, multiplier running
      // Streams LFSR activations and weights through the MAC pipeline.
      // The hybrid overhead vs a pure-MAC PE is measured here.
      // ════════════════════════════════════════════════════════════════════
      snn_i = 0;
      repeat (ANN_CYCLES) begin
        @(posedge clk_i);
        lfsr_a   = lfsr_next(lfsr_a);
        lfsr_w   = lfsr_next(lfsr_w);
        a_i      = lfsr_a;
        weight_i = lfsr_w;
        b_i      = {1'b0, {3{lfsr_w}}, lfsr_a};
      end

      // ════════════════════════════════════════════════════════════════════
      // SNN phase — snn_i=1, multiplier clock-gated
      // One full TW=4 timestep: 4 integrate + 4 process cycles.
      // The hybrid overhead vs a pure-SAC PE is measured here.
      // ════════════════════════════════════════════════════════════════════
      snn_i    = 1;
      weight_i = 8'h00;  // weight travels via b_i in SNN mode

      // Integrate phase
      for (int c = 0; c < TW; c++) begin
        @(posedge clk_i);
        lfsr_s        = lfsr_next(lfsr_s);
        cell_select_i = TW_WIDTH'(c);
        a_i           = (lfsr_s[1:0] == 2'b01) ? 8'h01 : 8'h00; // ~25% spike
        b_i           = make_b(1'b0, lfsr_s);
      end

      // Process phase
      for (int c = 0; c < TW; c++) begin
        @(posedge clk_i);
        lfsr_s        = lfsr_next(lfsr_s);
        cell_select_i = TW_WIDTH'(c);
        a_i           = 8'h00;
        b_i           = make_b(1'b1, 8'h00);
      end

    end

    $display("[HYBRID PPA] Stimulus complete — %0d epochs (%0d cycles) at 100 MHz",
             N_EPOCHS, N_EPOCHS * (ANN_CYCLES + TW * 2));
    $finish;
  end

  // ── Watchdog ───────────────────────────────────────────────────────────────
  initial begin
    #((N_EPOCHS * (ANN_CYCLES + TW * 2) + 100) * CLK_PERIOD);
    $display("TIMEOUT");
    $finish;
  end

endmodule
