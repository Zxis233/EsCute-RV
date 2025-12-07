`timescale 1ns / 1ps
`include "../src/include/defines.svh"
`include "../src/PC.sv"

module tb_PC;

    // 时钟 & 复位
    logic        clk;
    logic        rst_n;

    // 来自流水线控制的信号
    logic        keep_pc;
    logic        branch_op;
    logic [31:0] branch_target;

    // 被测 PC 模块输出
    logic [31:0] pc_if;
    logic [31:0] pc4_if;

    // DUT 实例
    PC u_PC (
        .clk          (clk),
        .rst_n        (rst_n),
        .keep_pc      (keep_pc),
        .branch_op    (branch_op),
        .branch_target(branch_target),
        .pc_if        (pc_if),
        .pc4_if       (pc4_if)
    );

    // 生成时钟：10ns 周期
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 简单检查任务
    task automatic check_pc(input string tag, input logic [31:0] exp_pc,
                            input logic [31:0] exp_pc4);
        if (pc_if !== exp_pc || pc4_if !== exp_pc4) begin
            $display("[%0t] %s  ASSERT FAILED", $time, tag);
            $display("    exp_pc  = 0x%08x, act_pc  = 0x%08x", exp_pc, pc_if);
            $display("    exp_pc4 = 0x%08x, act_pc4 = 0x%08x", exp_pc4, pc4_if);
            $stop;
        end else begin
            $display("[%0t] %s  ASSERT OK", $time, tag);
            $display("    pc  = 0x%08x, pc4 = 0x%08x", pc_if, pc4_if);
        end
    endtask

    int unsigned i;
    logic [31:0] exp_pc, exp_pc4;  // 期望 PC
    // 主测试流程：先定向测试，再随机测试
    initial begin : main_test
        // 初始值
        rst_n         = 1'b0;
        keep_pc       = 1'b0;
        branch_op     = 1'b0;
        branch_target = 32'h0000_0000;

        // -------------- 1. 复位阶段 --------------
        @(posedge clk);  // 第一个上升沿，rst_n=0
        #1;
        // 复位时 pc_if 应为 0，pc4_if = 4
        check_pc("reset_hold", 32'h0000_0000, 32'h0000_0004);

        // -------------- 2. 释放复位，正常自增 --------------
        rst_n = 1'b1;

        @(posedge clk);
        #1;
        // pc: 0 -> 4, pc4: 8
        check_pc("after_reset_release", 32'h0000_0004, 32'h0000_0008);

        @(posedge clk);
        #1;
        // pc: 4 -> 8, pc4: 12
        check_pc("normal_inc1", 32'h0000_0008, 32'h0000_000C);

        @(posedge clk);
        #1;
        // pc: 8 -> 12, pc4: 16
        check_pc("normal_inc2", 32'h0000_000C, 32'h0000_0010);

        // -------------- 3. keep_pc=1 时 PC 应保持不变 --------------
        keep_pc = 1'b1;
        @(posedge clk);
        #1;
        // 进这一拍前 pc=0x0C，因此这一拍保持 0x0C，pc4=0x10
        check_pc("keep_pc", 32'h0000_000C, 32'h0000_0010);

        // 取消保持
        keep_pc       = 1'b0;

        // -------------- 4. 分支跳转 branch_op=1 --------------
        branch_target = 32'h0000_0100;
        branch_op     = 1'b1;

        @(posedge clk);
        #1;
        // 应该跳到 branch_target
        check_pc("branch_jump", 32'h0000_0100, 32'h0000_0104);

        // 关闭 branch，继续顺序执行
        branch_op     = 1'b0;
        branch_target = 32'h0000_0000;

        @(posedge clk);
        #1;
        check_pc("after_branch", 32'h0000_0104, 32'h0000_0108);

        // -------------- 5. 随机测试（scoreboard 自检） --------------

        // 跟当前 DUT pc 对齐
        exp_pc = pc_if;

        $display("==== Start random test ====");

        for (i = 0; i < 100; i++) begin
            // 随机产生控制信号
            keep_pc       = $urandom_range(0, 1);
            branch_op     = $urandom_range(0, 1);
            // 让分支目标大致 4 字节对齐
            branch_target = {$urandom_range(0, 1023), 2'b00};

            @(posedge clk);
            #1;

            // 按 PC 模块同样的规则更新期望值
            exp_pc4 = exp_pc + 4;

            if (!keep_pc) begin
                if (branch_op) exp_pc = branch_target;
                else exp_pc = exp_pc4;
            end
            // keep_pc==1 时 exp_pc 保持不变

            check_pc($sformatf("random_cycle_%0d", i), exp_pc, exp_pc + 4);
        end

        $display("==== Random test finished ====");
        $display("All PC tests PASSED!");
        $finish;
    end

    // 超时保护：防止仿真跑飞
    initial begin
        #1000;
        $display("Time Out!");
        $finish;
    end

    // 波形
    initial begin
        $dumpfile("wave.vcd");  // 指定输出的波形文件名
        $dumpvars;  // dump 全部层级
    end

endmodule
