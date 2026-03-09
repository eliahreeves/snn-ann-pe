
package config_pkg;

  // Global parameters for the design
  localparam int I_W = 8;   // Input/activation width
  localparam int O_W = 32;  // Output/accumulator width
  localparam int TW = O_W / I_W;  // Temporal window size

  // North-South signals for PE array communication
  typedef struct packed {
    logic process;  // Processing mode (vs integration mode)
    logic flush;    // Flush accumulator
    logic first;    // First cycle of processing
  } ns_signals_t;

  // North-South data bundle
  typedef struct packed {
    ns_signals_t signals;
    logic [O_W-I_W-4:0] _empty;  // Padding to fill O_W bits
    logic [I_W-1:0] weight;
  } ns_data_t;

endpackage
