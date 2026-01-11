`include "include/defines.svh"

module RegisterF (
    input  logic        clk,
    // input  logic            rst_n,
    input  logic        rf_we,
    // 读地址端口
    input  logic [ 4:0] rR1,
    input  logic [ 4:0] rR2,
    // 写地址端口1 (主流水线)
    input  logic [ 4:0] wR,
    // 写数据端口1 (主流水线)
    input  logic [31:0] wD,
    // 写端口2 (乘法器)
    input  logic        rf_we2,
    input  logic [ 4:0] wR2,
    input  logic [31:0] wD2,
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

    // 写入使用时序逻辑 - 支持双写端口
    // 当两个端口同时写入同一寄存器时主流水线端口优先
    // 因乘法为长指令 后写回的短指令在时序上更靠后因此结果更新
    // 应当采用更新的寄存器值
    always_ff @(posedge clk) begin
        // 主流水线写端口
        if (rf_we && wR != 5'd0) begin
            rf_in[wR] <= wD;
        end
        // 乘法器写端口（优先级更低）
        if (rf_we2 && wR2 != 5'd0 && !(rf_we && wR == wR2)) begin
            rf_in[wR2] <= wD2;
        end
    end

    // 读取使用组合逻辑
    always_comb begin
        rD1 = (rR1 == 0) ? {32{1'b0}} : rf_in[rR1];  // x0寄存器恒为0
        rD2 = (rR2 == 0) ? {32{1'b0}} : rf_in[rR2];
    end

endmodule