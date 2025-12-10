module LoadStoreUnit (
    input  logic [ 3:0] sl_type,
    input  logic [31:0] addr,
    input  logic [31:0] load_data_i,
    output logic [31:0] load_data_o,
    input  logic [31:0] store_data_i,
    output logic [31:0] store_data_o,
    input  logic        dram_we,
    output logic [ 3:0] wstrb          // 按位写使能
);
    // [TODO] 添加对于LB/LH/SB/SH等访存的支持

endmodule
