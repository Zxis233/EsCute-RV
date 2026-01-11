`timescale 1ns / 1ps
`include "../src/MUL.sv"

module tb_MUL;

    // 时钟周期
    localparam CLK_PERIOD = 10;

    // 乘法操作类型
    localparam MUL_OP_MUL = 2'b00;
    localparam MUL_OP_MULH = 2'b01;
    localparam MUL_OP_MULHSU = 2'b10;
    localparam MUL_OP_MULHU = 2'b11;

    // 信号声明
    logic               clk;
    logic               rst_n;
    logic               mul_valid_i;
    logic   [ 1:0]      mul_op_i;
    logic   [31:0]      mul_src1_i;
    logic   [31:0]      mul_src2_i;
    logic   [ 4:0]      mul_rd_i;
    logic               flush_i;
    logic   [ 4:0]      cancel_rd_i;

    logic               mul_valid_o;
    logic   [31:0]      mul_result_o;
    logic   [ 4:0]      mul_rd_o;
    logic               mul_rf_we_o;
    logic               mul_busy_o;
    logic   [ 5:0]      mul_stage_busy_o;
    logic   [ 5:0][4:0] mul_rd_s_o;

    // 测试统计
    integer             test_count;
    integer             pass_count;
    integer             fail_count;

    // 期望结果数组 (使用简单数组代替 struct 队列)
    // 最多支持 64 个待验证结果
    reg     [31:0]      exp_result              [0:63];
    reg     [ 4:0]      exp_rd                  [0:63];
    reg     [ 1:0]      exp_op                  [0:63];
    reg     [31:0]      exp_src1                [0:63];
    reg     [31:0]      exp_src2                [0:63];
    integer             exp_head;  // 队列头
    integer             exp_tail;  // 队列尾

    // 实例化被测模块
    MUL u_MUL (
        .clk             (clk),
        .rst_n           (rst_n),
        .mul_valid_i     (mul_valid_i),
        .mul_op_i        (mul_op_i),
        .mul_src1_i      (mul_src1_i),
        .mul_src2_i      (mul_src2_i),
        .mul_rd_i        (mul_rd_i),
        .flush_i         (flush_i),
        .cancel_rd_i     (cancel_rd_i),
        .mul_valid_o     (mul_valid_o),
        .mul_result_o    (mul_result_o),
        .mul_rd_o        (mul_rd_o),
        .mul_rf_we_o     (mul_rf_we_o),
        .mul_busy_o      (mul_busy_o),
        .mul_stage_busy_o(mul_stage_busy_o),
        .mul_rd_s_o      (mul_rd_s_o)
    );

    // 时钟生成
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // 计算期望结果
    function [31:0] calc_expected;
        input [1:0] op;
        input [31:0] src1;
        input [31:0] src2;
        reg signed [63:0] result_ss;
        reg        [63:0] result_uu;
        reg signed [63:0] result_su;
        begin
            case (op)
                MUL_OP_MUL: begin
                    result_ss     = $signed(src1) * $signed(src2);
                    calc_expected = result_ss[31:0];
                end
                MUL_OP_MULH: begin
                    result_ss     = $signed(src1) * $signed(src2);
                    calc_expected = result_ss[63:32];
                end
                MUL_OP_MULHSU: begin
                    result_su     = $signed(src1) * $signed({1'b0, src2});
                    calc_expected = result_su[63:32];
                end
                MUL_OP_MULHU: begin
                    result_uu     = {32'b0, src1} * {32'b0, src2};
                    calc_expected = result_uu[63:32];
                end
                default: calc_expected = 32'b0;
            endcase
        end
    endfunction

    // 队列操作 - 入队
    task enqueue;
        input [31:0] result;
        input [4:0] rd;
        input [1:0] op;
        input [31:0] src1;
        input [31:0] src2;
        begin
            exp_result[exp_tail] = result;
            exp_rd[exp_tail]     = rd;
            exp_op[exp_tail]     = op;
            exp_src1[exp_tail]   = src1;
            exp_src2[exp_tail]   = src2;
            exp_tail             = (exp_tail + 1) % 64;
        end
    endtask

    // 队列操作 - 检查是否为空
    function integer queue_empty;
        begin
            queue_empty = (exp_head == exp_tail);
        end
    endfunction

    // 发送乘法请求
    task send_mul_request;
        input [1:0] op;
        input [31:0] src1;
        input [31:0] src2;
        input [4:0] rd;
        reg [31:0] expected;
        begin
            @(posedge clk);
            mul_valid_i <= 1'b1;
            mul_op_i    <= op;
            mul_src1_i  <= src1;
            mul_src2_i  <= src2;
            mul_rd_i    <= rd;

            // 计算并存储期望结果
            expected = calc_expected(op, src1, src2);
            enqueue(expected, rd, op, src1, src2);

            @(posedge clk);
            mul_valid_i <= 1'b0;
        end
    endtask

    // 检查单个结果
    task check_one_result;
        reg [31:0] exp_res;
        reg [ 4:0] exp_r;
        reg [ 1:0] op;
        reg [31:0] s1, s2;
        reg signed [63:0] full_result;
        begin
            exp_res    = exp_result[exp_head];
            exp_r      = exp_rd[exp_head];
            op         = exp_op[exp_head];
            s1         = exp_src1[exp_head];
            s2         = exp_src2[exp_head];
            exp_head   = (exp_head + 1) % 64;

            test_count = test_count + 1;

            if (mul_result_o === exp_res && mul_rd_o === exp_r) begin
                pass_count = pass_count + 1;
                $display("[PASS] Test %0d: op=%0d", test_count, op);
                $display("       src1=0x%08h (%0d), src2=0x%08h (%0d)", s1, $signed(s1), s2,
                         $signed(s2));
                $display("       Result=0x%08h, rd=%0d", mul_result_o, mul_rd_o);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] Test %0d: op=%0d", test_count, op);
                $display("       src1=0x%08h (%0d), src2=0x%08h (%0d)", s1, $signed(s1), s2,
                         $signed(s2));
                $display("       Got:      result=0x%08h, rd=%0d", mul_result_o, mul_rd_o);
                $display("       Expected: result=0x%08h, rd=%0d", exp_res, exp_r);

                // 显示完整64位结果用于调试
                full_result = $signed(s1) * $signed(s2);
                $display("       Debug: signed full=0x%016h", full_result);
                full_result = {32'b0, s1} * {32'b0, s2};
                $display("       Debug: unsigned full=0x%016h", full_result);
            end
            $display("");
        end
    endtask

    // 等待并检查结果
    task wait_and_check;
        input integer timeout;
        integer cnt;
        begin
            cnt = 0;
            while (!queue_empty() && cnt < timeout) begin
                @(posedge clk);
                if (mul_valid_o) begin
                    check_one_result();
                end
                cnt = cnt + 1;
            end
        end
    endtask

    // 单步调试测试
    task test_single_debug;
        reg [31:0] a, b;
        reg signed [63:0] expected_full;
        integer           cyc;
        begin
            $display("\n========== Single Step Debug ==========\n");

            a             = 32'd7;
            b             = 32'd8;
            expected_full = $signed(a) * $signed(b);

            $display("Testing: %0d * %0d = %0d (0x%016h)", $signed(a), $signed(b), expected_full,
                     expected_full);
            $display("Expected low 32:  0x%08h (%0d)", expected_full[31:0], expected_full[31:0]);
            $display("Expected high 32: 0x%08h", expected_full[63:32]);

            send_mul_request(MUL_OP_MUL, a, b, 5'd1);

            // 监控每个周期的流水线状态
            for (cyc = 0; cyc < 10; cyc = cyc + 1) begin
                @(posedge clk);
                $display("Cycle %0d:  busy=%b, stage_busy=%06b, valid_o=%b, result=0x%08h, rd=%0d",
                         cyc, mul_busy_o, mul_stage_busy_o, mul_valid_o, mul_result_o, mul_rd_o);
                if (mul_valid_o && !queue_empty()) begin
                    check_one_result();
                end
            end
        end
    endtask

    // 基本测试用例
    task test_basic;
        begin
            $display("\n========== Basic Tests ==========\n");

            // 测试1: 简单正数乘法
            $display("--- Test:  Simple positive multiplication ---");
            send_mul_request(MUL_OP_MUL, 32'd3, 32'd7, 5'd1);
            wait_and_check(20);

            // 测试2: 零乘法
            $display("--- Test:  Zero multiplication ---");
            send_mul_request(MUL_OP_MUL, 32'd0, 32'd12345, 5'd2);
            wait_and_check(20);

            // 测试3: 1乘法
            $display("--- Test:  Multiply by 1 ---");
            send_mul_request(MUL_OP_MUL, 32'd1, 32'd99999, 5'd3);
            wait_and_check(20);

            // 测试4: 负数乘正数
            $display("--- Test: Negative * Positive ---");
            send_mul_request(MUL_OP_MUL, 32'hFFFFFFFB, 32'd6, 5'd4);  // -5 * 6
            wait_and_check(20);

            // 测试5: 负数乘负数
            $display("--- Test: Negative * Negative ---");
            send_mul_request(MUL_OP_MUL, 32'hFFFFFFFC, 32'hFFFFFFF8, 5'd5);  // -4 * -8
            wait_and_check(20);

            // 测试6: 较大数
            $display("--- Test:  Larger numbers ---");
            send_mul_request(MUL_OP_MUL, 32'd1000, 32'd2000, 5'd6);
            wait_and_check(20);
        end
    endtask

    // MULH测试用例
    task test_mulh;
        begin
            $display("\n========== MULH Tests ==========\n");

            // 大正数乘法 - 高32位
            $display("--- Test: Large positive MULH ---");
            send_mul_request(MUL_OP_MULH, 32'h7FFFFFFF, 32'h7FFFFFFF, 5'd7);
            wait_and_check(20);

            // 负数乘正数 - 高32位
            $display("--- Test:  Negative * Positive MULH ---");
            send_mul_request(MUL_OP_MULH, 32'h80000000, 32'h00000002, 5'd8);
            wait_and_check(20);

            // 负数乘负数 - 高32位
            $display("--- Test: Negative * Negative MULH ---");
            send_mul_request(MUL_OP_MULH, 32'h80000000, 32'h80000000, 5'd9);
            wait_and_check(20);

            // 小数高位应为0或-1
            $display("--- Test: Small number MULH (should be 0) ---");
            send_mul_request(MUL_OP_MULH, 32'd100, 32'd200, 5'd10);
            wait_and_check(20);

            $display("--- Test: Small negative MULH (should be -1/0xFFFFFFFF) ---");
            send_mul_request(MUL_OP_MULH, 32'hFFFFFFFF, 32'd100, 5'd11);  // -1 * 100
            wait_and_check(20);
        end
    endtask

    // MULHU测试用例
    task test_mulhu;
        begin
            $display("\n========== MULHU Tests ==========\n");

            // 大无符号数乘法
            $display("--- Test: Large unsigned MULHU ---");
            send_mul_request(MUL_OP_MULHU, 32'hFFFFFFFF, 32'hFFFFFFFF, 5'd12);
            wait_and_check(20);

            // 另一个无符号乘法
            $display("--- Test: 0x80000000 * 2 MULHU ---");
            send_mul_request(MUL_OP_MULHU, 32'h80000000, 32'h00000002, 5'd13);
            wait_and_check(20);

            // 小数无符号高位应为0
            $display("--- Test: Small unsigned MULHU (should be 0) ---");
            send_mul_request(MUL_OP_MULHU, 32'd1000, 32'd2000, 5'd14);
            wait_and_check(20);
        end
    endtask

    // MULHSU测试用例
    task test_mulhsu;
        begin
            $display("\n========== MULHSU Tests ==========\n");

            // 负有符号 * 无符号
            $display("--- Test: Negative signed * Unsigned MULHSU ---");
            send_mul_request(MUL_OP_MULHSU, 32'h80000000, 32'h00000002, 5'd15);
            wait_and_check(20);

            // 正有符号 * 无符号
            $display("--- Test:  Positive signed * Unsigned MULHSU ---");
            send_mul_request(MUL_OP_MULHSU, 32'h7FFFFFFF, 32'hFFFFFFFF, 5'd16);
            wait_and_check(20);

            // -1 * large unsigned
            $display("--- Test: -1 * 0x80000000 MULHSU ---");
            send_mul_request(MUL_OP_MULHSU, 32'hFFFFFFFF, 32'h80000000, 5'd17);
            wait_and_check(20);
        end
    endtask

    // 边界测试
    task test_boundary;
        begin
            $display("\n========== Boundary Tests ==========\n");

            // 最大正数 * 2
            $display("--- Test:  MAX_INT * 2 ---");
            send_mul_request(MUL_OP_MUL, 32'h7FFFFFFF, 32'd2, 5'd18);
            wait_and_check(20);

            // 最小负数 * 2
            $display("--- Test: MIN_INT * 2 ---");
            send_mul_request(MUL_OP_MUL, 32'h80000000, 32'd2, 5'd19);
            wait_and_check(20);

            // -1 * -1
            $display("--- Test: -1 * -1 ---");
            send_mul_request(MUL_OP_MUL, 32'hFFFFFFFF, 32'hFFFFFFFF, 5'd20);
            wait_and_check(20);

            // 0x12345678 * 0x9ABCDEF0
            $display("--- Test:  0x12345678 * 0x9ABCDEF0 ---");
            send_mul_request(MUL_OP_MUL, 32'h12345678, 32'h9ABCDEF0, 5'd21);
            wait_and_check(20);
        end
    endtask

    // 流水线连续测试
    task test_pipeline;
        begin
            $display("\n========== Pipeline Continuous Tests ==========\n");

            // 连续发送多个请求（不等待结果）
            send_mul_request(MUL_OP_MUL, 32'd10, 32'd20, 5'd1);
            send_mul_request(MUL_OP_MUL, 32'd30, 32'd40, 5'd2);
            send_mul_request(MUL_OP_MUL, 32'd50, 32'd60, 5'd3);
            send_mul_request(MUL_OP_MULH, 32'h10000000, 32'h10000000, 5'd4);
            send_mul_request(MUL_OP_MULHU, 32'hF0000000, 32'hF0000000, 5'd5);
            send_mul_request(MUL_OP_MULHSU, 32'h80000000, 32'hF0000000, 5'd6);

            // 等待所有结果
            wait_and_check(50);
        end
    endtask

    // 随机测试
    task test_random;
        input integer num_tests;
        reg [31:0] rand_src1, rand_src2;
        reg     [1:0] rand_op;
        reg     [4:0] rand_rd;
        integer       i;
        begin
            $display("\n========== Random Tests (%0d iterations) ==========\n", num_tests);

            for (i = 0; i < num_tests; i = i + 1) begin
                rand_src1 = $random;
                rand_src2 = $random;
                rand_op   = $random % 4;
                rand_rd   = ($random % 31) + 1;

                send_mul_request(rand_op, rand_src1, rand_src2, rand_rd);

                // 每4个请求等待一次结果
                if ((i % 4) == 3) begin
                    wait_and_check(30);
                end
            end

            // 等待剩余结果
            wait_and_check(50);
        end
    endtask

    // 主测试流程
    initial begin
        // 初始化
        rst_n       = 0;
        mul_valid_i = 0;
        mul_op_i    = 0;
        mul_src1_i  = 0;
        mul_src2_i  = 0;
        mul_rd_i    = 0;
        flush_i     = 0;
        cancel_rd_i = 0;

        test_count  = 0;
        pass_count  = 0;
        fail_count  = 0;
        exp_head    = 0;
        exp_tail    = 0;

        // 复位
        repeat (5) @(posedge clk);
        rst_n = 1;
        repeat (5) @(posedge clk);

        $display("\n");
        $display("========================================================");
        $display("         MUL Module Testbench Started                   ");
        $display("========================================================");
        $display("\n");

        // 运行测试
        test_single_debug();
        test_basic();
        test_mulh();
        test_mulhu();
        test_mulhsu();
        test_boundary();
        test_pipeline();
        test_random(20);

        // 等待所有测试完成
        repeat (50) @(posedge clk);

        // 打印测试结果
        $display("\n");
        $display("========================================================");
        $display("                   Test Summary                         ");
        $display("========================================================");
        $display("  Total Tests:  %0d", test_count);
        $display("  Passed:       %0d", pass_count);
        $display("  Failed:        %0d", fail_count);
        $display("========================================================");
        if (fail_count == 0) $display("           *** ALL TESTS PASSED ***                    ");
        else $display("           *** SOME TESTS FAILED ***                   ");
        $display("========================================================");
        $display("\n");

        $finish;
    end

    // 超时保护
    initial begin
        #200000;
        $display("\n[ERROR] Simulation timeout!\n");
        $finish;
    end

    // 波形输出
    initial begin
        $dumpfile("tb_MUL.vcd");
        $dumpvars(0, tb_MUL);
    end

endmodule
