`include "include/defines.svh"

module Static_Predictor #(
    parameter int unsigned META_BITS = 8
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 valid_i,
    input  logic [         31:0] pc_i,
    input  logic                 is_branch_instr_i,
    input  logic [          1:0] jump_type_i,
    input  logic [         31:0] imm_i,
    input  logic [         31:0] branch_target_i,
    input  logic                 update_valid_i,
    input  logic [         31:0] update_pc_i,
    input  logic                 update_is_branch_i,
    input  logic                 update_taken_i,
    input  logic [META_BITS-1:0] update_meta_i,
    output logic                 predict_taken_o,
    output logic [         31:0] predict_target_o,
    output logic [META_BITS-1:0] predict_meta_o
);

    // 静态预测策略：
    // - JAL: 恒预测跳转
    // - JALR: 目标依赖寄存器，不在ID级预测
    // - 条件分支: Backward Taken, Forward Not Taken
    always_comb begin
        predict_taken_o  = 1'b0;
        predict_target_o = branch_target_i;

        if (valid_i) begin
            unique case (jump_type_i)
                `JUMP_JAL:  predict_taken_o = 1'b1;
                `JUMP_JALR: predict_taken_o = 1'b0;
                default: begin
                    if (is_branch_instr_i) begin
                        predict_taken_o = imm_i[31];
                    end
                end
            endcase
        end
    end

    // 统一BPU接口保留训练端口，静态预测器不使用这些信号。
    assign predict_meta_o = '0;

    logic unused_signals;
    assign unused_signals = clk ^ rst_n ^ pc_i[0] ^ update_valid_i ^ update_pc_i[0] ^
        update_is_branch_i ^ update_taken_i ^ update_meta_i[0];

endmodule
