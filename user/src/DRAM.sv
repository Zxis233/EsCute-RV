// DRAM 行为模型 - 用于仿真
// 替代 Xilinx IP 核
module DRAM #(
    parameter int unsigned ADDR_WIDTH = 16
) (
    input  logic                  clk,  // 时钟
    input  logic [ADDR_WIDTH-1:0] a,    // 地址输入
    output logic [          31:0] spo,  // 数据输出
    input  logic [           3:0] we,   // 按位写使能
    input  logic [          31:0] din   // 数据输入
);

    logic [31:0] ram_data[1 << ADDR_WIDTH];

    // 初始化
    initial begin
        integer i;
        string  testcase;

        // 初始化所有内存为0
        for (i = 0; i < 1 << ADDR_WIDTH; i = i + 1) begin
            ram_data[i] = 32'h00000000;
        end

        // 如果有testcase参数，从hex文件加载数据段
        // hex文件是完整的内存镜像，按字地址索引
        // 数据段从0x2000开始，即hex文件的第0x800行(2048)
        if ($value$plusargs("TESTCASE=%s", testcase)) begin
            // 读取整个hex文件到DRAM
            // SystemVerilog的$readmemh会自动处理地址映射
            // 但是最好还是手动指定范围以防万一
            $readmemh(testcase, ram_data);
            $display("DRAM: Loaded memory image from %s", testcase);
        end
    end

    // 同步写
    always_ff @(posedge clk) begin
        if (we != 4'b0000) begin
            // 按位写使能
            // 这里禁止使用case-true 会只匹配第一个结果
            // [HACK] 将合并输入数据放到LoadStoreUnit模块中处理
            if (we[0]) ram_data[a][7:0] <= din[7:0];
            if (we[1]) ram_data[a][15:8] <= din[15:8];
            if (we[2]) ram_data[a][23:16] <= din[23:16];
            if (we[3]) ram_data[a][31:24] <= din[31:24];
        end
        spo <= ram_data[a];  // 同步读
    end

    // `ifdef DEBUG
    //     logic [31:0] ram_data_debug_24, ram_data_debug_28, ram_data_debug_32;
    //     always_comb begin
    //         ram_data_debug_24 = ram_data[16'd24][31:0];
    //         ram_data_debug_28 = ram_data[16'd28][31:0];
    //         ram_data_debug_32 = ram_data[16'd32][31:0];
    //     end
    // `endif
endmodule
