(* blackbox *)
module DRAM #(
    parameter int unsigned ADDR_WIDTH = 12
) (
    input  logic                  clk,
    input  logic [ADDR_WIDTH-1:0] a,
    output logic [          31:0] spo,
    input  logic [           3:0] we,
    input  logic [          31:0] din
);
endmodule
