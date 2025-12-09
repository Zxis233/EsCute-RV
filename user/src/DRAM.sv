`timescale 1ns / 1ps

// DRAM 行为模型 - 用于仿真
// 替代 Xilinx IP 核
module DRAM (
    input  logic        clk,  // 时钟
    input  logic [15:0] a,    // 地址输入 (16位 = 64K words)
    output logic [31:0] spo,  // 数据输出
    input  logic [ 3:0] we,   // 按位写使能
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
    end

    // [FIXME] 在添加对LB/LH等非对齐访问支持后时序错误
    // 因第一条 LB 用的是前一拍的 DRAM 数据
    // 后面使用的是正确数据
    // [HACK] 解决方法1 DRAM 打两拍
    // 极为困难 因未采取ready-valid 握手 每级流水线只能打单拍
    // 只能在 LoadStoreUnit 里做数据对齐处理
    // [HACK] 解决方法2 实现 新的前向旁路 但可能情况极为复杂

    // 写操作 (同步) - 支持按位写使能
    always_ff @(posedge clk) begin
        if (we != 4'b0000) begin
            // 按位写使能
            // 这里禁止使用case-true 会只匹配第一个结果
            // [HACK] 将合并输入数据放到LoadStoreUnit模块中处理
            if (we[0]) ram_data[a][7:0] <= din[7:0];
            if (we[1]) ram_data[a][15:8] <= din[15:8];
            if (we[2]) ram_data[a][23:16] <= din[23:16];
            if (we[3]) ram_data[a][31:24] <= din[31:24];
            $display("%0t\t| 0x%4h <| 0x%h (we=%b)\t|[MEM W]", $time, a, din, we);
        end else begin
            $display("%0t\t| 0x%4h |> 0x%h\t|[MEM R]", $time, a, ram_data[a]);
        end
        spo <= ram_data[a];  // 同步读
    end

`ifdef DEBUG
    logic [31:0] ram_data_debug_24, ram_data_debug_28, ram_data_debug_32;
    always_comb begin
        ram_data_debug_24 = ram_data[16'd24][31:0];  // 仅
        ram_data_debug_28 = ram_data[16'd28][31:0];  // 仅供调试观察
        ram_data_debug_32 = ram_data[16'd32][31:0];  // 仅供调试观察
    end
`endif
endmodule
