`include "include/defines.svh"

module RegisterF (
    input  logic        clk,
    // input  logic            rst_n,
    input  logic        rf_we,
    // 读地址端口
    input  logic [ 4:0] rR1,
    input  logic [ 4:0] rR2,
    // 写地址端口
    input  logic [ 4:0] wR,
    // 写数据端口
    input  logic [31:0] wD,
    // 读数据端口
    output logic [31:0] rD1,
    output logic [31:0] rD2
);

    logic [31:0] rf_in[32];  // 32个寄存器 unpacked 维度使用 [32]

    // 初始化：x0 = 0
    // 便于Yosys综合识别
    initial begin
        rf_in[0] = '0;  // 初始 x0 = 0
    end

    // 写入使用时序逻辑
    always_ff @(posedge clk) begin
        if (rf_we && wR != 5'd0) rf_in[wR] <= wD;
    end

    // 读取使用组合逻辑
    always_comb begin
        rD1 = (rR1 == 0) ? {32{1'b0}} : rf_in[rR1];  // x0寄存器恒为0
        rD2 = (rR2 == 0) ? {32{1'b0}} : rf_in[rR2];
    end

endmodule
