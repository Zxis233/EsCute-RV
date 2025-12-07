`include "include/defines.svh"

module Decoder (
    input  logic [31:0] instr,
    output logic [ 4:0] alu_op,
    // ALU 第一操作数来源
    output logic        is_auipc,
    // ALU 第二操作数来源
    output logic        alu_src,
    // 写使能
    output logic        dram_we,          // 高电平为写使能 低电平为读
    output logic        rf_we,
    // 写回数据来源
    output logic [ 1:0] wd_sel,
    // 分支相关
    output logic        is_branch_instr,
    output logic [ 2:0] branch_type,
    // 跳转相关
    output logic [ 1:0] jump_type,
    // 数据读取类型
    output logic [ 1:0] load_type,
    // 源寄存器是否在使用
    output logic        rs1_used,
    output logic        rs2_used
);

    // 提取指令字段
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = instr[6:0];
        funct3 = instr[14:12];
        funct7 = instr[31:25];

    end

    // 跳转类型判断
    // assign jump_type = (opcode == `OPCODE_JAL) ?
    //     `JUMP_JAL : (opcode == `OPCODE_JALR) ? `JUMP_JALR : `JUMP_NOP;
    always_comb begin
        case (opcode)
            `OPCODE_JAL:  jump_type = `JUMP_JAL;
            `OPCODE_JALR: jump_type = `JUMP_JALR;
            default:      jump_type = `JUMP_NOP;
        endcase
    end

    // 源寄存器读取判断
    // 反向判断简化逻辑 记得去除ERROR
    // rs1：除了 LUI/AUIPC/JAL 之外都用到
    assign rs1_used = ~((opcode == `OPCODE_LUI) || (opcode == `OPCODE_AUIPC) ||
                        (opcode == `OPCODE_JAL) || (opcode == `OPCODE_ZERO));
    // // rs2：只有 R-type / B-type / S-type 用到
    assign rs2_used = (opcode == `OPCODE_RTYPE) || (opcode == `OPCODE_BTYPE) ||
        (opcode == `OPCODE_STYPE);


    // [HACK] Icarus Verilog 不支持 inside 语法糖 :(
    // assign rs1_used = !(opcode inside {
    //     `OPCODE_LUI,
    //     `OPCODE_AUIPC,
    //     `OPCODE_JAL
    // });
    // assign rs2_used = (opcode inside {
    //     `OPCODE_RTYPE,
    //     `OPCODE_BTYPE,
    //     `OPCODE_STYPE
    // });


    // 分支类型判断
    // 看funct3决定具体的分支类型
    // assign is_branch_instr = (opcode == `OPCODE_BTYPE);
    // assign branch_type = funct3;

    // ALU 第一操作数来源
    // 判断是否为 AUIPC 指令即可
    assign is_auipc = (opcode == `OPCODE_AUIPC);

    // ALU 第二操作数来源
    // verilog_format:off
    always_comb begin : alu_src_selection
        unique case (opcode)
            `OPCODE_RTYPE,
            `OPCODE_BTYPE:  alu_src = `ALUSRC_RS2;  // 来自寄存器 rs2

            `OPCODE_ITYPE,
            `OPCODE_LTYPE,
            `OPCODE_STYPE,
            `OPCODE_AUIPC,
            `OPCODE_JALR:
                            alu_src = `ALUSRC_IMM;  // 来自立即数

            default:        alu_src = `ALUSRC_RS2;
        endcase
    end
    // verilog_format:on

    // 回写数据来源选择
    // verilog_format:off
    always_comb begin : wb_source_selection
        unique case (opcode)
            `OPCODE_RTYPE,
            `OPCODE_ITYPE:  wd_sel = `WD_SEL_FROM_ALU;

            `OPCODE_LTYPE:  wd_sel = `WD_SEL_FROM_DRAM;

            `OPCODE_JAL,
            `OPCODE_JALR:   wd_sel = `WD_SEL_FROM_PC4;

            `OPCODE_LUI,
            `OPCODE_AUIPC:  wd_sel = `WD_SEL_FROM_IEXT;

            default:        wd_sel = 2'b0;
        endcase
    end
    // verilog_format:on

    // 寄存器堆写使能
    // verilog_format:off
    always_comb begin : rf_write_enable
        unique case (opcode)
            `OPCODE_RTYPE,
            `OPCODE_ITYPE,
            `OPCODE_LTYPE,
            `OPCODE_LUI,
            `OPCODE_AUIPC,
            `OPCODE_JAL,
            `OPCODE_JALR:   rf_we = 1'b1;

            `OPCODE_BTYPE,
            `OPCODE_STYPE:  rf_we = 1'b0;

            default:        rf_we = 1'b0;  // 考虑异常情况 默认不写
        endcase
    end
    // verilog_format:on

    // 数据存储器写使能
    assign dram_we = (opcode == `OPCODE_STYPE) ? 1'b1 : 1'b0;

    // ALU 操作码生成
    // verilog_format:off
    always_comb begin : ALUOp_selection
        // 默认值
        alu_op          = `ALU_NOP;
        branch_type     = `BRANCH_NOP;
        is_branch_instr = 1'b0;

        unique case (opcode)

            `OPCODE_RTYPE, `OPCODE_ITYPE: begin
                unique case (funct3)
                    `FUNCT3_ADD_SUB_MUL:
                    // [HACK] 使用 case-true 结构
                    // alu_op = (opcode == `OPCODE_RTYPE ?
                    //           ((funct7 == `FUNCT7_SUB) ?
                    //                                  `ALU_SUB : `ALU_ADD)
                    //                                : `ALU_ADD);
                        case (1'b1)
                            (opcode == `OPCODE_RTYPE) &&        // R-Type SUB
                            (funct7 == `FUNCT7_SUB):
                                            alu_op = `ALU_SUB;

                            (opcode == `OPCODE_RTYPE):          // R-Type 其它（默认为 ADD）
                                            alu_op = `ALU_ADD;

                            default:                            // 非 R-type（同样默认 ADD）
                                            alu_op = `ALU_ADD;
                        endcase

                    `FUNCT3_SLL_MULH:       alu_op = `ALU_SLL;
                    `FUNCT3_SLT_MULHSU:     alu_op = `ALU_SLT;
                    `FUNCT3_SLTU_MULHU:     alu_op = `ALU_SLTU;
                    `FUNCT3_XOR_DIV:        alu_op = `ALU_XOR;
                    `FUNCT3_SRL_SRA_DIVU:   alu_op = (funct7 == `FUNCT7_SRA) ?
                                                     `ALU_SRA : `ALU_SRL;
                    `FUNCT3_OR_REM:         alu_op = `ALU_OR;
                    `FUNCT3_AND_REMU:       alu_op = `ALU_AND;
                    default:                alu_op = `ALU_NOP;  // 默认为空
                endcase
            end

            `OPCODE_BTYPE: begin
                alu_op = (funct3 == `FUNCT3_BLTU || funct3 == `FUNCT3_BGEU) ? `ALU_SLTU :
                    `ALU_SUB;  // 用于比较是否为有符号/无符号
                // 判断分支类型
                unique case (funct3)
                    `FUNCT3_BEQ:  branch_type = `BRANCH_BEQ;
                    `FUNCT3_BNE:  branch_type = `BRANCH_BNE;
                    `FUNCT3_BLT:  branch_type = `BRANCH_BLT;
                    `FUNCT3_BGE:  branch_type = `BRANCH_BGE;
                    `FUNCT3_BLTU: branch_type = `BRANCH_BLTU;
                    `FUNCT3_BGEU: branch_type = `BRANCH_BGEU;
                    default:      branch_type = `BRANCH_NOP;
                endcase

                is_branch_instr = 1'b1;

            end

            `OPCODE_JAL,
            `OPCODE_LUI:            alu_op = `ALU_RIGHT;  // 特殊指令

            `OPCODE_JALR,
            `OPCODE_AUIPC:          alu_op = `ALU_ADD;

            `OPCODE_LTYPE: begin
                unique case (funct3)
                    `FUNCT3_LB:     alu_op = `ALU_LB;
                    `FUNCT3_LBU:    alu_op = `ALU_LBU;
                    `FUNCT3_LH:     alu_op = `ALU_LH;
                    `FUNCT3_LHU:    alu_op = `ALU_LHU;
                    `FUNCT3_LW:     alu_op = `ALU_LW;
                    default:        alu_op = `ALU_NOP;
                endcase
            end

            `OPCODE_STYPE: begin
                unique case (funct3)
                    `FUNCT3_SB:     alu_op = `ALU_SB;
                    `FUNCT3_SH:     alu_op = `ALU_SH;
                    `FUNCT3_SW:     alu_op = `ALU_SW;
                    default:        alu_op = `ALU_NOP;
                endcase
            end

            default:                alu_op = `ALU_NOP;  // 默认加法
        endcase
    end
    // verilog_format:on

    // 可视化输出判断
    //verilog_format:off
