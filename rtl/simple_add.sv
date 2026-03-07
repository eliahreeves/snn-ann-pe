module simple_add
  import config_pkg::*;
#(
    parameter I_W = 8
) (
    input logic [I_W-1:0] a_i,
    input logic [I_W-1:0] b_i,
    input logic c_i,

    output logic [I_W-1:0] sum_o,
    output logic c_o
);

  logic [I_W:0] full_sum;
  assign full_sum = a_i + b_i + {{I_W{1'b0}}, c_i};
  assign c_o = full_sum[I_W];
  assign sum_o = full_sum[I_W-1:0];
endmodule
