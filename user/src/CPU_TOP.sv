`include "include/defines.svh"

module CPU_TOP (
    input  logic        clk,
    input  logic        rst_n,
    // 来自指令存储器IROM的指令
    input  logic [31:0] instr,
    // 输出给指令存储器IROM的地址
    output logic [13:0] pc
);

    localparam int unsigned XLEN = 32;
    // verilog_format:off
// ================= 各级之间的信号 ===================
    logic         valid_IF,  valid_ID,  valid_EX,  valid_MEM,  valid_WB;
    logic [31:0]     pc_IF,     pc_ID,     pc_EX,     pc_MEM,     pc_WB;
    logic [31:0]    pc4_IF,    pc4_ID,    pc4_EX,    pc4_MEM,    pc4_WB;
    logic [31:0]  instr_IF,  instr_ID,  instr_EX,  instr_MEM,  instr_WB;

    logic [4:0]             alu_op_ID, alu_op_EX;

    logic                  dram_we_ID,dram_we_EX,dram_we_MEM;
    logic                    rf_we_ID,  rf_we_EX,  rf_we_MEM,  rf_we_WB;
    logic [1:0]             wd_sel_ID, wd_sel_EX, wd_sel_MEM;

    logic [4:0]                 wR_ID,     wR_EX,     wR_MEM,     wR_WB;
    logic [31:0]                        rf_wd_EX,  rf_wd_MEM,  rf_wd_WB;

    // 第一第二操作数来源
    logic                 is_auipc_ID,is_auipc_EX;
    logic                  alu_src_ID, alu_src_EX;
    // 寄存器堆读数据
    logic [31:0]            rf_rd1_ID, rf_rd1_EX;
    // 存储指令需要在MEM级使用rs2的值 因此多一级
    logic [31:0]            rf_rd2_ID, rf_rd2_EX,rf_rd2_MEM;

    logic          is_branch_instr_ID, is_branch_instr_EX;
    logic [2:0]        branch_type_ID,     branch_type_EX;
    logic [1:0]          jump_type_ID,       jump_type_EX;
    logic [1:0]          load_type_ID,       load_type_EX,      load_type_MEM;
    // 已扩展后的立即数
    logic [31:0]               imm_ID,             imm_EX;
    // 分支目标地址/AUIPC计算地址
    logic [31:0]     branch_target_ID,   branch_target_EX;
    // ALU结果
    logic [31:0]                            alu_result_EX,      alu_result_MEM;

    logic flush_IF_ID, flush_ID_EX;
    logic keep_PC, stall_IF_ID;
// ================= 各级之间的信号 ===================
    // verilog_format:on

    assign instr_IF = instr;
    assign pc       = pc_IF[15:2];

    // IF级

    // PC寄存器
    logic        take_branch_NextPC;
    logic [31:0] branch_target_NextPC;
    PC U_PC (
        .clk          (clk),
        .rst_n        (rst_n),
        .keep_pc      (keep_PC),
        .branch_op    (take_branch_NextPC),
        .branch_target(branch_target_NextPC),
        .pc_if        (pc_IF),
        .pc4_if       (pc4_IF)
    );

    // ================= IF/ID 流水线寄存器 ===================

    assign valid_IF = (pc_IF >= 0);  // 复位时指令无效

    PR_IF_ID u_PR_IF_ID (
        .clk             (clk),
        .rst_n           (rst_n),
        // 流水线控制信号
        .flush           (flush_IF_ID),
        .stall           (stall_IF_ID),
        // IF级输入
        .pc_if_i         (pc_IF),
        .pc4_if_i        (pc4_IF),
        .instr_if_i      (instr_IF),
        // IF级输出 给ID级输入
        .pc_id_o         (pc_ID),
        .pc4_id_o        (pc4_ID),
        .instr_id_o      (instr_ID),
        // 判断指令是否有效
        // 流水线冲刷时需要将指令置为无效
        .instr_valid_if_i(valid_IF),
        .instr_valid_id_o(valid_ID)
    );

    // ID级

    assign wR_ID = instr_ID[11:7];


    imm_extender u_imm_extender (
        .instr  (instr_ID),
        .imm_out(imm_ID)
    );

    // 将分支目标地址计算放在ID级
    assign branch_target_ID = pc_ID + imm_ID;
    logic [4:0] rR1, rR2;
    assign rR1 = instr_ID[19:15], rR2 = instr_ID[24:20];

    RegisterF u_registerf (
        .clk  (clk),
        // .rst_n(rst_n),
        .rf_we(rf_we_WB),
        // 读地址端口
        .rR1  (rR1),
        .rR2  (rR2),
        // 写地址端口
        .wR   (wR_WB),
        // 写数据端口
        .wD   (rf_wd_WB),
        // 读数据端口
        .rD1  (rf_rd1_ID),
        .rD2  (rf_rd2_ID)
    );


    // output declaration of module Decoder

    logic rs1_used_ID;
    logic rs2_used_ID;

    Decoder u_Decoder (
        .instr          (instr_ID),
        .alu_op         (alu_op_ID),
        .is_auipc       (is_auipc_ID),
        .alu_src        (alu_src_ID),
        .dram_we        (dram_we_ID),
        .rf_we          (rf_we_ID),
        .wd_sel         (wd_sel_ID),
        .is_branch_instr(is_branch_instr_ID),
        .branch_type    (branch_type_ID),
        .jump_type      (jump_type_ID),
        .load_type      (load_type_ID),
        .rs1_used       (rs1_used_ID),
        .rs2_used       (rs2_used_ID)
    );

    // ================= ID/EX 流水线寄存器 ===================

    // 前递信号与数据
    logic        fwd_rD1e_ID;
    logic        fwd_rD2e_ID;
    logic [31:0] fwd_rD1_ID;
    logic [31:0] fwd_rD2_ID;

    PR_ID_EX u_PR_ID_EX (
        .clk                 (clk),
        .rst_n               (rst_n),
        // 流水线控制信号
        .flush               (flush_ID_EX),
        // ID级输入
        .pc_id_i             (pc_ID),
        .pc4_id_i            (pc4_ID),
        // .instr_id_i          (instr_ID),
        // ID级输出 给EX级输入
        .pc_ex_o             (pc_EX),
        .pc4_ex_o            (pc4_EX),
        // .instr_ex_o          (instr_EX),
        // 判断指令是否有效
        // 流水线冲刷时需要将指令置为无效
        .instr_valid_id_i    (valid_ID),
        .instr_valid_ex_o    (valid_EX),
        // 寄存器堆第一寄存器数据
        .rD1_i               (rf_rd1_ID),
        .rD1_o               (rf_rd1_EX),
        // 寄存器堆第二寄存器数据
        .rD2_i               (rf_rd2_ID),
        .rD2_o               (rf_rd2_EX),
        // ALUOp
        .alu_op_id_i         (alu_op_ID),
        .alu_op_ex_o         (alu_op_EX),
        // AUIPC
        .is_auipc_id_i       (is_auipc_ID),
        .is_auipc_ex_o       (is_auipc_EX),
        // ALU第二操作数来源
        .alu_src2_sel_id_i   (alu_src_ID),
        .alu_src2_sel_ex_o   (alu_src_EX),
        // 写使能
        .dram_we_id_i        (dram_we_ID),
        .dram_we_ex_o        (dram_we_EX),
        .rf_we_id_i          (rf_we_ID),
        .rf_we_ex_o          (rf_we_EX),
        // 写回数据来源
        .wd_sel_id_i         (wd_sel_ID),
        .wd_sel_ex_o         (wd_sel_EX),
        // 写回寄存器地址
        .wr_id_i             (wR_ID),
        .wr_ex_o             (wR_EX),
        // 分支跳转
        .is_branch_instr_id_i(is_branch_instr_ID),
        .is_branch_instr_ex_o(is_branch_instr_EX),
        .branch_type_id_i    (branch_type_ID),
        .branch_type_ex_o    (branch_type_EX),
        // 跳转相关
        .jump_type_id_i      (jump_type_ID),
        .jump_type_ex_o      (jump_type_EX),
        // 读取类型
        .load_type_id_i      (load_type_ID),
        .load_type_ex_o      (load_type_EX),
        // 立即数
        .imm_id_i            (imm_ID),
        .imm_ex_o            (imm_EX),
        // PC跳转时地址
        .pc_jump_id_i        (branch_target_ID),
        .pc_jump_ex_o        (branch_target_EX),
        // 前递相关
        .fwd_rD1e_ID         (fwd_rD1e_ID),
        .fwd_rD2e_ID         (fwd_rD2e_ID),
        .fwd_rD1_ID          (fwd_rD1_ID),
        .fwd_rD2_ID          (fwd_rD2_ID)
    );

    // EX 级

    // ALU
    logic alu_zero;
    logic alu_sign;
    logic alu_unsigned;

    ALU u_ALU (
        .alu_op      (alu_op_EX),
        .src1        (rf_rd1_EX),
        .src2        (rf_rd2_EX),
        .imm         (imm_EX),
        .alu_src2_sel(alu_src_EX),
        .alu_result  (alu_result_EX),
        .zero        (alu_zero),
        .sign        (alu_sign),
        .alu_unsigned(alu_unsigned)
    );

    // NextPC 计算
    NextPC_Generator u_NextPC_Generator (
        .is_branch_instr     (is_branch_instr_EX),
        .branch_type         (branch_type_EX),
        .jump_type           (jump_type_EX),
        .alu_result          (alu_result_EX),
        .branch_target_i     (branch_target_EX),
        .alu_zero            (alu_zero),
        .alu_sign            (alu_sign),
        .alu_unsigned        (alu_unsigned),
        .take_branch         (take_branch_NextPC),
        .branch_target_NextPC(branch_target_NextPC)
    );

    // 回写数据来源选择MUX
    // 在EX级完成选择以减少流水线寄存器宽度
    // 注意 load 指令的数据在 MEM 级才可用 因此不可能选择 DRAM 作为回写数据来源
    always_comb begin : wd_EX_MUX
        case (wd_sel_EX)
            `WD_SEL_FROM_ALU:  rf_wd_EX = alu_result_EX;
            // `WD_SEL_FROM_DRAM在MEM级处理
            `WD_SEL_FROM_PC4:  rf_wd_EX = pc4_EX;
            // 如果回写的是立即数扩展值 则需要判断是否为AUIPC指令
            `WD_SEL_FROM_IEXT: rf_wd_EX = (is_auipc_EX) ? branch_target_EX : imm_EX;
            default:           rf_wd_EX = 32'b0;
        endcase
    end

    // ================= EX/MEM 流水线寄存器 ===================

    logic [31:0] rf_wd_MEM_PR2MUX;
    PR_EX_MEM u_PR_EX_MEM (
        .clk              (clk),
        .rst_n            (rst_n),
        .pc_ex_i          (pc_EX),
        .pc_mem_o         (pc_MEM),
        .instr_valid_ex_i (valid_EX),
        .instr_valid_mem_o(valid_MEM),
        .dram_we_ex_i     (dram_we_EX),
        .dram_we_mem_o    (dram_we_MEM),
        .rf_we_ex_i       (rf_we_EX),
        .rf_we_mem_o      (rf_we_MEM),
        .wd_sel_ex_i      (wd_sel_EX),
        .wd_sel_mem_o     (wd_sel_MEM),
        .wr_ex_i          (wR_EX),
        .wr_mem_o         (wR_MEM),
        .alu_result_ex_i  (alu_result_EX),
        .alu_result_mem_o (alu_result_MEM),
        .wd_ex_i          (rf_wd_EX),
        .wd_mem_o         (rf_wd_MEM_PR2MUX),
        .rD2_ex_i         (rf_rd2_EX),
        .rD2_mem_o        (rf_rd2_MEM)
    );

    // MEM 级

    // DRAM模块
    logic [31:0] DRAM_output_data;

    DRAM u_DRAM (
        .clk(clk),
        .a  (alu_result_MEM),
        .spo(DRAM_output_data),
        .we (dram_we_MEM),
        .din(rf_rd2_MEM)
    );

    // 回写数据来源2选择MUX
    // 选择是否为DRAM数据
    // 对于同步DRAM 将MUX放到WB级
    assign rf_wd_MEM = (wd_sel_MEM == `WD_SEL_FROM_DRAM) ? DRAM_output_data : rf_wd_MEM_PR2MUX;

    // ================= MEM/WB 流水线寄存器 ===================

    PR_MEM_WB u_PR_MEM_WB (
        .clk              (clk),
        .rst_n            (rst_n),
        // MEM级输入
        .pc_mem_i         (pc_MEM),
        // MEM级输出 给WB级输入
        .pc_wb_o          (pc_WB),
        .instr_valid_mem_i(valid_MEM),
        .instr_valid_wb_o (valid_WB),
        // 寄存器堆写使能
        .rf_we_mem_i      (rf_we_MEM),
        .rf_we_wb_o       (rf_we_WB),
        // 写回寄存器地址
        .wr_mem_i         (wR_MEM),
        .wr_wb_o          (wR_WB),
        // 写回数据
        .wd_mem_i         (rf_wd_MEM),
        .wd_wb_o          (rf_wd_WB)
    );

    // 冒险控制单元

    HazardUnit u_HazardUnit (
        .clk               (clk),
        .rst_n             (rst_n),
        .wd_sel_EX         (wd_sel_EX),
        .rs1_used_ID       (rs1_used_ID),
        .rs2_used_ID       (rs2_used_ID),
        .rR1_ID            (rR1),
        .rR2_ID            (rR2),
        .wR_EX             (wR_EX),
        .wR_MEM            (wR_MEM),
        .wR_WB             (wR_WB),
        .rf_we_EX          (rf_we_EX),
        .rf_we_MEM         (rf_we_MEM),
        .rf_we_WB          (rf_we_WB),
        .rf_wd_EX          (rf_wd_EX),
        .rf_wd_MEM         (rf_wd_MEM),
        .rf_wd_WB          (rf_wd_WB),
        .take_branch_NextPC(take_branch_NextPC),
        .branch_predicted_i(),
        .keep_pc           (keep_PC),
        .stall_IF_ID       (stall_IF_ID),
        .flush_IF_ID       (flush_IF_ID),
        .flush_ID_EX       (flush_ID_EX),
        .fwd_rD1e_ID       (fwd_rD1e_ID),
        .fwd_rD2e_ID       (fwd_rD2e_ID),
        .fwd_rD1_ID        (fwd_rD1_ID),
        .fwd_rD2_ID        (fwd_rD2_ID)
    );


endmodule
