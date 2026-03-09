module tb_array_snn_power
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
    snn = 1;  // SNN mode
    v_thresh = 8'd128;  // Example threshold for SNN
    weight_load_en = 0;
    weight_shift = 0;
    a = '0;
    b = '0;

    // Reset
    repeat (5) @(posedge clk);
    rst_n = 1;
    repeat (2) @(posedge clk);

    $display("Starting SNN power model testbench");
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
      logic [I_W-1:0] current_b_value;

      // Choose a random 8-bit number for b inputs
      current_b_value = $urandom_range(0, 255);

      // Feed the same b value for TW (4) cycles
      for (int tw_cycle = 0; tw_cycle < TW; tw_cycle++) begin
        // Set b inputs (same value to all rows)
        for (int row = 0; row < SIZE; row++) begin
          b[row*O_W+:I_W] = current_b_value;  // Only bottom 8 bits
          // Upper bits of b remain 0
          for (int b_idx = I_W; b_idx < O_W; b_idx++) begin
            b[row*O_W+b_idx] = 1'b0;
          end
        end

        // Generate random spike inputs for a (only lowest bit)
        for (int col = 0; col < SIZE; col++) begin
          // Randomly choose 0 or 1 for lowest bit (70% chance of 0, 30% chance of 1)
          int rand_val = $urandom_range(0, 99);
          if (rand_val < 70) begin
            a[col*I_W] = 1'b0;  // 70% chance
          end else begin
            a[col*I_W] = 1'b1;  // 30% chance
          end
          // Upper 7 bits are always 0
          for (int a_idx = 1; a_idx < I_W; a_idx++) begin
            a[col*I_W+a_idx] = 1'b0;
          end
        end

        // Wait one cycle
        @(posedge clk);
      end

      if ((inference % 100) == 0) begin
        $display("Completed %0d/%0d inferences", inference, NUM_INFERENCES);
      end
    end

    // Allow pipeline to drain
    repeat (MULT_STAGES + SIZE + 5) @(posedge clk);

    $display("SNN power model test completed");
    $finish;
  end

  // Optional: Monitor power-related events
  initial begin
    // VCD dump for power analysis tools
    $dumpfile("tb_array_snn_power.vcd");
    $dumpvars(0, tb_array_snn_power);
  end

endmodule
