module PC (
    input  logic        clk,
    input  logic        rst_n,
    // 是否要打一拍 保持PC不变
    input  logic        keep_pc,
    // 进行分支跳转
    input  logic        branch_op,
    // 分支跳转目标地址
    input  logic [31:0] branch_target,
    output logic [31:0] pc_if,
    output logic [31:0] pc4_if
);

    logic [31:0] npc;

    always_comb begin
        pc4_if = pc_if + 4;
        npc    = branch_op ? branch_target : pc4_if;
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)       pc_if <= 0;
        else if (keep_pc) pc_if <= pc_if;
        else              pc_if <= npc;
    end

endmodule
