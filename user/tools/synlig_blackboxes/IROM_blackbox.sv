(* blackbox *)
module IROM #(
    parameter int unsigned ADDR_WIDTH = 14
) (
    input  logic [ADDR_WIDTH-1:0] a,
    output logic [          31:0] spo
);
endmodule
