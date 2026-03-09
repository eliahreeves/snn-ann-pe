// Wrapper to rename pe_snn module to pe for testbench compatibility
// SNN PE doesn't have: snn_i, weight_i
module pe (
    input clk_i,
    output fired_o,
    input rst_ni,
    input snn_i,
    input [7:0] a_i,
    output [7:0] a_o,
    input [31:0] b_i,
    output [31:0] b_o,
    input [7:0] v_thresh_i,
    input [7:0] weight_i
);

pe_snn pe_snn_inst (
    .clk_i(clk_i),
    .fired_o(fired_o),
    .rst_ni(rst_ni),
    .a_i(a_i),
    .a_o(a_o),
    .b_i(b_i),
    .b_o(b_o),
    .v_thresh_i(v_thresh_i)
    // snn_i and weight_i are not connected (unused in SNN-only mode)
);

endmodule
