module tb_pe_snn_random
  import config_pkg::*;
  import dv_pkg::*;
;

  // Testbench parameters
  localparam MULT_STAGES = 3;
  localparam NUM_CYCLES = 1000;
  localparam RESET_PERIOD = 128;  // Reset every 128 cycles

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

  localparam realtime ClockPeriod = 8;

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
    int rand_val;
    int cycle_count;
    logic [I_W-1:0] current_weight;

`ifdef DUMP_FILE
    $dumpfile(`DUMP_FILE);
`else
    $dumpfile("dump.vcd");
`endif
    $dumpvars(0, tb_pe_snn_random);
    $display("[%0t] === SNN PE Random Testbench Start ===", $time);
    $timeformat(-9, 3, "ns", 10);

    // Initialize
    rst_ni = 0;
    snn_i = 1;  // SNN mode
    v_thresh_i = 8'd128;  // Threshold for firing
    weight_i = 0;
    a_i = 0;
    b_i = 0;
    cycle_count = 0;
    current_weight = $random;
    repeat (3) @(posedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);
    $display("[%0t] Reset complete", $time);

    // Run random stimulus for NUM_CYCLES
    $display("[%0t] Starting random stimulus generation", $time);
    for (int i = 0; i < NUM_CYCLES; i++) begin
      // Reset every 128 cycles to clear accumulator
      if (i > 0 && i % RESET_PERIOD == 0) begin
        $display("[%0t] === Resetting at cycle %0d ===", $time, i);
        rst_ni = 0;
        repeat (3) @(posedge clk_i);
        rst_ni = 1;
        @(posedge clk_i);
        cycle_count = 0;
        current_weight = $random;
        $display("[%0t] Reset complete, new weight: 0x%02h", $time, current_weight);
      end

      @(posedge clk_i);

      rand_val = $random % 100;
      if (rand_val < 30) begin
        a_i[0] = 1'b1;
      end else begin
        a_i[0] = 1'b0;
      end
      a_i[I_W-1:1] = '0;

      if (cycle_count >= TW) begin
        current_weight = $random;
        cycle_count = 0;
        $display("[%0t] New weight: 0x%02h", $time, current_weight);
      end

      b_i[I_W-1:0]   = current_weight;
      b_i[O_W-1:I_W] = '0;

      cycle_count++;

      if (i % 100 == 0) begin
        $display("[%0t] Cycle %0d: a_i[0]=%0b, b_i[7:0]=0x%02h, fired_o=%0b", $time, i, a_i[0],
                 b_i[I_W-1:0], fired_o);
      end

      if (fired_o) begin
        $display("[%0t] SPIKE FIRED at cycle %0d", $time, i);
      end
    end

    @(posedge clk_i);
    $display("[%0t] === SNN PE Random Testbench Complete ===", $time);
    $finish;
  end

  // Timeout watchdog
  initial begin
    #(ClockPeriod * (NUM_CYCLES + 100));
    $error("[%0t] Testbench timeout!", $time);
    $finish;
  end

endmodule
