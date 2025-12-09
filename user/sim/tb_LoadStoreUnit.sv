`include "../src/LoadStoreUnit.sv"

// Note: When compiling from user/src directory, LoadStoreUnit.sv is in current dir
// When using iverilog: cd user/src && iverilog -I ./include ../sim/tb_LoadStoreUnit.sv
module tb_LoadStoreUnit ();
    // 测试信号
    logic [ 3:0] sl_type;
    logic [31:0] addr;
    logic [31:0] store_data_i;
    logic [31:0] load_data_i;
    logic [31:0] load_data_o;
    logic [31:0] store_data_o;
    logic        dram_we;
    logic [ 3:0] wstrb;
    logic [31:0] expected;  // For test verification

    // 实例化被测模块
    LoadStoreUnit uut (
        .sl_type     (sl_type),
        .addr        (addr),
        .load_data_i (load_data_i),
        .load_data_o (load_data_o),
        .store_data_i(store_data_i),
        .store_data_o(store_data_o),
        .dram_we     (dram_we),
        .wstrb       (wstrb)
    );

    // 测试任务：检查结果
    task automatic check_result(input [31:0] exp);
        begin
            #1;
            if (load_data_o !== exp) begin
                $display("[FAIL] Time=%0t, sl_type=%b, addr=%h, load_data_i=%h", $time, sl_type,
                         addr, load_data_i);
                $display("       Expected: %h, Got: %h", exp, load_data_o);
                $stop;
            end else begin
                $display("[PASS] Time=%0t, sl_type=%b, addr=%h, load_data_i=%h, load_data_o=%h",
                         $time, sl_type, addr, load_data_i, load_data_o);
            end
        end
    endtask

    // 测试流程
    initial begin
        $display("========================================");
        $display("LoadStoreUnit Testbench Start");
        $display("========================================\n");

        // 初始化信号
        sl_type      = `MEM_NOP;
        addr         = 32'h0;
        load_data_i  = 32'h0;
        store_data_i = 32'h0;
        dram_we      = 1'b0;
        #10;

        // ====================================
        // 测试 LB (Load Byte - 符号扩展)
        // ====================================
        $display("--- Testing LB (Load Byte) ---");

        // 测试用例1: LB - 地址对齐到 byte 0, 正数
        sl_type     = `MEM_LB;
        addr        = 32'h0000_0000;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_0012;  // 符号扩展 0x12
        #10;
        check_result(expected);

        // 测试用例2: LB - 地址对齐到 byte 1, 负数
        sl_type     = `MEM_LB;
        addr        = 32'h0000_0001;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'hFFFF_FFCD;  // 符号扩展 0xCD
        #10;
        check_result(expected);

        // 测试用例3: LB - 地址对齐到 byte 2, 负数
        sl_type     = `MEM_LB;
        addr        = 32'h0000_0002;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'hFFFF_FFAB;  // 符号扩展 0xAB
        #10;
        check_result(expected);

        // 测试用例4: LB - 地址对齐到 byte 3, 负数
        sl_type     = `MEM_LB;
        addr        = 32'h0000_0003;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'hFFFF_FF89;  // 符号扩展 0x89
        #10;
        check_result(expected);

        // ====================================
        // 测试 LBU (Load Byte Unsigned - 零扩展)
        // ====================================
        $display("\n--- Testing LBU (Load Byte Unsigned) ---");

        // 测试用例5: LBU - 地址对齐到 byte 0
        sl_type     = `MEM_LBU;
        addr        = 32'h0000_0000;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_0012;  // 零扩展
        #10;
        check_result(expected);

        // 测试用例6: LBU - 地址对齐到 byte 1
        sl_type     = `MEM_LBU;
        addr        = 32'h0000_0001;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_00CD;  // 零扩展
        #10;
        check_result(expected);

        // 测试用例7: LBU - 地址对齐到 byte 2
        sl_type     = `MEM_LBU;
        addr        = 32'h0000_0002;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_00AB;  // 零扩展
        #10;
        check_result(expected);

        // 测试用例8: LBU - 地址对齐到 byte 3
        sl_type     = `MEM_LBU;
        addr        = 32'h0000_0003;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_0089;  // 零扩展
        #10;
        check_result(expected);

        // ====================================
        // 测试 LH (Load Halfword - 符号扩展)
        // ====================================
        $display("\n--- Testing LH (Load Halfword) ---");

        // 测试用例9: LH - 地址对齐到 halfword 0, 正数
        sl_type     = `MEM_LH;
        addr        = 32'h0000_0000;
        load_data_i = 32'h89AB_7D12;
        dram_we     = 1'b0;
        expected    = 32'h0000_7D12;  // 符号扩展 0x7D12
        #10;
        check_result(expected);

        // 测试用例10: LH - 地址对齐到 halfword 1, 负数
        sl_type     = `MEM_LH;
        addr        = 32'h0000_0002;
        load_data_i = 32'h89AB_7D12;
        dram_we     = 1'b0;
        expected    = 32'hFFFF_89AB;  // 符号扩展 0x89AB
        #10;
        check_result(expected);

        // ====================================
        // 测试 LHU (Load Halfword Unsigned - 零扩展)
        // ====================================
        $display("\n--- Testing LHU (Load Halfword Unsigned) ---");

        // 测试用例11: LHU - 地址对齐到 halfword 0
        sl_type     = `MEM_LHU;
        addr        = 32'h0000_0000;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_CD12;  // 零扩展
        #10;
        check_result(expected);

        // 测试用例12: LHU - 地址对齐到 halfword 1
        sl_type     = `MEM_LHU;
        addr        = 32'h0000_0002;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h0000_89AB;  // 零扩展
        #10;
        check_result(expected);

        // ====================================
        // 测试 LW (Load Word)
        // ====================================
        $display("\n--- Testing LW (Load Word) ---");

        // 测试用例13: LW - 加载整个字
        sl_type     = `MEM_LW;
        addr        = 32'h0000_0000;
        load_data_i = 32'h89AB_CD12;
        dram_we     = 1'b0;
        expected    = 32'h89AB_CD12;
        #10;
        check_result(expected);

        // 测试用例14: LW - 另一个测试值
        sl_type     = `MEM_LW;
        addr        = 32'h0000_0004;
        load_data_i = 32'hDEAD_BEEF;
        dram_we     = 1'b0;
        expected    = 32'hDEAD_BEEF;
        #10;
        check_result(expected);

        // ====================================
        // 测试 Store 指令 (SB, SH, SW)
        // ====================================
        $display("\n--- Testing Store Instructions ---");

        // 测试用例15: SB - Store Byte at offset 0
        sl_type      = `MEM_SB;
        addr         = 32'h0000_0000;
        store_data_i = 32'h1234_5678;
        dram_we      = 1'b1;
        #10;
        if (store_data_o !== 32'h0000_0078 || wstrb !== 4'b0001) begin
            $display("[FAIL] SB test at offset 0: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
            $stop;
        end else begin
            $display("[PASS] SB test at offset 0: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
        end

        // 测试用例16: SB - Store Byte at offset 1
        sl_type      = `MEM_SB;
        addr         = 32'h0000_0001;
        store_data_i = 32'h1234_5678;
        dram_we      = 1'b1;
        #10;
        if (store_data_o !== 32'h0000_7800 || wstrb !== 4'b0010) begin
            $display("[FAIL] SB test at offset 1: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
            $stop;
        end else begin
            $display("[PASS] SB test at offset 1: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
        end

        // 测试用例17: SH - Store Halfword at offset 0
        sl_type      = `MEM_SH;
        addr         = 32'h0000_0000;
        store_data_i = 32'hABCD_EF01;
        dram_we      = 1'b1;
        #10;
        if (store_data_o !== 32'h0000_EF01 || wstrb !== 4'b0011) begin
            $display("[FAIL] SH test at offset 0: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
            $stop;
        end else begin
            $display("[PASS] SH test at offset 0: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
        end

        // 测试用例18: SH - Store Halfword at offset 2
        sl_type      = `MEM_SH;
        addr         = 32'h0000_0002;
        store_data_i = 32'hABCD_EF01;
        dram_we      = 1'b1;
        #10;
        if (store_data_o !== 32'hEF01_0000 || wstrb !== 4'b1100) begin
            $display("[FAIL] SH test at offset 2: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
            $stop;
        end else begin
            $display("[PASS] SH test at offset 2: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
        end

        // 测试用例19: SW - Store Word
        sl_type      = `MEM_SW;
        addr         = 32'h0000_0000;
        store_data_i = 32'hFEDC_BA98;
        dram_we      = 1'b1;
        #10;
        if (store_data_o !== 32'hFEDC_BA98 || wstrb !== 4'b1111) begin
            $display("[FAIL] SW test: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
            $stop;
        end else begin
            $display("[PASS] SW test: store_data_o=%h, wstrb=%b", store_data_o, wstrb);
        end

        // ====================================
        // 测试 MEM_NOP
        // ====================================
        $display("\n--- Testing MEM_NOP ---");

        // 测试用例20: MEM_NOP
        sl_type     = `MEM_NOP;
        addr        = 32'h0000_0000;
        load_data_i = 32'hFFFF_FFFF;
        dram_we     = 1'b0;
        expected    = 32'h0000_0000;
        #10;
        check_result(expected);

        // ====================================
        // 边界测试
        // ====================================
        $display("\n--- Testing Edge Cases ---");

        // 测试用例21: LB 最大负数
        sl_type     = `MEM_LB;
        addr        = 32'h0000_0000;
        load_data_i = 32'h0000_0080;
        dram_we     = 1'b0;
        expected    = 32'hFFFF_FF80;
        #10;
        check_result(expected);

        // 测试用例22: LB 最大正数
        sl_type     = `MEM_LB;
        addr        = 32'h0000_0000;
        load_data_i = 32'h0000_007F;
        dram_we     = 1'b0;
        expected    = 32'h0000_007F;
        #10;
        check_result(expected);

        // 测试用例23: LH 最大负数
        sl_type     = `MEM_LH;
        addr        = 32'h0000_0000;
        load_data_i = 32'h0000_8000;
        dram_we     = 1'b0;
        expected    = 32'hFFFF_8000;
        #10;
        check_result(expected);

        // 测试用例24: LH 最大正数
        sl_type     = `MEM_LH;
        addr        = 32'h0000_0000;
        load_data_i = 32'h0000_7FFF;
        dram_we     = 1'b0;
        expected    = 32'h0000_7FFF;
        #10;
        check_result(expected);

        // 测试完成
        $display("\n========================================");
        $display("All Tests Passed!");
        $display("========================================");
        $finish;
    end

endmodule
