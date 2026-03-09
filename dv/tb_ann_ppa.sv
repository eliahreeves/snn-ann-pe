`timescale 1ns/1ps
// =============================================================================
// tb_ann_ppa.sv — ANN-mode PPA Testbench
//
// Purpose: Generate realistic switching activity for power/area analysis of
//          the PE running exclusively in ANN (MAC) mode.
//
// Operation:
//   - snn_i = 0 throughout → multiplier is always active (no clock gating)
//   - Streams pseudo-random a_i, weight_i, and b_i each cycle using an 8-bit
//     LFSR to mimic real activation/weight distributions (~50% toggle rate)
//   - Runs N_CYCLES cycles for a statistically stable activity window
//
// PPA Usage (Vivado Tcl):
//   open_saif ann_ppa.saif
//   log_saif [get_objects -r /tb_ann_ppa/*]
//   run N_CYCLES * 10ns
//   close_saif
//   read_saif ann_ppa.saif -strip_path tb_ann_ppa/dut
//   report_power -file results/Power_ANN.rpt
// =============================================================================

module tb_ann_ppa;

  // ── Parameters ─────────────────────────────────────────────────────────────
  localparam int MULT_STAGES = 3;
  localparam int I_W         = 8;
  localparam int O_W         = 32;
  localparam int TW          = O_W / I_W;       // 4
  localparam int TW_WIDTH    = $clog2(TW);       // 2
  localparam int CLK_PERIOD  = 10;               // 100 MHz — matches constraints.xdc
  localparam int N_CYCLES    = 2000;             // stimulus window for power averaging

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

  // ── 8-bit Galois LFSR for pseudo-random stimulus ───────────────────────────
  // Taps: [8,6,5,4] — maximal-length sequence (period 255)
  logic [7:0] lfsr_a, lfsr_w, lfsr_b;

  function automatic logic [7:0] lfsr_next(input logic [7:0] s);
    return {s[6:0], s[7] ^ s[5] ^ s[4] ^ s[3]};
  endfunction

  // ── Stimulus ───────────────────────────────────────────────────────────────
  initial begin
    $dumpfile("tb_ann_ppa.vcd");
    $dumpvars(0, tb_ann_ppa);

    // Initialise
    rst_ni        = 0;
    snn_i         = 0;      // ANN mode — multiplier always enabled
    cell_select_i = '0;     // unused in ANN mode
    v_thresh_i    = '0;     // unused in ANN mode
    a_i           = 8'h00;
    weight_i      = 8'h00;
    b_i           = '0;
    lfsr_a        = 8'hA3;  // non-zero seeds
    lfsr_w        = 8'h5C;
    lfsr_b        = 8'hF1;

    // Release reset after 2 cycles
    @(posedge clk_i); @(posedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);

    // ── Main stimulus loop ──────────────────────────────────────────────────
    // Each cycle: advance LFSR → new activation, weight, and partial-sum b_i.
    // The LFSR ensures varied bit transitions (~50% toggle) on all inputs,
    // giving representative dynamic power numbers for the MAC datapath.
    repeat (N_CYCLES) begin
      @(posedge clk_i);
      lfsr_a   = lfsr_next(lfsr_a);
      lfsr_w   = lfsr_next(lfsr_w);
      lfsr_b   = lfsr_next(lfsr_b);
      a_i      = lfsr_a;
      weight_i = lfsr_w;
      // Simulate partial sum flowing into b_i (process=0, 32-bit data)
      b_i      = {1'b0, {3{lfsr_b}}, lfsr_b};
    end

    $display("[ANN PPA] Stimulus complete — %0d cycles at 100 MHz", N_CYCLES);
    $finish;
  end

  // ── Watchdog ───────────────────────────────────────────────────────────────
  initial begin
    #((N_CYCLES + 100) * CLK_PERIOD);
    $display("TIMEOUT");
    $finish;
  end

endmodule
