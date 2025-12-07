`include "include/defines.svh"

module LoadStoreUnit #(
    parameter int unsigned XLEN = 32
) (
    input logic [XLEN-1:0] addr,
    input logic [     1:0] load_type
);
    // [TODO] 非对齐访存

endmodule
