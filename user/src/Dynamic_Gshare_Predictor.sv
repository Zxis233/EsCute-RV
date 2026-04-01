`include "include/defines.svh"

module Dynamic_Gshare_Predictor #(
    parameter int unsigned INDEX_BITS = 8,
    parameter int unsigned META_BITS  = 2
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

    localparam int unsigned PHT_ENTRIES = 1 << INDEX_BITS;
    localparam int unsigned HASH_BITS = (INDEX_BITS < META_BITS) ? INDEX_BITS : META_BITS;

    logic   [           1:0] pht_table   [0:PHT_ENTRIES-1];
    logic   [ META_BITS-1:0] ghr_q;
    logic   [INDEX_BITS-1:0] predict_idx;
    logic   [INDEX_BITS-1:0] update_idx;
    integer                  i;

    function automatic logic [INDEX_BITS-1:0] gshare_index(input logic [31:0] pc,
                                                           input logic [META_BITS-1:0] history);
        logic [INDEX_BITS-1:0] pc_idx;
        logic [INDEX_BITS-1:0] history_folded;
        begin
            pc_idx         = pc[INDEX_BITS+1:2];
            history_folded = '0;
            if (HASH_BITS > 0) begin
                history_folded[HASH_BITS-1:0] = history[HASH_BITS-1:0];
            end
            gshare_index = pc_idx ^ history_folded;
        end
    endfunction

    function automatic logic [1:0] next_counter(input logic [1:0] counter, input logic taken);
        begin
            if (taken) begin
                if (counter != 2'b11) begin
                    next_counter = counter + 2'b01;
                end else begin
                    next_counter = counter;
                end
            end else if (counter != 2'b00) begin
                next_counter = counter - 2'b01;
            end else begin
                next_counter = counter;
            end
        end
    endfunction

    assign predict_idx    = gshare_index(pc_i, ghr_q);
    assign update_idx     = gshare_index(update_pc_i, update_meta_i);
    assign predict_meta_o = ghr_q;

    // 非投机式 GShare：
    // - 条件分支在 ID 级使用当前已提交的 GHR 做预测
    // - EX 级更新时使用随流水线带下来的 history snapshot 回写同一项 PHT
    // - GHR 只在分支真实结果产生时更新，避免额外的回滚机制
    always_comb begin
        predict_taken_o  = 1'b0;
        predict_target_o = branch_target_i;

        if (valid_i) begin
            unique case (jump_type_i)
                `JUMP_JAL:  predict_taken_o = 1'b1;
                `JUMP_JALR: predict_taken_o = 1'b0;
                default: begin
                    if (is_branch_instr_i) begin
                        predict_taken_o = pht_table[predict_idx][1];
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ghr_q <= '0;
            for (i = 0; i < PHT_ENTRIES; i++) begin
                pht_table[i] = 2'b01;
            end
        end else if (update_valid_i && update_is_branch_i) begin
            pht_table[update_idx] <= next_counter(pht_table[update_idx], update_taken_i);
            ghr_q                 <= {ghr_q[META_BITS-2:0], update_taken_i};
        end
    end

    logic unused_imm_bit;
    assign unused_imm_bit = imm_i[0];

endmodule
