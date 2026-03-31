`include "include/defines.svh"
// 四级流水线乘法器模块
// 独立于EX级实现 支持流水线暂停和清空
// 并行变延迟操作 不阻塞主流水线

module MUL (
    input logic clk,
    input logic rst_n,

    // 来自 ID 阶段的输入
    input  logic             mul_valid_i,
    input  logic [ 1:0]      mul_op_i,
    input  logic [31:0]      mul_src1_i,
    input  logic [31:0]      mul_src2_i,
    input  logic [ 4:0]      mul_rd_i,
    // 流水线冲刷
    input  logic             flush_i,
    // WAW 冒险取消写回 高使能
    input  logic [ 4:0]      cancel_rd_i,
    // 输出到 WB 阶段
    output logic             mul_valid_o,
    output logic [31:0]      mul_result_o,
    output logic [ 4:0]      mul_rd_o,
    output logic             mul_rf_we_o,
    // 流水线状态
    output logic             mul_busy_o,        // 乘法器忙
    output logic [ 3:0]      mul_stage_busy_o,
    // 各级忙信号
    output logic [ 3:0][4:0] mul_rd_s_o         // 4 个元素，每个 5-bit
);

    // 乘法操作类型
    localparam MUL_OP_MUL    = 2'b00;  // 低32位有符号乘法
    localparam MUL_OP_MULH   = 2'b01;  // 高32位有符号乘法
    localparam MUL_OP_MULHSU = 2'b10;  // 高32位有符号-无符号乘法
    localparam MUL_OP_MULHU  = 2'b11;  // 高32位无符号乘法

    // =====================================================================
    // 使用部分积进行分布式乘法
    //
    // 对于 33 位有符号乘法 (A * B)，我们将操作数分为 17 位的高低两部分：
    //   A = A_hi * 2^16 + A_lo  (A_hi: 17 位, A_lo: 16 位)
    //   B = B_hi * 2^16 + B_lo  (B_hi: 17 位, B_lo: 16 位)
    //
    // A * B = (A_hi * B_hi) * 2^32
    //       + (A_hi * B_lo + A_lo * B_hi) * 2^16
    //       + (A_lo * B_lo)
    //
    // 阶段 1：符号扩展操作数，计算 pp_ll = A_lo * B_lo (16x16 = 32 位)
    // 阶段 2：计算 pp_lh = A_lo * B_hi 和 pp_hl = A_hi * B_lo (16x17 = 33 位)
    // 阶段 3：计算 pp_hh = A_hi * B_hi (17x17 = 34 位) 和部分和
    // 阶段 4：最终累加并选择结果
    // =====================================================================

    // 阶段 1 寄存器
    logic       s1_valid;
    logic [1:0] s1_op;
    logic [4:0] s1_rd;
    logic       s1_canceled;
    logic signed [16:0] s1_a_hi, s1_b_hi;  // 有符号高17位
    logic [15:0] s1_a_lo, s1_b_lo;  // 无符号低16位
    logic [31:0] s1_pp_ll;  // 部分积：A_lo * B_lo

    // 阶段 2 寄存器
    logic        s2_valid;
    logic [ 1:0] s2_op;
    logic [ 4:0] s2_rd;
    logic        s2_canceled;
    logic signed [16:0] s2_a_hi, s2_b_hi;
    logic        [31:0] s2_pp_ll;
    logic signed [32:0] s2_pp_lh;  // 部分积：A_lo * B_hi
    logic signed [32:0] s2_pp_hl;  // 部分积：A_hi * B_lo

    // 阶段 3 寄存器
    logic               s3_valid;
    logic        [ 1:0] s3_op;
    logic        [ 4:0] s3_rd;
    logic               s3_canceled;
    logic        [31:0] s3_pp_ll;
    logic signed [33:0] s3_pp_mid;  // 中间部分积的和
    logic signed [33:0] s3_pp_hh;  // 部分积：A_hi * B_hi

    // 阶段 4 寄存器
    logic               s4_valid;
    logic        [ 1:0] s4_op;
    logic        [ 4:0] s4_rd;
    logic               s4_canceled;
    logic        [63:0] s4_product;  // 最终 64 位结果

    // 阶段 1 的组合逻辑信号
    logic signed [32:0] src1_signed, src2_signed;
    logic [31:0] pp_ll_comb;

    // 阶段 1 逻辑：捕获输入，符号扩展，计算第一个部分积
    always_comb begin
        // 根据操作类型进行符号扩展
        case (mul_op_i)
            MUL_OP_MUL, MUL_OP_MULH: begin
                src1_signed = {mul_src1_i[31], mul_src1_i};  // 符号扩展
                src2_signed = {mul_src2_i[31], mul_src2_i};  // 符号扩展
            end
            MUL_OP_MULHSU: begin
                src1_signed = {mul_src1_i[31], mul_src1_i};  // 符号扩展
                src2_signed = {1'b0, mul_src2_i};  // 零扩展
            end
            MUL_OP_MULHU: begin
                src1_signed = {1'b0, mul_src1_i};  // 零扩展
                src2_signed = {1'b0, mul_src2_i};  // 零扩展
            end
            default: begin
                src1_signed = 33'b0;
                src2_signed = 33'b0;
            end
        endcase

        // 计算第一个部分积：A_lo * B_lo (16x16 无符号)
        pp_ll_comb = src1_signed[15:0] * src2_signed[15:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid    <= 1'b0;
            s1_op       <= 2'b0;
            s1_rd       <= 5'b0;
            s1_canceled <= 1'b0;
            s1_a_hi     <= 17'b0;
            s1_b_hi     <= 17'b0;
            s1_a_lo     <= 16'b0;
            s1_b_lo     <= 16'b0;
            s1_pp_ll    <= 32'b0;
        end else if (flush_i) begin
            s1_valid    <= 1'b0;
            s1_op       <= 2'b0;
            s1_rd       <= 5'b0;
            s1_canceled <= 1'b0;
            s1_a_hi     <= 17'b0;
            s1_b_hi     <= 17'b0;
            s1_a_lo     <= 16'b0;
            s1_b_lo     <= 16'b0;
            s1_pp_ll    <= 32'b0;
        end else begin
            s1_valid    <= mul_valid_i;
            s1_op       <= mul_op_i;
            s1_rd       <= mul_rd_i;
            // 检查此阶段是否应被取消（WAW 无 RAW）
            s1_canceled <= (cancel_rd_i != 5'b0) && (cancel_rd_i == mul_rd_i) && mul_valid_i;
            // 存储分割的操作数以供下一阶段使用
            s1_a_hi     <= src1_signed[32:16];
            s1_b_hi     <= src2_signed[32:16];
            s1_a_lo     <= src1_signed[15:0];
            s1_b_lo     <= src2_signed[15:0];
            s1_pp_ll    <= pp_ll_comb;
        end
    end

    // 阶段 2 逻辑：计算中间部分积
    logic signed [32:0] pp_lh_comb, pp_hl_comb;

    always_comb begin
        // A_lo * B_hi (16 位无符号 * 17 位有符号 = 33 位有符号)
        pp_lh_comb = $signed({1'b0, s1_a_lo}) * s1_b_hi;
        // A_hi * B_lo (17 位有符号 * 16 位无符号 = 33 位有符号)
        pp_hl_comb = s1_a_hi * $signed({1'b0, s1_b_lo});
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid    <= 1'b0;
            s2_op       <= 2'b0;
            s2_rd       <= 5'b0;
            s2_canceled <= 1'b0;
            s2_a_hi     <= 17'b0;
            s2_b_hi     <= 17'b0;
            s2_pp_ll    <= 32'b0;
            s2_pp_lh    <= 33'b0;
            s2_pp_hl    <= 33'b0;
        end else if (flush_i) begin
            s2_valid    <= 1'b0;
            s2_op       <= 2'b0;
            s2_rd       <= 5'b0;
            s2_canceled <= 1'b0;
            s2_a_hi     <= 17'b0;
            s2_b_hi     <= 17'b0;
            s2_pp_ll    <= 32'b0;
            s2_pp_lh    <= 33'b0;
            s2_pp_hl    <= 33'b0;
        end else begin
            s2_valid <= s1_valid;
            s2_op <= s1_op;
            s2_rd <= s1_rd;
            // 传播取消信号或检测此阶段的新取消信号
            s2_canceled <= s1_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s1_rd) && s1_valid);
            s2_a_hi <= s1_a_hi;
            s2_b_hi <= s1_b_hi;
            s2_pp_ll <= s1_pp_ll;
            s2_pp_lh <= pp_lh_comb;
            s2_pp_hl <= pp_hl_comb;
        end
    end

    // 阶段 3 逻辑：计算高部分积并求中间部分积的和
    logic signed [33:0] pp_hh_comb;
    logic signed [33:0] pp_mid_comb;

    always_comb begin
        // A_hi * B_hi (17 位有符号 * 17 位有符号 = 34 位有符号)
        pp_hh_comb  = s2_a_hi * s2_b_hi;
        // 中间部分积的和（带符号扩展）
        pp_mid_comb = $signed(s2_pp_lh) + $signed(s2_pp_hl);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid    <= 1'b0;
            s3_op       <= 2'b0;
            s3_rd       <= 5'b0;
            s3_canceled <= 1'b0;
            s3_pp_ll    <= 32'b0;
            s3_pp_mid   <= 34'b0;
            s3_pp_hh    <= 34'b0;
        end else if (flush_i) begin
            s3_valid    <= 1'b0;
            s3_op       <= 2'b0;
            s3_rd       <= 5'b0;
            s3_canceled <= 1'b0;
            s3_pp_ll    <= 32'b0;
            s3_pp_mid   <= 34'b0;
            s3_pp_hh    <= 34'b0;
        end else begin
            s3_valid <= s2_valid;
            s3_op <= s2_op;
            s3_rd <= s2_rd;
            // 传播取消信号或检测此阶段的新取消信号
            s3_canceled <= s2_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s2_rd) && s2_valid);
            s3_pp_ll <= s2_pp_ll;
            s3_pp_mid <= pp_mid_comb;
            s3_pp_hh <= pp_hh_comb;
        end
    end

    // 阶段 4 逻辑：最终累加
    // 结果 = pp_hh * 2^32 + pp_mid * 2^16 + pp_ll
    logic [63:0] product_comb;

    always_comb begin
        // 结合部分积并进行适当移位
        // pp_ll 贡献到 [31:0] 位
        // pp_mid 贡献到 [49:16] 位（34 位左移 16 位）
        // pp_hh 贡献到 [65:32] 位（34 位左移 32 位）
        // 注意：符号扩展确保了正确的有符号乘法语义。
        // 结果被截断为 64 位，这对于 RISC-V 的 MUL/MULH 是正确的。
        product_comb = {32'b0, s3_pp_ll} + ({{30{s3_pp_mid[33]}}, s3_pp_mid} << 16) +
            ({{30{s3_pp_hh[33]}}, s3_pp_hh} << 32);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid    <= 1'b0;
            s4_op       <= 2'b0;
            s4_rd       <= 5'b0;
            s4_canceled <= 1'b0;
            s4_product  <= 64'b0;
        end else if (flush_i) begin
            s4_valid    <= 1'b0;
            s4_op       <= 2'b0;
            s4_rd       <= 5'b0;
            s4_canceled <= 1'b0;
            s4_product  <= 64'b0;
        end else begin
            s4_valid <= s3_valid;
            s4_op <= s3_op;
            s4_rd <= s3_rd;
            // 传播取消信号或检测此阶段的新取消信号
            s4_canceled <= s3_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s3_rd) && s3_valid);
            s4_product <= product_comb;
        end
    end

    // 输出逻辑：根据操作类型选择结果
    always_comb begin
        case (s4_op)
            MUL_OP_MUL: mul_result_o = s4_product[31:0];  // 低 32 位
            MUL_OP_MULH, MUL_OP_MULHSU, MUL_OP_MULHU:
            mul_result_o = s4_product[63:32];  // 高 32 位
            default: mul_result_o = 32'b0;
        endcase
    end

    // 输出有效信号和寄存器信号
    assign mul_valid_o = s4_valid && !s4_canceled;  // 如果被取消则不输出有效信号
    assign mul_rd_o    = s4_rd;

    // 写使能：有效，未取消（无论是来自之前周期还是当前周期），且 rd != x0
    // 注意：s4_canceled 跟踪了指令在早期阶段的取消情况。
    // 我们还需要检查当前周期的取消情况，因为它尚未记录在 s4_canceled 中。
    logic s4_cancel_current_cycle;
    assign s4_cancel_current_cycle = (cancel_rd_i != 5'b0) && (cancel_rd_i == s4_rd);
    assign mul_rf_we_o = s4_valid && !s4_canceled && !s4_cancel_current_cycle && (s4_rd != 5'b0);

    // 状态信号
    always_comb begin
        mul_stage_busy_o = {s4_valid, s3_valid, s2_valid, s1_valid};
        mul_busy_o       = |mul_stage_busy_o;
    end

    assign mul_rd_s_o = {s4_rd, s3_rd, s2_rd, s1_rd};

endmodule
