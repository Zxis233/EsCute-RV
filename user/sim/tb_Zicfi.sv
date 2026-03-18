`timescale 1ns / 1ps

`include "../src/CPU_TOP.sv"

module tb_Zicfi;

    logic        clk;
    logic        rst_n;
    logic [13:0] pc_addr;
    logic [31:0] instr_data;
    logic        saw_exception;

    logic [31:0] rom           [0:255];

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

        // M-mode setup
        rom[0]  = 32'h08000093;  // addi x1, x0, 0x80
        rom[1]  = 32'h00c00193;  // addi x3, x0, 0x0c (LPE|SSE)
        rom[2]  = 32'h30a19073;  // csrw menvcfg, x3
        rom[3]  = 32'h10a19073;  // csrw senvcfg, x3
        rom[4]  = 32'h04000213;  // addi x4, x0, 0x40
        rom[5]  = 32'h01121073;  // csrw ssp, x4
        rom[6]  = 32'h00100313;  // addi x6, x0, 1
        rom[7]  = 32'h00b31313;  // slli x6, x6, 11
        rom[8]  = 32'h30031073;  // csrw mstatus, x6
        rom[9]  = 32'h03400313;  // addi x6, x0, 52
        rom[10] = 32'h34131073;  // csrw mepc, x6
        rom[11] = 32'h30200073;  // mret

        // S-mode body @ 0x34
        rom[13] = 32'hcdc01573;  // ssrdp x10
        rom[14] = 32'hce809073;  // sspush x1
        rom[15] = 32'hcdc015f3;  // ssrdp x11
        rom[16] = 32'hcdc0c073;  // sspopchk x1
        rom[17] = 32'hcdc01673;  // ssrdp x12
        rom[18] = 32'h05800113;  // addi x2, x0, 88
        rom[19] = 32'h00010067;  // jalr x0, 0(x2)
        rom[22] = 32'h00000017;  // lpad 0
        rom[23] = 32'h00100693;  // addi x13, x0, 1
        rom[24] = 32'h0000006f;  // jal x0, 0
    end

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    initial begin
        rst_n         = 1'b0;
        saw_exception = 1'b0;
        #5;
        rst_n = 1'b1;
    end

    always_ff @(posedge clk) begin
        if (rst_n && u_CPU_TOP.exception_valid && !saw_exception) begin
            saw_exception <= 1'b1;
            $display("first exception: pc=%h cause=%h tval=%h priv=%0b instr_ex=%h instr_id=%h",
                     u_CPU_TOP.exception_pc, u_CPU_TOP.exception_cause, u_CPU_TOP.exception_tval,
                     u_CPU_TOP.current_priv_mode, u_CPU_TOP.instr_EX, u_CPU_TOP.instr_ID);
        end
    end

    always_ff @(posedge clk) begin
        if (rst_n && u_CPU_TOP.u_registerf.rf_in[13] == 32'd1) begin
            if (u_CPU_TOP.current_priv_mode !== `PRV_S) begin
                $error("Expected S-mode, got %0b", u_CPU_TOP.current_priv_mode);
            end
            if (u_CPU_TOP.u_registerf.rf_in[10] !== 32'h0000_0040) begin
                $error("SSRDP before push mismatch: %h", u_CPU_TOP.u_registerf.rf_in[10]);
            end
            if (u_CPU_TOP.u_registerf.rf_in[11] !== 32'h0000_003c) begin
                $error("SSRDP after push mismatch: %h", u_CPU_TOP.u_registerf.rf_in[11]);
            end
            if (u_CPU_TOP.u_registerf.rf_in[12] !== 32'h0000_0040) begin
                $error("SSRDP after pop mismatch: %h", u_CPU_TOP.u_registerf.rf_in[12]);
            end
            if (u_CPU_TOP.ssp_value !== 32'h0000_0040) begin
                $error("Final ssp mismatch: %h", u_CPU_TOP.ssp_value);
            end
            if (u_CPU_TOP.elp_expected !== 1'b0) begin
                $error("ELP should be cleared after LPAD");
            end
            if (u_CPU_TOP.u_DRAM.ram_data[15] !== 32'h0000_0080) begin
                $error("Shadow stack memory mismatch: %h", u_CPU_TOP.u_DRAM.ram_data[15]);
            end
            $display("tb_Zicfi PASS");
            $finish;
        end
    end

    initial begin
        #5000;
        $display(
            "pc=%h priv=%0b x10=%h x11=%h x12=%h x13=%h ssp=%h elp=%0b mem[15]=%h mcause=%h mtval=%h mepc=%h",
            u_CPU_TOP.pc_IF, u_CPU_TOP.current_priv_mode, u_CPU_TOP.u_registerf.rf_in[10],
            u_CPU_TOP.u_registerf.rf_in[11], u_CPU_TOP.u_registerf.rf_in[12],
            u_CPU_TOP.u_registerf.rf_in[13], u_CPU_TOP.ssp_value, u_CPU_TOP.elp_expected,
            u_CPU_TOP.u_DRAM.ram_data[15], u_CPU_TOP.u_CSR.mcause, u_CPU_TOP.u_CSR.mtval,
            u_CPU_TOP.u_CSR.mepc);
        $display("tb_Zicfi TIMEOUT");
        $finish;
    end

endmodule
