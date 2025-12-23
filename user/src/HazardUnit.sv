`include "include/defines.svh"

module HazardUnit (
    input  logic        clk,
    input  logic        rst_n,
    // LOAD/MUL指令判断 (扩展到3位以支持WD_SEL_FROM_MUL)
    input  logic [ 2:0] wd_sel_EX,
    input  logic [ 2:0] wd_sel_MEM,
    // 寄存器使用信号
    input  logic        rs1_used_ID,
    input  logic        rs2_used_ID,
    // ID级源寄存器地址
    input  logic [ 4:0] rR1_ID,
    input  logic [ 4:0] rR2_ID,
    // EX级目的寄存器地址
    input  logic [ 4:0] wR_EX,
    // MEM级目的寄存器地址
    input  logic [ 4:0] wR_MEM,
    // WB级目的寄存器地址
    input  logic [ 4:0] wR_WB,
    // 写入数据使能
    input  logic        rf_we_EX,
    input  logic        rf_we_MEM,
    input  logic        rf_we_WB,
    // 写入数据
    input  logic [31:0] rf_wd_EX,
    input  logic [31:0] rf_wd_MEM,
    input  logic [31:0] rf_wd_WB,
    // 分支跳转信号
    input  logic        take_branch_NextPC,
    // 预留的分支预测结果
    input  logic        branch_predicted_i,
    // 乘法器状态信号 (4级流水线)
    input  logic        mul_stage1_busy,     // 乘法器第一级忙
    input  logic        mul_stage2_busy,     // 乘法器第二级忙
    input  logic        mul_stage3_busy,     // 乘法器第三级忙
    input  logic        mul_stage4_busy,     // 乘法器第四级忙
    input  logic [ 4:0] mul_rd_s1,           // 乘法器第一级目标寄存器
    input  logic [ 4:0] mul_rd_s2,           // 乘法器第二级目标寄存器
    input  logic [ 4:0] mul_rd_s3,           // 乘法器第三级目标寄存器
    input  logic [ 4:0] mul_rd_s4,           // 乘法器第四级目标寄存器
    input  logic        is_mul_instr_ID,     // ID级是否为乘法指令
    input  logic        is_mul_instr_EX,     // EX级是否为乘法指令
    // ID级目的寄存器地址和写使能 (用于WAW冒险检测)
    input  logic [ 4:0] wR_ID,               // ID级目的寄存器地址
    input  logic        rf_we_ID,            // ID级寄存器写使能
    // PC保持信号
    output logic        keep_pc,
    // IF/ID停顿信号
    output logic        stall_IF_ID,
    // IF/ID冲刷信号
    output logic        flush_IF_ID,
    // ID/EX冲刷信号
    output logic        flush_ID_EX,
    // 前递使能
    output logic        fwd_rD1e_EX,
    output logic        fwd_rD2e_EX,
    // 前递数据
    output logic [31:0] fwd_rD1_EX,
    output logic [31:0] fwd_rD2_EX
);

    // RAW 冒险判断
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

    // 乘法指令冒险判断
    // 乘法器是四级流水线，结果在第四级末尾才可用
    // 如果ID级的指令依赖于乘法器中正在计算的结果，需要停顿
    logic mul_use_hazard;
    logic mul_ex_hazard_rD1, mul_ex_hazard_rD2;  // EX级的乘法指令导致的冒险
    logic mul_s1_hazard_rD1, mul_s1_hazard_rD2;
    logic mul_s2_hazard_rD1, mul_s2_hazard_rD2;
    logic mul_s3_hazard_rD1, mul_s3_hazard_rD2;
    logic mul_s4_hazard_rD1, mul_s4_hazard_rD2;

    always_comb begin
        // EX级的乘法指令导致的冒险
        // 当MUL在EX级时，如果ID级的指令需要MUL的结果，必须停顿
        // 流水线流程：EX -> MUL_S1 -> MUL_S2 -> MUL_S3 -> MUL_S4(结果可用)，需停顿3个周期
        mul_ex_hazard_rD1 = is_mul_instr_EX && (wR_EX == rR1_ID) && rs1_used_ID && (wR_EX != 5'b0);
        mul_ex_hazard_rD2 = is_mul_instr_EX && (wR_EX == rR2_ID) && rs2_used_ID && (wR_EX != 5'b0);

        // 乘法器第一级的数据冒险
        // 流水线流程：MUL_S1 -> MUL_S2 -> MUL_S3 -> MUL_S4(结果可用)，需停顿2个周期
        mul_s1_hazard_rD1 = mul_stage1_busy && (mul_rd_s1 == rR1_ID) && rs1_used_ID &&
            (mul_rd_s1 != 5'b0);
        mul_s1_hazard_rD2 = mul_stage1_busy && (mul_rd_s1 == rR2_ID) && rs2_used_ID &&
            (mul_rd_s1 != 5'b0);

        // 乘法器第二级的数据冒险
        // 流水线流程：MUL_S2 -> MUL_S3 -> MUL_S4(结果可用)，需停顿1个周期
        mul_s2_hazard_rD1 = mul_stage2_busy && (mul_rd_s2 == rR1_ID) && rs1_used_ID &&
            (mul_rd_s2 != 5'b0);
        mul_s2_hazard_rD2 = mul_stage2_busy && (mul_rd_s2 == rR2_ID) && rs2_used_ID &&
            (mul_rd_s2 != 5'b0);

        // 乘法器第三级的数据冒险
        // 流水线流程：MUL_S3 -> MUL_S4(结果可用)，结果将在下个周期可用
        mul_s3_hazard_rD1 = mul_stage3_busy && (mul_rd_s3 == rR1_ID) && rs1_used_ID &&
            (mul_rd_s3 != 5'b0);
        mul_s3_hazard_rD2 = mul_stage3_busy && (mul_rd_s3 == rR2_ID) && rs2_used_ID &&
            (mul_rd_s3 != 5'b0);

        // 乘法器第四级的数据冒险
        // 结果在当前周期末可用，但WB尚未完成，仍需停顿等待写回
        mul_s4_hazard_rD1 = mul_stage4_busy && (mul_rd_s4 == rR1_ID) && rs1_used_ID &&
            (mul_rd_s4 != 5'b0);
        mul_s4_hazard_rD2 = mul_stage4_busy && (mul_rd_s4 == rR2_ID) && rs2_used_ID &&
            (mul_rd_s4 != 5'b0);

        mul_use_hazard = mul_ex_hazard_rD1 || mul_ex_hazard_rD2 || mul_s1_hazard_rD1 ||
            mul_s1_hazard_rD2 || mul_s2_hazard_rD1 || mul_s2_hazard_rD2 || mul_s3_hazard_rD1 ||
            mul_s3_hazard_rD2 || mul_s4_hazard_rD1 || mul_s4_hazard_rD2;
    end

    // 乘法指令结构冒险判断
    // 如果乘法器第一级正在使用，新的乘法指令需要等待
    logic mul_struct_hazard;
    assign mul_struct_hazard = is_mul_instr_ID && mul_stage1_busy;

    // WAW (Write-After-Write) 冒险判断
    // 当ID级的指令要写入的寄存器与乘法器中正在计算的目标寄存器相同时
    // 需要停顿流水线，确保乘法器先完成写回，保持程序顺序语义
    logic mul_waw_hazard;
    logic mul_waw_ex_hazard;  // EX级的MUL指令导致的WAW冒险
    logic mul_waw_s1_hazard;  // 乘法器第一级的WAW冒险
    logic mul_waw_s2_hazard;  // 乘法器第二级的WAW冒险
    logic mul_waw_s3_hazard;  // 乘法器第三级的WAW冒险
    logic mul_waw_s4_hazard;  // 乘法器第四级的WAW冒险

    always_comb begin
        // EX级的乘法指令导致的WAW冒险
        // 当ID级的指令要写入与EX级MUL相同的目标寄存器时
        mul_waw_ex_hazard = is_mul_instr_EX && rf_we_ID && (wR_EX == wR_ID) && (wR_ID != 5'b0);

        // 乘法器各级的WAW冒险
        // 当ID级的指令要写入与乘法器流水线中某级相同的目标寄存器时
        mul_waw_s1_hazard = mul_stage1_busy && rf_we_ID && (mul_rd_s1 == wR_ID) && (wR_ID != 5'b0);
        mul_waw_s2_hazard = mul_stage2_busy && rf_we_ID && (mul_rd_s2 == wR_ID) && (wR_ID != 5'b0);
        mul_waw_s3_hazard = mul_stage3_busy && rf_we_ID && (mul_rd_s3 == wR_ID) && (wR_ID != 5'b0);
        mul_waw_s4_hazard = mul_stage4_busy && rf_we_ID && (mul_rd_s4 == wR_ID) && (wR_ID != 5'b0);

        mul_waw_hazard = mul_waw_ex_hazard || mul_waw_s1_hazard || mul_waw_s2_hazard ||
            mul_waw_s3_hazard || mul_waw_s4_hazard;
    end

    // [TODO] 静态分支预测
    // [TODO] 动态分支预测
    logic branch_predicted_result;
    // 此处设置为静态不预测 因此获取EX级的跳转结果
    // assign branch_predicted_result = branch_predicted_i;
    assign branch_predicted_result = take_branch_NextPC;

    // 流水线冲刷与停顿
    logic any_hazard;
    assign any_hazard = load_use_hazard || mul_use_hazard || mul_struct_hazard || mul_waw_hazard;

    always_comb begin
        keep_pc     = any_hazard ? 1'b1 : 1'b0;
        stall_IF_ID = any_hazard ? 1'b1 : 1'b0;
        flush_IF_ID = branch_predicted_result ? 1'b1 : 1'b0;
        flush_ID_EX = (branch_predicted_result || any_hazard) ? 1'b1 : 1'b0;
    end

endmodule
