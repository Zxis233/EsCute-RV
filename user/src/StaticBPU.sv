`include "include/defines.svh"

module StaticBPU (
    input  logic        valid_i,
    input  logic        is_branch_instr_i,
    input  logic [ 1:0] jump_type_i,
    input  logic [31:0] imm_i,
    input  logic [31:0] branch_target_i,
    output logic        predict_taken_o,
    output logic [31:0] predict_target_o
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

endmodule
