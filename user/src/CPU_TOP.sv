`include "include/defines.svh"
`ifndef CPU_TOP_SV_INCLUDED
`define CPU_TOP_SV_INCLUDED


module CPU_TOP #(
    localparam bit ENABLE_STATIC_BPU = 1'b1
) (
    input  logic        clk,
    input  logic        rst_n,
    // 来自指令存储器IROM的指令 (可能是加密的)
    input  logic [31:0] instr,
    // 输出给指令存储器IROM的地址
    // 这里实际上是PC的高14位
    output logic [13:0] pc
);

    localparam int unsigned XLEN = 32;
    // verilog_format:off
// ================= 各级之间的信号 ===================
    logic         valid_IF,  valid_ID,  valid_EX,  valid_MEM,  valid_WB;
    logic [31:0]     pc_IF,     pc_ID,     pc_EX,     pc_MEM,     pc_WB;
    logic [31:0]    pc4_IF,    pc4_ID,    pc4_EX,    pc4_MEM,    pc4_WB;
    logic [31:0]  instr_IF,  instr_ID,  instr_EX,  instr_MEM,  instr_WB;
    logic [31:0] load_data_WB;
    logic [31:0] rf_wd_WB_from_ALU;
    logic        rf_we_commit;
    logic [ 4:0] wR_commit;
    logic [31:0] rf_wd_commit;

    logic [4:0]             alu_op_ID, alu_op_EX;

    logic                  dram_we_ID,dram_we_EX,dram_we_MEM;
    logic                    rf_we_ID,  rf_we_EX,  rf_we_MEM,  rf_we_WB;
    logic [2:0]             wd_sel_ID, wd_sel_EX, wd_sel_MEM, wd_sel_WB;

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
    logic [3:0]            sl_type_ID,         sl_type_EX,         sl_type_MEM,         sl_type_WB;
    // 已扩展后的立即数
    logic [31:0]               imm_ID,             imm_EX;
    // 分支目标地址/AUIPC计算地址
    logic [31:0]     branch_target_ID,   branch_target_EX;
    logic            branch_predicted_ID, branch_predicted_fire_ID, branch_predicted_EX;
    logic [31:0]     branch_predicted_target_ID, branch_predicted_target_EX;
    // ALU结果
    logic [31:0]                            alu_result_EX,      alu_result_MEM,      alu_result_WB;

    // 乘法器相关信号
    logic                   is_mul_instr_ID, is_mul_instr_EX;
    logic [1:0]                mul_op_ID,       mul_op_EX;
    logic                   mul_valid_i;
    logic                   mul_valid_o;
    logic [31:0]            mul_result;
    logic [ 4:0]            mul_rd_o;
    logic                   mul_rf_we_o;
    logic                   mul_busy;
    logic [ 3:0]            mul_stage_busy;
    logic [ 3:0][4:0]       mul_rd_s;
    logic [ 4:0]            mul_cancel_rd;    // WAW hazard: cancel MUL write to this register

    logic flush_IF_ID, flush_ID_EX;
    logic keep_PC, stall_IF_ID;
    logic pc_redirect_op;
    logic [31:0] pc_redirect_target;

    // CSR相关信号
    logic        is_csr_instr_ID, is_csr_instr_EX;
    logic [ 2:0] csr_op_ID, csr_op_EX;
    logic [11:0] csr_addr_ID, csr_addr_EX;
    logic        is_ecall_ID, is_ecall_EX;
    logic        is_mret_ID, is_mret_EX;
    logic        is_sret_ID, is_sret_EX;
    logic        is_lpad_instr_ID;
    logic [31:0] csr_rdata_EX;
    logic [31:0] csr_wdata_EX;
    logic        csr_write_intent_ID, csr_write_intent_EX;
    logic [ 1:0] current_priv_mode;
    logic        mstatus_tsr;
    logic        mstatus_tvm;
    logic        current_sse_enabled;
    logic        current_lpe_enabled;
    logic        elp_expected;
    logic [31:0] ssp_value;

    // 非法指令检测信号
    logic        is_illegal_instr_ID, is_illegal_instr_EX;
    logic        privileged_illegal_instr_ID;
    logic        illegal_instr_exception_effective_ID;
    logic        software_check_exception_effective_ID;
    logic        flushes_id_exception_ID;
    logic        redirect_from_ex_stage;
    logic        csr_implemented_ID;
    logic        csr_implemented_EX;

    // Exception/Trap相关信号
    logic        exception_valid;
    logic [31:0] exception_pc;
    logic [31:0] exception_cause;
    logic [31:0] exception_tval;
    logic        trap_to_mmode;
    logic [31:0] trap_target;
    logic [31:0] xret_target;

    // 提前检测的非法指令异常 (在ID级检测)
    // 这样可以在非法指令进入EX之前就触发异常，防止其前一条指令提交
    logic        illegal_instr_exception_ID;
    logic [31:0] illegal_instr_pc_ID;
    logic [31:0] illegal_instr_encoding_ID;

    logic [31:0] x7_rf_ID;
    logic [31:0] x7_effective_ID;
    logic        lpad_pass_ID;
    logic        software_check_exception_ID;
    logic [31:0] software_check_tval_ID;
    logic [ 3:0] sl_type_effective_EX;
    logic [31:0] shadow_addr_EX;
    logic        shadow_mem_active_EX;
    logic        mul_commit_serialize_active;
    logic        shadow_serialize_EX;
    logic        shadow_serialize_MEM;
    logic        shadow_serialize_WB;
    logic        shadow_access_fault_EX;
    logic        sspopchk_fault_WB;
    logic        sspopchk_success_WB;
    logic        ssp_update_valid;
    logic [31:0] ssp_update_data;
    logic        elp_update_valid;
    logic        elp_update_expected;
// ================= 各级之间的信号 ===================

    function automatic logic csr_is_implemented(input logic [11:0] addr);
        begin
            unique case (addr)
                `CSR_SSP, `CSR_SSTATUS, `CSR_SIE, `CSR_STVEC, `CSR_SCOUNTEREN,
                `CSR_SENVCFG, `CSR_SSCRATCH, `CSR_SEPC, `CSR_SCAUSE, `CSR_STVAL,
                `CSR_SIP, `CSR_SATP, `CSR_MSTATUS, `CSR_MISA, `CSR_MVENDORID,
                `CSR_MARCHID, `CSR_MIMPID, `CSR_MHARTID, `CSR_MEDELEG,
                `CSR_MIDELEG, `CSR_MIE, `CSR_MNSTATUS, `CSR_MTVEC,
                `CSR_MSTATUSH, `CSR_PMPCFG0, `CSR_PMPADDR0, `CSR_MENVCFG,
                `CSR_MCOUNTEREN, `CSR_MSCRATCH, `CSR_MEPC, `CSR_MCAUSE,
                `CSR_MTVAL, `CSR_MIP, `CSR_MSECCFG, `CSR_MCYCLE, `CSR_CYCLE,
                `CSR_MCYCLEH, `CSR_CYCLEH, `CSR_INSTRET, `CSR_INSTRETH:
                    csr_is_implemented = 1'b1;
                default:
                    csr_is_implemented = 1'b0;
            endcase
        end
    endfunction

// IF级

    assign instr_IF = instr;
    // 这里取PC的高14位作为IROM地址 这样输出的地址就是字地址
    assign pc       = pc_IF[15:2];

    // PC寄存器
    logic        take_branch_NextPC;
    logic [31:0] branch_target_NextPC;
    PC U_PC (
        .clk          (clk),
        .rst_n        (rst_n),
        .keep_pc      (keep_PC),
        .branch_op    (pc_redirect_op),
        .branch_target(pc_redirect_target),
        .pc_if        (pc_IF),
        .pc4_if       (pc4_IF)
    );

// ================= IF/ID 流水线寄存器 ===================

    assign valid_IF = 1'b1;  // 初始始终有效 复位时由流水线寄存器控制

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

    logic [31:0] rf_wd_WB_from_ALU_or_DRAM;
    RegisterF u_registerf (
        .clk   (clk),
        // .rst_n(rst_n),
        // 统一提交写端口
        .rf_we (rf_we_commit),
        .wR    (wR_commit),
        .wD    (rf_wd_commit),
        // 读地址端口
        .rR1   (rR1),
        .rR2   (rR2),
        // 读数据端口
        .rD1   (rf_rd1_ID),
        .rD2   (rf_rd2_ID),
        .x7_o  (x7_rf_ID)
    );

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
        .sl_type        (sl_type_ID),
        .rs1_used       (rs1_used_ID),
        .rs2_used       (rs2_used_ID),
        .is_mul_instr   (is_mul_instr_ID),
        .mul_op         (mul_op_ID),
        // CSR相关输出
        .is_csr_instr   (is_csr_instr_ID),
        .csr_op         (csr_op_ID),
        .csr_addr       (csr_addr_ID),
        .is_ecall       (is_ecall_ID),
        .is_mret        (is_mret_ID),
        .is_sret        (is_sret_ID),
        .is_lpad_instr  (is_lpad_instr_ID),
        // 非法指令检测
        .is_illegal_instr(is_illegal_instr_ID)
    );

    StaticBPU u_StaticBPU (
        .valid_i          (valid_ID),
        .is_branch_instr_i(is_branch_instr_ID),
        .jump_type_i      (jump_type_ID),
        .imm_i            (imm_ID),
        .branch_target_i  (branch_target_ID),
        .predict_taken_o  (branch_predicted_ID),
        .predict_target_o (branch_predicted_target_ID)
    );

    always_comb begin
        unique case (csr_op_ID)
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI: csr_write_intent_ID = is_csr_instr_ID;
            `FUNCT3_CSRRS, `FUNCT3_CSRRC, `FUNCT3_CSRRSI, `FUNCT3_CSRRCI:
                csr_write_intent_ID = is_csr_instr_ID && (instr_ID[19:15] != 5'b0);
            default: csr_write_intent_ID = 1'b0;
        endcase
    end

    always_comb begin
        x7_effective_ID = x7_rf_ID;
        if (rf_we_commit && (wR_commit == 5'd7)) begin
            x7_effective_ID = rf_wd_commit;
        end
        if (rf_we_MEM && (wR_MEM == 5'd7)) begin
            x7_effective_ID = rf_wd_MEM;
        end
        if (rf_we_EX && (wR_EX == 5'd7)) begin
            x7_effective_ID = rf_wd_EX;
        end
    end

    assign privileged_illegal_instr_ID =
        (is_csr_instr_ID && !csr_implemented_ID) ||
        (is_csr_instr_ID && (current_priv_mode < csr_addr_ID[9:8])) ||
        (is_csr_instr_ID && csr_write_intent_ID && (csr_addr_ID[11:10] == 2'b11)) ||
        (is_csr_instr_ID && (csr_addr_ID == `CSR_SSP) &&
         (current_priv_mode != `PRV_M) && !current_sse_enabled) ||
        (is_csr_instr_ID && (csr_addr_ID == `CSR_SATP) &&
         (current_priv_mode == `PRV_S) && mstatus_tvm) ||
        (is_mret_ID && (current_priv_mode != `PRV_M)) ||
        (is_sret_ID &&
         ((current_priv_mode == `PRV_U) ||
          ((current_priv_mode == `PRV_S) && mstatus_tsr)));

    assign lpad_pass_ID = is_lpad_instr_ID &&
                          (pc_ID[1:0] == 2'b00) &&
                          ((instr_ID[31:12] == 20'b0) ||
                           (instr_ID[31:12] == x7_effective_ID[31:12]));
    assign software_check_exception_ID = valid_ID && current_lpe_enabled && elp_expected && !lpad_pass_ID;
    assign software_check_tval_ID = `SOFTCHK_LPAD_FAULT;

    // 早期非法指令异常检测 (ID级)
    // 当检测到非法指令时，在ID级就触发异常
    // 这样可以防止非法指令前面的指令(在EX级)提交
    assign illegal_instr_exception_ID = (is_illegal_instr_ID || privileged_illegal_instr_ID) && valid_ID;
    assign illegal_instr_pc_ID = pc_ID;
    assign illegal_instr_encoding_ID = instr_ID;
    assign csr_implemented_ID = csr_is_implemented(csr_addr_ID);

// ================= ID/EX 流水线寄存器 ===================

    // 前递信号与数据
    logic        fwd_rD1e_EX;
    logic        fwd_rD2e_EX;
    logic [31:0] fwd_rD1_EX;
    logic [31:0] fwd_rD2_EX;

    PR_ID_EX u_PR_ID_EX (
        .clk                 (clk),
        .rst_n               (rst_n),
        // 流水线控制信号
        .flush               (flush_ID_EX),
        // ID级输入
        .pc_id_i             (pc_ID),
        .pc4_id_i            (pc4_ID),
        .instr_id_i          (instr_ID),
        // ID级输出 给EX级输入
        .pc_ex_o             (pc_EX),
        .pc4_ex_o            (pc4_EX),
        .instr_ex_o          (instr_EX),
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
        .sl_type_id_i        (sl_type_ID),
        .sl_type_ex_o        (sl_type_EX),
        // 立即数
        .imm_id_i            (imm_ID),
        .imm_ex_o            (imm_EX),
        // PC跳转时地址
        .pc_jump_id_i        (branch_target_ID),
        .pc_jump_ex_o        (branch_target_EX),
        // 分支预测信息
        .predicted_taken_id_i(branch_predicted_fire_ID),
        .predicted_taken_ex_o(branch_predicted_EX),
        .predicted_target_id_i(branch_predicted_target_ID),
        .predicted_target_ex_o(branch_predicted_target_EX),
        // 前递相关
        .fwd_rD1e_EX         (fwd_rD1e_EX),
        .fwd_rD2e_EX         (fwd_rD2e_EX),
        .fwd_rD1_EX          (fwd_rD1_EX),
        .fwd_rD2_EX          (fwd_rD2_EX),
        // 乘法相关
        .is_mul_instr_id_i   (is_mul_instr_ID),
        .is_mul_instr_ex_o   (is_mul_instr_EX),
        .mul_op_id_i         (mul_op_ID),
        .mul_op_ex_o         (mul_op_EX),
        // CSR相关
        .is_csr_instr_id_i   (is_csr_instr_ID),
        .is_csr_instr_ex_o   (is_csr_instr_EX),
        .csr_op_id_i         (csr_op_ID),
        .csr_op_ex_o         (csr_op_EX),
        .csr_addr_id_i       (csr_addr_ID),
        .csr_addr_ex_o       (csr_addr_EX),
        .is_ecall_id_i       (is_ecall_ID),
        .is_ecall_ex_o       (is_ecall_EX),
        .is_mret_id_i        (is_mret_ID),
        .is_mret_ex_o        (is_mret_EX),
        .is_sret_id_i        (is_sret_ID),
        .is_sret_ex_o        (is_sret_EX),
        // 非法指令相关
        .is_illegal_instr_id_i(is_illegal_instr_ID || privileged_illegal_instr_ID),
        .is_illegal_instr_ex_o(is_illegal_instr_EX)
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

    // 乘法器 - 四级流水线，与EX级并行
    // 乘法指令在EX级启动，结果在4个周期后可用
    // 只有分支跳转会阻止乘法器启动，数据冒险不会
    assign mul_valid_i = is_mul_instr_EX && valid_EX && !redirect_from_ex_stage;

    MUL u_MUL (
        .clk             (clk),
        .rst_n           (rst_n),
        .mul_valid_i     (mul_valid_i),
        .mul_op_i        (mul_op_EX),
        .mul_src1_i      (rf_rd1_EX),
        .mul_src2_i      (rf_rd2_EX),
        .mul_rd_i        (wR_EX),
        .flush_i         (redirect_from_ex_stage),  // EX级控制流改变时冲刷乘法器
        .cancel_rd_i     (mul_cancel_rd),       // WAW hazard: cancel write to this register
        .mul_valid_o     (mul_valid_o),
        .mul_result_o    (mul_result),
        .mul_rd_o        (mul_rd_o),
        .mul_rf_we_o     (mul_rf_we_o),
        .mul_busy_o      (mul_busy),
        .mul_stage_busy_o(mul_stage_busy),
        .mul_rd_s_o      (mul_rd_s)
    );

    // CSR模块 - 在EX级处理CSR读写和异常
    // CSR write data selection:
    // - Register variants (CSRRW/CSRRS/CSRRC): use rs1 value (rf_rd1_EX)
    // - Immediate variants (CSRRWI/CSRRSI/CSRRCI): use 5-bit zimm from imm_EX
    always_comb begin
        if (csr_op_EX[2]) begin
            // Immediate variants: zimm is zero-extended 5-bit immediate
            csr_wdata_EX = {27'b0, imm_EX[4:0]};
        end else begin
            // Register variants: use rs1 value
            csr_wdata_EX = rf_rd1_EX;
        end
    end

    always_comb begin
        unique case (csr_op_EX)
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI: csr_write_intent_EX = is_csr_instr_EX;
            `FUNCT3_CSRRS, `FUNCT3_CSRRC, `FUNCT3_CSRRSI, `FUNCT3_CSRRCI:
                csr_write_intent_EX = is_csr_instr_EX && (instr_EX[19:15] != 5'b0);
            default: csr_write_intent_EX = 1'b0;
        endcase
    end

    assign shadow_mem_active_EX = valid_EX && current_sse_enabled &&
                                  ((sl_type_EX == `MEM_SSPUSH) || (sl_type_EX == `MEM_SSPOPCHK));
    assign csr_implemented_EX = csr_is_implemented(csr_addr_EX);
    assign sl_type_effective_EX =
        shadow_mem_active_EX ? sl_type_EX :
        (((sl_type_EX == `MEM_SSPUSH) || (sl_type_EX == `MEM_SSPOPCHK)) ? `MEM_NOP : sl_type_EX);
    assign shadow_addr_EX = (sl_type_EX == `MEM_SSPUSH) ? (ssp_value - 32'd4) : ssp_value;

    // Exception handling:
    // 异常分为两类：
    // 1. ID级异常：非法指令 - 需要早期检测以防止其前面的指令提交
    // 2. EX级异常：地址未对齐、ECALL - 在执行阶段检测
    //
    // - Instruction address misaligned: mcause = 0, mtval = misaligned address
    // - Illegal instruction: mcause = 2, mtval = instruction encoding
    // - Load address misaligned: mcause = 4, mtval = misaligned address
    // - Store address misaligned: mcause = 6, mtval = misaligned address
    // - ECALL: mcause = 11, mtval = 0

    // Misaligned address detection (EX stage)
    // For JALR: target must be 4-byte aligned (bit 1 must be 0 for RV32I without C extension)
    // JAL/branch targets must also be 4-byte aligned when the C extension is absent.
    // JALR target = (rs1 + imm) & ~1, so we check bit 1 of alu_result (before masking).
    logic instr_misaligned_EX;
    logic [31:0] jalr_target_EX;
    logic [31:0] branch_target_normal;
    logic [31:0] instr_target_EX;
    logic branch_jal_target_misaligned_EX;
    logic take_branch_normal;
    logic normal_control_mispredict_EX;
    logic [31:0] normal_control_recover_target_EX;
    assign jalr_target_EX = {alu_result_EX[31:1], 1'b0};  // JALR target after masking bit 0
    assign branch_jal_target_misaligned_EX = take_branch_normal &&
                                             (jump_type_EX != `JUMP_JALR) &&
                                             (branch_target_normal[1] != 1'b0);
    assign instr_misaligned_EX = ((jump_type_EX == `JUMP_JALR) && (alu_result_EX[1] != 1'b0)) ||
                                 branch_jal_target_misaligned_EX;
    assign instr_target_EX = (jump_type_EX == `JUMP_JALR) ? jalr_target_EX : branch_target_normal;

    // Load/Store address misaligned detection (EX stage)
    // LW/SW: must be 4-byte aligned (bits [1:0] == 00)
    // LH/LHU/SH: must be 2-byte aligned (bit [0] == 0)
    // LB/LBU/SB: no alignment requirement
    logic load_misaligned_EX;
    logic store_misaligned_EX;
    always_comb begin
        load_misaligned_EX = 1'b0;
        store_misaligned_EX = 1'b0;
        case (sl_type_effective_EX)
            `MEM_LW:  load_misaligned_EX  = (alu_result_EX[1:0] != 2'b00);
            `MEM_LH,
            `MEM_LHU: load_misaligned_EX  = (alu_result_EX[0] != 1'b0);
            `MEM_SW:  store_misaligned_EX = (alu_result_EX[1:0] != 2'b00);
            `MEM_SH:  store_misaligned_EX = (alu_result_EX[0] != 1'b0);
            default: begin
                load_misaligned_EX  = 1'b0;
                store_misaligned_EX = 1'b0;
            end
        endcase
    end

    // EX级异常 (不包括非法指令，非法指令在ID级处理)
    logic exception_valid_EX;
    assign shadow_access_fault_EX = shadow_mem_active_EX && (shadow_addr_EX[1:0] != 2'b00);
    assign exception_valid_EX = (instr_misaligned_EX || load_misaligned_EX ||
                                 store_misaligned_EX || shadow_access_fault_EX ||
                                 is_ecall_EX) && valid_EX;
    assign mul_commit_serialize_active = is_mul_instr_EX || mul_busy;
    assign redirect_from_ex_stage = normal_control_mispredict_EX ||
                                    exception_valid_EX ||
                                    (is_mret_EX && valid_EX) ||
                                    (is_sret_EX && valid_EX);
    assign flushes_id_exception_ID = redirect_from_ex_stage || sspopchk_fault_WB ||
                                     mul_commit_serialize_active || shadow_serialize_EX ||
                                     shadow_serialize_MEM || shadow_serialize_WB;
    assign software_check_exception_effective_ID =
        software_check_exception_ID && !flushes_id_exception_ID;
    assign illegal_instr_exception_effective_ID =
        illegal_instr_exception_ID && !flushes_id_exception_ID && !software_check_exception_ID;

    // 总异常信号：EX级异常 OR ID级非法指令异常
    // 优先级：EX级异常 > ID级异常
    // 注意：当EX级有有效的跳转/分支时，ID级的指令将被flush，
    // 所以ID级的非法指令异常不应该生效
    // 这防止了跳转到数据区域时，数据被误认为非法指令而触发异常
    assign exception_valid = sspopchk_fault_WB ||
                             exception_valid_EX ||
                             software_check_exception_effective_ID ||
                             illegal_instr_exception_effective_ID;

    // 异常PC和原因/值的选择
    always_comb begin
        if (sspopchk_fault_WB) begin
            exception_pc    = pc_WB;
            exception_cause = `EXC_SOFTWARE_CHECK;
            exception_tval  = `SOFTCHK_SHADOW_STACK_FAULT;
        end else if (instr_misaligned_EX && valid_EX) begin
            // EX级地址未对齐异常优先
            exception_pc    = pc_EX;
            exception_cause = 32'd0;  // Instruction address misaligned
            exception_tval  = instr_target_EX;
        end else if (load_misaligned_EX && valid_EX) begin
            exception_pc    = pc_EX;
            exception_cause = 32'd4;  // Load address misaligned
            exception_tval  = alu_result_EX;
        end else if (store_misaligned_EX && valid_EX) begin
            exception_pc    = pc_EX;
            exception_cause = `EXC_STORE_MISALIGNED;
            exception_tval  = alu_result_EX;
        end else if (shadow_access_fault_EX && valid_EX) begin
            exception_pc    = pc_EX;
            exception_cause = `EXC_STORE_ACCESS_FAULT;
            exception_tval  = shadow_addr_EX;
        end else if (is_ecall_EX && valid_EX) begin
            exception_pc    = pc_EX;
            case (current_priv_mode)
                `PRV_U:  exception_cause = `EXC_ECALL_U;
                `PRV_S:  exception_cause = `EXC_ECALL_S;
                default: exception_cause = `EXC_ECALL_M;
            endcase
            exception_tval  = 32'b0;
        end else if (software_check_exception_effective_ID) begin
            exception_pc    = pc_ID;
            exception_cause = `EXC_SOFTWARE_CHECK;
            exception_tval  = software_check_tval_ID;
        end else if (illegal_instr_exception_effective_ID) begin
            // ID级非法指令异常
            exception_pc    = illegal_instr_pc_ID;
            exception_cause = `EXC_ILLEGAL_INSTR;
            exception_tval  = illegal_instr_encoding_ID;
        end else begin
            // 默认值 (不应该到达这里)
            exception_pc    = pc_EX;
            exception_cause = `EXC_INST_MISALIGNED;
            exception_tval  = 32'b0;
        end
    end

    CSR u_CSR (
        .clk            (clk),
        .rst_n          (rst_n),
        // CSR instruction interface
        .csr_we         (is_csr_instr_EX && valid_EX && csr_write_intent_EX && csr_implemented_EX),
        .csr_addr       (csr_addr_EX),
        .csr_wdata      (csr_wdata_EX),
        .csr_op         (csr_op_EX),
        .csr_rdata      (csr_rdata_EX),
        // Exception/trap interface
        .exception_valid(exception_valid),
        .exception_pc   (exception_pc),
        .exception_cause(exception_cause),
        .exception_tval (exception_tval),
        // xRET interface
        .mret_valid     (is_mret_EX && valid_EX),
        .sret_valid     (is_sret_EX && valid_EX),
        .ssp_update_valid(ssp_update_valid),
        .ssp_update_data(ssp_update_data),
        .elp_update_valid(elp_update_valid),
        .elp_update_expected(elp_update_expected),
        // Trap output
        .trap_to_mmode  (trap_to_mmode),
        .trap_target    (trap_target),
        .xret_target    (xret_target),
        .current_priv_mode(current_priv_mode),
        .mstatus_tsr    (mstatus_tsr),
        .mstatus_tvm    (mstatus_tvm),
        .current_sse_enabled(current_sse_enabled),
        .current_lpe_enabled(current_lpe_enabled),
        .elp_expected   (elp_expected),
        .ssp_value      (ssp_value)
    );

    assign sspopchk_fault_WB = valid_WB && (sl_type_WB == `MEM_SSPOPCHK) &&
                               (load_data_WB != rf_wd_WB_from_ALU);
    assign sspopchk_success_WB = valid_WB && (sl_type_WB == `MEM_SSPOPCHK) &&
                                 (load_data_WB == rf_wd_WB_from_ALU);
    assign ssp_update_valid = (shadow_mem_active_EX && (sl_type_EX == `MEM_SSPUSH) &&
                               !shadow_access_fault_EX) || sspopchk_success_WB;
    assign ssp_update_data = (shadow_mem_active_EX && (sl_type_EX == `MEM_SSPUSH)) ?
                             shadow_addr_EX : (ssp_value + 32'd4);
    assign elp_update_valid = (valid_EX && current_lpe_enabled &&
                               (jump_type_EX == `JUMP_JALR) &&
                               (instr_EX[19:15] != 5'd1) &&
                               (instr_EX[19:15] != 5'd5) &&
                               (instr_EX[19:15] != 5'd7) &&
                               !exception_valid_EX) ||
                              (lpad_pass_ID && valid_ID && !flushes_id_exception_ID);
    assign elp_update_expected = valid_EX && current_lpe_enabled &&
                                 (jump_type_EX == `JUMP_JALR) &&
                                 (instr_EX[19:15] != 5'd1) &&
                                 (instr_EX[19:15] != 5'd5) &&
                                 (instr_EX[19:15] != 5'd7) &&
                                 !exception_valid_EX;

    // NextPC 计算 - 现在需要考虑异常、MRET和SRET
    NextPC_Generator u_NextPC_Generator (
        .is_branch_instr     (is_branch_instr_EX),
        .branch_type         (branch_type_EX),
        .jump_type           (jump_type_EX),
        .alu_result          (alu_result_EX),
        .branch_target_i     (branch_target_EX),
        .alu_zero            (alu_zero),
        .alu_sign            (alu_sign),
        .alu_unsigned        (alu_unsigned),
        .take_branch         (take_branch_normal),
        .branch_target_NextPC(branch_target_normal)
    );

    assign normal_control_mispredict_EX =
        valid_EX &&
        ((branch_predicted_EX != take_branch_normal) ||
         (branch_predicted_EX && take_branch_normal &&
          (branch_predicted_target_EX != branch_target_normal)));
    assign normal_control_recover_target_EX = take_branch_normal ? branch_target_normal : pc4_EX;

    // 优先级: Exception > xRET > 错预测恢复
    always_comb begin
        if (exception_valid) begin
            take_branch_NextPC    = 1'b1;
            branch_target_NextPC  = trap_target;
        end else if ((is_mret_EX || is_sret_EX) && valid_EX) begin
            take_branch_NextPC    = 1'b1;
            branch_target_NextPC  = xret_target;
        end else if (normal_control_mispredict_EX) begin
            take_branch_NextPC    = 1'b1;
            branch_target_NextPC  = normal_control_recover_target_EX;
        end else begin
            take_branch_NextPC    = 1'b0;
            branch_target_NextPC  = 32'b0;
        end
    end

    assign branch_predicted_fire_ID = ENABLE_STATIC_BPU && branch_predicted_ID && !keep_PC && !take_branch_NextPC;
    assign pc_redirect_op = take_branch_NextPC || branch_predicted_fire_ID;
    assign pc_redirect_target = take_branch_NextPC ? branch_target_NextPC : branch_predicted_target_ID;

    logic [31:0] shadow_operand_EX;
    always_comb begin
        unique case (sl_type_EX)
            `MEM_SSPUSH:   shadow_operand_EX = rf_rd2_EX;
            `MEM_SSPOPCHK: shadow_operand_EX = rf_rd1_EX;
            default:       shadow_operand_EX = 32'b0;
        endcase
    end

    // 回写数据来源选择MUX
    // 在EX级完成选择以减少流水线寄存器宽度
    // 注意 load 指令的数据在 MEM 级才可用 因此不可能选择 DRAM 作为回写数据来源
    always_comb begin : wd_EX_MUX
        if (shadow_mem_active_EX &&
            ((sl_type_EX == `MEM_SSPUSH) || (sl_type_EX == `MEM_SSPOPCHK))) begin
            rf_wd_EX = shadow_operand_EX;
        end else begin
            case (wd_sel_EX)
                `WD_SEL_FROM_ALU:  rf_wd_EX = alu_result_EX;
                // `WD_SEL_FROM_DRAM在MEM级处理
                `WD_SEL_FROM_PC4:  rf_wd_EX = pc4_EX;
                // 如果回写的是立即数扩展值 则需要判断是否为AUIPC指令
                `WD_SEL_FROM_IEXT: rf_wd_EX = (is_auipc_EX) ? branch_target_EX : imm_EX;
                `WD_SEL_FROM_CSR:  rf_wd_EX = csr_rdata_EX;
                `WD_SEL_FROM_SSP:  rf_wd_EX = current_sse_enabled ? ssp_value : 32'b0;
                default:           rf_wd_EX = 32'b0;
            endcase
        end
    end

// ================= EX/MEM 流水线寄存器 ===================

    // 异常处理和流水线冲刷：
    // - EX级异常需要阻止 faulting 指令进入 MEM
    // - ID级非法指令只应杀掉它自己和更年轻的指令，不能回滚更老的 EX/MEM/WB 指令
    logic flush_EX_MEM;
    logic flush_MEM_WB;
    assign flush_EX_MEM = exception_valid_EX || sspopchk_fault_WB;
    assign flush_MEM_WB = sspopchk_fault_WB;

    PR_EX_MEM u_PR_EX_MEM (
        .clk              (clk),
        .rst_n            (rst_n),
        .flush            (flush_EX_MEM),
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
        .alu_result_ex_i  (shadow_mem_active_EX ? shadow_addr_EX : alu_result_EX),
        .alu_result_mem_o (alu_result_MEM),
        .wd_ex_i          (rf_wd_EX),
        .wd_mem_o         (rf_wd_MEM),
        .rD2_ex_i         (rf_rd2_EX),
        .rD2_mem_o        (rf_rd2_MEM),
        .sl_type_ex_i     (sl_type_effective_EX),
        .sl_type_mem_o    (sl_type_MEM)
    );

// MEM 级

    // LoadStoreUnit模块 - MEM级只处理Store操作
    logic [31:0] DRAM_input_data;  // LSU处理后数据
    logic [ 3:0] dram_we_MEM_strbe;
    // MEM级LSU仅用于Store处理，Load在WB级处理
    StoreUnit u_StoreUnit_MEM (
        .sl_type      (sl_type_MEM),
        .addr         (alu_result_MEM),
        .store_data_i ((sl_type_MEM == `MEM_SSPUSH) ? rf_wd_MEM : rf_rd2_MEM),
        .store_data_o (DRAM_input_data),
        .dram_we      (dram_we_MEM),
        .wstrb        (dram_we_MEM_strbe)
    );

    logic [31:0] DRAM_output_data;  // LSU从DRAM得到的数据
    // DRAM模块
    DRAM #(
        // [HACK] Xilinx 可综合的位写入BRAM最大为12位地址宽度
        .ADDR_WIDTH(14)
    ) u_DRAM (
        .clk(clk),
        .a  (alu_result_MEM[31:2]),  // 字节地址转换为字地址 (除以4)
        .spo(DRAM_output_data),
        .we (dram_we_MEM_strbe),
        .din(DRAM_input_data)
    );

    // 对于同步DRAM，数据将在下一个时钟周期可用
    // 将数据传递到WB级，在WB级进行选择

// ================= MEM/WB 流水线寄存器 ===================

    PR_MEM_WB u_PR_MEM_WB (
        .clk              (clk),
        .rst_n            (rst_n),
        .flush            (flush_MEM_WB),
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
        .wd_wb_o          (rf_wd_WB_from_ALU),
        // 注意：DRAM的spo输出已经是寄存器输出，但我们不在PR_MEM_WB中再次寄存
        // 而是在WB级直接使用DRAM_output_data以避免额外的一个周期延迟
        // 写回数据来源选择信号
        .wd_sel_mem_i     (wd_sel_MEM),
        .wd_sel_wb_o      (wd_sel_WB),
        // 存取类型传递到WB级，用于Load数据处理
        .sl_type_mem_i    (sl_type_MEM),
        .sl_type_wb_o     (sl_type_WB),
        // ALU结果（地址）传递到WB级，用于Load数据字节偏移计算
        .alu_result_mem_i (alu_result_MEM),
        .alu_result_wb_o  (alu_result_WB)
    );

// WB 级
    // WB级LoadStoreUnit - 专门处理Load操作
    // 使用WB级的sl_type和地址来正确处理DRAM读取的数据
    LoadUnit u_LoadUnit_WB (
        .sl_type    (sl_type_WB),
        .addr       (alu_result_WB),
        .load_data_i(DRAM_output_data),
        .load_data_o(load_data_WB)
    );

    assign shadow_serialize_EX = shadow_mem_active_EX;
    assign shadow_serialize_MEM = valid_MEM &&
                                  ((sl_type_MEM == `MEM_SSPUSH) || (sl_type_MEM == `MEM_SSPOPCHK));
    assign shadow_serialize_WB = valid_WB &&
                                 ((sl_type_WB == `MEM_SSPUSH) || (sl_type_WB == `MEM_SSPOPCHK));

    // 主流水线WB数据选择
    // 对于同步DRAM，DRAM的spo已经是寄存器输出，在WB级直接使用以避免多余延迟
    // DRAM_output_data在整个WB周期内保持稳定，可以安全地被寄存器堆采样
    always_comb begin
        if (wd_sel_WB == `WD_SEL_FROM_DRAM) begin
            rf_wd_WB_from_ALU_or_DRAM = load_data_WB;
        end else begin
            rf_wd_WB_from_ALU_or_DRAM = rf_wd_WB_from_ALU;
        end
    end

    // 单写口提交仲裁：
    // 当前顺序提交实现保证MUL完成时不会与主流水线WB同拍冲突。
    always_comb begin
        rf_we_commit = 1'b0;
        wR_commit    = 5'b0;
        rf_wd_commit = 32'b0;

        if (rf_we_WB) begin
            rf_we_commit = 1'b1;
            wR_commit    = wR_WB;
            rf_wd_commit = rf_wd_WB_from_ALU_or_DRAM;
        end else if (mul_rf_we_o) begin
            rf_we_commit = 1'b1;
            wR_commit    = mul_rd_o;
            rf_wd_commit = mul_result;
        end
    end

    assign rf_wd_WB = rf_wd_WB_from_ALU_or_DRAM;

    // 冒险控制单元

    HazardUnit u_HazardUnit (
        .wd_sel_EX         (wd_sel_EX),
        .wd_sel_MEM        (wd_sel_MEM),
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
        .branch_predicted_i(branch_predicted_fire_ID),
        // 乘法器状态信号 (4级流水线)
        .mul_stage_busy    (mul_stage_busy),
        .mul_rd_s          (mul_rd_s),
        .is_mul_instr_ID   (is_mul_instr_ID),
        .is_mul_instr_EX   (is_mul_instr_EX),
        // WAW冒险检测所需的ID级信号
        .wR_ID             (wR_ID),
        .rf_we_ID          (rf_we_ID),
        .shadow_serialize_EX(shadow_serialize_EX),
        .shadow_serialize_MEM(shadow_serialize_MEM),
        .shadow_serialize_WB(shadow_serialize_WB),
        // 输出
        .keep_pc           (keep_PC),
        .stall_IF_ID       (stall_IF_ID),
        .flush_IF_ID       (flush_IF_ID),
        .flush_ID_EX       (flush_ID_EX),
        .fwd_rD1e_EX       (fwd_rD1e_EX),
        .fwd_rD2e_EX       (fwd_rD2e_EX),
        .fwd_rD1_EX        (fwd_rD1_EX),
        .fwd_rD2_EX        (fwd_rD2_EX),
        .mul_cancel_rd     (mul_cancel_rd)
    );

    logic [1:0] check_csr_ID, check_csr_EX;
    assign check_csr_ID = $countones({is_csr_instr_ID,is_ecall_ID, is_mret_ID, is_sret_ID});
    assign check_csr_EX = $countones({is_csr_instr_EX,is_ecall_EX, is_mret_EX, is_sret_EX});

    always_ff @(posedge clk) begin
        if (rst_n) begin

            // load: 读内存/写寄存器 不写内存
            if (alu_op_ID == `ALU_LW || alu_op_ID == `ALU_LH || alu_op_ID == `ALU_LB ||
                alu_op_ID == `ALU_LHU || alu_op_ID == `ALU_LBU) begin
                assert (!dram_we_ID && rf_we_ID)
                else $error("[FATAL] LOAD INCONSISTENT");
            end

            // store: 写内存 不写寄存器
            if (alu_op_ID == `ALU_SW || alu_op_ID == `ALU_SH || alu_op_ID == `ALU_SB) begin
                assert (dram_we_ID && !rf_we_ID)
                else $error("[FATAL] STORE INCONSISTENT");
            end

            // branch: 不读/写内存
            if (is_branch_instr_ID) begin
                assert (!dram_we_ID && !rf_we_ID)
                else $error("[FATAL] BRANCH INCONSISTENT");
            end

            // ALU_OP 不应为X
            assert (alu_op_ID[0] !== 1'bx && alu_op_ID[1] !== 1'bx && alu_op_ID[2] !== 1'bx &&
                    alu_op_ID[3] !== 1'bx && alu_op_ID[4] !== 1'bx)
            else $error("[FATAL] ALU_OP X detected in ID stage");

            // is_ecall/is_mret/is_sret同一时间只能有一个为1
            assert (check_csr_ID < 2'd2)
            else $error("[FATAL] ECALL/MRET/SRET conflict in ID stage");
            assert (check_csr_EX < 2'd2)
            else $error("[FATAL] ECALL/MRET/SRET conflict in EX stage");

            // 单写口提交约束：顺序提交模式下MUL与主流水线WB不应同拍有效
            assert (!(rf_we_WB && mul_rf_we_o))
            else $error("[FATAL] WB and MUL commit conflict on single write port");
        end
    end

`ifdef DEBUG
`ifndef YOSYS
    always_comb begin
        if ($time > 0) begin
            assert (pc_IF[1:0] == 2'b00)
            else $error("CPU_TOP Error: PC is not word-aligned! PC=0x%h", pc_IF);
            assert (!(dram_we_ID && rf_we_ID))
            else $error("[%0t] Decoder Error: dram_we and rf_we are both high!", $time);
            if (!rst_n) begin
                assert (pc_IF >= `INITIAL_PC)
                else
                    $error("CPU_TOP Error: PC is less than INITIAL_PC after reset! PC=0x%h", pc_IF);
            end
        end
    end

`else
    property pc_reset_stable;
        @(posedge clk) (!rst_n) |-> (pc_IF == `INITIAL_PC);
    endproperty
    assert property (pc_reset_stable);
`endif
`endif

endmodule
`endif
