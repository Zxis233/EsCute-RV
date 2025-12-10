module PR_EX_MEM (
    input  logic        clk,
    input  logic        rst_n,
    // EX级输入
    input  logic [31:0] pc_ex_i,
    // EX级输出 给MEM级输入
    output logic [31:0] pc_mem_o,
    // 判断指令是否有效
    input  logic        instr_valid_ex_i,
    output logic        instr_valid_mem_o,
    // 写使能
    input  logic        dram_we_ex_i,
    output logic        dram_we_mem_o,
    input  logic        rf_we_ex_i,
    output logic        rf_we_mem_o,
    // 写回数据来源
    input  logic [ 1:0] wd_sel_ex_i,
    output logic [ 1:0] wd_sel_mem_o,
    // 写回寄存器地址
    input  logic [ 4:0] wr_ex_i,
    output logic [ 4:0] wr_mem_o,
    // ALU计算结果
    input  logic [31:0] alu_result_ex_i,
    output logic [31:0] alu_result_mem_o,
    // MUX数据 控制写回数据来源
    input  logic [31:0] wd_ex_i,
    output logic [31:0] wd_mem_o,
    // 回写数据 来自ID/EX级
    input  logic [31:0] rD2_ex_i,
    output logic [31:0] rD2_mem_o
);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_mem_o          <= 32'b0;
            instr_valid_mem_o <= 1'b0;
            dram_we_mem_o     <= 1'b0;
            rf_we_mem_o       <= 1'b0;
            wd_sel_mem_o      <= 2'b0;
            alu_result_mem_o  <= 32'b0;
            wd_mem_o          <= 32'b0;
            rD2_mem_o         <= 32'b0;
        end else begin
            pc_mem_o          <= pc_ex_i;
            instr_valid_mem_o <= instr_valid_ex_i;
            dram_we_mem_o     <= dram_we_ex_i;
            rf_we_mem_o       <= rf_we_ex_i;
            wd_sel_mem_o      <= wd_sel_ex_i;
            alu_result_mem_o  <= alu_result_ex_i;
            wd_mem_o          <= wd_ex_i;
            rD2_mem_o         <= rD2_ex_i;
        end
    end

    // 写回寄存器地址
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_mem_o <= 5'b0;
        end else begin
            wr_mem_o <= wr_ex_i;
        end
    end

endmodule
