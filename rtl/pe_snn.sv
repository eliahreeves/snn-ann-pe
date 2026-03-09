module pe_snn
  import config_pkg::*;
#(
    parameter MULT_STAGES = 3
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [I_W-1:0] v_thresh_i,
    // spikes/inputs
    input logic [I_W-1:0] a_i,
    output logic [I_W-1:0] a_o,
    //weights/outputs
    input logic [O_W-1:0] b_i,
    output logic [O_W-1:0] b_o,

    output logic fired_o
);
  pe #() pe_snn_int (
      .snn_i(1),
      .weight_i(),
      .*
  );
endmodule
