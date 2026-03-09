module pe
  import config_pkg::*;
#(
    parameter MULT_STAGES = 3
) (
    input logic clk_i,
    input logic rst_ni,
    input logic snn_i,
    input logic [I_W-1:0] v_thresh_i,
    input logic [I_W-1:0] weight_i,
    // spikes/inputs
    input logic [I_W-1:0] a_i,
    output logic [I_W-1:0] a_o,
    //weights/outputs
    input logic [O_W-1:0] b_i,
    output logic [O_W-1:0] b_o,

    output logic fired_o
);
  ns_data_t ns_data_in, ns_data_out;
  assign ns_data_in = ns_data_t'(b_i);

  if (O_W % I_W != 0) $error("Input must be a multiple of output");
  if (O_W - $bits(ns_data_in.signals) <= I_W) $error("at least 3 biots required for signals");
  if (MULT_STAGES <= 0) $error("At least one mult stage required");

  localparam MULT_OUT = I_W * 2;

  assign b_o = ns_data_out;

  logic [TW-1:0][I_W-1:0] acc_pipe_d, acc_pipe_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      acc_pipe_q <= 0;
    end else begin
      acc_pipe_q <= acc_pipe_d;
    end
  end

  // *************************************************************
  // Pipeline Buffer NS
  //
  // Reconfigurable length buffer to deal with mulitplier delay.
  // If in SNN mode add 1 pipeline stage for the spikes, If in ANN mode,
  // add MULT_STAGES + 1 for inputs.
  // *************************************************************

  logic [MULT_STAGES:0][I_W-1:0] buffer_a_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      buffer_a_q <= '0;
    end else begin
      buffer_a_q[0] <= a_i;
      for (int i = 1; i < MULT_STAGES + 1; i++) begin
        buffer_a_q[i] <= buffer_a_q[i-1];
      end
    end
  end

  assign a_o = snn_i ? buffer_a_q[0] : buffer_a_q[MULT_STAGES];

  // *************************************************************
  // Pipeline Buffer WE
  //
  // Reconfigurable length buffer to deal with SNN TW delay,	
  // If in SNN mode add TW pipeline stage for the weights, If in ANN
  // dat ais flowing through MAC
  // *************************************************************

  logic [TW-1:0][I_W+$bits(ns_data_in.signals)-1:0] buffer_b_q;

  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      buffer_b_q <= '0;
    end else begin
      buffer_b_q[0] <= {ns_data_in.signals, ns_data_in.weight};
      for (int i = 1; i < TW; i++) begin
        buffer_b_q[i] <= buffer_b_q[i-1];
      end
    end
  end

  // *************************************************************
  // Adder
  // *************************************************************

  logic [MULT_OUT-1:0] adder_input_a;
  logic [O_W-1:0] adder_input_b;
  logic [O_W-1:0] adder_output;

  assign adder_output = adder_input_b + O_W'(adder_input_a);

  // *************************************************************
  // Multiplier Clock Gating
  // *************************************************************

  // Gate the multiplier clock when in SNN mode
  logic mult_clk_en;
  logic mult_gated_clk;

  assign mult_clk_en = !snn_i;  // Enable clock only in ANN mode

  // SKY130 Integrated Clock Gating Cell
  sky130_fd_sc_hd__dlclkp_1 icg_mult (
      .CLK (clk_i),
      .GATE(mult_clk_en),
      .GCLK(mult_gated_clk)
  );

  // *************************************************************
  // Multiplier
  // *************************************************************

  logic [MULT_OUT-1:0] mult_out;
  // output valid after MULT_STAGES # of cycles have passed
  simple_mult #(
      .STAGES(MULT_STAGES)
  ) mult (
      .clk_i(mult_gated_clk),
      .rst_ni(rst_ni),
      .a_i(snn_i ? a_i : 0),
      .b_i(weight_i),
      .c_o(mult_out)
  );

  // *************************************************************
  // Combinational
  // *************************************************************

  always_comb begin
    acc_pipe_d = acc_pipe_q;
    adder_input_a = 0;
    adder_input_b = 0;
    fired_o = 0;
    ns_data_out = '0;

    // if in SNN mode
    if (snn_i) begin
      // Set adder_input_b for SNN mode
      if (ns_data_in.signals.flush) begin
        adder_input_b = 0;
      end else begin
        adder_input_b = O_W'(acc_pipe_q[0]);
      end
      // output weight bundle
      ns_data_out = '{
          signals:
          ns_signals_t
          '(
          buffer_b_q[TW-1][$bits(buffer_b_q[0])-1:$bits(buffer_b_q[0])-$bits(ns_data_in.signals)]
          ),
          _empty: '0,
          weight: buffer_b_q[TW-1][I_W-1:0]
      };
      // create a ring buffer
      for (int i = 0; i < TW - 1; i++) begin
        acc_pipe_d[i] = acc_pipe_q[i+1];
      end
      // load sums into registers
      if (~ns_data_in.signals.process) begin
        adder_input_a[I_W-1:0] = a_i[0] ? ns_data_in.weight : 0;
        // if in integrate mode, accumulate and saturate, write to tail since
        // right now we are reading from the head
        acc_pipe_d[TW-1] = (adder_output[I_W]) ? {I_W{1'b1}} : adder_output[I_W-1:0];
      end else begin
        // change b out to final cell when processing
        // adder_input_b = O_W'(acc_q.cells[cell_select_i]);
        if (ns_data_in.signals.first) begin
          ns_data_out.weight = acc_pipe_q[TW-1];
          adder_input_a[I_W-1:0] = ns_data_in.weight;
        end else begin
          adder_input_a[I_W-1:0] = acc_pipe_q[TW-1];
        end

        fired_o = adder_output[I_W:0] >= ((I_W + 1)'(v_thresh_i));
        if (fired_o) begin
          acc_pipe_d[TW-1] = 0;
        end else begin
          acc_pipe_d[TW-1] = adder_output[I_W-1:0];
        end
      end
    end else begin
      // ANN mode
      // this is the same as b_i. I am using it because it suppresses lint
      // warning for not using _empty
      adder_input_b = ns_data_in;
      adder_input_a = mult_out;
      acc_pipe_d = adder_output;
      ns_data_out = acc_pipe_q;
    end
  end
endmodule
