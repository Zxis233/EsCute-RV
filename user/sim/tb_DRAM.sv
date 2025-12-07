`timescale 1ns / 1ps
`include "../src/DRAM.sv"

module tb_DRAM;

    // 信号定义
    logic        clk;
    logic [13:0] a;
    logic [31:0] spo;
    logic        we;
    logic [31:0] din;

    // DUT 实例
    DRAM dut (
        .clk(clk),
        .a  (a),
        .spo(spo),
        .we (we),
        .din(din)
    );

    // 时钟产生：10ns 周期
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // 写任务：在 posedge clk 写入
    task automatic dram_write(input logic [13:0] addr, input logic [31:0] data);
        begin
            // 在时钟低电平阶段准备好地址和数据
            @(negedge clk);
            a   = addr;
            din = data;
            we  = 1'b1;

            // 在下一个上升沿写入
            @(posedge clk);

            // 写完拉低 we
            @(negedge clk);
            we = 1'b0;
        end
    endtask

    // 读并检查任务：读 addr，期望数据为 exp
    task automatic dram_read_check(input logic [13:0] addr, input logic [31:0] exp,
                                   input string msg = "");
        begin
            // 读是组合逻辑，这里只需要给地址，稍微等一下
            a   = addr;
            we  = 1'b0;
            din = 'z;  // 读的时候 d 无意义

            #1;  // 等一个很小的时间，给组合逻辑稳定

            assert (spo === exp)
            else
                $error(
                    "[DRAM READ ERROR] %s addr=0x%04h exp=0x%08h got=0x%08h", msg, addr, exp, spo
                );

            $display("[DRAM READ OK] %s addr=0x%04h data=0x%08h", msg, addr, spo);
        end
    endtask

    initial begin
        // 波形输出
`ifdef VCD_FILEPATH
        $dumpfile(`VCD_FILEPATH);
`else
        $dumpfile("wave.vcd");
`endif
        $dumpvars(0, tb_DRAM);

        // 初始值
        clk = 1'b0;
        we  = 1'b0;
        a   = '0;
        din = '0;

        // 等一小段时间“上电稳定”
        #20;

        //========================================================
        // 1. 基本写读测试
        //========================================================
        dram_write(14'h0000, 32'hDEAD_BEEF);
        dram_write(14'h0001, 32'hCAFE_BABE);
        dram_write(14'h3FFF, 32'h1234_5678);  // 最高地址

        dram_read_check(14'h0000, 32'hDEAD_BEEF, "basic");
        dram_read_check(14'h0001, 32'hCAFE_BABE, "basic");
        dram_read_check(14'h3FFF, 32'h1234_5678, "basic");

        //========================================================
        // 2. 写同一地址覆盖测试
        //========================================================
        dram_write(14'h0001, 32'hA5A5_5A5A);
        dram_read_check(14'h0001, 32'hA5A5_5A5A, "overwrite");

        //========================================================
        // 3. we=0 时不应该写入测试
        //    尝试在 we=0 的情况下“写”入新值，看是否仍保持旧值
        //========================================================
        @(negedge clk);
        a   = 14'h0001;
        din = 32'hFFFF_FFFF;
        we  = 1'b0;
        @(posedge clk);
        #1;

        dram_read_check(14'h0001, 32'hA5A5_5A5A, "no_write_when_we_0");

        //========================================================
        // 测试结束
        //========================================================
        $display("==== DRAM testbench finished ====");
        $finish;
    end

endmodule
