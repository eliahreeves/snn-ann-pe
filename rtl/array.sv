module array
  import config_pkg::*;
#(
    parameter MULT_STAGES = 3,
    parameter I_W = 8,
    parameter O_W = 32,
    parameter SIZE = 16
) (
    input logic clk_i,
    input logic rst_ni,
    input logic snn_i,
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

  // SIZExSIZE array of PE modules
  // a_chain: flows vertically north-to-south through columns (gets dropped at bottom)
  // b_chain: flows horizontally west-to-east through rows (connects to output at right edge)
  // weight_chain: weight shift register chain (horizontal, left to right, wraps around rows)
  /* verilator lint_off UNUSEDSIGNAL */
  logic [SIZE:0][SIZE-1:0][I_W-1:0] a_chain;  // [row][col] - extra row for outputs (bottom dropped)
  /* verilator lint_on UNUSEDSIGNAL */
  logic [SIZE-1:0][SIZE:0][O_W-1:0] b_chain;  // [row][col] - extra col for outputs

  // Weight registers - one per PE to store the loaded weight
  logic [SIZE-1:0][SIZE-1:0][I_W-1:0] weight_reg_q;

  // Weight shift register chain logic
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      weight_reg_q <= '0;
    end else if (weight_load_en_i) begin
      // Shift weights through the chain row-by-row
      weight_reg_q[0][0] <= weight_shift_i;
      // First row, remaining columns
      for (int col = 1; col < SIZE; col++) begin
        weight_reg_q[0][col] <= weight_reg_q[0][col-1];
      end
      // Remaining rows
      for (int row = 1; row < SIZE; row++) begin
        // First column of each row connects to last column of previous row
        weight_reg_q[row][0] <= weight_reg_q[row-1][SIZE-1];
        // Remaining columns
        for (int col = 1; col < SIZE; col++) begin
          weight_reg_q[row][col] <= weight_reg_q[row][col-1];
        end
      end
    end
  end

  // Connect input activations to the top edge of each column (flow north-to-south)
  genvar row, col;
  generate
    for (col = 0; col < SIZE; col++) begin : gen_col_inputs
      assign a_chain[0][col] = a_i[(col+1)*I_W-1:col*I_W];
    end
  endgenerate

  // Connect input b values to the left edge of each row (flow west-to-east)
  generate
    for (row = 0; row < SIZE; row++) begin : gen_row_inputs
      assign b_chain[row][0] = b_i[(row+1)*O_W-1:row*O_W];
    end
  endgenerate

  // Instantiate SIZExSIZE PE array
  generate
    for (row = 0; row < SIZE; row++) begin : gen_pe_rows
      for (col = 0; col < SIZE; col++) begin : gen_pe_cols
        /* verilator lint_off PINCONNECTEMPTY */
        pe #(
            .MULT_STAGES(MULT_STAGES),
            .I_W(I_W),
            .O_W(O_W)
        ) pe_inst (
            .clk_i     (clk_i),
            .rst_ni    (rst_ni),
            .snn_i     (snn_i),
            .v_thresh_i(v_thresh_i),
            .weight_i  (weight_reg_q[row][col]),  // Connected to weight register
            .a_i       (a_chain[row][col]),       // From north (top)
            .a_o       (a_chain[row+1][col]),     // To south (bottom) - dropped at end
            .b_i       (b_chain[row][col]),       // From west (left)
            .b_o       (b_chain[row][col+1]),     // To east (right) - output at end
            .fired_o   ()                         // Not connected at array level
        );
        /* verilator lint_on PINCONNECTEMPTY */
      end
    end
  endgenerate

  // Connect output b values from the right edge (east side of each row)
  generate
    for (row = 0; row < SIZE; row++) begin : gen_outputs
      assign b_o[(row+1)*O_W-1:row*O_W] = b_chain[row][SIZE];
    end
  endgenerate

endmodule
