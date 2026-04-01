`include "include/defines.svh"

module Dynamic_1bit_Predictor #(
    parameter int unsigned INDEX_BITS = 8,
    parameter int unsigned META_BITS  = 8
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 valid_i,
    input  logic [         31:0] pc_i,
    input  logic                 is_branch_instr_i,
    input  logic [          1:0] jump_type_i,
    input  logic [         31:0] imm_i,
    input  logic [         31:0] branch_target_i,
    input  logic                 update_valid_i,
    input  logic [         31:0] update_pc_i,
    input  logic                 update_is_branch_i,
    input  logic                 update_taken_i,
    input  logic [META_BITS-1:0] update_meta_i,
    output logic                 predict_taken_o,
    output logic [         31:0] predict_target_o,
    output logic [META_BITS-1:0] predict_meta_o
);

    localparam int unsigned BHT_ENTRIES = 1 << INDEX_BITS;

    logic   [BHT_ENTRIES-1:0] bht_table;
    logic   [ INDEX_BITS-1:0] predict_idx;
    logic   [ INDEX_BITS-1:0] update_idx;
    integer                   i;

    assign predict_idx = pc_i[INDEX_BITS+1:2];
    assign update_idx  = update_pc_i[INDEX_BITS+1:2];

    // 预测策略：
    // - JAL: 恒预测跳转
    // - JALR: 不预测
    // - 条件分支: 查询 1-bit BHT，记录该PC上一次实际结果
    always_comb begin
        predict_taken_o  = 1'b0;
        predict_target_o = branch_target_i;
        predict_meta_o   = '0;

        if (valid_i) begin
            unique case (jump_type_i)
                `JUMP_JAL:  predict_taken_o = 1'b1;
                `JUMP_JALR: predict_taken_o = 1'b0;
                default: begin
                    if (is_branch_instr_i) begin
                        predict_taken_o = bht_table[predict_idx];
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < BHT_ENTRIES; i++) begin
                bht_table[i] <= 1'b0;
            end
        end else if (update_valid_i && update_is_branch_i) begin
            bht_table[update_idx] <= update_taken_i;
        end
    end

    logic unused_imm_bit;
    assign unused_imm_bit = imm_i[0] ^ update_meta_i[0];

endmodule
