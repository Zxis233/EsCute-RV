module PR_ID_EX (
    input  logic        clk,
    input  logic        rst_n,
    // 流水线控制信号
    input  logic        flush,
    // ID级输入
    input  logic [31:0] pc_id_i,
    input  logic [31:0] pc4_id_i,
    // input  logic [31:0] instr_id_i,
    // ID级输出 给EX级输入
    output logic [31:0] pc_ex_o,
    output logic [31:0] pc4_ex_o,
    // output logic [31:0] instr_ex_o,
    // 判断指令是否有效
    // 流水线冲刷时需要将指令置为无效
    input  logic        instr_valid_id_i,
    output logic        instr_valid_ex_o,

    // 寄存器堆第一寄存器数据
    input  logic [31:0] rD1_i,
    output logic [31:0] rD1_o,
    // 寄存器堆第二寄存器数据
    input  logic [31:0] rD2_i,
    output logic [31:0] rD2_o,

    // ALUOp
    input  logic [ 4:0] alu_op_id_i,
    output logic [ 4:0] alu_op_ex_o,
    // ALU第一操作数来源 判断AUIPC
    input  logic        is_auipc_id_i,
    output logic        is_auipc_ex_o,
    // ALU第二操作数来源
    input  logic        alu_src2_sel_id_i,
    output logic        alu_src2_sel_ex_o,
    // 写使能
    input  logic        dram_we_id_i,
    output logic        dram_we_ex_o,
    input  logic        rf_we_id_i,
    output logic        rf_we_ex_o,
    // 写回数据来源
    input  logic [ 1:0] wd_sel_id_i,
    output logic [ 1:0] wd_sel_ex_o,
    // 写回寄存器地址
    input  logic [ 4:0] wr_id_i,
    output logic [ 4:0] wr_ex_o,
    // 分支跳转
    input  logic        is_branch_instr_id_i,
    output logic        is_branch_instr_ex_o,
    input  logic [ 2:0] branch_type_id_i,
    output logic [ 2:0] branch_type_ex_o,
    // 跳转相关
    input  logic [ 1:0] jump_type_id_i,
    output logic [ 1:0] jump_type_ex_o,
    // 读取类型
    input  logic [ 3:0] sl_type_id_i,
    output logic [ 3:0] sl_type_ex_o,
    // 立即数
    input  logic [31:0] imm_id_i,
    output logic [31:0] imm_ex_o,
    // PC跳转时地址
    input  logic [31:0] pc_jump_id_i,
    output logic [31:0] pc_jump_ex_o,
    // 加上前递相关
    input               fwd_rD1e_EX,
    input               fwd_rD2e_EX,
    input  logic [31:0] fwd_rD1_EX,
    input  logic [31:0] fwd_rD2_EX
);

    // 前递信号与数据
    logic [31:0] rD1_forwarded, rD2_forwarded;
    // 考虑了前递就不需要冲刷了
    always_comb begin
        rD1_forwarded = fwd_rD1e_EX ? fwd_rD1_EX : rD1_i;
        rD2_forwarded = fwd_rD2e_EX ? fwd_rD2_EX : rD2_i;
    end

    // 寄存器堆数据
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rD1_o <= 32'b0;
            rD2_o <= 32'b0;
        end else begin
            rD1_o <= rD1_forwarded;
            rD2_o <= rD2_forwarded;
        end
    end

    // 分支跳转相关
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            is_branch_instr_ex_o <= 1'b0;
            branch_type_ex_o     <= 3'b0;
            jump_type_ex_o       <= 2'b0;
        end else if (flush) begin
            is_branch_instr_ex_o <= 1'b0;
            branch_type_ex_o     <= 3'b0;
            jump_type_ex_o       <= 2'b0;
        end else begin
            is_branch_instr_ex_o <= is_branch_instr_id_i;
            branch_type_ex_o     <= branch_type_id_i;
            jump_type_ex_o       <= jump_type_id_i;
        end
    end

    // ALUOp相关
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_op_ex_o       <= 4'b0;
            is_auipc_ex_o     <= 1'b0;
            alu_src2_sel_ex_o <= 1'b0;
            dram_we_ex_o      <= 1'b0;
            sl_type_ex_o      <= 3'b0;
            imm_ex_o          <= 32'b0;
        end else if (flush) begin
            alu_op_ex_o       <= 4'b0;
            is_auipc_ex_o     <= 1'b0;
            alu_src2_sel_ex_o <= 1'b0;
            dram_we_ex_o      <= 1'b0;
            sl_type_ex_o      <= sl_type_id_i;
            imm_ex_o          <= 32'b0;
        end else begin
            alu_op_ex_o       <= alu_op_id_i;
            is_auipc_ex_o     <= is_auipc_id_i;
            alu_src2_sel_ex_o <= alu_src2_sel_id_i;
            dram_we_ex_o      <= dram_we_id_i;
            sl_type_ex_o      <= sl_type_id_i;
            imm_ex_o          <= imm_id_i;
        end
    end

    // 写回来源
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_ex_o          <= 32'b0;
            pc4_ex_o         <= 32'b0;
            instr_valid_ex_o <= 1'b0;

            rf_we_ex_o       <= 1'b0;
            wd_sel_ex_o      <= 2'b0;
            pc_jump_ex_o     <= 32'b0;

        end else if (flush && pc_id_i) begin  // 确保不是因为流水线暂停引起的冲刷
            pc_ex_o          <= 32'b0;
            pc4_ex_o         <= 32'b0;
            instr_valid_ex_o <= 1'b0;

            rf_we_ex_o       <= 1'b0;
            wd_sel_ex_o      <= 2'b0;
            pc_jump_ex_o     <= 32'b0;

        end else begin
            pc_ex_o          <= pc_id_i;
            pc4_ex_o         <= pc4_id_i;
            instr_valid_ex_o <= instr_valid_id_i;

            rf_we_ex_o       <= rf_we_id_i;
            wd_sel_ex_o      <= wd_sel_id_i;
            pc_jump_ex_o     <= pc_jump_id_i;
        end
    end

    // 写回寄存器地址
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ex_o <= 5'b0;
        end else if (flush) begin
            wr_ex_o <= 5'b0;
        end else begin
            wr_ex_o <= wr_id_i;
        end
    end

endmodule
