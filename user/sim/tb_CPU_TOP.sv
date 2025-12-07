`timescale 1ns / 1ps

`include "../src/CPU_TOP.sv"
`define DEBUG 

`define REG_FILE u_CPU_TOP.u_registerf

module tb_CPU_TOP;

    // 时钟和复位信号
    logic        clk;
    logic        rst_n;

    // IROM 信号
    logic [13:0] irom_addr;
    logic [31:0] irom_data;

    // 实例化 IROM (指令存储器)
    IROM u_IROM (
        .a  (irom_addr),
        .spo(irom_data)
    );

    // 实例化 CPU_TOP
    CPU_TOP u_CPU_TOP (
        .clk  (clk),
        .rst_n(rst_n),
        .instr(irom_data),
        .pc   (irom_addr)
    );

    // verilog_format: off
// 寄存器堆监控信号
    logic [31:0] x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15,
                  x16, x17, x18, x19, x20, x21, x22, x23, x24, x25, x26, x27, x28, x29,
                  x30, x31;

    always_comb begin
        x0  = `REG_FILE.rf_in[0];
        x1  = `REG_FILE.rf_in[1];
        x2  = `REG_FILE.rf_in[2];
        x3  = `REG_FILE.rf_in[3];
        x4  = `REG_FILE.rf_in[4];
        x5  = `REG_FILE.rf_in[5];
        x6  = `REG_FILE.rf_in[6];
        x7  = `REG_FILE.rf_in[7];
        x8  = `REG_FILE.rf_in[8];
        x9  = `REG_FILE.rf_in[9];
        x10 = `REG_FILE.rf_in[10];
        x11 = `REG_FILE.rf_in[11];
        x12 = `REG_FILE.rf_in[12];
        x13 = `REG_FILE.rf_in[13];
        x14 = `REG_FILE.rf_in[14];
        x15 = `REG_FILE.rf_in[15];
        x16 = `REG_FILE.rf_in[16];
        x17 = `REG_FILE.rf_in[17];
        x18 = `REG_FILE.rf_in[18];
        x19 = `REG_FILE.rf_in[19];
        x20 = `REG_FILE.rf_in[20];
        x21 = `REG_FILE.rf_in[21];
        x22 = `REG_FILE.rf_in[22];
        x23 = `REG_FILE.rf_in[23];
        x24 = `REG_FILE.rf_in[24];
        x25 = `REG_FILE.rf_in[25];
        x26 = `REG_FILE.rf_in[26];
        x27 = `REG_FILE.rf_in[27];
        x28 = `REG_FILE.rf_in[28];
        x29 = `REG_FILE.rf_in[29];
        x30 = `REG_FILE.rf_in[30];
        x31 = `REG_FILE.rf_in[31];
    end

    // verilog_format: on

    // 时钟生成 (100MHz, 周期 10ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // 复位和测试控制
    initial begin
        // 波形文件设置
`ifdef VCD_FILEPATH
        $dumpfile(`VCD_FILEPATH);
`else
        $dumpfile("wave.vcd");
`endif
        $dumpvars;

        // 初始化信号
        rst_n = 0;

        // 复位 CPU
        #5;  // 保持复位 25ns
        rst_n = 1;
        $display("========================================");
        $display("CPU Reset Released at time %0t", $time);
        $display("========================================");

        // 运行一段时间让 CPU 执行指令
        #2000;

        $display("========================================");
        $display("Simulation finished at time %0t", $time);
        $display("========================================");

        // 打印寄存器堆状态
        print_register_file();

        $finish;
    end

    // 监控关键信号
    initial begin
        $display("========================================");
        $display("Time\t| PC\t| Instruction\t| Stage");
        $display("========================================");

        forever begin
            @(posedge clk);
            if (rst_n) begin
                // IF 级
                if (u_CPU_TOP.valid_IF)
                    $display("%0t\t| %h\t| %h\t| IF", $time, u_CPU_TOP.pc_IF, u_CPU_TOP.instr_IF);

                // ID 级
                if (u_CPU_TOP.valid_ID && u_CPU_TOP.instr_ID != 32'h00000013)  // 跳过 NOP
                    $display("%0t\t| %h\t| %h\t| ID", $time, u_CPU_TOP.pc_ID, u_CPU_TOP.instr_ID);

                // EX 级
                if (u_CPU_TOP.valid_EX)
                    $display(
                        "%0t\t| %h\t| --------\t| EX (ALU=%h)",
                        $time,
                        u_CPU_TOP.pc_EX,
                        u_CPU_TOP.alu_result_EX
                    );
            end
        end
    end

    // 监控寄存器写回操作
    initial begin
        forever begin
            @(posedge clk);
            if (rst_n && u_CPU_TOP.rf_we_WB && u_CPU_TOP.wR_WB != 0) begin
                $display("%0t\t|  x%-2d   <= 0x%h \t|[WB]", $time, u_CPU_TOP.wR_WB,
                         u_CPU_TOP.rf_wd_WB);
            end
        end
    end

    // 打印寄存器堆内容的任务
    task automatic print_register_file();
        integer i;
        begin
            $display("\n========================================");
            $display("Register File Contents:");
            $display("========================================");
            for (i = 0; i < 32; i = i + 1) begin
                if (u_CPU_TOP.u_registerf.rf_in[i] != 0) begin
                    $display("x%0d\t= 0x%h\t(%0d)", i, u_CPU_TOP.u_registerf.rf_in[i],
                             $signed(u_CPU_TOP.u_registerf.rf_in[i]));
                end
            end
            $display("========================================\n");
        end
    endtask

    // 超时保护
    initial begin
        #5000;  // 50us 超时
        $display("ERROR: Simulation timeout!");
        $finish;
    end

    // 新建一个时钟 为clk的两倍周期 便于观察
    logic        slow_clk;
    int unsigned count;
    initial slow_clk = 0;

    always_ff @(posedge clk) begin
        slow_clk <= ~slow_clk;
        count    <= count + 1;
    end


endmodule
