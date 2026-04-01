`timescale 1ns / 1ps
`include "../src/include/defines.svh"

`define REG_FILE u_CPU_TOP.u_registerf
`define CSR_FILE u_CPU_TOP.u_CSR

module tb_Verilator #(
    parameter int BPU_TYPE = 0
);

    logic        clk;
    logic        rst_n;

    logic [13:0] irom_addr;
    logic [31:0] irom_data;

    IROM #(
        .ADDR_WIDTH(14)
    ) u_IROM (
        .a  (irom_addr),
        .spo(irom_data)
    );

    CPU_TOP #(
        .BPU_TYPE(bpu_type_e'(BPU_TYPE))
    ) u_CPU_TOP (
        .clk  (clk),
        .rst_n(rst_n),
        .instr(irom_data),
        .pc   (irom_addr)
    );

    logic [1:0] priv_lvl;

    logic [31:0]
        x0,
        x1,
        x2,
        x3,
        x4,
        x5,
        x6,
        x7,
        x8,
        x9,
        x10,
        x11,
        x12,
        x13,
        x14,
        x15,
        x16,
        x17,
        x18,
        x19,
        x20,
        x21,
        x22,
        x23,
        x24,
        x25,
        x26,
        x27,
        x28,
        x29,
        x30,
        x31;

    logic  [31:0] mstatus;
    logic  [31:0] mstatush;
    logic  [31:0] mtvec;
    logic  [31:0] mepc;
    logic  [31:0] mcause;
    logic  [31:0] mscratch;
    logic  [31:0] mtval;
    logic  [31:0] mie;
    logic  [31:0] mip;
    logic  [31:0] misa;
    logic  [31:0] medeleg;
    logic  [31:0] mideleg;
    logic  [31:0] menvcfg;
    logic  [31:0] mseccfg;

    logic  [31:0] stvec;
    logic  [31:0] sepc;
    logic  [31:0] scause;
    logic  [31:0] sscratch;
    logic  [31:0] stval;
    logic  [31:0] satp;
    logic  [31:0] senvcfg;

    logic  [31:0] tohost_data;
    logic  [31:0] tohost_data_1000;
    logic  [31:0] tohost_data_2000;
    logic         tohost_1000_armed;
    logic         tohost_2000_armed;

    string        testcase;
    string        wavefile;

    localparam logic [31:0] PASS_MAGIC = 32'h0d000721;
    localparam logic [31:0] FAIL_MAGIC = 32'h01919810;
    localparam int unsigned TOHOST_WORD_ADDR_1000 = 32'h1000 >> 2;
    localparam int unsigned TOHOST_WORD_ADDR_2000 = 32'h2000 >> 2;

    always_comb begin
        priv_lvl         = u_CPU_TOP.current_priv_mode;

        x0               = `REG_FILE.rf_in[0];
        x1               = `REG_FILE.rf_in[1];
        x2               = `REG_FILE.rf_in[2];
        x3               = `REG_FILE.rf_in[3];
        x4               = `REG_FILE.rf_in[4];
        x5               = `REG_FILE.rf_in[5];
        x6               = `REG_FILE.rf_in[6];
        x7               = `REG_FILE.rf_in[7];
        x8               = `REG_FILE.rf_in[8];
        x9               = `REG_FILE.rf_in[9];
        x10              = `REG_FILE.rf_in[10];
        x11              = `REG_FILE.rf_in[11];
        x12              = `REG_FILE.rf_in[12];
        x13              = `REG_FILE.rf_in[13];
        x14              = `REG_FILE.rf_in[14];
        x15              = `REG_FILE.rf_in[15];
        x16              = `REG_FILE.rf_in[16];
        x17              = `REG_FILE.rf_in[17];
        x18              = `REG_FILE.rf_in[18];
        x19              = `REG_FILE.rf_in[19];
        x20              = `REG_FILE.rf_in[20];
        x21              = `REG_FILE.rf_in[21];
        x22              = `REG_FILE.rf_in[22];
        x23              = `REG_FILE.rf_in[23];
        x24              = `REG_FILE.rf_in[24];
        x25              = `REG_FILE.rf_in[25];
        x26              = `REG_FILE.rf_in[26];
        x27              = `REG_FILE.rf_in[27];
        x28              = `REG_FILE.rf_in[28];
        x29              = `REG_FILE.rf_in[29];
        x30              = `REG_FILE.rf_in[30];
        x31              = `REG_FILE.rf_in[31];

        mstatus          = `CSR_FILE.mstatus;
        mstatush         = `CSR_FILE.mstatush;
        mtvec            = `CSR_FILE.mtvec;
        mepc             = `CSR_FILE.mepc;
        mcause           = `CSR_FILE.mcause;
        mscratch         = `CSR_FILE.mscratch;
        mtval            = `CSR_FILE.mtval;
        mie              = `CSR_FILE.mie;
        mip              = `CSR_FILE.mip;
        misa             = `CSR_FILE.misa;
        medeleg          = `CSR_FILE.medeleg;
        mideleg          = `CSR_FILE.mideleg;
        menvcfg          = `CSR_FILE.menvcfg;
        mseccfg          = `CSR_FILE.mseccfg;

        stvec            = `CSR_FILE.stvec;
        sepc             = `CSR_FILE.sepc;
        scause           = `CSR_FILE.scause;
        sscratch         = `CSR_FILE.sscratch;
        stval            = `CSR_FILE.stval;
        satp             = `CSR_FILE.satp;
        senvcfg          = `CSR_FILE.senvcfg;

        tohost_data_1000 = u_CPU_TOP.u_DRAM.ram_data[TOHOST_WORD_ADDR_1000];
        tohost_data_2000 = u_CPU_TOP.u_DRAM.ram_data[TOHOST_WORD_ADDR_2000];
        if (tohost_1000_armed && tohost_data_1000 != 32'b0) begin
            tohost_data = tohost_data_1000;
        end else if (tohost_2000_armed && tohost_data_2000 != 32'b0) begin
            tohost_data = tohost_data_2000;
        end else begin
            tohost_data = 32'b0;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tohost_1000_armed <= 1'b0;
            tohost_2000_armed <= 1'b0;
        end else begin
            if (!tohost_1000_armed && tohost_data_1000 == 32'b0) begin
                tohost_1000_armed <= 1'b1;
            end
            if (!tohost_2000_armed && tohost_data_2000 == 32'b0) begin
                tohost_2000_armed <= 1'b1;
            end
        end
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        int dumpwave;

        if (!$value$plusargs("WAVEFILE=%s", wavefile)) begin
            wavefile = "prj/verilator/wave.vcd";
        end
        if ($value$plusargs("DUMPWAVE=%d", dumpwave) && dumpwave == 1) begin
            $dumpfile(wavefile);
            $dumpvars(0, tb_Verilator);
        end

        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    end

    initial begin
        if (!$value$plusargs("TESTCASE=%s", testcase)) begin
            testcase = "unknown";
        end
    end

    integer unsigned test_count;
    initial test_count = 0;

    always_ff @(posedge clk) begin
        if (x17 == PASS_MAGIC || x17 == FAIL_MAGIC) begin
            test_count <= test_count + 1;
        end
    end

    always_comb begin
        if (test_count == 3) begin
            case (x17)
                PASS_MAGIC: begin
                    $display("%10t| [INFO] |  Mispredict_counter = %0d", $time,
                             u_CPU_TOP.mispredict_counter);
                    $display("%10t| [PASS] |\t\t| %20s", $time, testcase);
                    $finish;
                end
                FAIL_MAGIC: begin
                    $display("%10t| [INFO] |  Mispredict_counter = %0d", $time,
                             u_CPU_TOP.mispredict_counter);
                    $display("%10t| [FAIL] |  No.%2d\t| %20s", $time, x10, testcase);
                    $finish;
                end
                default: begin
                end
            endcase
        end else if (rst_n && tohost_data != 32'b0) begin
            if (tohost_data == 32'd1) begin
                $display("%10t| [INFO] |  Mispredict_counter = %0d", $time,
                         u_CPU_TOP.mispredict_counter);
                $display("%10t| [PASS] |\t\t| %20s", $time, testcase);
                $finish;
            end else if (tohost_data[0]) begin
                $display("%10t| [INFO] |  Mispredict_counter = %0d", $time,
                         u_CPU_TOP.mispredict_counter);
                $display("%10t| [FAIL] |  No.%2d\t| %20s", $time, (tohost_data >> 1), testcase);
                $finish;
            end
        end
    end

    initial begin
        #1000000;
        $display("%10t| [INFO] |  Mispredict_counter = %0d", $time, u_CPU_TOP.mispredict_counter);
        $display("%10t| [EROR] |  TimeOut!  | %20s", $time, testcase);
        $finish;
    end

    logic        slow_clk;
    int unsigned count;

    initial begin
        slow_clk = 1'b0;
        count    = '0;
    end

    always_ff @(posedge clk) begin
        slow_clk <= ~slow_clk;
        count    <= count + 1;
    end

endmodule
