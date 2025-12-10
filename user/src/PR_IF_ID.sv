module PR_IF_ID (
    input  logic        clk,
    input  logic        rst_n,
    // 流水线控制信号
    input  logic        flush,
    input  logic        stall,
    // IF级输入
    input  logic [31:0] pc_if_i,
    input  logic [31:0] pc4_if_i,
    input  logic [31:0] instr_if_i,
    // IF级输出 给ID级输入
    output logic [31:0] pc_id_o,
    output logic [31:0] pc4_id_o,
    output logic [31:0] instr_id_o,
    // 判断指令是否有效
    // 流水线冲刷时需要将指令置为无效
    input  logic        instr_valid_if_i,
    output logic        instr_valid_id_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_id_o          <= 32'b0;
            pc4_id_o         <= 32'b0;
            instr_id_o       <= 32'b0;
            instr_valid_id_o <= 1'b0;
        end else if (flush) begin
            pc_id_o          <= 32'b0;
            pc4_id_o         <= 32'b0;
            instr_id_o       <= 32'b0;
            instr_valid_id_o <= 1'b0;  // 冲刷时指令无效
        end else if (stall) begin
            pc_id_o          <= pc_id_o;
            pc4_id_o         <= pc4_id_o;
            instr_id_o       <= instr_id_o;
            instr_valid_id_o <= instr_valid_id_o;
        end else begin
            pc_id_o          <= pc_if_i;
            pc4_id_o         <= pc4_if_i;
            instr_id_o       <= instr_if_i;
            instr_valid_id_o <= instr_valid_if_i;
        end
    end

endmodule
