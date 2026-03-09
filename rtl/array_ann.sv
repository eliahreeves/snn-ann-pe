module array_ann
  import config_pkg::*;
#(
    parameter SIZE = 16
) (
    input logic clk_i,
    input logic rst_ni,
    input logic [I_W-1:0] v_thresh_i,
    // Weight shift register control and input (loads one weight per cycle)
    input logic weight_load_en_i,
    input logic [I_W-1:0] weight_shift_i,
    // Input activations for each row
    input logic [SIZE*I_W-1:0] a_i,
    // Initial b input for first column
    input logic [SIZE*O_W-1:0] b_i,
    // Final b output from last column
    output logic [SIZE*O_W-1:0] b_o
);

  array #() int_ann_array (
      .snn_i(0),
      .*
  );
endmodule
