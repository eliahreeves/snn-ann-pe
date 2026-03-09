/* verilator lint_off DECLFILENAME */
module sky130_fd_sc_hd__dlclkp_1 (
    input  logic CLK,   // Input clock
    input  logic GATE,  // Gate enable signal
    output logic GCLK   // Gated clock output
);
  logic latch_out;

  /* verilator lint_off COMBDLY */
  always_latch begin
    if (!CLK) begin
      latch_out <= GATE;
    end
  end
  /* verilator lint_on COMBDLY */

  assign GCLK = CLK & latch_out;

endmodule
/* verilator lint_on DECLFILENAME */
