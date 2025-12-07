`timescale 1ns / 1ps
`define DEBUG 

`include "../src/Decoder.sv"

module tb_Decoder;

    localparam XLEN = 32;
    localparam NUM_TESTS = 37;  // 目前写了 37 条指令的测试

    // 驱动指令输入
    logic [XLEN-1:0] instr;

    // Decoder 输出信号
    logic [     3:0] alu_op;
    logic            is_auipc;
    logic            alu_src;
    logic            dram_we;
    logic            rf_we;
    logic [     1:0] wd_sel;
    logic [     2:0] branch_type;
    logic            is_branch_instr;
    logic [     1:0] jump_type;  // 本例没有检查 jump_type
    logic [     1:0] load_type;  // 本例没有检查 load_type
    logic            rs1_used;
    logic            rs2_used;

    // 实例化被测 Decoder
    Decoder #(
        .XLEN(XLEN)
    ) dut (
        .instr          (instr),
        .alu_op         (alu_op),
        .is_auipc       (is_auipc),
        .alu_src        (alu_src),
        .dram_we        (dram_we),
        .rf_we          (rf_we),
        .wd_sel         (wd_sel),
        .branch_type    (branch_type),
        .is_branch_instr(is_branch_instr),
        .jump_type      (jump_type),
        .load_type      (load_type),
        .rs1_used       (rs1_used),
        .rs2_used       (rs2_used)
    );

    logic [256-1:0] instr_ascii;
    logic [256-1:0] branch_type_ascii;

    always_comb begin
        instr_ascii       = dut.instr_ascii;
        branch_type_ascii = dut.branch_type_ascii;
    end


    // ========= 期望值表 =========
    logic  [XLEN-1:0] instr_vec          [0:NUM_TESTS-1];
    logic  [     3:0] exp_alu_op         [0:NUM_TESTS-1];
    logic             exp_is_auipc       [0:NUM_TESTS-1];
    logic             exp_alu_src        [0:NUM_TESTS-1];
    logic             exp_dram_we        [0:NUM_TESTS-1];
    logic             exp_rf_we          [0:NUM_TESTS-1];
    logic  [     1:0] exp_wb_sel         [0:NUM_TESTS-1];
    logic  [     2:0] exp_branch_type    [0:NUM_TESTS-1];
    logic             exp_is_branch_instr[0:NUM_TESTS-1];
    logic             exp_rs1_used       [0:NUM_TESTS-1];
    logic             exp_rs2_used       [0:NUM_TESTS-1];

    string            instr_name         [0:NUM_TESTS-1];

    // ========= 测试向量初始化 =========
    initial begin : init_vectors
        // 注：所有期望信号是根据 Decoder.sv 里的逻辑 + RISC-V RV32I 标准推出来的
        // 寄存器约定：一般使用 rd=x1, rs1=x2, rs2=x3，立即数都是小数字方便阅读

        // Test 0: LUI
        instr_name[0]           = "LUI";
        instr_vec[0]            = 32'h123450b7;
        exp_alu_op[0]           = `ALU_RIGHT;
        exp_is_auipc[0]         = 1'b0;
        exp_alu_src[0]          = `ALUSRC_RS2;
        exp_dram_we[0]          = 1'b0;
        exp_rf_we[0]            = 1'b1;
        exp_wb_sel[0]           = `WD_SEL_FROM_IEXT;
        exp_branch_type[0]      = `BRANCH_NOP;
        exp_is_branch_instr[0]  = 1'b0;
        exp_rs1_used[0]         = 1'b0;
        exp_rs2_used[0]         = 1'b0;

        // Test 1: AUIPC
        instr_name[1]           = "AUIPC";
        instr_vec[1]            = 32'h12345097;
        exp_alu_op[1]           = `ALU_RIGHT;
        exp_is_auipc[1]         = 1'b1;
        exp_alu_src[1]          = `ALUSRC_IMM;
        exp_dram_we[1]          = 1'b0;
        exp_rf_we[1]            = 1'b1;
        exp_wb_sel[1]           = `WD_SEL_FROM_ALU;
        exp_branch_type[1]      = `BRANCH_NOP;
        exp_is_branch_instr[1]  = 1'b0;
        exp_rs1_used[1]         = 1'b0;
        exp_rs2_used[1]         = 1'b0;

        // Test 2: JAL
        instr_name[2]           = "JAL";
        instr_vec[2]            = 32'h010000ef;  // rd=x1, offset=16
        exp_alu_op[2]           = `ALU_RIGHT;
        exp_is_auipc[2]         = 1'b0;
        exp_alu_src[2]          = `ALUSRC_RS2;
        exp_dram_we[2]          = 1'b0;
        exp_rf_we[2]            = 1'b1;
        exp_wb_sel[2]           = `WD_SEL_FROM_PC4;
        exp_branch_type[2]      = `BRANCH_NOP;
        exp_is_branch_instr[2]  = 1'b0;
        exp_rs1_used[2]         = 1'b0;
        exp_rs2_used[2]         = 1'b0;

        // Test 3: JALR x1, 0(x2)
        instr_name[3]           = "JALR";
        instr_vec[3]            = 32'h000100e7;
        exp_alu_op[3]           = `ALU_RIGHT;
        exp_is_auipc[3]         = 1'b0;
        exp_alu_src[3]          = `ALUSRC_IMM;
        exp_dram_we[3]          = 1'b0;
        exp_rf_we[3]            = 1'b1;
        exp_wb_sel[3]           = `WD_SEL_FROM_PC4;
        exp_branch_type[3]      = `BRANCH_NOP;
        exp_is_branch_instr[3]  = 1'b0;
        exp_rs1_used[3]         = 1'b1;
        exp_rs2_used[3]         = 1'b0;

        // Test 4: BEQ x2, x3, +8
        instr_name[4]           = "BEQ";
        instr_vec[4]            = 32'h00310463;
        exp_alu_op[4]           = `ALU_SLT;
        exp_is_auipc[4]         = 1'b0;
        exp_alu_src[4]          = `ALUSRC_RS2;
        exp_dram_we[4]          = 1'b0;
        exp_rf_we[4]            = 1'b0;
        exp_wb_sel[4]           = `WD_SEL_FROM_ALU;
        exp_branch_type[4]      = `BRANCH_BEQ;
        exp_is_branch_instr[4]  = 1'b1;
        exp_rs1_used[4]         = 1'b1;
        exp_rs2_used[4]         = 1'b1;

        // Test 5: BNE
        instr_name[5]           = "BNE";
        instr_vec[5]            = 32'h00311463;
        exp_alu_op[5]           = `ALU_SLT;
        exp_is_auipc[5]         = 1'b0;
        exp_alu_src[5]          = `ALUSRC_RS2;
        exp_dram_we[5]          = 1'b0;
        exp_rf_we[5]            = 1'b0;
        exp_wb_sel[5]           = `WD_SEL_FROM_ALU;
        exp_branch_type[5]      = `BRANCH_BNE;
        exp_is_branch_instr[5]  = 1'b1;
        exp_rs1_used[5]         = 1'b1;
        exp_rs2_used[5]         = 1'b1;

        // Test 6: BLT
        instr_name[6]           = "BLT";
        instr_vec[6]            = 32'h00314463;
        exp_alu_op[6]           = `ALU_SLT;
        exp_is_auipc[6]         = 1'b0;
        exp_alu_src[6]          = `ALUSRC_RS2;
        exp_dram_we[6]          = 1'b0;
        exp_rf_we[6]            = 1'b0;
        exp_wb_sel[6]           = `WD_SEL_FROM_ALU;
        exp_branch_type[6]      = `BRANCH_BLT;
        exp_is_branch_instr[6]  = 1'b1;
        exp_rs1_used[6]         = 1'b1;
        exp_rs2_used[6]         = 1'b1;

        // Test 7: BGE
        instr_name[7]           = "BGE";
        instr_vec[7]            = 32'h00315463;
        exp_alu_op[7]           = `ALU_SLT;
        exp_is_auipc[7]         = 1'b0;
        exp_alu_src[7]          = `ALUSRC_RS2;
        exp_dram_we[7]          = 1'b0;
        exp_rf_we[7]            = 1'b0;
        exp_wb_sel[7]           = `WD_SEL_FROM_ALU;
        exp_branch_type[7]      = `BRANCH_BGE;
        exp_is_branch_instr[7]  = 1'b1;
        exp_rs1_used[7]         = 1'b1;
        exp_rs2_used[7]         = 1'b1;

        // Test 8: BLTU
        instr_name[8]           = "BLTU";
        instr_vec[8]            = 32'h00316463;
        exp_alu_op[8]           = `ALU_SLTU;
        exp_is_auipc[8]         = 1'b0;
        exp_alu_src[8]          = `ALUSRC_RS2;
        exp_dram_we[8]          = 1'b0;
        exp_rf_we[8]            = 1'b0;
        exp_wb_sel[8]           = `WD_SEL_FROM_ALU;
        exp_branch_type[8]      = `BRANCH_BLTU;
        exp_is_branch_instr[8]  = 1'b1;
        exp_rs1_used[8]         = 1'b1;
        exp_rs2_used[8]         = 1'b1;

        // Test 9: BGEU
        instr_name[9]           = "BGEU";
        instr_vec[9]            = 32'h00317463;
        exp_alu_op[9]           = `ALU_SLTU;
        exp_is_auipc[9]         = 1'b0;
        exp_alu_src[9]          = `ALUSRC_RS2;
        exp_dram_we[9]          = 1'b0;
        exp_rf_we[9]            = 1'b0;
        exp_wb_sel[9]           = `WD_SEL_FROM_ALU;
        exp_branch_type[9]      = `BRANCH_BGEU;
        exp_is_branch_instr[9]  = 1'b1;
        exp_rs1_used[9]         = 1'b1;
        exp_rs2_used[9]         = 1'b1;

        // Test 10: LB x1, 4(x2)
        instr_name[10]          = "LB";
        instr_vec[10]           = 32'h00410083;
        exp_alu_op[10]          = `ALU_LB;
        exp_is_auipc[10]        = 1'b0;
        exp_alu_src[10]         = `ALUSRC_IMM;
        exp_dram_we[10]         = 1'b0;
        exp_rf_we[10]           = 1'b1;
        exp_wb_sel[10]          = `WD_SEL_FROM_DRAM;
        exp_branch_type[10]     = `BRANCH_NOP;
        exp_is_branch_instr[10] = 1'b0;
        exp_rs1_used[10]        = 1'b1;
        exp_rs2_used[10]        = 1'b0;

        // Test 11: LH
        instr_name[11]          = "LH";
        instr_vec[11]           = 32'h00411083;
        exp_alu_op[11]          = `ALU_LH;
        exp_is_auipc[11]        = 1'b0;
        exp_alu_src[11]         = `ALUSRC_IMM;
        exp_dram_we[11]         = 1'b0;
        exp_rf_we[11]           = 1'b1;
        exp_wb_sel[11]          = `WD_SEL_FROM_DRAM;
        exp_branch_type[11]     = `BRANCH_NOP;
        exp_is_branch_instr[11] = 1'b0;
        exp_rs1_used[11]        = 1'b1;
        exp_rs2_used[11]        = 1'b0;

        // Test 12: LW
        instr_name[12]          = "LW";
        instr_vec[12]           = 32'h00412083;
        exp_alu_op[12]          = `ALU_LW;
        exp_is_auipc[12]        = 1'b0;
        exp_alu_src[12]         = `ALUSRC_IMM;
        exp_dram_we[12]         = 1'b0;
        exp_rf_we[12]           = 1'b1;
        exp_wb_sel[12]          = `WD_SEL_FROM_DRAM;
        exp_branch_type[12]     = `BRANCH_NOP;
        exp_is_branch_instr[12] = 1'b0;
        exp_rs1_used[12]        = 1'b1;
        exp_rs2_used[12]        = 1'b0;

        // Test 13: LBU
        instr_name[13]          = "LBU";
        instr_vec[13]           = 32'h00414083;
        exp_alu_op[13]          = `ALU_LBU;
        exp_is_auipc[13]        = 1'b0;
        exp_alu_src[13]         = `ALUSRC_IMM;
        exp_dram_we[13]         = 1'b0;
        exp_rf_we[13]           = 1'b1;
        exp_wb_sel[13]          = `WD_SEL_FROM_DRAM;
        exp_branch_type[13]     = `BRANCH_NOP;
        exp_is_branch_instr[13] = 1'b0;
        exp_rs1_used[13]        = 1'b1;
        exp_rs2_used[13]        = 1'b0;

        // Test 14: LHU
        instr_name[14]          = "LHU";
        instr_vec[14]           = 32'h00415083;
        exp_alu_op[14]          = `ALU_LHU;
        exp_is_auipc[14]        = 1'b0;
        exp_alu_src[14]         = `ALUSRC_IMM;
        exp_dram_we[14]         = 1'b0;
        exp_rf_we[14]           = 1'b1;
        exp_wb_sel[14]          = `WD_SEL_FROM_DRAM;
        exp_branch_type[14]     = `BRANCH_NOP;
        exp_is_branch_instr[14] = 1'b0;
        exp_rs1_used[14]        = 1'b1;
        exp_rs2_used[14]        = 1'b0;

        // Test 15: SB x1,4(x2)
        instr_name[15]          = "SB";
        instr_vec[15]           = 32'h00110223;
        exp_alu_op[15]          = `ALU_SB;
        exp_is_auipc[15]        = 1'b0;
        exp_alu_src[15]         = `ALUSRC_IMM;
        exp_dram_we[15]         = 1'b1;
        exp_rf_we[15]           = 1'b0;
        exp_wb_sel[15]          = `WD_SEL_FROM_ALU;
        exp_branch_type[15]     = `BRANCH_NOP;
        exp_is_branch_instr[15] = 1'b0;
        exp_rs1_used[15]        = 1'b1;
        exp_rs2_used[15]        = 1'b1;

        // Test 16: SH
        instr_name[16]          = "SH";
        instr_vec[16]           = 32'h00111223;
        exp_alu_op[16]          = `ALU_SH;
        exp_is_auipc[16]        = 1'b0;
        exp_alu_src[16]         = `ALUSRC_IMM;
        exp_dram_we[16]         = 1'b1;
        exp_rf_we[16]           = 1'b0;
        exp_wb_sel[16]          = `WD_SEL_FROM_ALU;
        exp_branch_type[16]     = `BRANCH_NOP;
        exp_is_branch_instr[16] = 1'b0;
        exp_rs1_used[16]        = 1'b1;
        exp_rs2_used[16]        = 1'b1;

        // Test 17: SW
        instr_name[17]          = "SW";
        instr_vec[17]           = 32'h00112223;
        exp_alu_op[17]          = `ALU_SW;
        exp_is_auipc[17]        = 1'b0;
        exp_alu_src[17]         = `ALUSRC_IMM;
        exp_dram_we[17]         = 1'b1;
        exp_rf_we[17]           = 1'b0;
        exp_wb_sel[17]          = `WD_SEL_FROM_ALU;
        exp_branch_type[17]     = `BRANCH_NOP;
        exp_is_branch_instr[17] = 1'b0;
        exp_rs1_used[17]        = 1'b1;
        exp_rs2_used[17]        = 1'b1;

        // Test 18: ADDI x1,x2,1
        instr_name[18]          = "ADDI";
        instr_vec[18]           = 32'h00110093;
        exp_alu_op[18]          = `ALU_ADD;
        exp_is_auipc[18]        = 1'b0;
        exp_alu_src[18]         = `ALUSRC_IMM;
        exp_dram_we[18]         = 1'b0;
        exp_rf_we[18]           = 1'b1;
        exp_wb_sel[18]          = `WD_SEL_FROM_ALU;
        exp_branch_type[18]     = `BRANCH_NOP;
        exp_is_branch_instr[18] = 1'b0;
        exp_rs1_used[18]        = 1'b1;
        exp_rs2_used[18]        = 1'b0;

        // Test 19: SLTI
        instr_name[19]          = "SLTI";
        instr_vec[19]           = 32'h00112093;
        exp_alu_op[19]          = `ALU_SLT;
        exp_is_auipc[19]        = 1'b0;
        exp_alu_src[19]         = `ALUSRC_IMM;
        exp_dram_we[19]         = 1'b0;
        exp_rf_we[19]           = 1'b1;
        exp_wb_sel[19]          = `WD_SEL_FROM_ALU;
        exp_branch_type[19]     = `BRANCH_NOP;
        exp_is_branch_instr[19] = 1'b0;
        exp_rs1_used[19]        = 1'b1;
        exp_rs2_used[19]        = 1'b0;

        // Test 20: SLTIU
        instr_name[20]          = "SLTIU";
        instr_vec[20]           = 32'h00113093;
        exp_alu_op[20]          = `ALU_SLTU;
        exp_is_auipc[20]        = 1'b0;
        exp_alu_src[20]         = `ALUSRC_IMM;
        exp_dram_we[20]         = 1'b0;
        exp_rf_we[20]           = 1'b1;
        exp_wb_sel[20]          = `WD_SEL_FROM_ALU;
        exp_branch_type[20]     = `BRANCH_NOP;
        exp_is_branch_instr[20] = 1'b0;
        exp_rs1_used[20]        = 1'b1;
        exp_rs2_used[20]        = 1'b0;

        // Test 21: XORI
        instr_name[21]          = "XORI";
        instr_vec[21]           = 32'h00114093;
        exp_alu_op[21]          = `ALU_XOR;
        exp_is_auipc[21]        = 1'b0;
        exp_alu_src[21]         = `ALUSRC_IMM;
        exp_dram_we[21]         = 1'b0;
        exp_rf_we[21]           = 1'b1;
        exp_wb_sel[21]          = `WD_SEL_FROM_ALU;
        exp_branch_type[21]     = `BRANCH_NOP;
        exp_is_branch_instr[21] = 1'b0;
        exp_rs1_used[21]        = 1'b1;
        exp_rs2_used[21]        = 1'b0;

        // Test 22: ORI
        instr_name[22]          = "ORI";
        instr_vec[22]           = 32'h00116093;
        exp_alu_op[22]          = `ALU_OR;
        exp_is_auipc[22]        = 1'b0;
        exp_alu_src[22]         = `ALUSRC_IMM;
        exp_dram_we[22]         = 1'b0;
        exp_rf_we[22]           = 1'b1;
        exp_wb_sel[22]          = `WD_SEL_FROM_ALU;
        exp_branch_type[22]     = `BRANCH_NOP;
        exp_is_branch_instr[22] = 1'b0;
        exp_rs1_used[22]        = 1'b1;
        exp_rs2_used[22]        = 1'b0;

        // Test 23: ANDI
        instr_name[23]          = "ANDI";
        instr_vec[23]           = 32'h00117093;
        exp_alu_op[23]          = `ALU_AND;
        exp_is_auipc[23]        = 1'b0;
        exp_alu_src[23]         = `ALUSRC_IMM;
        exp_dram_we[23]         = 1'b0;
        exp_rf_we[23]           = 1'b1;
        exp_wb_sel[23]          = `WD_SEL_FROM_ALU;
        exp_branch_type[23]     = `BRANCH_NOP;
        exp_is_branch_instr[23] = 1'b0;
        exp_rs1_used[23]        = 1'b1;
        exp_rs2_used[23]        = 1'b0;

        // Test 24: SLLI
        instr_name[24]          = "SLLI";
        instr_vec[24]           = 32'h00111093;
        exp_alu_op[24]          = `ALU_SLL;
        exp_is_auipc[24]        = 1'b0;
        exp_alu_src[24]         = `ALUSRC_IMM;
        exp_dram_we[24]         = 1'b0;
        exp_rf_we[24]           = 1'b1;
        exp_wb_sel[24]          = `WD_SEL_FROM_ALU;
        exp_branch_type[24]     = `BRANCH_NOP;
        exp_is_branch_instr[24] = 1'b0;
        exp_rs1_used[24]        = 1'b1;
        exp_rs2_used[24]        = 1'b0;

        // Test 25: SRLI
        instr_name[25]          = "SRLI";
        instr_vec[25]           = 32'h00115093;
        exp_alu_op[25]          = `ALU_SRL;
        exp_is_auipc[25]        = 1'b0;
        exp_alu_src[25]         = `ALUSRC_IMM;
        exp_dram_we[25]         = 1'b0;
        exp_rf_we[25]           = 1'b1;
        exp_wb_sel[25]          = `WD_SEL_FROM_ALU;
        exp_branch_type[25]     = `BRANCH_NOP;
        exp_is_branch_instr[25] = 1'b0;
        exp_rs1_used[25]        = 1'b1;
        exp_rs2_used[25]        = 1'b0;

        // Test 26: SRAI
        instr_name[26]          = "SRAI";
        instr_vec[26]           = 32'h40115093;
        exp_alu_op[26]          = `ALU_SRA;
        exp_is_auipc[26]        = 1'b0;
        exp_alu_src[26]         = `ALUSRC_IMM;
        exp_dram_we[26]         = 1'b0;
        exp_rf_we[26]           = 1'b1;
        exp_wb_sel[26]          = `WD_SEL_FROM_ALU;
        exp_branch_type[26]     = `BRANCH_NOP;
        exp_is_branch_instr[26] = 1'b0;
        exp_rs1_used[26]        = 1'b1;
        exp_rs2_used[26]        = 1'b0;

        // Test 27: ADD
        instr_name[27]          = "ADD";
        instr_vec[27]           = 32'h003100b3;
        exp_alu_op[27]          = `ALU_ADD;
        exp_is_auipc[27]        = 1'b0;
        exp_alu_src[27]         = `ALUSRC_RS2;
        exp_dram_we[27]         = 1'b0;
        exp_rf_we[27]           = 1'b1;
        exp_wb_sel[27]          = `WD_SEL_FROM_ALU;
        exp_branch_type[27]     = `BRANCH_NOP;
        exp_is_branch_instr[27] = 1'b0;
        exp_rs1_used[27]        = 1'b1;
        exp_rs2_used[27]        = 1'b1;

        // Test 28: SUB
        instr_name[28]          = "SUB";
        instr_vec[28]           = 32'h403100b3;
        exp_alu_op[28]          = `ALU_SUB;
        exp_is_auipc[28]        = 1'b0;
        exp_alu_src[28]         = `ALUSRC_RS2;
        exp_dram_we[28]         = 1'b0;
        exp_rf_we[28]           = 1'b1;
        exp_wb_sel[28]          = `WD_SEL_FROM_ALU;
        exp_branch_type[28]     = `BRANCH_NOP;
        exp_is_branch_instr[28] = 1'b0;
        exp_rs1_used[28]        = 1'b1;
        exp_rs2_used[28]        = 1'b1;

        // Test 29: SLL
        instr_name[29]          = "SLL";
        instr_vec[29]           = 32'h003110b3;
        exp_alu_op[29]          = `ALU_SLL;
        exp_is_auipc[29]        = 1'b0;
        exp_alu_src[29]         = `ALUSRC_RS2;
        exp_dram_we[29]         = 1'b0;
        exp_rf_we[29]           = 1'b1;
        exp_wb_sel[29]          = `WD_SEL_FROM_ALU;
        exp_branch_type[29]     = `BRANCH_NOP;
        exp_is_branch_instr[29] = 1'b0;
        exp_rs1_used[29]        = 1'b1;
        exp_rs2_used[29]        = 1'b1;

        // Test 30: SLT
        instr_name[30]          = "SLT";
        instr_vec[30]           = 32'h003120b3;
        exp_alu_op[30]          = `ALU_SLT;
        exp_is_auipc[30]        = 1'b0;
        exp_alu_src[30]         = `ALUSRC_RS2;
        exp_dram_we[30]         = 1'b0;
        exp_rf_we[30]           = 1'b1;
        exp_wb_sel[30]          = `WD_SEL_FROM_ALU;
        exp_branch_type[30]     = `BRANCH_NOP;
        exp_is_branch_instr[30] = 1'b0;
        exp_rs1_used[30]        = 1'b1;
        exp_rs2_used[30]        = 1'b1;

        // Test 31: SLTU
        instr_name[31]          = "SLTU";
        instr_vec[31]           = 32'h003130b3;
        exp_alu_op[31]          = `ALU_SLTU;
        exp_is_auipc[31]        = 1'b0;
        exp_alu_src[31]         = `ALUSRC_RS2;
        exp_dram_we[31]         = 1'b0;
        exp_rf_we[31]           = 1'b1;
        exp_wb_sel[31]          = `WD_SEL_FROM_ALU;
        exp_branch_type[31]     = `BRANCH_NOP;
        exp_is_branch_instr[31] = 1'b0;
        exp_rs1_used[31]        = 1'b1;
        exp_rs2_used[31]        = 1'b1;

        // Test 32: XOR
        instr_name[32]          = "XOR";
        instr_vec[32]           = 32'h003140b3;
        exp_alu_op[32]          = `ALU_XOR;
        exp_is_auipc[32]        = 1'b0;
        exp_alu_src[32]         = `ALUSRC_RS2;
        exp_dram_we[32]         = 1'b0;
        exp_rf_we[32]           = 1'b1;
        exp_wb_sel[32]          = `WD_SEL_FROM_ALU;
        exp_branch_type[32]     = `BRANCH_NOP;
        exp_is_branch_instr[32] = 1'b0;
        exp_rs1_used[32]        = 1'b1;
        exp_rs2_used[32]        = 1'b1;

        // Test 33: SRL
        instr_name[33]          = "SRL";
        instr_vec[33]           = 32'h003150b3;
        exp_alu_op[33]          = `ALU_SRL;
        exp_is_auipc[33]        = 1'b0;
        exp_alu_src[33]         = `ALUSRC_RS2;
        exp_dram_we[33]         = 1'b0;
        exp_rf_we[33]           = 1'b1;
        exp_wb_sel[33]          = `WD_SEL_FROM_ALU;
        exp_branch_type[33]     = `BRANCH_NOP;
        exp_is_branch_instr[33] = 1'b0;
        exp_rs1_used[33]        = 1'b1;
        exp_rs2_used[33]        = 1'b1;

        // Test 34: SRA
        instr_name[34]          = "SRA";
        instr_vec[34]           = 32'h403150b3;
        exp_alu_op[34]          = `ALU_SRA;
        exp_is_auipc[34]        = 1'b0;
        exp_alu_src[34]         = `ALUSRC_RS2;
        exp_dram_we[34]         = 1'b0;
        exp_rf_we[34]           = 1'b1;
        exp_wb_sel[34]          = `WD_SEL_FROM_ALU;
        exp_branch_type[34]     = `BRANCH_NOP;
        exp_is_branch_instr[34] = 1'b0;
        exp_rs1_used[34]        = 1'b1;
        exp_rs2_used[34]        = 1'b1;

        // Test 35: OR
        instr_name[35]          = "OR";
        instr_vec[35]           = 32'h003160b3;
        exp_alu_op[35]          = `ALU_OR;
        exp_is_auipc[35]        = 1'b0;
        exp_alu_src[35]         = `ALUSRC_RS2;
        exp_dram_we[35]         = 1'b0;
        exp_rf_we[35]           = 1'b1;
        exp_wb_sel[35]          = `WD_SEL_FROM_ALU;
        exp_branch_type[35]     = `BRANCH_NOP;
        exp_is_branch_instr[35] = 1'b0;
        exp_rs1_used[35]        = 1'b1;
        exp_rs2_used[35]        = 1'b1;

        // Test 36: AND
        instr_name[36]          = "AND";
        instr_vec[36]           = 32'h003170b3;
        // instr_vec[36]           = 32'b0000000_00011_00010_111_00001_0000000; // AND x1, x2, x3
        exp_alu_op[36]          = `ALU_AND;
        exp_is_auipc[36]        = 1'b0;
        exp_alu_src[36]         = `ALUSRC_RS2;
        exp_dram_we[36]         = 1'b0;
        exp_rf_we[36]           = 1'b1;
        exp_wb_sel[36]          = `WD_SEL_FROM_ALU;
        exp_branch_type[36]     = `BRANCH_NOP;
        exp_is_branch_instr[36] = 1'b0;
        exp_rs1_used[36]        = 1'b1;
        exp_rs2_used[36]        = 1'b1;
    end

    // ========= 主测试过程 =========
    initial begin : run_tests
        integer i;
        integer error_count = 0;

        $display("====== Decoder 自测开始，共 %0d 条指令 ======", NUM_TESTS);

        for (i = 0; i < NUM_TESTS; i = i + 1) begin
            instr = instr_vec[i];

            // 组合逻辑，给一小段时间传播
            #1;

            if (alu_op !== exp_alu_op[i] ||
                is_auipc !== exp_is_auipc[i] || alu_src !== exp_alu_src[i] ||
                dram_we !== exp_dram_we[i] || rf_we !== exp_rf_we[i] || wd_sel !== exp_wb_sel[i] ||
                branch_type !== exp_branch_type[i] || is_branch_instr !== exp_is_branch_instr[i] ||
                rs1_used !== exp_rs1_used[i] || rs2_used !== exp_rs2_used[i]) begin

                error_count = error_count + 1;
                $display("FAIL: idx=%0d instr=0x%08h (%s)", i, instr_vec[i], instr_name[i]);
                $display("      alu_op exp=%0d got=%0d", exp_alu_op[i], alu_op);
                $display("      is_auipc exp=%0b got=%0b", exp_is_auipc[i], is_auipc);
                $display("      alu_src exp=%0b got=%0b", exp_alu_src[i], alu_src);
                $display("      dram_we exp=%0b got=%0b", exp_dram_we[i], dram_we);
                $display("      rf_we   exp=%0b got=%0b", exp_rf_we[i], rf_we);
                $display("      wd_sel  exp=%0d got=%0d", exp_wb_sel[i], wd_sel);
                $display("      branch_type exp=%0d got=%0d", exp_branch_type[i], branch_type);
                $display("      is_branch_instr exp=%0b got=%0b", exp_is_branch_instr[i],
                         is_branch_instr);
                $display("      rs1_used exp=%0b got=%0b", exp_rs1_used[i], rs1_used);
                $display("      rs2_used exp=%0b got=%0b", exp_rs2_used[i], rs2_used);
            end else begin
                $display("PASS: idx=%0d instr=0x%08h (%s)", i, instr_vec[i], instr_name[i]);
            end
        end

        $display("====== 测试结束：错误数 = %0d ======", error_count);
        if (error_count == 0) $display("所有指令解码结果与期望完全一致 ✅");
        else
            $display(
                "有 %0d 条指令解码不符合期望，请检查上面的 FAIL 记录 ❌",
                error_count
            );

        $finish;
    end

    initial begin
        $dumpfile(`VCD_FILEPATH);  // 指定输出的波形文件名
        $dumpvars;  // 或者简单粗暴：dump 全部层级
    end

    // 断言检查
`ifdef ASSERT_ON
    always_comb begin

        if ($time > 0 && instr != 32'h00000000) begin
            // 保证每条指令的 ALUOp 都有定义
            // 排除时刻0和全0指令（NOP）的情况
            assert (alu_op != `ALU_NOP)
            else $error("Decoder: ALUOp not defined for instruction %h", instr);

            // 寄存器读写状态检查
            // 读写互斥
            // 1) 不允许同时写寄存器和写数据存储器
            assert (!(rf_we && dram_we))
            else $error("Decoder ASSERT: rf_we && dram_we both 1, instr = %h", instr);

            // 2) BTYPE / STYPE 这种不该写寄存器的指令，rf_we 必须为 0
            if (opcode == `OPCODE_BTYPE || opcode == `OPCODE_STYPE) begin
                assert (!rf_we)
                else $error("Decoder ASSERT: branch/store should not write RF, instr = %h", instr);
            end
        end
    end
`endif

endmodule
