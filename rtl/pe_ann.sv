// Dedicated ANN PE - snn_i tied to 0
// This wrapper allows Yosys to optimize away SNN-specific logic
module pe_ann
  import config_pkg::*;
#(
    parameter MULT_STAGES = 3,
    parameter I_W = 8,
    parameter O_W = 32
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [I_W-1:0] weight_i,
    // inputs
    input logic [I_W-1:0] a_i,
    output logic [I_W-1:0] a_o,
    // weights/outputs
    input logic [O_W-1:0] b_i,
    output logic [O_W-1:0] b_o
);

  pe #(
      .MULT_STAGES(MULT_STAGES),
      .I_W(I_W),
      .O_W(O_W)
  ) pe_inst (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .snn_i(1'b0),  // Constant 0 - ANN mode
      .v_thresh_i('0),
      .weight_i(weight_i),
      .a_i(a_i),
      .a_o(a_o),
      .b_i(b_i),
      .b_o(b_o),
      .fired_o()  // Unconnected output
  );

endmodule
