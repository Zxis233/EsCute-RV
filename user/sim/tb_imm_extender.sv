//~ `New testbench
`timescale 1ns / 1ps
`include "../src/imm_extender.sv"

module tb_imm_extender;

    // imm_extender Parameters
    parameter PERIOD = 10;


    // imm_extender Inputs
    logic [31:0] instr = 0;

    // imm_extender Outputs
    logic [31:0] imm_out;
    logic        clk = 0;

    initial begin
        forever #(PERIOD / 2) clk = ~clk;
    end

    imm_extender u_imm_extender (
        .instr  (instr),
        .imm_out(imm_out)
    );

    initial begin
        $dumpfile(`VCD_FILEPATH);  // 指定输出的波形文件名
        $dumpvars;  // 或者简单粗暴：dump 全部层级
    end

    initial begin
        instr = 32'b000001100100_00010_000_00001_0010011;
        #20;

        instr = 32'b000001100100_00100_010_00011_0000011;
        #20;

        instr = 32'b0000011_00101_00110_010_00100_0100011;
        #20;

        instr = 32'b0_000011_01000_00111_000_00100_1100011;
        #20;

        instr = 32'b00000000000000000110_01001_0110111;
        #20;

        instr = 32'b0_0000110010_0_00000000_01010_1101111;
        #20;

        $finish;
    end

endmodule
