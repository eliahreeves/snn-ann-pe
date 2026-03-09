// Dedicated SNN PE - snn_i tied to 1
// This wrapper allows Yosys to optimize away ANN-specific logic (multiplier)
module pe_snn
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
    input logic [TW_WIDTH-1:0] cell_select_i,
    input logic [I_W-1:0] v_thresh_i,
    input logic [I_W-1:0] weight_i,
    // spikes/inputs
    input logic [I_W-1:0] a_i,
    output logic [I_W-1:0] a_o,
    // weights/outputs
    input logic [O_W-1:0] b_i,
    output logic [O_W-1:0] b_o,

    output logic fired_o
);

  pe #(
      .MULT_STAGES(MULT_STAGES),
      .I_W(I_W),
      .O_W(O_W)
  ) pe_inst (
      .clk_i(clk_i),
      .rst_ni(rst_ni),
      .snn_i(1'b1),  // Constant 1 - SNN mode
      .v_thresh_i(v_thresh_i),
      .weight_i(weight_i),
      .a_i(a_i),
      .a_o(a_o),
      .b_i(b_i),
      .b_o(b_o),
      .fired_o(fired_o)
  );

endmodule
