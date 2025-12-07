`include "include/defines.svh"

module ALU (
    // 操作码
    input  logic [ 4:0] alu_op,
    // 操作数
    input  logic [31:0] src1,
    input  logic [31:0] src2,
    // 来自ID/EX级的立即数
    input  logic [31:0] imm,
    // 第二操作数选择 0: src2 1: imm
    input  logic        alu_src2_sel,
    // 结果输出
    output logic [31:0] alu_result,
    // 标志位输出
    output logic        zero,
    output logic        sign,
    output logic        alu_unsigned
);
    logic [31:0] src2_inner;

    assign src2_inner = (alu_src2_sel) ? imm : src2;

    // 运算操作
    always_comb begin : alu_operation
        case (alu_op)
            // 基础运算
            `ALU_ADD:   alu_result = src1 + src2_inner;
            `ALU_SUB:   alu_result = src1 - src2_inner;  // src1 + (~src2 + 1)
            `ALU_OR:    alu_result = src1 | src2_inner;
            `ALU_AND:   alu_result = src1 & src2_inner;
            `ALU_XOR:   alu_result = src1 ^ src2_inner;
            `ALU_SLL:   alu_result = src1 << src2_inner[4:0];
            `ALU_SRL:   alu_result = src1 >> src2_inner[4:0];
            // 必须显式声明src1为有符号数
            `ALU_SRA:   alu_result = $signed(src1) >>> src2_inner[4:0];
            `ALU_SLT:   alu_result = ($signed(src1) < $signed(src2_inner)) ? 1 : 0;
            `ALU_SLTU:  alu_result = (src1 < src2_inner) ? 1 : 0;
            `ALU_RIGHT: alu_result = src2_inner;  // 用于AUIPC指令
            // L-Type
            `ALU_LW:    alu_result = src1 + src2_inner;  // 地址计算
            // [TODO] 非对齐访存
            //S-Type
            `ALU_SW:    alu_result = src1 + src2_inner;  // 地址计算
            default:    alu_result = 0;
        endcase
    end

    // Load/Store指令使用的地址计算不放在ALU内
    // 拆分为独立模块 LoadStoreUnit

    // 标志位输出
    always_comb begin
        zero         = (alu_result == 32'b0);
        sign         = alu_result[31];
        alu_unsigned = (src1 < src2_inner);
    end

`ifdef DEBUG
    // 方便调试的 ASCII 指令输出
    logic [64-1:0] aluop_ascii;
    always_comb begin : aluop_ascii_output
        case (alu_op)
            `ALU_ADD:   aluop_ascii = "AADD";
            `ALU_SUB:   aluop_ascii = "ASUB";
            `ALU_OR:    aluop_ascii = "AOR";
            `ALU_AND:   aluop_ascii = "AAND";
            `ALU_XOR:   aluop_ascii = "AXOR";
            `ALU_SLL:   aluop_ascii = "ASLL";
            `ALU_SRL:   aluop_ascii = "ASRL";
            `ALU_SRA:   aluop_ascii = "ASRA";
            `ALU_SLT:   aluop_ascii = "ASLT";
            `ALU_SLTU:  aluop_ascii = "ASLTU";
            `ALU_RIGHT: aluop_ascii = "ARGHT";
            `ALU_LW:    aluop_ascii = "ALW";
            `ALU_SW:    aluop_ascii = "ASW";
            default:    aluop_ascii = "ANOP";
        endcase
    end
`endif

endmodule
