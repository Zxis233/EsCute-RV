`timescale 1ns / 1ps

// DRAM 行为模型 - 用于仿真
// 替代 Xilinx IP 核
// [HACK] Vivado无法综合异步读的RAM
module DRAM (
    input  logic        clk,  // 时钟
    input  logic [15:0] a,    // 地址输入 (16位 = 64K words)
    output logic [31:0] spo,  // 数据输出
    input  logic        we,   // 写使能
    input  logic [31:0] din   // 数据输入
);

    // 数据存储器 - 16K x 32bit
    reg [31:0] ram_data[65536];

    // 初始化
    initial begin
        integer             i;
        reg     [256*8-1:0] ram_file;  // 字符串缓冲区

        for (i = 0; i < 65536; i = i + 1) begin
            ram_data[i] = 32'h00000000;
        end

        // 可选: 从文件加载初始数据
        // if ($value$plusargs("DRAM=%s", ram_file)) begin
        //     $readmemh(ram_file, ram_data);
        //     $display("DRAM: Loaded data from %s", ram_file);
        // end
    end

    // 写操作 (同步)
    always_ff @(posedge clk) begin
        if (we) begin
            ram_data[a] <= din;
            $display("%0t\t| 0x%4h <| 0x%h\t|[MEM W]", $time, a, din);
        end
        spo <= ram_data[a];  // [FIXME] 同步读
        if (!we) begin
            $display("%0t\t| 0x%4h |> 0x%h\t|[MEM R]", $time, a, ram_data[a]);
        end
    end

endmodule
