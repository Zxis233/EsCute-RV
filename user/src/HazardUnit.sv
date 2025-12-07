`include "include/defines.svh"

module HazardUnit (
    input  logic        clk,
    input  logic        rst_n,
    // LOAD指令判断
    input  logic [ 1:0] wd_sel_EX,
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
    // PC保持信号
    output logic        keep_pc,
    // IF/ID停顿信号
    output logic        stall_IF_ID,
    // IF/ID冲刷信号
    output logic        flush_IF_ID,
    // ID/EX冲刷信号
    output logic        flush_ID_EX,
    // 前递使能
    output logic        fwd_rD1e_ID,
    output logic        fwd_rD2e_ID,
    // 前递数据
    output logic [31:0] fwd_rD1_ID,
    output logic [31:0] fwd_rD2_ID
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
        fwd_rD1e_ID = RAW_1_rD1 || RAW_2_rD1 || RAW_3_rD1;
        fwd_rD2e_ID = RAW_1_rD2 || RAW_2_rD2 || RAW_3_rD2;
    end

    // 前递数据选择
    // 优先级：EX > MEM > WB
    always_comb begin
        // 源操作数1前递数据选择
        if (RAW_1_rD1)      fwd_rD1_ID = rf_wd_EX;  // 来自EX级
        else if (RAW_2_rD1) fwd_rD1_ID = rf_wd_MEM; // 来自MEM级
        else if (RAW_3_rD1) fwd_rD1_ID = rf_wd_WB;  // 来自WB级
        else                fwd_rD1_ID = 32'b0;

        // 源操作数2前递数据选择
        if (RAW_1_rD2)      fwd_rD2_ID = rf_wd_EX;  // 来自EX级
        else if (RAW_2_rD2) fwd_rD2_ID = rf_wd_MEM; // 来自MEM级
        else if (RAW_3_rD2) fwd_rD2_ID = rf_wd_WB;  // 来自WB级
        else                fwd_rD2_ID = 32'b0;
    end
    // verilog_format: on

    // Load_use 冒险判断
    logic load_use_hazard;
    assign load_use_hazard = (wd_sel_EX == `WD_SEL_FROM_DRAM) && (RAW_1_rD1 || RAW_1_rD2);

    // [TODO] 静态分支预测
    // [TODO] 动态分支预测
    logic branch_predicted_result;
    // 此处设置为静态不预测 因此获取EX级的跳转结果
    // assign branch_predicted_result = branch_predicted_i;
    assign branch_predicted_result = take_branch_NextPC;

    // // 控制冒险时将IF/ID寄存器打一拍
    // logic control_hazard_stall;
    // always_ff @(posedge clk or negedge rst_n) begin
    //     if (!rst_n) control_hazard_stall <= 1'b0;
    //     else control_hazard_stall <= branch_predicted_result;
    // end

    // 流水线冲刷与停顿
    always_comb begin
        keep_pc     = load_use_hazard ? 1'b1 : 1'b0;
        stall_IF_ID = load_use_hazard ? 1'b1 : 1'b0;
        flush_IF_ID = branch_predicted_result ? 1'b1 : 1'b0;
        flush_ID_EX = (branch_predicted_result || load_use_hazard) ? 1'b1 : 1'b0;
    end

endmodule
