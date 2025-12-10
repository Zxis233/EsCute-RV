`include "include/defines.svh"

module NextPC_Generator (
    input  logic        is_branch_instr,
    input  logic [ 2:0] branch_type,
    input  logic [ 1:0] jump_type,
    // ALU计算结果输入
    input  logic [31:0] alu_result,
    // PC加立即数输入
    input  logic [31:0] branch_target_i,
    // ALU标志位输入
    input  logic        alu_zero,
    input  logic        alu_sign,
    input  logic        alu_unsigned,
    // PC控制输出
    output logic        take_branch,
    output logic [31:0] branch_target_NextPC

);

    // verilog_format:off
    always_comb begin
        if (jump_type)        take_branch = 1'b1;
        else if (is_branch_instr) begin
            unique case (branch_type)
                `BRANCH_BEQ:  take_branch = alu_zero;
                `BRANCH_BNE:  take_branch = ~alu_zero;
                `BRANCH_BLT:  take_branch = alu_sign;
                `BRANCH_BGE:  take_branch = ~alu_sign;
                `BRANCH_BLTU: take_branch = alu_unsigned;
                `BRANCH_BGEU: take_branch = ~alu_unsigned;
                default:      take_branch = 1'b0;
            endcase
        end else              take_branch = 1'b0;

    end

    // JALR 需要将最低位置0
    assign branch_target_NextPC = (jump_type == `JUMP_JALR) ?
                                  {alu_result[31:1], 1'b0} : branch_target_i;

    // verilog_format:on

endmodule
