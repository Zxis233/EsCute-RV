`timescale 1ns / 1ps

// IROM 行为模型 - 用于仿真
// 替代 Xilinx IP 核

module IROM (
    input  logic [13:0] a,   // 地址输入 (14位 = 16K words)
    output logic [31:0] spo  // 数据输出
);

    // 指令存储器 - 16K x 32bit
    logic [31:0] rom_data[16384];

`ifdef YOSYS
    logic [255:0] rom_file;  // 字符串缓冲区
`else
    string rom_file;  // 字符串缓冲区
`endif

    // 从文件加载指令
    initial begin

        integer i;

        for (i = 0; i < 16384; i = i + 1) begin
            // rom_data[i] = 32'h00000013;  // NOP
            rom_data[i] = 32'h0d000721;
        end

        // verilog_format: off
`ifdef YOSYS
        `define IROM_FILE \
        "user/data/hex/full_test.hex"
        // "user/data/hex/jalr.hex"
        // "user/data/hex/U.hex"
        // "user/data/hex/simple_test.hex"

        // "user/data/hex/branch.hex"
        // "user/data/hex/myFirstTest.hex"
        // "user/data/hex/no_hazard.hex"
        // "user/data/hex/loaduse_test.hex"
        // "user/data/hex/hazard12.hex"
        // 尝试从文件加载指令
        // if ($value$plusargs("IROM=%s", rom_file)) begin
        if (1) begin
            $readmemh(`IROM_FILE, rom_data, 0, 16383);
            $display("IROM: Loaded instructions from %s", `IROM_FILE);
        end else begin
            // 如果没有指定文件,加载默认的测试程序
            $display("IROM: Loading default test program");
            load_default_program();
        end
`else
        if (1) begin
            rom_file =
            // "user/data/hex/jalr.hex"
            "user/data/hex/full_test.hex"
            // "user/data/hex/full_test_rv.hex"
            // "user/data/hex/full_test_label.hex"
            // "user/data/hex/sw_lw.hex"
            // "user/data/hex/sw.hex"
            // "user/data/hex/U.hex"
            // "user/data/hex/simple_test.hex"

            // "user/data/hex/branch.hex"
            // "user/data/hex/myFirstTest.hex"
            // "user/data/hex/no_hazard.hex"
            // "user/data/hex/loaduse_test.hex"
            // "user/data/hex/hazard.hex"
            // "user/data/hex/hazard_full.hex"
            ;
            $readmemh(rom_file, rom_data, 0, 16383);
            $display("IROM: Loaded instructions from %s", rom_file);
        end else begin
            // 如果没有指定文件,加载默认的测试程序
            $display("IROM: Loading default test program");
            load_default_program();
        end
`endif

    end

    // 读取数据 (组合逻辑)

    always_comb begin
        spo = rom_data[a];
    end


    // 加载默认测试程序
    task automatic load_default_program;
        begin
            // 更复杂的测试程序 - 测试算术、逻辑、移位指令和数据冒险
            $display("IROM: Default test program loaded");
            rom_data[0] = 32'h00500093;  // addi x1, x0, 5      x1 = 5
            rom_data[1] = 32'h00300113;  // addi x2, x0, 3      x2 = 3
            rom_data[2] = 32'h002081b3;  // add  x3, x1, x2     x3 = x1 + x2 = 8
            rom_data[3] = 32'h40208233;  // sub  x4, x1, x2     x4 = x1 - x2 = 2
            rom_data[4] = 32'h0020f2b3;  // and  x5, x1, x2     x5 = x1 & x2 = 1
            rom_data[5] = 32'h0020e333;  // or   x6, x1, x2     x6 = x1 | x2 = 7
            rom_data[6] = 32'h002093b3;  // sll  x7, x1, x2     x7 = x1 << x2 = 40
            rom_data[7] = 32'h0020c433;  // xor  x8, x1, x2     x8 = x1 ^ x2 = 6
        end
    endtask

endmodule
