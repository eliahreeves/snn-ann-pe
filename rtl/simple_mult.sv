module simple_mult
  import config_pkg::*;
#(
    parameter STAGES = 0
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [I_W-1:0] a_i,
    input logic [I_W-1:0] b_i,
    output logic [I_W*2-1:0] c_o
);
  localparam MUL_W = I_W * 2;  // Multiplier output width
  
  logic [STAGES-1:0][MUL_W-1:0] buff_q;  // Pipeline registers
  logic [ MUL_W-1:0]            prod_d;


  assign prod_d = a_i * b_i;
  assign c_o = buff_q[STAGES-1];

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      buff_q <= '0;
    end else begin
      buff_q[0] <= prod_d;
      for (int i = 1; i < STAGES; i++) begin
        buff_q[i] <= buff_q[i-1];
      end
    end
  end

endmodule
