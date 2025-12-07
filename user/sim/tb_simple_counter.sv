// ================== Testbench ==================
`timescale 1ns / 1ps
module tb_simple_counter;

    logic       clk;
    logic       rst_n;
    logic       en;
    logic [3:0] cnt;  // 对应 WIDTH = 4

    logic test_out1, test_out2;
    logic [1:0] test_out3;

    // 实例化 DUT
    simple_counter #(
        .WIDTH(4),
        .MAX  (5)
    ) u_dut (
        .clk  (clk),
        .rst_n(rst_n),
        .en   (en),
        .cnt  (cnt)
    );

    // 10ns 时钟
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    always_comb begin
        if (cnt == 4'd5) begin
            test_out1 = 1'b1;
        end else begin
            test_out1 = 1'b0;
        end
    end

    always_comb begin
        if (cnt == 4'd6) begin
            test_out2 = 1'b1;
        end else begin
            test_out2 = 1'b0;
        end
    end

    always_comb begin
        case (1'b1)
            test_out1: test_out3 = 1'b1;
            test_out2: test_out3 = 1'b0;
            default:   test_out3 = 2'b10;
        endcase
    end

    // 复位 + 激活 en
    initial begin
        rst_n = 0;
        en    = 0;
        #20;  // 复位保持 20ns
        rst_n = 1;
        #10;
        en = 1;  // 开始计数，一段时间后会触发 assert
        #300;
        $finish;
    end

    initial begin
        $dumpfile("prj/icarus/wave.vcd");  // 指定输出的波形文件名
        $dumpvars;  // 从 tb_top 这个层级往下 dump 所有信号
        // $dumpvars;              // 或者简单粗暴：dump 全部层级
    end

endmodule
