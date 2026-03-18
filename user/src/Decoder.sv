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
    output logic [ 2:0] wd_sel,
    // 分支相关
    output logic        is_branch_instr,
    output logic [ 2:0] branch_type,
    // 跳转相关
    output logic [ 1:0] jump_type,
    // 数据读取类型
    output logic [ 3:0] sl_type,
    // 源寄存器是否在使用
    output logic        rs1_used,
    output logic        rs2_used,
    // 乘法指令标识
    output logic        is_mul_instr,
    output logic [ 1:0] mul_op,
    // CSR相关输出
    output logic        is_csr_instr,     // CSR指令标识
    output logic [ 2:0] csr_op,           // CSR操作类型 (funct3)
    output logic [11:0] csr_addr,         // CSR地址
    output logic        is_ecall,         // ECALL指令
    output logic        is_mret,          // MRET指令
    output logic        is_sret,          // SRET指令
    output logic        is_lpad_instr,    // LPAD 指令标识
    // 非法指令检测
    output logic        is_illegal_instr  // 非法指令标识
);

    // 提取指令字段
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    always_comb begin
        opcode = opcode_e'(instr[6:0]);
        funct3 = instr[14:12];
        funct7 = instr[31:25];
    end

    // 乘法指令预检测 - 用于简化后续逻辑
    logic is_mul_funct3;
    assign is_mul_funct3 = (funct3 == `FUNCT3_ADD_SUB_MUL) || (funct3 == `FUNCT3_SLL_MULH) ||
        (funct3 == `FUNCT3_SLT_MULHSU) || (funct3 == `FUNCT3_SLTU_MULHU);

    logic is_lpad_internal;
    logic is_sspush_internal;
    logic is_sspopchk_internal;
    logic is_ssrdp_encoding;
    logic is_ssrdp_internal;

    assign is_lpad_internal = ((instr & `MASK_LPAD) == `MATCH_LPAD);
    assign is_sspush_internal = ((instr & `MASK_SSPUSH) == `MATCH_SSPUSH);
    assign is_ssrdp_encoding = ((instr & `MASK_SSRDP) == `MATCH_SSRDP);
    assign is_ssrdp_internal = is_ssrdp_encoding && (instr[11:7] != 5'd0);
    assign is_sspopchk_internal = !is_ssrdp_encoding &&
                                  ((instr & `MASK_SSPOPCHK) == `MATCH_SSPOPCHK);
    assign is_lpad_instr = is_lpad_internal;

    // 内部乘法指令信号（用于wd_sel和rf_we判断）
    logic is_mul_internal;
    assign is_mul_internal = (opcode == OPCODE_RTYPE) && (funct7 == `FUNCT7_MUL) && is_mul_funct3;

    // 跳转类型判断
    always_comb begin
        case (opcode)
            OPCODE_JAL:  jump_type = `JUMP_JAL;
            OPCODE_JALR: jump_type = `JUMP_JALR;
            default:     jump_type = `JUMP_NOP;
        endcase
    end

    // 源寄存器读取判断
    // 反向判断简化逻辑 记得去除ERROR
    // rs1：除了 LUI/AUIPC/JAL 之外都用到 (CSR immediate variants don't use rs1)
    // CSRRWI, CSRRSI, CSRRCI use zimm instead of rs1
    logic csr_use_imm;
    assign csr_use_imm = (opcode == OPCODE_ZICSR) &&
        (funct3[2] == 1'b1);  // funct3[2]=1 for immediate variants

    assign rs1_used = (is_sspush_internal || is_sspopchk_internal) ? 1'b1 :
        (is_lpad_internal || is_sspush_internal || is_ssrdp_encoding) ? 1'b0 :
        ~((opcode == OPCODE_LUI) || (opcode == OPCODE_AUIPC) || (opcode == OPCODE_JAL) ||
          (opcode == OPCODE_ZERO) || csr_use_imm ||
          ((opcode == OPCODE_ZICSR) && (funct3 == `FUNCT3_CALL)));  // ECALL/MRET/SRET don't use rs1
    // // rs2：只有 R-type / B-type / S-type 用到
    assign rs2_used = (opcode == OPCODE_RTYPE) || (opcode == OPCODE_BTYPE) || (opcode == OPCODE_STYPE);


    // [HACK] Icarus Verilog 不支持 inside 语法糖 :(
    // assign rs1_used = !(opcode inside {
    //     OPCODE_LUI,
    //     OPCODE_AUIPC,
    //     OPCODE_JAL
    // });
    // assign rs2_used = (opcode inside {
    //     OPCODE_RTYPE,
    //     OPCODE_BTYPE,
    //     OPCODE_STYPE
    // });


    // ALU 第一操作数来源
    // 判断是否为 AUIPC 指令即可
    assign is_auipc = (opcode == OPCODE_AUIPC) && !is_lpad_internal;

    // ALU 第二操作数来源
    // verilog_format:off
    always_comb begin : alu_src_selection
        unique case (opcode)
            OPCODE_RTYPE,
            OPCODE_BTYPE:  alu_src = `ALUSRC_RS2;  // 来自寄存器 rs2

            OPCODE_ITYPE,
            OPCODE_LTYPE,
            OPCODE_STYPE,
            OPCODE_AUIPC,
            OPCODE_JALR:
                            alu_src = `ALUSRC_IMM;  // 来自立即数

            default:        alu_src = `ALUSRC_RS2;
        endcase
    end
    // verilog_format:on

    // 回写数据来源选择
    // verilog_format:off
    always_comb begin : wb_source_selection
        // 首先检测是否为乘法指令
        if (is_mul_internal) begin
            wd_sel = `WD_SEL_FROM_MUL;
        end else if (is_ssrdp_internal) begin
            wd_sel = `WD_SEL_FROM_SSP;
        end else if (is_lpad_internal) begin
            wd_sel = 3'b0;
        end else begin
            unique case (opcode)
                OPCODE_RTYPE,
                OPCODE_ITYPE:  wd_sel = `WD_SEL_FROM_ALU;

                OPCODE_LTYPE:  wd_sel = `WD_SEL_FROM_DRAM;

                OPCODE_JAL,
                OPCODE_JALR:   wd_sel = `WD_SEL_FROM_PC4;

                OPCODE_LUI,
                OPCODE_AUIPC:  wd_sel = `WD_SEL_FROM_IEXT;

                OPCODE_ZICSR:  wd_sel = (funct3 != `FUNCT3_CALL) ? `WD_SEL_FROM_CSR : 3'b0;

                default:        wd_sel = 3'b0;
            endcase
        end
    end
    // verilog_format:on

    // 寄存器堆写使能
    // 乘法指令通过乘法器写回，不在此处设置rf_we
    // verilog_format:off
    always_comb begin : rf_write_enable
        // 首先检测是否为乘法指令
        if (is_mul_internal) begin
            rf_we = 1'b0;  // 乘法指令的写回由乘法器处理
        end else if (is_ssrdp_internal) begin
            rf_we = 1'b1;
        end else if (is_lpad_internal || is_sspush_internal || is_sspopchk_internal) begin
            rf_we = 1'b0;
        end else begin
            unique case (opcode)
                OPCODE_RTYPE,
                OPCODE_ITYPE,
                OPCODE_LTYPE,
                OPCODE_LUI,
                OPCODE_AUIPC,
                OPCODE_JAL,
                OPCODE_JALR:   rf_we = 1'b1;

                // CSR instructions write to rd (except ECALL/MRET which have funct3=0)
                OPCODE_ZICSR:  rf_we = (funct3 != `FUNCT3_CALL) && (instr[11:7] != 5'b0);

                OPCODE_BTYPE,
                OPCODE_STYPE:  rf_we = 1'b0;

                default:        rf_we = 1'b0;  // 考虑异常情况 默认不写
            endcase
        end
    end
    // verilog_format:on

    // 数据存储器写使能
    assign dram_we = (opcode == OPCODE_STYPE) || is_sspush_internal;

    // ALU 操作码生成
    // verilog_format:off
    always_comb begin : ALUOp_selection
        // 默认值
        alu_op          = `ALU_NOP;
        branch_type     = `BRANCH_NOP;
        is_branch_instr = 1'b0;

        unique case (opcode)

            OPCODE_RTYPE, OPCODE_ITYPE: begin
                unique case (funct3)
                    `FUNCT3_ADD_SUB_MUL:
                    // 使用 case-true 结构
                        case (1'b1)
                            (opcode == OPCODE_RTYPE) &&        // R-Type SUB
                            (funct7 == `FUNCT7_SUB):
                                            alu_op = `ALU_SUB;

                            (opcode == OPCODE_RTYPE):          // R-Type 其它（默认为 ADD）
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

            OPCODE_BTYPE: begin
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

            OPCODE_JAL,
            OPCODE_LUI:            alu_op = `ALU_RIGHT;  // 特殊指令

            OPCODE_JALR,
            OPCODE_AUIPC:          alu_op = `ALU_ADD;

            OPCODE_LTYPE: begin
                unique case (funct3)
                    `FUNCT3_LB:     alu_op = `ALU_LB;
                    `FUNCT3_LBU:    alu_op = `ALU_LBU;
                    `FUNCT3_LH:     alu_op = `ALU_LH;
                    `FUNCT3_LHU:    alu_op = `ALU_LHU;
                    `FUNCT3_LW:     alu_op = `ALU_LW;
                    default:        alu_op = `ALU_NOP;
                endcase
            end

            OPCODE_STYPE: begin
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

    // 数据存取类型判断
    // verilog_format:off
    always_comb begin : sl_selection
        if (is_sspush_internal) begin
            sl_type = `MEM_SSPUSH;
        end else if (is_sspopchk_internal) begin
            sl_type = `MEM_SSPOPCHK;
        end else begin
            unique case (opcode)
                OPCODE_LTYPE: begin
                    case (funct3)
                        `FUNCT3_LB:     sl_type = `MEM_LB;
                        `FUNCT3_LBU:    sl_type = `MEM_LBU;
                        `FUNCT3_LH:     sl_type = `MEM_LH;
                        `FUNCT3_LHU:    sl_type = `MEM_LHU;
                        `FUNCT3_LW:     sl_type = `MEM_LW;
                        default:        sl_type = `MEM_NOP;
                    endcase
                end

                OPCODE_STYPE:begin
                    case (funct3)
                        `FUNCT3_SB:     sl_type = `MEM_SB;
                        `FUNCT3_SH:     sl_type = `MEM_SH;
                        `FUNCT3_SW:     sl_type = `MEM_SW;
                        default:        sl_type = `MEM_NOP;
                    endcase
                end
                default:                sl_type = `MEM_NOP;
            endcase
        end
    end

    // 乘法指令检测
    // 使用预计算的is_mul_internal信号简化逻辑
    // verilog_format:off
    always_comb begin : mul_detection
        is_mul_instr = is_mul_internal;
        // mul_op由funct3的低两位决定（仅在乘法指令时有意义）
        if (is_mul_internal) begin
            mul_op = funct3[1:0];  // MUL=00, MULH=01, MULHSU=10, MULHU=11
        end else begin
            mul_op = 2'b00;  // 非乘法指令时默认值
        end
    end
    // verilog_format:on

    // CSR指令检测和ECALL/MRET/SRET检测
    // verilog_format:off
    always_comb begin : csr_detection
        // 提取CSR地址
        csr_addr = instr[31:20];
        csr_op   = funct3;

        if (is_sspush_internal || is_sspopchk_internal || is_ssrdp_encoding) begin
            is_csr_instr = 1'b0;
            is_ecall     = 1'b0;
            is_mret      = 1'b0;
            is_sret      = 1'b0;
        end else if (opcode == OPCODE_ZICSR) begin
            if (funct3 == `FUNCT3_CALL) begin
                // ECALL: instr = 0x00000073
                // MRET:  instr = 0x30200073
                // SRET:  instr = 0x10200073
                is_csr_instr = 1'b0;
                is_ecall     = (instr[31:7] == 25'b0);
                is_mret      = (instr[31:7] == 25'b0011000000100000000000000);
                is_sret      = (instr[31:7] == 25'b0001000000100000000000000);
            end else begin
                // CSR instructions: CSRRW, CSRRS, CSRRC, CSRRWI, CSRRSI, CSRRCI
                is_csr_instr = 1'b1;
                is_ecall     = 1'b0;
                is_mret      = 1'b0;
                is_sret      = 1'b0;
            end
        end else begin
            is_csr_instr = 1'b0;
            is_ecall     = 1'b0;
            is_mret      = 1'b0;
            is_sret      = 1'b0;
        end
    end
    // verilog_format:on

    // 非法指令检测
    // 检测无效opcode、无效funct3/funct7组合、无效shamt等
    // verilog_format:off
    always_comb begin : illegal_instr_detection
        // 默认为合法指令
        is_illegal_instr = 1'b0;

        case (opcode)
            OPCODE_LUI,
            OPCODE_AUIPC,
            OPCODE_JAL: begin
                // U-type 和 J-type 指令无需额外检查
                is_illegal_instr = 1'b0;
            end

            OPCODE_JALR: begin
                // JALR 只有 funct3=000 是合法的
                is_illegal_instr = (funct3 != 3'b000);
            end

            OPCODE_BTYPE: begin
                // B-type: funct3 只有 000,001,100,101,110,111 是合法的
                // 010 和 011 是非法的
                is_illegal_instr = (funct3 == 3'b010) || (funct3 == 3'b011);
            end

            OPCODE_LTYPE: begin
                // Load: funct3 000,001,010,100,101 are valid (LB,LH,LW,LBU,LHU)
                // 011,110,111 are invalid
                is_illegal_instr = (funct3 == 3'b011) || (funct3 == 3'b110) || (funct3 == 3'b111);
            end

            OPCODE_STYPE: begin
                // Store: funct3 000,001,010 are valid (SB,SH,SW)
                // 011,100,101,110,111 are invalid
                is_illegal_instr = (funct3 == 3'b011) || (funct3 == 3'b100) || 
                                   (funct3 == 3'b101) || (funct3 == 3'b110) || (funct3 == 3'b111);
            end

            OPCODE_ITYPE: begin
                // I-type arithmetic instructions
                case (funct3)
                    `FUNCT3_ADD_SUB_MUL,  // ADDI
                    `FUNCT3_SLT_MULHSU,   // SLTI
                    `FUNCT3_SLTU_MULHU,   // SLTIU
                    `FUNCT3_XOR_DIV,      // XORI
                    `FUNCT3_OR_REM,       // ORI
                    `FUNCT3_AND_REMU: begin // ANDI
                        is_illegal_instr = 1'b0;
                    end
                    `FUNCT3_SLL_MULH: begin // SLLI
                        // RV32I: funct7 must be 0000000
                        // shamt is in instr[24:20], for RV32I it's 5 bits, always valid
                        is_illegal_instr = (funct7 != `FUNCT7_SLLI);
                    end
                    `FUNCT3_SRL_SRA_DIVU: begin // SRLI/SRAI
                        // SRLI: funct7 = 0000000
                        // SRAI: funct7 = 0100000
                        is_illegal_instr = (funct7 != `FUNCT7_SRLI) && (funct7 != `FUNCT7_SRAI);
                    end
                    default: begin
                        is_illegal_instr = 1'b1;
                    end
                endcase
            end

            OPCODE_RTYPE: begin
                // R-type 算术指令
                if (funct7 == `FUNCT7_MUL) begin
                    // M扩展乘法指令，检查funct3
                    is_illegal_instr = !is_mul_funct3;
                end else begin
                    case (funct3)
                        `FUNCT3_ADD_SUB_MUL: begin // ADD/SUB
                            is_illegal_instr = (funct7 != `FUNCT7_ADD) && (funct7 != `FUNCT7_SUB);
                        end
                        `FUNCT3_SLL_MULH: begin // SLL
                            is_illegal_instr = (funct7 != `FUNCT7_SLL);
                        end
                        `FUNCT3_SLT_MULHSU: begin // SLT
                            is_illegal_instr = (funct7 != `FUNCT7_SLT);
                        end
                        `FUNCT3_SLTU_MULHU: begin // SLTU
                            is_illegal_instr = (funct7 != `FUNCT7_SLTU);
                        end
                        `FUNCT3_XOR_DIV: begin // XOR
                            is_illegal_instr = (funct7 != `FUNCT7_XOR);
                        end
                        `FUNCT3_SRL_SRA_DIVU: begin // SRL/SRA
                            is_illegal_instr = (funct7 != `FUNCT7_SRL) && (funct7 != `FUNCT7_SRA);
                        end
                        `FUNCT3_OR_REM: begin // OR
                            is_illegal_instr = (funct7 != `FUNCT7_OR);
                        end
                        `FUNCT3_AND_REMU: begin // AND
                            is_illegal_instr = (funct7 != `FUNCT7_AND);
                        end
                        default: begin
                            is_illegal_instr = 1'b1;
                        end
                    endcase
                end
            end

            OPCODE_ZICSR: begin
                // CSR and system instructions
                if (is_sspush_internal || is_sspopchk_internal || is_ssrdp_internal) begin
                    is_illegal_instr = 1'b0;
                end else if (is_ssrdp_encoding) begin
                    is_illegal_instr = 1'b1;  // SSRDP rd=x0 保留为非法编码
                end else if (funct3 == `FUNCT3_CALL) begin
                    // ECALL: instr = 0x00000073
                    // MRET:  instr = 0x30200073
                    // SRET:  instr = 0x10200073
                    // EBREAK: instr = 0x00100073 (not supported, marked as illegal)
                    // WFI: instr = 0x10500073 (not supported, marked as illegal)
                    // Check ECALL: bits[31:7] = 0
                    // Check MRET: bits[31:20]=0x302, bits[19:7]=0
                    // Check SRET: bits[31:20]=0x102, bits[19:7]=0
                    is_illegal_instr = !((instr == 32'h00000073) ||  // ECALL
                                         (instr == 32'h30200073) ||  // MRET
                                         (instr == 32'h10200073));   // SRET
                end else begin
                    // CSR instructions: funct3 001-011, 101-111 are valid
                    // funct3 = 000 handled above, funct3 = 100 is invalid
                    is_illegal_instr = (funct3 == 3'b100);
                end
            end

            OPCODE_FENCE: begin
                // FENCE 指令是合法的 (作为 NOP 处理)
                is_illegal_instr = 1'b0;
            end

            OPCODE_ZERO: begin
                // 全零指令是非法的
                is_illegal_instr = 1'b1;
            end

            default: begin
                // 其他未知opcode都是非法指令
                is_illegal_instr = 1'b1;
            end
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
    if (is_lpad_internal) begin
      instr_ascii = "LPAD";
    end else if (is_sspush_internal) begin
      instr_ascii = "SSPUSH";
    end else if (is_sspopchk_internal) begin
      instr_ascii = "SSPOPCHK";
    end else if (is_ssrdp_internal) begin
      instr_ascii = "SSRDP";
    end else begin
    unique case (opcode)
      OPCODE_LUI:              instr_ascii = "LUI";
      OPCODE_AUIPC:            instr_ascii = "AUIPC";
      OPCODE_JAL:              instr_ascii = "JAL";
      OPCODE_JALR:             instr_ascii = "JALR";

      OPCODE_BTYPE: begin
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

      OPCODE_LTYPE: begin
        unique case (funct3)
          `FUNCT3_LB:           instr_ascii = "LB";
          `FUNCT3_LH:           instr_ascii = "LH";
          `FUNCT3_LW:           instr_ascii = "LW";
          `FUNCT3_LBU:          instr_ascii = "LBU";
          `FUNCT3_LHU:          instr_ascii = "LHU";
          default:              instr_ascii = "L_UNKNOWN";
        endcase
      end

      OPCODE_STYPE: begin
        unique case (funct3)
          `FUNCT3_SB:           instr_ascii = "SB";
          `FUNCT3_SH:           instr_ascii = "SH";
          `FUNCT3_SW:           instr_ascii = "SW";
          default:              instr_ascii = "S_UNKNOWN";
        endcase
      end

      OPCODE_ITYPE: begin
        if (instr == 32'h13) begin
                                  instr_ascii = "NOP";
        end else begin
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
      end

      OPCODE_RTYPE: begin
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

            OPCODE_ZICSR: begin
                unique case (funct3)
                    `FUNCT3_CSRRW:        instr_ascii = "CSRRW";
                    `FUNCT3_CSRRS:        instr_ascii = "CSRRS";
                    `FUNCT3_CSRRC:        instr_ascii = "CSRRC";
          `FUNCT3_CSRRWI:       instr_ascii = "CSRRWI";
          `FUNCT3_CSRRSI:       instr_ascii = "CSRRSI";
          `FUNCT3_CSRRCI:       instr_ascii = "CSRRCI";
                    `FUNCT3_CALL: begin
                        if (instr == 32'h00000073)
                                instr_ascii = "ECALL";
                        else if (instr == 32'h30200073)
                                instr_ascii = "MRET";
                        else if (instr == 32'h10200073)
                                instr_ascii = "SRET";
                        else                instr_ascii = "SYS_UNKNOWN";
                    end
                    default:              instr_ascii = "CSR_UNKNOWN";
                endcase
      end

      7'hf:                     instr_ascii = "FENCE";

      default:                  instr_ascii = "ERROR";
    endcase
    end
  end
`endif
    // verilog_format:on


endmodule
