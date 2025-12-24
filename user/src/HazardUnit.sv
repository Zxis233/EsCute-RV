`include "include/defines.svh"
module HazardUnit (
    input  logic             clk,
    input  logic             rst_n,
    // LOAD/MUL指令判断 (扩展到3位以支持WD_SEL_FROM_MUL)
    input  logic [ 2:0]      wd_sel_EX,
    input  logic [ 2:0]      wd_sel_MEM,
    // 寄存器使用信号
    input  logic             rs1_used_ID,
    input  logic             rs2_used_ID,
    // ID级源寄存器地址
    input  logic [ 4:0]      rR1_ID,
    input  logic [ 4:0]      rR2_ID,
    // EX级目的寄存器地址
    input  logic [ 4:0]      wR_EX,
    // MEM级目的寄存器地址
    input  logic [ 4:0]      wR_MEM,
    // WB级目的寄存器地址
    input  logic [ 4:0]      wR_WB,
    // 写入数据使能
    input  logic             rf_we_EX,
    input  logic             rf_we_MEM,
    input  logic             rf_we_WB,
    // 写入数据
    input  logic [31:0]      rf_wd_EX,
    input  logic [31:0]      rf_wd_MEM,
    input  logic [31:0]      rf_wd_WB,
    // 分支跳转信号
    input  logic             take_branch_NextPC,
    // 预留的分支预测结果
    input  logic             branch_predicted_i,
    // 乘法器状态信号 (4级流水线)
    // 约定：mul_stage_busy[0]=S1 ... [3]=S4；mul_rd_s[0]=S1 ... [3]=S4
    input  logic [ 3:0]      mul_stage_busy,      // 乘法器各级流水线忙状态
    input  logic [ 3:0][4:0] mul_rd_s,            // 乘法器各级流水线目标寄存器地址
    input  logic             is_mul_instr_ID,     // ID级是否为乘法指令
    input  logic             is_mul_instr_EX,     // EX级是否为乘法指令
    // ID级目的寄存器地址和写使能 (用于WAW冒险检测)
    input  logic [ 4:0]      wR_ID,               // ID级目的寄存器地址
    input  logic             rf_we_ID,            // ID级寄存器写使能
    // PC保持信号
    output logic             keep_pc,
    // IF/ID停顿信号
    output logic             stall_IF_ID,
    // IF/ID冲刷信号
    output logic             flush_IF_ID,
    // ID/EX冲刷信号
    output logic             flush_ID_EX,
    // 前递使能
    output logic             fwd_rD1e_EX,
    output logic             fwd_rD2e_EX,
    // 前递数据
    output logic [31:0]      fwd_rD1_EX,
    output logic [31:0]      fwd_rD2_EX,
    // 乘法器写回无效化信号 (WAW冒险时取消MUL写回)
    output logic [ 4:0]      mul_cancel_rd
);

    // ------------------------------------------------------------
    // RAW 冒险判断 (用于前递/Load-Use 等)
    // ------------------------------------------------------------
    // verilog_format: off
    logic RAW_1_rD1, RAW_1_rD2;
    logic RAW_2_rD1, RAW_2_rD2;
    logic RAW_3_rD1, RAW_3_rD2;

    always_comb begin
        // 间隔一级流水线 判断下写入的不为x0即可
        RAW_1_rD1 = (wR_EX ==  rR1_ID) &&  rf_we_EX && rs1_used_ID && (wR_EX != 5'b0);
        RAW_1_rD2 = (wR_EX ==  rR2_ID) &&  rf_we_EX && rs2_used_ID && (wR_EX != 5'b0);
        // 间隔两级流水线
        RAW_2_rD1 = (wR_MEM == rR1_ID) && rf_we_MEM && rs1_used_ID && (wR_MEM != 5'b0);
        RAW_2_rD2 = (wR_MEM == rR2_ID) && rf_we_MEM && rs2_used_ID && (wR_MEM != 5'b0);
        // 间隔三级流水线
        RAW_3_rD1 = (wR_WB ==  rR1_ID) &&  rf_we_WB && rs1_used_ID && (wR_WB != 5'b0);
        RAW_3_rD2 = (wR_WB ==  rR2_ID) &&  rf_we_WB && rs2_used_ID && (wR_WB != 5'b0);
    end

    // 前递使能信号生成
    always_comb begin
        fwd_rD1e_EX = RAW_1_rD1 || RAW_2_rD1 || RAW_3_rD1;
        fwd_rD2e_EX = RAW_1_rD2 || RAW_2_rD2 || RAW_3_rD2;
    end

    // 前递数据选择
    // 优先级 EX > MEM > WB
    // 对于同步DRAM MEM级的load指令数据尚未可用 不能前递
    always_comb begin
        // case-true 语句
        // 源操作数1前递数据选择
        case (1'b1)
            RAW_1_rD1: fwd_rD1_EX = rf_wd_EX;  // 来自EX级
            RAW_2_rD1: fwd_rD1_EX = rf_wd_MEM; // 来自MEM级
            RAW_3_rD1: fwd_rD1_EX = rf_wd_WB;
            default:   fwd_rD1_EX = 32'b0;
        endcase
        // 源操作数2前递数据选择
        case (1'b1)
            RAW_1_rD2: fwd_rD2_EX = rf_wd_EX;  // 来自EX级
            RAW_2_rD2: fwd_rD2_EX = rf_wd_MEM; // 来自MEM级
            RAW_3_rD2: fwd_rD2_EX = rf_wd_WB;
            default:   fwd_rD2_EX = 32'b0;
        endcase
    end
    // verilog_format: on

    // Load_use 冒险判断
    // 对于同步DRAM load指令的数据在WB级才可用
    // 需要检测EX级和MEM级的load指令
    logic load_use_hazard;
    logic load_use_hazard_ex;  // EX级的load指令导致的冒险
    logic load_use_hazard_mem;  // MEM级的load指令导致的冒险

    // EX级的load指令需要停顿2个周期
    assign load_use_hazard_ex  = (wd_sel_EX == `WD_SEL_FROM_DRAM) && (RAW_1_rD1 || RAW_1_rD2);

    // MEM级的load指令需要停顿1个周期（数据还未到达WB级）
    assign load_use_hazard_mem = (wd_sel_MEM == `WD_SEL_FROM_DRAM) && (RAW_2_rD1 || RAW_2_rD2);

    assign load_use_hazard     = load_use_hazard_ex || load_use_hazard_mem;

    // ------------------------------------------------------------
    // MUL 冒险判断（RAW + 结构冒险 + WAW处理）
    // 乘法器 4 级流水：S1->S2->S3->S4（结果在S4末尾可用）
    // ------------------------------------------------------------
    logic mul_use_hazard;
    logic mul_struct_hazard;
    logic mul_waw_hazard;
    logic pure_waw_conflict;

    // 结构冒险：S1被占用时，新的乘法指令不能进入
    assign mul_struct_hazard = is_mul_instr_ID && mul_stage_busy[0];

    // 将 EX + S1..S4 统一成 5 路，便于循环处理
    // mul_rd_all[0]=EX，mul_rd_all[1]=S1 ... mul_rd_all[4]=S4
    logic [4:0][4:0] mul_rd_all;
    logic [4:0]      mul_vld_all;
    assign mul_rd_all  = {mul_rd_s, wR_EX};
    assign mul_vld_all = {mul_stage_busy, is_mul_instr_EX};

    // Debug/可视化向量（可在波形里直接看每一级是否命中）
    logic [4:0] mul_raw_hit_r1;
    logic [4:0] mul_raw_hit_r2;
    logic [4:0] id_reads_mul_rd;
    logic [4:0] mul_waw_conflict;

    always_comb begin
        mul_raw_hit_r1   = '0;
        mul_raw_hit_r2   = '0;
        id_reads_mul_rd  = '0;
        mul_waw_conflict = '0;

        for (int i = 0; i < 5; i++) begin
            // RAW：ID读取 rR1/rR2，且命中任一在飞MUL的rd
            mul_raw_hit_r1[i] = mul_vld_all[i] && (mul_rd_all[i] != 5'd0) && rs1_used_ID &&
                (mul_rd_all[i] == rR1_ID);
            mul_raw_hit_r2[i] = mul_vld_all[i] && (mul_rd_all[i] != 5'd0) && rs2_used_ID &&
                (mul_rd_all[i] == rR2_ID);

            // ID是否读取了该rd（用于区分 WAW 需要停顿 / 仅取消写回）
            id_reads_mul_rd[i] = (mul_rd_all[i] != 5'd0) &&
                ((rs1_used_ID && (rR1_ID == mul_rd_all[i])) ||
                 (rs2_used_ID && (rR2_ID == mul_rd_all[i])));

            // WAW冲突：ID将写 wR_ID，且与某级MUL rd 相同
            mul_waw_conflict[i] = mul_vld_all[i] && rf_we_ID && (wR_ID != 5'd0) &&
                (mul_rd_all[i] == wR_ID);
        end

        mul_use_hazard    = (|mul_raw_hit_r1) || (|mul_raw_hit_r2);

        // WAW冒险：只有 WAW + 同时存在RAW读依赖 才需要停顿
        mul_waw_hazard    = |(mul_waw_conflict & id_reads_mul_rd);
        pure_waw_conflict = |(mul_waw_conflict & ~id_reads_mul_rd);
    end

    // 纯WAW冲突（无RAW依赖）时，取消MUL对该寄存器的写回
    assign mul_cancel_rd = pure_waw_conflict ? wR_ID : 5'd0;

    // [TODO] 静态/动态分支预测
    logic branch_predicted_result;
    // 目前：不预测，使用EX级实际跳转结果
    // assign branch_predicted_result = branch_predicted_i;
    assign branch_predicted_result = take_branch_NextPC;

    // ------------------------------------------------------------
    // 流水线冲刷与停顿
    // ------------------------------------------------------------
    logic any_hazard;
    assign any_hazard = load_use_hazard || mul_use_hazard || mul_struct_hazard || mul_waw_hazard;

    always_comb begin
        keep_pc     = any_hazard ? 1'b1 : 1'b0;
        stall_IF_ID = any_hazard ? 1'b1 : 1'b0;
        flush_IF_ID = branch_predicted_result ? 1'b1 : 1'b0;
        flush_ID_EX = (branch_predicted_result || any_hazard) ? 1'b1 : 1'b0;
    end

endmodule
