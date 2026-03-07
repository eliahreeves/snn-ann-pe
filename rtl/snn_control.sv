module snn_control
  import config_pkg::*;
#(
    parameter TW = 4,
    localparam TW_WIDTH = $clog2(TW)
) (
    input logic clk_i,
    input logic en_i,
    input logic rst_ni,

    output logic [TW_WIDTH-1:0] cell_o
);
  logic [TW_WIDTH-1:0] cell_d, cell_q;
  assign cell_o = cell_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      cell_q <= 0;
    end else begin
      cell_q <= cell_d;
    end
  end
  always_comb begin
    cell_d = cell_q;
    if (en_i) begin
      if (cell_q == (TW_WIDTH'(TW - 1))) begin
        cell_d = 0;
      end else begin
        cell_d = cell_q + 1;
      end
    end
  end

endmodule
