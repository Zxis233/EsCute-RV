`include "include/defines.svh"

module PC (
    input  logic        clk,
    input  logic        rst_n,
    // 是否要打一拍 保持PC不变
    input  logic        keep_pc,
    // 进行分支跳转
    input  logic        branch_op,
    // 分支跳转目标地址
    input  logic [31:0] branch_target,
    output logic [31:0] pc_if,
    output logic [31:0] pc4_if
);
    assign pc4_if = pc_if + 4;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)         pc_if <= `INITIAL_PC;
        else if (branch_op) pc_if <= branch_target;
        else if (keep_pc)   pc_if <= pc_if;
        else                pc_if <= pc4_if;
    end

endmodule
