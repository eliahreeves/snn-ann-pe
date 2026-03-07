
module pe_tb
    import config_pkg::*;
    import dv_pkg::*;
    ;

import "DPI-C" function void example_dpi();
pe_runner pe_runner ();

initial begin
    $dumpfile( "dump.fst" );
    $dumpvars;
    $display( "Begin simulation." );
    $urandom(100);
    $timeformat( -3, 3, "ms", 0);

    pe_runner.reset();

    repeat(4) begin
        pe_runner.wait_for_on();
        pe_runner.wait_for_off();
    end

    $display( "End simulation." );
    $finish;
end

endmodule
