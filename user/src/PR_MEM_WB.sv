module PR_MEM_WB (
    input  logic        clk,
    input  logic        rst_n,
    // MEM级输入
    input  logic [31:0] pc_mem_i,
    // MEM级输出 给WB级输入
    output logic [31:0] pc_wb_o,
    // 判断指令是否有效
    input  logic        instr_valid_mem_i,
    output logic        instr_valid_wb_o,
    // 寄存器堆写使能
    input  logic        rf_we_mem_i,
    output logic        rf_we_wb_o,
    // 写回寄存器地址
    input  logic [ 4:0] wr_mem_i,
    output logic [ 4:0] wr_wb_o,
    // 写回数据
    input  logic [31:0] wd_mem_i,
    output logic [31:0] wd_wb_o,
    // 同步读DRAM时的额外数据
    input  logic [31:0] dram_data_mem_i,
    output logic [31:0] dram_data_wb_o,
    // 写回数据来源 用于在WB级选择
    input  logic [ 1:0] wd_sel_mem_i,
    output logic [ 1:0] wd_sel_wb_o,
    // 存取类型 用于WB级LoadStoreUnit处理DRAM读取数据
    input  logic [ 3:0] sl_type_mem_i,
    output logic [ 3:0] sl_type_wb_o,
    // ALU结果（地址） 用于WB级LoadStoreUnit确定字节偏移
    input  logic [31:0] alu_result_mem_i,
    output logic [31:0] alu_result_wb_o
);

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_wb_o          <= 32'b0;
            instr_valid_wb_o <= 1'b0;
            rf_we_wb_o       <= 1'b0;
            wr_wb_o          <= 5'b0;
            wd_wb_o          <= 32'b0;
            dram_data_wb_o   <= 32'b0;
            wd_sel_wb_o      <= 2'b0;
            sl_type_wb_o     <= 4'b0;
            alu_result_wb_o  <= 32'b0;
        end else begin
            pc_wb_o          <= pc_mem_i;
            instr_valid_wb_o <= instr_valid_mem_i;
            rf_we_wb_o       <= rf_we_mem_i;
            wr_wb_o          <= wr_mem_i;
            wd_wb_o          <= wd_mem_i;
            dram_data_wb_o   <= dram_data_mem_i;
            wd_sel_wb_o      <= wd_sel_mem_i;
            sl_type_wb_o     <= sl_type_mem_i;
            alu_result_wb_o  <= alu_result_mem_i;
        end
    end

endmodule
