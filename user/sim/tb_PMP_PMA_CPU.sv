`timescale 1ns / 1ps

`include "../src/CPU_TOP.sv"

module tb_PMP_PMA_CPU;

    logic        clk;
    logic        rst_n;
    logic [13:0] pc_addr;
    logic [31:0] instr_data;
    logic [31:0] rom[0:7];

    CPU_TOP u_CPU_TOP (
        .clk  (clk),
        .rst_n(rst_n),
        .instr(instr_data),
        .pc   (pc_addr)
    );

    assign instr_data = rom[pc_addr[2:0]];

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        for (int i = 0; i < 8; i++) begin
            rom[i] = 32'h0000_0013;  // nop
        end
        rom[0] = 32'h0001_00b7;  // lui x1, 0x10 -> x1 = 0x00010000
        rom[1] = 32'h0000_8067;  // jalr x0, 0(x1)

        rst_n = 1'b0;
        repeat (3) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;
    end

    initial begin
        repeat (80) begin
            @(posedge clk);
            if (rst_n && u_CPU_TOP.exception_valid) begin
                if (u_CPU_TOP.exception_cause !== `EXC_INST_ACCESS_FAULT) begin
                    $error("Expected instruction access fault, got cause=%h",
                           u_CPU_TOP.exception_cause);
                    $finish;
                end
                if (u_CPU_TOP.exception_tval !== 32'h0001_0000) begin
                    $error("Expected mtval=0x00010000, got %h", u_CPU_TOP.exception_tval);
                    $finish;
                end
                $display("[PASS] tb_PMP_PMA_CPU");
                $finish;
            end
        end
        $error("Timed out waiting for instruction access fault");
        $finish;
    end

endmodule
