`timescale 1ns / 1ps

`include "../src/CPU_TOP.sv"

module tb_BadCsr;

    logic        clk = 1'b0;
    logic        rst_n = 1'b0;
    logic [13:0] pc_addr;
    logic [31:0] instr_data;

    logic [31:0] rom          [256];

    CPU_TOP u_CPU_TOP (
        .clk  (clk),
        .rst_n(rst_n),
        .instr(instr_data),
        .pc   (pc_addr)
    );

    always_comb begin
        instr_data = rom[pc_addr];
    end

    initial begin
        integer i;
        for (i = 0; i < 256; i = i + 1) begin
            rom[i] = 32'h00000013;  // nop
        end

        rom[0] = 32'h30b02173;  // csrr x2, 0x30b (unimplemented CSR)
        rom[1] = 32'h0000006f;  // jal x0, 0
    end

    initial begin
        forever #5 clk = ~clk;
    end

    initial begin
        #20;
        rst_n = 1'b1;
    end

    logic        saw_exception = 1'b0;
    logic [31:0] last_mcause = 32'b0;
    logic [31:0] last_mtval = 32'b0;
    initial begin
        saw_exception = 1'b0;
        last_mcause   = 32'b0;
        last_mtval    = 32'b0;
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            saw_exception <= 1'b0;
            last_mcause   <= 32'b0;
            last_mtval    <= 32'b0;
        end else if (u_CPU_TOP.exception_valid && !saw_exception) begin
            saw_exception <= 1'b1;
            last_mcause   <= u_CPU_TOP.exception_cause;
            last_mtval    <= u_CPU_TOP.exception_tval;
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && saw_exception) begin
            if (last_mcause !== `EXC_ILLEGAL_INSTR) begin
                $error("Expected illegal instruction cause, got %h", last_mcause);
            end
            if (last_mtval !== 32'h30b02173) begin
                $error("Expected mtval for bad CSR read, got %h", last_mtval);
            end
            $display("tb_BadCsr PASS");
            $finish;
        end
    end

    initial begin
        #5000;
        $display("tb_BadCsr TIMEOUT saw_exception=%0b mcause=%h mtval=%h pc=%h", saw_exception,
                 last_mcause, last_mtval, u_CPU_TOP.pc_IF);
        $finish;
    end

endmodule
