`include "include/defines.svh"
// 六级流水线乘法器 - Radix-4 Booth编码 + Wallace Tree
// 使用Booth编码减少部分积数量，Wallace Tree并行归约
// 显著降低关键路径延时

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
    // WAW 冒险取消写回
    input  logic [ 4:0]      cancel_rd_i,
    // 输出到 WB 阶段
    output logic             mul_valid_o,
    output logic [31:0]      mul_result_o,
    output logic [ 4:0]      mul_rd_o,
    output logic             mul_rf_we_o,
    // 流水线状态
    output logic             mul_busy_o,
    output logic [ 5:0]      mul_stage_busy_o,
    output logic [ 5:0][4:0] mul_rd_s_o
);

    // 乘法操作类型
    localparam MUL_OP_MUL    = 2'b00;
    localparam MUL_OP_MULH   = 2'b01;
    localparam MUL_OP_MULHSU = 2'b10;
    localparam MUL_OP_MULHU  = 2'b11;

    // Booth编码常量 (使用 localparam 代替 enum)
    localparam [2:0]  BOOTH_0 = 3'b000;  // 0
    localparam [2:0] BOOTH_P1 = 3'b001;  // +1
    localparam [2:0] BOOTH_P2 = 3'b010;  // +2
    localparam [2:0] BOOTH_N2 = 3'b011;  // -2
    localparam [2:0] BOOTH_N1 = 3'b100;  // -1

    // =====================================================================
    // 3: 2 CSA 压缩器宏定义
    // =====================================================================
    `define CSA_3_2(a, b, c, sum, carry) \
        assign sum   = (a) ^ (b) ^ (c); \
        assign carry = (((a) & (b)) | ((b) & (c)) | ((a) & (c))) << 1;

    // ======================== Stage 1: Booth编码 ========================
    logic               s1_valid;
    logic        [ 1:0] s1_op;
    logic        [ 4:0] s1_rd;
    logic               s1_canceled;
    logic signed [33:0] s1_multiplicand;
    logic        [ 2:0] s1_booth_enc     [16:0];  // 使用 logic [2:0] 代替 enum

    // 符号扩展逻辑
    logic signed [33:0] multiplicand_ext;
    logic signed [34:0] multiplier_ext;

    // Booth编码组合逻辑
    logic        [ 2:0] booth_enc_comb   [16:0];

    // Booth编码函数
    function automatic logic [2:0] booth_encode(input logic [2:0] bits);
        case (bits)
            3'b000:  return BOOTH_0;
            3'b001:  return BOOTH_P1;
            3'b010:  return BOOTH_P1;
            3'b011:  return BOOTH_P2;
            3'b100:  return BOOTH_N2;
            3'b101:  return BOOTH_N1;
            3'b110:  return BOOTH_N1;
            3'b111:  return BOOTH_0;
            default: return BOOTH_0;
        endcase
    endfunction

    always_comb begin
        case (mul_op_i)
            MUL_OP_MUL, MUL_OP_MULH: begin
                multiplicand_ext = {{2{mul_src1_i[31]}}, mul_src1_i};
                multiplier_ext   = {{3{mul_src2_i[31]}}, mul_src2_i};
            end
            MUL_OP_MULHSU: begin
                multiplicand_ext = {{2{mul_src1_i[31]}}, mul_src1_i};
                multiplier_ext   = {3'b0, mul_src2_i};
            end
            MUL_OP_MULHU: begin
                multiplicand_ext = {2'b0, mul_src1_i};
                multiplier_ext   = {3'b0, mul_src2_i};
            end
            default: begin
                multiplicand_ext = 34'b0;
                multiplier_ext   = 35'b0;
            end
        endcase

        // 生成17个Booth编码
        booth_enc_comb[0]  = booth_encode({multiplier_ext[1:0], 1'b0});
        booth_enc_comb[1]  = booth_encode(multiplier_ext[3:1]);
        booth_enc_comb[2]  = booth_encode(multiplier_ext[5:3]);
        booth_enc_comb[3]  = booth_encode(multiplier_ext[7:5]);
        booth_enc_comb[4]  = booth_encode(multiplier_ext[9:7]);
        booth_enc_comb[5]  = booth_encode(multiplier_ext[11:9]);
        booth_enc_comb[6]  = booth_encode(multiplier_ext[13:11]);
        booth_enc_comb[7]  = booth_encode(multiplier_ext[15:13]);
        booth_enc_comb[8]  = booth_encode(multiplier_ext[17:15]);
        booth_enc_comb[9]  = booth_encode(multiplier_ext[19:17]);
        booth_enc_comb[10] = booth_encode(multiplier_ext[21:19]);
        booth_enc_comb[11] = booth_encode(multiplier_ext[23:21]);
        booth_enc_comb[12] = booth_encode(multiplier_ext[25:23]);
        booth_enc_comb[13] = booth_encode(multiplier_ext[27:25]);
        booth_enc_comb[14] = booth_encode(multiplier_ext[29:27]);
        booth_enc_comb[15] = booth_encode(multiplier_ext[31:29]);
        booth_enc_comb[16] = booth_encode(multiplier_ext[33:31]);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_i) begin
            s1_valid         <= 1'b0;
            s1_op            <= 2'b0;
            s1_rd            <= 5'b0;
            s1_canceled      <= 1'b0;
            s1_multiplicand  <= 34'b0;
            s1_booth_enc[0]  <= BOOTH_0;
            s1_booth_enc[1]  <= BOOTH_0;
            s1_booth_enc[2]  <= BOOTH_0;
            s1_booth_enc[3]  <= BOOTH_0;
            s1_booth_enc[4]  <= BOOTH_0;
            s1_booth_enc[5]  <= BOOTH_0;
            s1_booth_enc[6]  <= BOOTH_0;
            s1_booth_enc[7]  <= BOOTH_0;
            s1_booth_enc[8]  <= BOOTH_0;
            s1_booth_enc[9]  <= BOOTH_0;
            s1_booth_enc[10] <= BOOTH_0;
            s1_booth_enc[11] <= BOOTH_0;
            s1_booth_enc[12] <= BOOTH_0;
            s1_booth_enc[13] <= BOOTH_0;
            s1_booth_enc[14] <= BOOTH_0;
            s1_booth_enc[15] <= BOOTH_0;
            s1_booth_enc[16] <= BOOTH_0;
        end else begin
            s1_valid         <= mul_valid_i;
            s1_op            <= mul_op_i;
            s1_rd            <= mul_rd_i;
            s1_canceled      <= (cancel_rd_i != 5'b0) && (cancel_rd_i == mul_rd_i) && mul_valid_i;
            s1_multiplicand  <= multiplicand_ext;
            s1_booth_enc[0]  <= booth_enc_comb[0];
            s1_booth_enc[1]  <= booth_enc_comb[1];
            s1_booth_enc[2]  <= booth_enc_comb[2];
            s1_booth_enc[3]  <= booth_enc_comb[3];
            s1_booth_enc[4]  <= booth_enc_comb[4];
            s1_booth_enc[5]  <= booth_enc_comb[5];
            s1_booth_enc[6]  <= booth_enc_comb[6];
            s1_booth_enc[7]  <= booth_enc_comb[7];
            s1_booth_enc[8]  <= booth_enc_comb[8];
            s1_booth_enc[9]  <= booth_enc_comb[9];
            s1_booth_enc[10] <= booth_enc_comb[10];
            s1_booth_enc[11] <= booth_enc_comb[11];
            s1_booth_enc[12] <= booth_enc_comb[12];
            s1_booth_enc[13] <= booth_enc_comb[13];
            s1_booth_enc[14] <= booth_enc_comb[14];
            s1_booth_enc[15] <= booth_enc_comb[15];
            s1_booth_enc[16] <= booth_enc_comb[16];
        end
    end

    // ======================== Stage 2: 部分积生成 ========================
    logic               s2_valid;
    logic        [ 1:0] s2_op;
    logic        [ 4:0] s2_rd;
    logic               s2_canceled;
    logic signed [67:0] s2_pp       [16:0];

    // 部分积生成函数
    function automatic logic signed [67:0] gen_partial_product(
        input logic [2:0] enc, input logic signed [33:0] multiplicand, input int shift);
        logic signed [67:0] result;
        case (enc)
            BOOTH_0:  result = 68'sb0;
            BOOTH_P1: result = {{34{multiplicand[33]}}, multiplicand} << shift;
            BOOTH_P2: result = {{33{multiplicand[33]}}, multiplicand, 1'b0} << shift;
            BOOTH_N1: result = (-{{34{multiplicand[33]}}, multiplicand}) << shift;
            BOOTH_N2: result = (-{{33{multiplicand[33]}}, multiplicand, 1'b0}) << shift;
            default:  result = 68'sb0;
        endcase
        return result;
    endfunction

    // 部分积组合逻辑
    logic signed [67:0] pp_comb[16:0];

    always_comb begin
        pp_comb[0]  = gen_partial_product(s1_booth_enc[0], s1_multiplicand, 0);
        pp_comb[1]  = gen_partial_product(s1_booth_enc[1], s1_multiplicand, 2);
        pp_comb[2]  = gen_partial_product(s1_booth_enc[2], s1_multiplicand, 4);
        pp_comb[3]  = gen_partial_product(s1_booth_enc[3], s1_multiplicand, 6);
        pp_comb[4]  = gen_partial_product(s1_booth_enc[4], s1_multiplicand, 8);
        pp_comb[5]  = gen_partial_product(s1_booth_enc[5], s1_multiplicand, 10);
        pp_comb[6]  = gen_partial_product(s1_booth_enc[6], s1_multiplicand, 12);
        pp_comb[7]  = gen_partial_product(s1_booth_enc[7], s1_multiplicand, 14);
        pp_comb[8]  = gen_partial_product(s1_booth_enc[8], s1_multiplicand, 16);
        pp_comb[9]  = gen_partial_product(s1_booth_enc[9], s1_multiplicand, 18);
        pp_comb[10] = gen_partial_product(s1_booth_enc[10], s1_multiplicand, 20);
        pp_comb[11] = gen_partial_product(s1_booth_enc[11], s1_multiplicand, 22);
        pp_comb[12] = gen_partial_product(s1_booth_enc[12], s1_multiplicand, 24);
        pp_comb[13] = gen_partial_product(s1_booth_enc[13], s1_multiplicand, 26);
        pp_comb[14] = gen_partial_product(s1_booth_enc[14], s1_multiplicand, 28);
        pp_comb[15] = gen_partial_product(s1_booth_enc[15], s1_multiplicand, 30);
        pp_comb[16] = gen_partial_product(s1_booth_enc[16], s1_multiplicand, 32);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_i) begin
            s2_valid    <= 1'b0;
            s2_op       <= 2'b0;
            s2_rd       <= 5'b0;
            s2_canceled <= 1'b0;
            s2_pp[0]    <= 68'b0;
            s2_pp[1]    <= 68'b0;
            s2_pp[2]    <= 68'b0;
            s2_pp[3]    <= 68'b0;
            s2_pp[4]    <= 68'b0;
            s2_pp[5]    <= 68'b0;
            s2_pp[6]    <= 68'b0;
            s2_pp[7]    <= 68'b0;
            s2_pp[8]    <= 68'b0;
            s2_pp[9]    <= 68'b0;
            s2_pp[10]   <= 68'b0;
            s2_pp[11]   <= 68'b0;
            s2_pp[12]   <= 68'b0;
            s2_pp[13]   <= 68'b0;
            s2_pp[14]   <= 68'b0;
            s2_pp[15]   <= 68'b0;
            s2_pp[16]   <= 68'b0;
        end else begin
            s2_valid <= s1_valid;
            s2_op <= s1_op;
            s2_rd <= s1_rd;
            s2_canceled <= s1_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s1_rd) && s1_valid);
            s2_pp[0] <= pp_comb[0];
            s2_pp[1] <= pp_comb[1];
            s2_pp[2] <= pp_comb[2];
            s2_pp[3] <= pp_comb[3];
            s2_pp[4] <= pp_comb[4];
            s2_pp[5] <= pp_comb[5];
            s2_pp[6] <= pp_comb[6];
            s2_pp[7] <= pp_comb[7];
            s2_pp[8] <= pp_comb[8];
            s2_pp[9] <= pp_comb[9];
            s2_pp[10] <= pp_comb[10];
            s2_pp[11] <= pp_comb[11];
            s2_pp[12] <= pp_comb[12];
            s2_pp[13] <= pp_comb[13];
            s2_pp[14] <= pp_comb[14];
            s2_pp[15] <= pp_comb[15];
            s2_pp[16] <= pp_comb[16];
        end
    end

    // ======================== Stage 3: Wallace Tree 第一层 ========================
    // 17个部分积 → 12个 (使用5个CSA)
    logic        s3_valid;
    logic [ 1:0] s3_op;
    logic [ 4:0] s3_rd;
    logic        s3_canceled;
    logic [67:0] s3_pp       [11:0];

    // CSA 第一层输出信号
    logic [67:0] w3_sum      [ 4:0];
    logic [67:0] w3_carry    [ 4:0];

    `CSA_3_2(s2_pp[0], s2_pp[1], s2_pp[2], w3_sum[0], w3_carry[0])
    `CSA_3_2(s2_pp[3], s2_pp[4], s2_pp[5], w3_sum[1], w3_carry[1])
    `CSA_3_2(s2_pp[6], s2_pp[7], s2_pp[8], w3_sum[2], w3_carry[2])
    `CSA_3_2(s2_pp[9], s2_pp[10], s2_pp[11], w3_sum[3], w3_carry[3])
    `CSA_3_2(s2_pp[12], s2_pp[13], s2_pp[14], w3_sum[4], w3_carry[4])

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_i) begin
            s3_valid    <= 1'b0;
            s3_op       <= 2'b0;
            s3_rd       <= 5'b0;
            s3_canceled <= 1'b0;
            s3_pp[0]    <= 68'b0;
            s3_pp[1]    <= 68'b0;
            s3_pp[2]    <= 68'b0;
            s3_pp[3]    <= 68'b0;
            s3_pp[4]    <= 68'b0;
            s3_pp[5]    <= 68'b0;
            s3_pp[6]    <= 68'b0;
            s3_pp[7]    <= 68'b0;
            s3_pp[8]    <= 68'b0;
            s3_pp[9]    <= 68'b0;
            s3_pp[10]   <= 68'b0;
            s3_pp[11]   <= 68'b0;
        end else begin
            s3_valid <= s2_valid;
            s3_op <= s2_op;
            s3_rd <= s2_rd;
            s3_canceled <= s2_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s2_rd) && s2_valid);
            s3_pp[0] <= w3_sum[0];
            s3_pp[1] <= w3_carry[0];
            s3_pp[2] <= w3_sum[1];
            s3_pp[3] <= w3_carry[1];
            s3_pp[4] <= w3_sum[2];
            s3_pp[5] <= w3_carry[2];
            s3_pp[6] <= w3_sum[3];
            s3_pp[7] <= w3_carry[3];
            s3_pp[8] <= w3_sum[4];
            s3_pp[9] <= w3_carry[4];
            s3_pp[10] <= s2_pp[15];
            s3_pp[11] <= s2_pp[16];
        end
    end

    // ======================== Stage 4: Wallace Tree 第二层 ========================
    // 12 → 8 → 6
    logic        s4_valid;
    logic [ 1:0] s4_op;
    logic [ 4:0] s4_rd;
    logic        s4_canceled;
    logic [67:0] s4_pp       [5:0];

    // 第一轮:  12 → 8
    logic [67:0] w4a_sum     [3:0];
    logic [67:0] w4a_carry   [3:0];

    `CSA_3_2(s3_pp[0], s3_pp[1], s3_pp[2], w4a_sum[0], w4a_carry[0])
    `CSA_3_2(s3_pp[3], s3_pp[4], s3_pp[5], w4a_sum[1], w4a_carry[1])
    `CSA_3_2(s3_pp[6], s3_pp[7], s3_pp[8], w4a_sum[2], w4a_carry[2])
    `CSA_3_2(s3_pp[9], s3_pp[10], s3_pp[11], w4a_sum[3], w4a_carry[3])

    // 第二轮: 8 → 6
    logic [67:0] w4b_sum  [1:0];
    logic [67:0] w4b_carry[1:0];

    `CSA_3_2(w4a_sum[0], w4a_carry[0], w4a_sum[1], w4b_sum[0], w4b_carry[0])
    `CSA_3_2(w4a_carry[1], w4a_sum[2], w4a_carry[2], w4b_sum[1], w4b_carry[1])

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_i) begin
            s4_valid    <= 1'b0;
            s4_op       <= 2'b0;
            s4_rd       <= 5'b0;
            s4_canceled <= 1'b0;
            s4_pp[0]    <= 68'b0;
            s4_pp[1]    <= 68'b0;
            s4_pp[2]    <= 68'b0;
            s4_pp[3]    <= 68'b0;
            s4_pp[4]    <= 68'b0;
            s4_pp[5]    <= 68'b0;
        end else begin
            s4_valid <= s3_valid;
            s4_op <= s3_op;
            s4_rd <= s3_rd;
            s4_canceled <= s3_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s3_rd) && s3_valid);
            s4_pp[0] <= w4b_sum[0];
            s4_pp[1] <= w4b_carry[0];
            s4_pp[2] <= w4b_sum[1];
            s4_pp[3] <= w4b_carry[1];
            s4_pp[4] <= w4a_sum[3];
            s4_pp[5] <= w4a_carry[3];
        end
    end

    // ======================== Stage 5: Wallace Tree 第三层 ========================
    // 6 → 4 → 3 → 2
    logic        s5_valid;
    logic [ 1:0] s5_op;
    logic [ 4:0] s5_rd;
    logic        s5_canceled;
    logic [67:0] s5_sum;
    logic [67:0] s5_carry;

    // 6 → 4
    logic [67:0] w5a_sum     [1:0];
    logic [67:0] w5a_carry   [1:0];

    `CSA_3_2(s4_pp[0], s4_pp[1], s4_pp[2], w5a_sum[0], w5a_carry[0])
    `CSA_3_2(s4_pp[3], s4_pp[4], s4_pp[5], w5a_sum[1], w5a_carry[1])

    // 4 → 3
    logic [67:0] w5b_sum;
    logic [67:0] w5b_carry;

    `CSA_3_2(w5a_sum[0], w5a_carry[0], w5a_sum[1], w5b_sum, w5b_carry)

    // 3 → 2
    logic [67:0] w5c_sum;
    logic [67:0] w5c_carry;

    `CSA_3_2(w5b_sum, w5b_carry, w5a_carry[1], w5c_sum, w5c_carry)

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_i) begin
            s5_valid    <= 1'b0;
            s5_op       <= 2'b0;
            s5_rd       <= 5'b0;
            s5_canceled <= 1'b0;
            s5_sum      <= 68'b0;
            s5_carry    <= 68'b0;
        end else begin
            s5_valid <= s4_valid;
            s5_op <= s4_op;
            s5_rd <= s4_rd;
            s5_canceled <= s4_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s4_rd) && s4_valid);
            s5_sum <= w5c_sum;
            s5_carry <= w5c_carry;
        end
    end

    // ======================== Stage 6: 最终CPA加法 ========================
    logic        s6_valid;
    logic [ 1:0] s6_op;
    logic [ 4:0] s6_rd;
    logic        s6_canceled;
    logic [63:0] s6_product;

    // 最终64位加法
    logic [63:0] final_product;
    assign final_product = s5_sum[63:0] + s5_carry[63:0];

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n || flush_i) begin
            s6_valid    <= 1'b0;
            s6_op       <= 2'b0;
            s6_rd       <= 5'b0;
            s6_canceled <= 1'b0;
            s6_product  <= 64'b0;
        end else begin
            s6_valid <= s5_valid;
            s6_op <= s5_op;
            s6_rd <= s5_rd;
            s6_canceled <= s5_canceled ||
                ((cancel_rd_i != 5'b0) && (cancel_rd_i == s5_rd) && s5_valid);
            s6_product <= final_product;
        end
    end

    // ======================== 输出逻辑 ========================
    always_comb begin
        case (s6_op)
            MUL_OP_MUL:                               mul_result_o = s6_product[31:0];
            MUL_OP_MULH, MUL_OP_MULHSU, MUL_OP_MULHU: mul_result_o = s6_product[63:32];
            default:                                  mul_result_o = 32'b0;
        endcase
    end

    assign mul_valid_o = s6_valid && !s6_canceled;
    assign mul_rd_o    = s6_rd;

    logic s6_cancel_current_cycle;
    assign s6_cancel_current_cycle = (cancel_rd_i != 5'b0) && (cancel_rd_i == s6_rd);
    assign mul_rf_we_o = s6_valid && !s6_canceled && !s6_cancel_current_cycle && (s6_rd != 5'b0);

    // 状态信号
    always_comb begin
        mul_stage_busy_o = {s6_valid, s5_valid, s4_valid, s3_valid, s2_valid, s1_valid};
        mul_busy_o       = |mul_stage_busy_o;
    end

    assign mul_rd_s_o = {s6_rd, s5_rd, s4_rd, s3_rd, s2_rd, s1_rd};

    // 取消宏定义
    `undef CSA_3_2

endmodule
