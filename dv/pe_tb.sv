module pe_tb
  import config_pkg::*;
  import dv_pkg::*;
;

  // Testbench parameters
  localparam MULT_STAGES = 3;
  // I_W, O_W, TW, ns_signals_t, ns_data_t now come from config_pkg

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
  localparam realtime ClockFrequency = 100e6;  // 100 MHz
  localparam realtime ClockPeriod = (1s / ClockFrequency);

  initial begin
    clk_i = 0;
    forever begin
      #(ClockPeriod / 2);
      clk_i = !clk_i;
    end
  end

  // DUT instantiation
  pe #(
      .MULT_STAGES(MULT_STAGES)
  ) dut (
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

  // Test tasks
  task automatic reset();
    rst_ni = 0;
    snn_i = 0;
    v_thresh_i = 0;
    weight_i = 0;
    a_i = 0;
    b_i = 0;
    repeat (3) @(posedge clk_i);
    rst_ni = 1;
    @(posedge clk_i);
    $display("[%0t] Reset complete", $time);
  endtask

  task automatic wait_clocks(int n);
    repeat (n) @(posedge clk_i);
  endtask

  // Test: ANN mode MAC operation
  task automatic test_ann_mode();
    $display("[%0t] === Testing ANN Mode ===", $time);
    snn_i = 0;
    weight_i = 8'd5;
    a_i = 8'd3;
    b_i = 32'd10;

    // Wait for multiplier pipeline + 1
    wait_clocks(MULT_STAGES + 2);

    // Expected: b_o should eventually be 10 + (5*3) = 25 after pipeline delay
    $display("[%0t] ANN Mode: a_i=%0d, weight_i=%0d, b_i=%0d -> b_o=%0d", $time, a_i, weight_i,
             b_i, b_o);

    // Test another cycle
    a_i = 8'd2;
    b_i = b_o;  // Chain the output
    wait_clocks(MULT_STAGES + 2);
    $display("[%0t] ANN Mode: a_i=%0d, weight_i=%0d, b_i=%0d -> b_o=%0d", $time, a_i, weight_i,
             b_i, b_o);
  endtask

  // Test: SNN mode spike accumulation
  task automatic test_snn_mode();
    ns_data_t test_data;

    $display("[%0t] === Testing SNN Mode ===", $time);
    snn_i = 1;
    v_thresh_i = 8'd50;  // Threshold for firing

    // Setup weight data in b_i
    test_data.signals.process = 0;
    test_data.signals.flush = 0;
    test_data.signals.first = 0;
    test_data._empty = '0;
    test_data.weight = 8'd10;

    b_i = test_data;

    // Send a spike (a_i[0] = 1)
    a_i = 8'b00000001;
    wait_clocks(1);
    $display("[%0t] SNN Mode: Spike sent, weight=%0d", $time, test_data.weight);

    // Wait for accumulation through pipeline
    a_i = 8'b00000000;
    wait_clocks(TW + 2);

    // Send more spikes to accumulate
    test_data.weight = 8'd15;
    b_i = test_data;
    a_i = 8'b00000001;
    wait_clocks(1);

    a_i = 8'b00000000;
    wait_clocks(TW + 2);
    $display("[%0t] SNN Mode: Accumulation in progress", $time);

    // Test firing by accumulating past threshold
    test_data.weight = 8'd30;
    b_i = test_data;
    a_i = 8'b00000001;
    wait_clocks(1);

    // Switch to process mode to check firing
    test_data.signals.process = 1;
    test_data.signals.first = 1;
    test_data.weight = 8'd0;
    b_i = test_data;
    a_i = 8'b00000000;
    wait_clocks(TW + 2);

    if (fired_o) begin
      $display("[%0t] SNN Mode: Neuron FIRED! fired_o=%0d", $time, fired_o);
    end else begin
      $display("[%0t] SNN Mode: Neuron did not fire. fired_o=%0d", $time, fired_o);
    end
  endtask

  // Test: SNN flush operation
  task automatic test_snn_flush();
    ns_data_t test_data;

    $display("[%0t] === Testing SNN Flush ===", $time);
    snn_i = 1;
    v_thresh_i = 8'd50;
    test_data.signals.process = 0;
    test_data.signals.flush = 1;  // Flush mode
    test_data.signals.first = 0;
    test_data._empty = '0;
    test_data.weight = 8'd10;

    b_i = test_data;
    a_i = 8'b00000001;

    wait_clocks(TW + 2);
    $display("[%0t] SNN Flush: After flush operation", $time);
  endtask

  // Main test sequence
  initial begin
    $dumpfile("dump.fst");
    $dumpvars(0, pe_tb);
    $display("[%0t] === PE Testbench Start ===", $time);
    $timeformat(-9, 3, "ns", 10);

    // Initialize
    reset();

    // Run tests
    test_ann_mode();
    wait_clocks(5);

    reset();
    test_snn_mode();
    wait_clocks(5);

    reset();
    test_snn_flush();
    wait_clocks(5);

    $display("[%0t] === PE Testbench Complete ===", $time);
    $finish;
  end

  // Timeout watchdog
  initial begin
    #(ClockPeriod * 10000);
    $error("[%0t] Testbench timeout!", $time);
    $finish;
  end

  // Monitor for combinational loops (signals should never be X after reset)
  always @(posedge clk_i) begin
    if (rst_ni) begin
      if ($isunknown(a_o)) begin
        $warning("[%0t] a_o is unknown - possible combinational loop", $time);
      end
      if ($isunknown(b_o)) begin
        $warning("[%0t] b_o is unknown - possible combinational loop", $time);
      end
      if ($isunknown(fired_o)) begin
        $warning("[%0t] fired_o is unknown - possible combinational loop", $time);
      end
    end
  end

endmodule
