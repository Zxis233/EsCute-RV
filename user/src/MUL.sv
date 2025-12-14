`include "include/defines.svh"
// 4-stage pipelined multiplier module with distributed computation
// Uses partial product method to split multiplication across 4 cycles
// This reduces critical path compared to single-cycle multiplication
// Parallel with EX stage - does not block non-dependent instructions

module MUL (
    input logic clk,
    input logic rst_n,

    // Input from ID stage
    input logic        mul_valid_i,  // Multiplication operation valid
    input logic [ 1:0] mul_op_i,     // Multiplication operation type
    input logic [31:0] mul_src1_i,   // Source operand 1
    input logic [31:0] mul_src2_i,   // Source operand 2
    input logic [ 4:0] mul_rd_i,     // Destination register
    input logic        flush_i,      // Pipeline flush

    // Output to WB stage
    output logic        mul_valid_o,   // Result valid
    output logic [31:0] mul_result_o,  // Multiplication result
    output logic [ 4:0] mul_rd_o,      // Destination register
    output logic        mul_rf_we_o,   // Register file write enable

    // Pipeline status
    output logic mul_busy_o,         // Multiplier is busy (any stage occupied)
    output logic mul_stage1_busy_o,  // Stage 1 is occupied
    output logic mul_stage2_busy_o,  // Stage 2 is occupied
    output logic mul_stage3_busy_o,  // Stage 3 is occupied
    output logic mul_stage4_busy_o,  // Stage 4 is occupied

    // Hazard detection outputs - destination registers in each stage
    output logic [4:0] mul_rd_s1_o,  // Stage 1 destination register
    output logic [4:0] mul_rd_s2_o,  // Stage 2 destination register
    output logic [4:0] mul_rd_s3_o,  // Stage 3 destination register
    output logic [4:0] mul_rd_s4_o   // Stage 4 destination register
);

    // Multiplication operation types
    localparam MUL_OP_MUL = 2'b00;  // Lower 32 bits of signed * signed
    localparam MUL_OP_MULH = 2'b01;  // Upper 32 bits of signed * signed
    localparam MUL_OP_MULHSU = 2'b10;  // Upper 32 bits of signed * unsigned
    localparam MUL_OP_MULHU = 2'b11;  // Upper 32 bits of unsigned * unsigned

    // =========================================================================
    // Distributed Multiplication using Partial Products
    // 
    // For 33-bit signed multiplication (A * B), we split into 17-bit halves:
    //   A = A_hi * 2^16 + A_lo  (A_hi: 17 bits, A_lo: 16 bits)
    //   B = B_hi * 2^16 + B_lo  (B_hi: 17 bits, B_lo: 16 bits)
    //
    // A * B = (A_hi * B_hi) * 2^32 + (A_hi * B_lo + A_lo * B_hi) * 2^16 + (A_lo * B_lo)
    //
    // Stage 1: Sign extend operands, compute pp_ll = A_lo * B_lo (16x16 = 32 bits)
    // Stage 2: Compute pp_lh = A_lo * B_hi and pp_hl = A_hi * B_lo (16x17 = 33 bits each)
    // Stage 3: Compute pp_hh = A_hi * B_hi (17x17 = 34 bits) and partial sum
    // Stage 4: Final accumulation and result selection
    // =========================================================================

    // Stage 1 registers
    logic       s1_valid;
    logic [1:0] s1_op;
    logic [4:0] s1_rd;
    logic signed [16:0] s1_a_hi, s1_b_hi;  // Upper 17 bits (with sign)
    logic [15:0] s1_a_lo, s1_b_lo;  // Lower 16 bits (unsigned)
    logic [31:0] s1_pp_ll;  // Partial product: A_lo * B_lo

    // Stage 2 registers
    logic        s2_valid;
    logic [ 1:0] s2_op;
    logic [ 4:0] s2_rd;
    logic signed [16:0] s2_a_hi, s2_b_hi;
    logic        [31:0] s2_pp_ll;
    logic signed [32:0] s2_pp_lh;  // Partial product: A_lo * B_hi
    logic signed [32:0] s2_pp_hl;  // Partial product: A_hi * B_lo

    // Stage 3 registers
    logic               s3_valid;
    logic        [ 1:0] s3_op;
    logic        [ 4:0] s3_rd;
    logic        [31:0] s3_pp_ll;
    logic signed [33:0] s3_pp_mid;  // Sum of middle partial products
    logic signed [33:0] s3_pp_hh;  // Partial product: A_hi * B_hi

    // Stage 4 registers
    logic               s4_valid;
    logic        [ 1:0] s4_op;
    logic        [ 4:0] s4_rd;
    logic        [63:0] s4_product;  // Final 64-bit product

    // Combinational signals for stage 1
    logic signed [32:0] src1_signed, src2_signed;
    logic [31:0] pp_ll_comb;

    // Stage 1 logic: Capture inputs, sign extend, compute first partial product
    always_comb begin
        // Sign extension based on operation type
        case (mul_op_i)
            MUL_OP_MUL, MUL_OP_MULH: begin
                src1_signed = {mul_src1_i[31], mul_src1_i};  // Sign extend
                src2_signed = {mul_src2_i[31], mul_src2_i};  // Sign extend
            end
            MUL_OP_MULHSU: begin
                src1_signed = {mul_src1_i[31], mul_src1_i};  // Sign extend
                src2_signed = {1'b0, mul_src2_i};  // Zero extend
            end
            MUL_OP_MULHU: begin
                src1_signed = {1'b0, mul_src1_i};  // Zero extend
                src2_signed = {1'b0, mul_src2_i};  // Zero extend
            end
            default: begin
                src1_signed = 33'b0;
                src2_signed = 33'b0;
            end
        endcase

        // Compute first partial product: A_lo * B_lo (16x16 unsigned)
        pp_ll_comb = src1_signed[15:0] * src2_signed[15:0];
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
            s1_op    <= 2'b0;
            s1_rd    <= 5'b0;
            s1_a_hi  <= 17'b0;
            s1_b_hi  <= 17'b0;
            s1_a_lo  <= 16'b0;
            s1_b_lo  <= 16'b0;
            s1_pp_ll <= 32'b0;
        end else if (flush_i) begin
            s1_valid <= 1'b0;
            s1_op    <= 2'b0;
            s1_rd    <= 5'b0;
            s1_a_hi  <= 17'b0;
            s1_b_hi  <= 17'b0;
            s1_a_lo  <= 16'b0;
            s1_b_lo  <= 16'b0;
            s1_pp_ll <= 32'b0;
        end else begin
            s1_valid <= mul_valid_i;
            s1_op    <= mul_op_i;
            s1_rd    <= mul_rd_i;
            // Store split operands for next stage
            s1_a_hi  <= src1_signed[32:16];
            s1_b_hi  <= src2_signed[32:16];
            s1_a_lo  <= src1_signed[15:0];
            s1_b_lo  <= src2_signed[15:0];
            s1_pp_ll <= pp_ll_comb;
        end
    end

    // Stage 2 logic: Compute middle partial products
    logic signed [32:0] pp_lh_comb, pp_hl_comb;

    always_comb begin
        // A_lo * B_hi (16-bit unsigned * 17-bit signed = 33-bit signed)
        pp_lh_comb = $signed({1'b0, s1_a_lo}) * s1_b_hi;
        // A_hi * B_lo (17-bit signed * 16-bit unsigned = 33-bit signed)
        pp_hl_comb = s1_a_hi * $signed({1'b0, s1_b_lo});
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid <= 1'b0;
            s2_op    <= 2'b0;
            s2_rd    <= 5'b0;
            s2_a_hi  <= 17'b0;
            s2_b_hi  <= 17'b0;
            s2_pp_ll <= 32'b0;
            s2_pp_lh <= 33'b0;
            s2_pp_hl <= 33'b0;
        end else if (flush_i) begin
            s2_valid <= 1'b0;
            s2_op    <= 2'b0;
            s2_rd    <= 5'b0;
            s2_a_hi  <= 17'b0;
            s2_b_hi  <= 17'b0;
            s2_pp_ll <= 32'b0;
            s2_pp_lh <= 33'b0;
            s2_pp_hl <= 33'b0;
        end else begin
            s2_valid <= s1_valid;
            s2_op    <= s1_op;
            s2_rd    <= s1_rd;
            s2_a_hi  <= s1_a_hi;
            s2_b_hi  <= s1_b_hi;
            s2_pp_ll <= s1_pp_ll;
            s2_pp_lh <= pp_lh_comb;
            s2_pp_hl <= pp_hl_comb;
        end
    end

    // Stage 3 logic: Compute high partial product and sum middle products
    logic signed [33:0] pp_hh_comb;
    logic signed [33:0] pp_mid_comb;

    always_comb begin
        // A_hi * B_hi (17-bit signed * 17-bit signed = 34-bit signed)
        pp_hh_comb  = s2_a_hi * s2_b_hi;
        // Sum of middle partial products (with sign extension)
        pp_mid_comb = $signed(s2_pp_lh) + $signed(s2_pp_hl);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s3_valid  <= 1'b0;
            s3_op     <= 2'b0;
            s3_rd     <= 5'b0;
            s3_pp_ll  <= 32'b0;
            s3_pp_mid <= 34'b0;
            s3_pp_hh  <= 34'b0;
        end else if (flush_i) begin
            s3_valid  <= 1'b0;
            s3_op     <= 2'b0;
            s3_rd     <= 5'b0;
            s3_pp_ll  <= 32'b0;
            s3_pp_mid <= 34'b0;
            s3_pp_hh  <= 34'b0;
        end else begin
            s3_valid  <= s2_valid;
            s3_op     <= s2_op;
            s3_rd     <= s2_rd;
            s3_pp_ll  <= s2_pp_ll;
            s3_pp_mid <= pp_mid_comb;
            s3_pp_hh  <= pp_hh_comb;
        end
    end

    // Stage 4 logic: Final accumulation
    // Product = pp_hh * 2^32 + pp_mid * 2^16 + pp_ll
    logic [63:0] product_comb;

    always_comb begin
        // Combine partial products with proper shifts
        // pp_ll contributes to bits [31:0]
        // pp_mid contributes to bits [49:16] (34 bits shifted left by 16)
        // pp_hh contributes to bits [65:32] (34 bits shifted left by 32)
        // Note: Sign extension ensures correct signed multiplication semantics.
        // The result is truncated to 64 bits, which is correct for RISC-V MUL/MULH.
        product_comb = {32'b0, s3_pp_ll} + ({{30{s3_pp_mid[33]}}, s3_pp_mid} << 16) +
            ({{30{s3_pp_hh[33]}}, s3_pp_hh} << 32);
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_valid   <= 1'b0;
            s4_op      <= 2'b0;
            s4_rd      <= 5'b0;
            s4_product <= 64'b0;
        end else if (flush_i) begin
            s4_valid   <= 1'b0;
            s4_op      <= 2'b0;
            s4_rd      <= 5'b0;
            s4_product <= 64'b0;
        end else begin
            s4_valid   <= s3_valid;
            s4_op      <= s3_op;
            s4_rd      <= s3_rd;
            s4_product <= product_comb;
        end
    end

    // Output logic: Select result based on operation type
    always_comb begin
        case (s4_op)
            MUL_OP_MUL: mul_result_o = s4_product[31:0];  // Lower 32 bits
            MUL_OP_MULH, MUL_OP_MULHSU, MUL_OP_MULHU:
            mul_result_o = s4_product[63:32];  // Upper 32 bits
            default: mul_result_o = 32'b0;
        endcase
    end

    // Output valid and register signals
    assign mul_valid_o       = s4_valid;
    assign mul_rd_o          = s4_rd;
    assign mul_rf_we_o       = s4_valid && (s4_rd != 5'b0);  // Write enable if valid and rd != x0

    // Status signals
    assign mul_busy_o        = s1_valid || s2_valid || s3_valid || s4_valid;
    assign mul_stage1_busy_o = s1_valid;
    assign mul_stage2_busy_o = s2_valid;
    assign mul_stage3_busy_o = s3_valid;
    assign mul_stage4_busy_o = s4_valid;

    // Hazard detection outputs
    assign mul_rd_s1_o       = s1_rd;
    assign mul_rd_s2_o       = s2_rd;
    assign mul_rd_s3_o       = s3_rd;
    assign mul_rd_s4_o       = s4_rd;

endmodule
