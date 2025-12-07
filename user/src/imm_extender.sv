`include "include/defines.svh"

module imm_extender (
    input  logic [31:0] instr,
    output logic [31:0] imm_out
);
    logic [6:0] opcode;
    assign opcode = instr[6:0];

    always_comb begin : imm_classifier
        unique case (opcode)
            `OPCODE_ITYPE, `OPCODE_LTYPE, `OPCODE_JALR: begin  // I-type
                // 先输出立即数
                // 之后再根据 instr[30] 区分 SLLI/SRLI和SRAI
                imm_out = {{20{instr[31]}}, instr[31:20]};
            end
            `OPCODE_BTYPE: begin  // B-type
                imm_out = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
            end
            `OPCODE_JAL: begin  // J-type
                imm_out = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
            end
            `OPCODE_STYPE: begin  // S-type
                imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            end
            `OPCODE_AUIPC, `OPCODE_LUI: begin  // U-type
                imm_out = {instr[31:12], 12'b0};
            end

            default: begin
                imm_out = 32'b0;
            end
        endcase
    end

endmodule
