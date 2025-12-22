`include "include/defines.svh"
// 2-stage pipelined multiplier module
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
    output logic mul_busy_o,         // Multiplier is busy (stage 1 occupied)
    output logic mul_stage1_busy_o,  // Stage 1 is occupied
    output logic mul_stage2_busy_o,  // Stage 2 is occupied

    // Hazard detection outputs - destination registers in each stage
    output logic [4:0] mul_rd_s1_o,  // Stage 1 destination register
    output logic [4:0] mul_rd_s2_o   // Stage 2 destination register
);

    // Multiplication operation types
    localparam MUL_OP_MUL = 2'b00;  // Lower 32 bits of signed * signed
    localparam MUL_OP_MULH = 2'b01;  // Upper 32 bits of signed * signed
    localparam MUL_OP_MULHSU = 2'b10;  // Upper 32 bits of signed * unsigned
    localparam MUL_OP_MULHU = 2'b11;  // Upper 32 bits of unsigned * unsigned

    // Stage 1 registers (ID -> MUL_S1)
    logic               s1_valid;
    logic        [ 1:0] s1_op;
    logic        [31:0] s1_src1;
    logic        [31:0] s1_src2;
    logic        [ 4:0] s1_rd;

    // Stage 2 registers (MUL_S1 -> MUL_S2)
    logic               s2_valid;
    logic        [ 1:0] s2_op;
    logic        [63:0] s2_product;
    logic        [ 4:0] s2_rd;

    // Sign extension for operands
    logic signed [32:0] src1_signed_s1;
    logic signed [32:0] src2_signed_s1;
    logic signed [65:0] product_full_s1;

    // Stage 1 logic: Capture inputs and start multiplication
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s1_valid <= 1'b0;
            s1_op    <= 2'b0;
            s1_src1  <= 32'b0;
            s1_src2  <= 32'b0;
            s1_rd    <= 5'b0;
        end else if (flush_i) begin
            s1_valid <= 1'b0;
            s1_op    <= 2'b0;
            s1_src1  <= 32'b0;
            s1_src2  <= 32'b0;
            s1_rd    <= 5'b0;
        end else begin
            s1_valid <= mul_valid_i;
            s1_op    <= mul_op_i;
            s1_src1  <= mul_src1_i;
            s1_src2  <= mul_src2_i;
            s1_rd    <= mul_rd_i;
        end
    end

    // Compute multiplication in stage 1 (combinational, registered in stage 2)
    always_comb begin
        case (s1_op)
            MUL_OP_MUL, MUL_OP_MULH: begin
                // Both operands signed
                src1_signed_s1 = {s1_src1[31], s1_src1};  // Sign extend
                src2_signed_s1 = {s1_src2[31], s1_src2};  // Sign extend
            end
            MUL_OP_MULHSU: begin
                // src1 signed, src2 unsigned
                src1_signed_s1 = {s1_src1[31], s1_src1};  // Sign extend
                src2_signed_s1 = {1'b0, s1_src2};  // Zero extend
            end
            MUL_OP_MULHU: begin
                // Both operands unsigned
                src1_signed_s1 = {1'b0, s1_src1};  // Zero extend
                src2_signed_s1 = {1'b0, s1_src2};  // Zero extend
            end
            default: begin
                src1_signed_s1 = 33'b0;
                src2_signed_s1 = 33'b0;
            end
        endcase
        // Note: This 33x33 bit multiplication may synthesize to a large combinational
        // multiplier. For better timing/area, consider using DSP blocks or breaking
        // this into smaller operations (e.g., Booth encoding, Wallace tree).
        product_full_s1 = src1_signed_s1 * src2_signed_s1;
    end

    // Stage 2 logic: Store the multiplication result
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s2_valid   <= 1'b0;
            s2_op      <= 2'b0;
            s2_product <= 64'b0;
            s2_rd      <= 5'b0;
        end else if (flush_i) begin
            s2_valid   <= 1'b0;
            s2_op      <= 2'b0;
            s2_product <= 64'b0;
            s2_rd      <= 5'b0;
        end else begin
            s2_valid   <= s1_valid;
            s2_op      <= s1_op;
            s2_product <= product_full_s1[63:0];
            s2_rd      <= s1_rd;
        end
    end

    // Output logic: Select result based on operation type
    always_comb begin
        case (s2_op)
            MUL_OP_MUL: mul_result_o = s2_product[31:0];  // Lower 32 bits
            MUL_OP_MULH, MUL_OP_MULHSU, MUL_OP_MULHU:
            mul_result_o = s2_product[63:32];  // Upper 32 bits
            default: mul_result_o = 32'b0;
        endcase
    end

    // Output valid and register signals
    assign mul_valid_o       = s2_valid;
    assign mul_rd_o          = s2_rd;
    assign mul_rf_we_o       = s2_valid && (s2_rd != 5'b0);  // Write enable if valid and rd != x0

    // Status signals
    assign mul_busy_o        = s1_valid || s2_valid;
    assign mul_stage1_busy_o = s1_valid;
    assign mul_stage2_busy_o = s2_valid;

    // Hazard detection outputs
    assign mul_rd_s1_o       = s1_rd;
    assign mul_rd_s2_o       = s2_rd;

endmodule
