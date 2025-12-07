`timescale 1ns / 1ps

// ================== DUT：简单计数器模块 ==================
module simple_counter #(
    parameter int WIDTH = 4,
    parameter int MAX   = 5   // 故意设得比较小，方便触发 assert
) (
    input  logic             clk,
    input  logic             rst_n,
    input  logic             en,
    output logic [WIDTH-1:0] cnt
);

    // 时序逻辑 + immediate assert 检查范围
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt <= '0;
        end else if (en) begin
            // 这里用 immediate assert 检查“下一个值不能超过 MAX”
`ifdef sv
            assert (MAX >= cnt + 1)
            else $error("[%0t] Counter overflow: next=%0d > MAX=%0d", $time, cnt + 1, MAX);

`endif

            cnt <= cnt + 1;
        end
    end

    // 提取指令字段
    logic [1:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    always_comb begin : easy_decode
        opcode = cnt[1:0];
        funct3 = cnt[2:0];
        funct7 = cnt[3:2];
    end

endmodule
