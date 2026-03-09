// Wrapper to rename pe_ann module to pe for testbench compatibility
// ANN PE doesn't have: fired_o, snn_i, v_thresh_i
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

// ANN PE never fires, so tie off
assign fired_o = 1'b0;

pe_ann pe_ann_inst (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .a_i(a_i),
    .a_o(a_o),
    .b_i(b_i),
    .b_o(b_o),
    .weight_i(weight_i)
    // snn_i and v_thresh_i are not connected (unused in ANN mode)
);

endmodule
