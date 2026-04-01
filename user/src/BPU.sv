`include "include/defines.svh"

module BPU #(
    parameter bpu_type_e   BPU_TYPE   = bpu_type_e'(1),  // STATIC
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

    generate
        if (BPU_TYPE == NONE) begin : gen_none
            assign predict_taken_o  = 1'b0;
            assign predict_target_o = branch_target_i;
            assign predict_meta_o   = '0;
        end else if (BPU_TYPE == STATIC) begin : gen_static
            Static_Predictor #(
                .META_BITS(META_BITS)
            ) u_bpu (
                .clk               (clk),
                .rst_n             (rst_n),
                .valid_i           (valid_i),
                .pc_i              (pc_i),
                .is_branch_instr_i (is_branch_instr_i),
                .jump_type_i       (jump_type_i),
                .imm_i             (imm_i),
                .branch_target_i   (branch_target_i),
                .update_valid_i    (update_valid_i),
                .update_pc_i       (update_pc_i),
                .update_is_branch_i(update_is_branch_i),
                .update_taken_i    (update_taken_i),
                .update_meta_i     (update_meta_i),
                .predict_taken_o   (predict_taken_o),
                .predict_target_o  (predict_target_o),
                .predict_meta_o    (predict_meta_o)
            );
        end else if (BPU_TYPE == DYNAMIC_1bit) begin : gen_dynamic_1bit
            Dynamic_1bit_Predictor #(
                .INDEX_BITS(INDEX_BITS),  // 1-bit预测器使用META_BITS作为索引位宽
                .META_BITS (META_BITS)
            ) u_bpu (
                .clk               (clk),
                .rst_n             (rst_n),
                .valid_i           (valid_i),
                .pc_i              (pc_i),
                .is_branch_instr_i (is_branch_instr_i),
                .jump_type_i       (jump_type_i),
                .imm_i             (imm_i),
                .branch_target_i   (branch_target_i),
                .update_valid_i    (update_valid_i),
                .update_pc_i       (update_pc_i),
                .update_is_branch_i(update_is_branch_i),
                .update_taken_i    (update_taken_i),
                .update_meta_i     (update_meta_i),
                .predict_taken_o   (predict_taken_o),
                .predict_target_o  (predict_target_o),
                .predict_meta_o    (predict_meta_o)
            );
        end else if (BPU_TYPE == GSHARE) begin : gen_gshare
            Dynamic_Gshare_Predictor #(
                .INDEX_BITS(INDEX_BITS),
                .META_BITS (META_BITS)
            ) u_bpu (
                .clk               (clk),
                .rst_n             (rst_n),
                .valid_i           (valid_i),
                .pc_i              (pc_i),
                .is_branch_instr_i (is_branch_instr_i),
                .jump_type_i       (jump_type_i),
                .imm_i             (imm_i),
                .branch_target_i   (branch_target_i),
                .update_valid_i    (update_valid_i),
                .update_pc_i       (update_pc_i),
                .update_is_branch_i(update_is_branch_i),
                .update_taken_i    (update_taken_i),
                .update_meta_i     (update_meta_i),
                .predict_taken_o   (predict_taken_o),
                .predict_target_o  (predict_target_o),
                .predict_meta_o    (predict_meta_o)
            );
        end else begin : gen_default
`ifdef YOSYS
            assign predict_taken_o  = 1'b0;
            assign predict_target_o = branch_target_i;
            assign predict_meta_o   = '0;
`else
            initial $fatal(1, "Invalid BPU_TYPE = %0d", BPU_TYPE);
`endif
        end
    endgenerate

endmodule