`ifdef DEBUG
  // 方便调试的 ASCII 指令输出
  logic [256-1:0] instr_ascii;
  logic [256-1:0] branch_type_ascii;

  always_comb begin : ascii_output
    unique case (branch_type)
      `BRANCH_NOP:        branch_type_ascii = "BRANCH_NOP";
      `BRANCH_BEQ:        branch_type_ascii = "BRANCH_BEQ";
      `BRANCH_BNE:        branch_type_ascii = "BRANCH_BNE";
      `BRANCH_BLT:        branch_type_ascii = "BRANCH_BLT";
      `BRANCH_BGE:        branch_type_ascii = "BRANCH_BGE";
      `BRANCH_BLTU:       branch_type_ascii = "BRANCH_BLTU";
      `BRANCH_BGEU:       branch_type_ascii = "BRANCH_BGEU";
      `BRANCH_JALR:       branch_type_ascii = "BRANCH_JALR";
      default:            branch_type_ascii = "BRANCH_UNKNOWN";
    endcase
    // 判断当前具体为32条基本指令的哪一条
    unique case (opcode)
      `OPCODE_LUI:              instr_ascii = "LUI";
      `OPCODE_AUIPC:            instr_ascii = "AUIPC";
      `OPCODE_JAL:              instr_ascii = "JAL";
      `OPCODE_JALR:             instr_ascii = "JALR";

      `OPCODE_BTYPE: begin
        unique case (funct3)
          `FUNCT3_BEQ:          instr_ascii = "BEQ";
          `FUNCT3_BNE:          instr_ascii = "BNE";
          `FUNCT3_BLT:          instr_ascii = "BLT";
          `FUNCT3_BGE:          instr_ascii = "BGE";
          `FUNCT3_BLTU:         instr_ascii = "BLTU";
          `FUNCT3_BGEU:         instr_ascii = "BGEU";
          default:              instr_ascii = "B_UNKNOWN";
        endcase
      end

      `OPCODE_LTYPE: begin
        unique case (funct3)
          `FUNCT3_LB:           instr_ascii = "LB";
          `FUNCT3_LH:           instr_ascii = "LH";
          `FUNCT3_LW:           instr_ascii = "LW";
          `FUNCT3_LBU:          instr_ascii = "LBU";
          `FUNCT3_LHU:          instr_ascii = "LHU";
          default:              instr_ascii = "L_UNKNOWN";
        endcase
      end

      `OPCODE_STYPE: begin
        unique case (funct3)
          `FUNCT3_SB:           instr_ascii = "SB";
          `FUNCT3_SH:           instr_ascii = "SH";
          `FUNCT3_SW:           instr_ascii = "SW";
          default:              instr_ascii = "S_UNKNOWN";
        endcase
      end

      `OPCODE_ITYPE: begin
        unique case (funct3)
          `FUNCT3_ADD_SUB_MUL:  instr_ascii = "ADDI";
          `FUNCT3_SLL_MULH:     instr_ascii = "SLLI";
          `FUNCT3_SLT_MULHSU:   instr_ascii = "SLTI";
          `FUNCT3_SLTU_MULHU:   instr_ascii = "SLTIU";
          `FUNCT3_XOR_DIV:      instr_ascii = "XORI";
          `FUNCT3_SRL_SRA_DIVU: instr_ascii = (funct7 == `FUNCT7_SRAI) ? "SRAI" : "SRLI";
          `FUNCT3_OR_REM:       instr_ascii = "ORI";
          `FUNCT3_AND_REMU:     instr_ascii = "ANDI";
          default:              instr_ascii = "I_UNKNOWN";
        endcase
      end

      `OPCODE_RTYPE: begin
        unique case (funct3)
          `FUNCT3_ADD_SUB_MUL: begin
            if (funct7 == `FUNCT7_SUB)
                                instr_ascii = "SUB";
            else if (funct7 == `FUNCT7_ADD)
                                instr_ascii = "ADD";
            else                instr_ascii = "R_UNKNOWN";
          end
          `FUNCT3_SLL_MULH:     instr_ascii = "SLL";
          `FUNCT3_SLT_MULHSU:   instr_ascii = "SLT";
          `FUNCT3_SLTU_MULHU:   instr_ascii = "SLTU";
          `FUNCT3_XOR_DIV:      instr_ascii = "XOR";
          `FUNCT3_SRL_SRA_DIVU: begin
            if (funct7 == `FUNCT7_SRA)
                                instr_ascii = "SRA";
            else if (funct7 == `FUNCT7_SRL)
                                instr_ascii = "SRL";
            else                instr_ascii = "R_UNKNOWN";
          end
          `FUNCT3_OR_REM:       instr_ascii = "OR";
          `FUNCT3_AND_REMU:     instr_ascii = "AND";
          default:              instr_ascii = "R_UNKNOWN";
        endcase
      end

      default:                  instr_ascii = "ERROR";
    endcase
  end
`endif
    // verilog_format:on


endmodule
