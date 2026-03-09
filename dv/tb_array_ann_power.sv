module tb_array_ann_power
  import config_pkg::*;
();

  // Parameters
  localparam int SIZE = 16;
  localparam int MULT_STAGES = 3;
  localparam int CLK_PERIOD = 10;  // 10ns clock period (100MHz)
  localparam int NUM_INFERENCES = 1000;  // Number of random inferences to run
  localparam int WEIGHT_LOAD_CYCLES = SIZE * SIZE;  // Total weights to load

  // DUT signals
  logic clk;
  logic rst_n;
  logic snn;
  logic [I_W-1:0] v_thresh;
  logic weight_load_en;
  logic [I_W-1:0] weight_shift;
  logic [SIZE*I_W-1:0] a;
  logic [SIZE*O_W-1:0] b;
  logic [SIZE*O_W-1:0] b_out;

  // Clock generation
  initial begin
    clk = 0;
    forever #(CLK_PERIOD / 2) clk = ~clk;
  end

  // DUT instantiation
  array #(
      .MULT_STAGES(MULT_STAGES),
      .SIZE(SIZE)
  ) dut (
      .clk_i(clk),
      .rst_ni(rst_n),
      .snn_i(snn),
      .v_thresh_i(v_thresh),
      .weight_load_en_i(weight_load_en),
      .weight_shift_i(weight_shift),
      .a_i(a),
      .b_i(b),
      .b_o(b_out)
  );

  // Test stimulus
  initial begin
    // Initialize signals
    rst_n = 0;
    snn = 0;  // ANN mode
    v_thresh = 8'd0;  // Not used in ANN mode
    weight_load_en = 0;
    weight_shift = 0;
    a = '0;
    b = '0;

    // Reset
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    $display("Starting ANN power model testbench");
    $display("Loading random weights...");

    // Load random weights
    weight_load_en = 1;
    for (int i = 0; i < WEIGHT_LOAD_CYCLES; i++) begin
      weight_shift = $urandom_range(0, 255);  // Random 8-bit weight
      @(posedge clk);
    end
    weight_load_en = 0;

    $display("Weights loaded. Running %0d random inferences...", NUM_INFERENCES);

    // Run random inferences for power measurement
    for (int inference = 0; inference < NUM_INFERENCES; inference++) begin
      // Generate random input activations (a)
      for (int i = 0; i < SIZE; i++) begin
        a[i*I_W+:I_W] = $urandom_range(0, 255);  // Random 8-bit activation
      end

      // Set b inputs to 0 (accumulator starts from 0)
      b = '0;

      // Wait for computation to complete
      // Pipeline depth + array propagation
      repeat (MULT_STAGES + SIZE + 5) @(posedge clk);

      if ((inference % 100) == 0) begin
        $display("Completed %0d/%0d inferences", inference, NUM_INFERENCES);
      end
    end

    $display("ANN power model test completed");
    $finish;
  end

  // Optional: Monitor power-related events
  initial begin
    // VCD dump for power analysis tools
    $dumpfile("tb_array_ann_power.vcd");
    $dumpvars(0, tb_array_ann_power);
  end

endmodule
