module tb_pe_ann_random
  import config_pkg::*;
  import dv_pkg::*;
;

  // Testbench parameters
  localparam MULT_STAGES = 3;
  localparam NUM_CYCLES = 1000;

  // Clock and reset
  logic clk_i;
  logic rst_ni;

  // Control signals
  logic snn_i;
  logic [I_W-1:0] v_thresh_i;
  logic [I_W-1:0] weight_i;

  // Data path signals
  logic [I_W-1:0] a_i;
  logic [I_W-1:0] a_o;
  logic [O_W-1:0] b_i;
  logic [O_W-1:0] b_o;
  logic fired_o;

  // Clock generation
  localparam ClockPeriod = 8;

  initial begin
    clk_i = 0;
    forever begin
      #(ClockPeriod / 2);
      clk_i = !clk_i;
    end
  end

  // DUT instantiation
`ifdef GATE_LEVEL_SIM
  // Gate-level netlist has no parameters
  pe dut (
`else
  // RTL simulation with parameters
  pe #(
      .MULT_STAGES(MULT_STAGES)
  ) dut (
`endif
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .snn_i(snn_i),
      .v_thresh_i(v_thresh_i),
      .weight_i(weight_i),
      .a_i(a_i),
      .a_o(a_o),
      .b_i(b_i),
      .b_o(b_o),
      .fired_o(fired_o)
  );

  // Test sequence
  initial begin
`ifdef DUMP_FILE
    $dumpfile(`DUMP_FILE);
`else
    $dumpfile("dump.vcd");
`endif
    $dumpvars(0, tb_pe_ann_random);
    $display("[%0t] === ANN PE Random Testbench Start ===", $time);
    $timeformat(-9, 3, "ns", 10);

    // Initialize
    rst_ni = 0;
    snn_i = 0;  // ANN mode
    v_thresh_i = 0;
    weight_i = 8'b01010101;  // Fixed weight pattern
    a_i = 0;
    b_i = 0;
    repeat (3) @(posedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);
    $display("[%0t] Reset complete", $time);

    // Run random stimulus for NUM_CYCLES
    $display("[%0t] Starting random stimulus generation", $time);
    for (int i = 0; i < NUM_CYCLES; i++) begin
      @(posedge clk_i);
      a_i = $random;  // Random 8-bit value
      b_i = $random;  // Random 32-bit value

      if (i % 100 == 0) begin
        $display("[%0t] Cycle %0d: a_i=0x%02h, b_i=0x%08h, b_o=0x%08h", $time, i, a_i, b_i, b_o);
      end
    end

    @(posedge clk_i);
    $display("[%0t] === ANN PE Random Testbench Complete ===", $time);
    $finish;
  end

  // Timeout watchdog
  initial begin
    #(ClockPeriod * (NUM_CYCLES + 100));
    $error("[%0t] Testbench timeout!", $time);
    $finish;
  end

endmodule
