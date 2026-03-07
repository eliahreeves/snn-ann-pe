module pe
  import config_pkg::*;
#(

    parameter MULT_STAGES = 3,
    parameter I_W = 8,
    parameter O_W = 32,
    localparam TW = O_W / I_W,
    localparam TW_WIDTH = $clog2(TW)
) (
    input logic clk_i,
    input logic rst_ni,
    input logic snn_i,
    input logic processes_i,
    input logic [TW_WIDTH-1:0] cell_select_i,
    // spikes/inputs
    input logic [I_W-1:0] a_i,
    output logic [I_W-1:0] a_o,
    //weights/outputs
    input logic [I_W-1:0] b_i,
    output logic [I_W-1:0] b_o,
    input logic [I_W-1:0] v_thresh_i,

    output logic fired_o
);
  if (O_W % I_W != 0) $error("Input must be a multiple of output");
  if (MULT_STAGES <= 0) $error("At least one mult stage required");

  localparam MULT_OUT = I_W * 2;

  typedef struct packed {logic [TW-1:0][I_W-1:0] cells;} snn_data_t;

  snn_data_t acc_d, acc_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      acc_q <= 0;
    end else begin
      acc_q <= acc_d;
    end
  end

  // *************************************************************
  // Pipeline Buffer NS
  //
  // Reconfigurable length buffer to deal with mulitplier delay
  // *************************************************************

  logic [MULT_STAGES-1:0][I_W-1:0] buffer_a_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      buffer_a_q <= '0;
    end else begin
      buffer_a_q[0] <= a_i;
      for (int i = 1; i < MULT_STAGES; i++) begin
        buffer_a_q[i] <= buffer_a_q[i-1];
      end
    end
  end

  assign a_o = snn_i ? buffer_a_q[0] : buffer_a_q[MULT_STAGES-1];

  // *************************************************************
  // Pipeline Buffer WE
  //
  //	
  // *************************************************************

  logic [I_W:0] buffer_b_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      buffer_b_q <= '0;
    end else begin
      buffer_b_q <= b_i;
    end
  end




  // *************************************************************
  // Adder
  // *************************************************************

  logic [MULT_OUT-1:0] adder_input_a;
  logic [O_W-1:0] adder_input_b;
  logic [O_W-1:0] adder_output;

  assign adder_output = adder_input_b + O_W'(adder_input_a);

  // *************************************************************
  // Multiplier
  // *************************************************************

  logic en_ann;
  logic gated_clk;
  assign gated_clk = clk_i && en_ann;

  always_latch begin
    if (!clk_i) begin
      en_ann = !snn_i;
    end
  end

  logic [MULT_OUT-1:0] mult_out;
  // output valid after MULT_STAGES # of cycles have passed
  simple_mult #(
      .STAGES(MULT_STAGES)
  ) mult (
      .clk_i(gated_clk),
      .rst_ni(rst_ni),
      .a_i(en_ann ? a_i : 0),
      .b_i(en_ann ? b_i : 0),
      .c_o(mult_out)
  );

  // *************************************************************
  // Combinational
  // *************************************************************

  always_comb begin
    acc_d = acc_q;
    adder_input_b = acc_q;
    adder_input_a = 0;
    fired_o = 0;
    // if in SNN mode
    if (snn_i) begin
      // load sums into registers
      if (~processes_i) begin
        adder_input_a[I_W-1:0] = a_i[0] ? b_i : 0;
        // if in integrate mode, accumulate and saturate
        acc_d.cells[cell_select_i] = adder_output[I_W] == 0 ? adder_output[I_W-1:0] : {I_W{1'b1}};
      end else begin
        adder_input_b = acc_q.cells[cell_select_i];
        if (cell_select_i == 0) begin
          adder_input_a[I_W-1:0] = b_i;
        end else begin
          adder_input_a = acc_q.cells[cell_select_i-1];
        end

        fired_o = adder_output[I_W:0] >= ((I_W + 1)'(v_thresh_i));
        if (fired_o) begin
          acc_d.cells[cell_select_i] = 0;
        end else begin
          acc_d.cells[cell_select_i] = adder_output[I_W-1:0];
        end
      end
    end else begin
      adder_input_a = mult_out;
      acc_d = adder_output;
    end
  end
endmodule
