`timescale 1ns / 1ps
`include "../src/RegisterF.sv"

module tb_RegisterF;

    // 时钟 / 复位
    logic              clk;
    logic              rst_n;

    // DUT 接口
    logic              rf_we;
    logic   [     4:0] rR1;
    logic   [     4:0] rR2;
    logic   [     4:0] wR;
    logic   [31:0] wD;
    logic   [31:0] rD1;
    logic   [31:0] rD2;

    // 黄金寄存器堆
    logic   [31:0] golden_rf[32];

    // 标记某个寄存器是否“写过”（x0 永远不会被标记为写过）
    logic              written  [32];

    integer            i;
    integer waddr, wdata, raddr1, raddr2;

    // ========= 例化被测模块 =========
    RegisterF dut (
        .clk  (clk),
        .rst_n(rst_n),
        .rf_we(rf_we),
        .rR1  (rR1),
        .rR2  (rR2),
        .wR   (wR),
        .wD   (wD),
        .rD1  (rD1),    // 如名字不同，改这里
        .rD2  (rD2)
    );

    // ========= 时钟 =========
    initial clk = 1'b0;
    always #5 clk = ~clk;  // 10ns 周期

    // ========= 写任务：同时更新 golden & written =========
    task automatic do_write;
        input [4:0] addr;
        input [31:0] data;
        begin
            @(negedge clk);
            rf_we = 1'b1;
            wR    = addr;
            wD    = data;

            @(negedge clk);
            rf_we = 1'b0;
            wR    = 5'd0;
            wD    = {32{1'b0}};

            // x0 应始终为 0，不算“写过”
            if (addr != 5'd0) begin
                golden_rf[addr] = data;
                written[addr]   = 1'b1;
            end else begin
                golden_rf[0] = {32{1'b0}};
                // written[0] 依然保持 0
            end
        end
    endtask

    // ========= 读+检查任务 =========
    task automatic check_read;
        input [4:0] addr1;
        input [4:0] addr2;
        input [79:0] tag;  // 当作字符串用
        logic [31:0] exp1, exp2;
        logic pass;
        begin
            exp1 = golden_rf[addr1];
            exp2 = golden_rf[addr2];

            @(negedge clk);
            rR1 = addr1;
            rR2 = addr2;

            #1;  // 等组合逻辑稳定

            pass = ((exp1 === rD1) && (exp2 === rD2));

            $display("%6t | %s | rR1=%2d exp1=%08h act1=%08h | rR2=%2d exp2=%08h act2=%08h | %s",
                     $time, tag, addr1, exp1, rD1, addr2, exp2, rD2, pass ? "PASS" : "FAIL");

            if (!pass) $display("ERROR: mismatch on %s", tag);
        end
    endtask

    // ========= 打印表头 =========
    initial begin
        $display(
            " time   |    tag     |         读口1                      |        读口2                       | result"
                );
        $display(
            "-------+------------+------------------------------------+------------------------------------+--------"
                );
    end

    // ========= 主激励 =========
    // integer rand_seed = 32'h0d000721;
    integer rand_seed = 32'h11451400;

    initial begin
        // 初始化黄金寄存器堆 & written 标记
        for (i = 0; i < 32; i = i + 1) begin
            golden_rf[i] = {32{1'b0}};
            written[i]   = 1'b0;
        end

        // 初值
        rf_we = 1'b0;
        rR1   = 5'd0;
        rR2   = 5'd0;
        wR    = 5'd0;
        wD    = {32{1'b0}};
        rst_n = 1'b0;

        // 复位两拍
        @(negedge clk);
        @(negedge clk);
        rst_n = 1'b1;
        @(negedge clk);

        // 手动写几组（也会把 written[...] 置 1）
        do_write(5'd1, 32'h1111_1111);
        do_write(5'd2, 32'h2222_2222);
        do_write(5'd3, 32'h3333_3333);
        do_write(5'd4, 32'h4444_4444);
        do_write(5'd7, 32'h0d00_0721);
        do_write(5'd0, 32'hFFFF_FFFF);  // 应该被忽略，x0 不算写过

        // 手动读几组（这里可以随便读）
        check_read(5'd1, 5'd2, "TEST1");
        check_read(5'd3, 5'd0, "TEST2");
        check_read(5'd2, 5'd2, "TEST3");
        check_read(5'd0, 5'd1, "TEST4");
        check_read(5'd7, 5'd4, "TEST5");
        check_read(5'd2, 5'd3, "TEST6");
        check_read(5'd1, 5'd5, "TEST7");

        // ========= 随机测试：只读“已经写过”的寄存器 =========
        repeat (20) begin
            // 随机写一个地址
            waddr = $urandom(rand_seed) % 32;
            if (waddr < 0) waddr = -waddr;
            wdata = $urandom(rand_seed);

            do_write(waddr[4:0], wdata[31:0]);

            // 选一个“写过”的地址做 raddr1
            raddr1 = $urandom(rand_seed) % 32;
            if (raddr1 < 0) raddr1 = -raddr1;
            while (!written[raddr1]) begin
                raddr1 = (raddr1 + 1) % 32;
            end

            // 再选一个“写过”的地址做 raddr2
            raddr2 = $urandom(rand_seed) % 32;
            if (raddr2 < 0) raddr2 = -raddr2;
            while (!written[raddr2]) begin
                raddr2 = (raddr2 + 1) % 32;
            end

            check_read(raddr1[4:0], raddr2[4:0], "RANDOM");
        end

        $display("======= 所有测试结束 =======");
        $finish;
    end

endmodule
