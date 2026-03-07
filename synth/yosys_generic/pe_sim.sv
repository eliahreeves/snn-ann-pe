
module pe_sim (
    input  logic clk_i,
    input  logic rst_ni,
    output logic led_o
);

pe #(
    .CyclesPerToggle(100)
) pe (.*);

endmodule
