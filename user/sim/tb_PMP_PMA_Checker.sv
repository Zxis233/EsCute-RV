`timescale 1ns / 1ps

`include "../src/include/defines.svh"

module tb_PMP_PMA_Checker;

    logic [31:0] addr;
    logic [ 1:0] access_type;
    logic [ 1:0] access_size;
    logic [ 1:0] priv_mode;
    logic [31:0] pmpcfg0;
    logic [31:0] pmpaddr0;
    logic        access_fault;
    int unsigned errors;

    PMP_PMA_Checker u_checker (
        .addr        (addr),
        .access_type (access_type),
        .access_size (access_size),
        .priv_mode   (priv_mode),
        .pmpcfg0     (pmpcfg0),
        .pmpaddr0    (pmpaddr0),
        .access_fault(access_fault)
    );

    task automatic check_fault(input string name, input logic expected);
        #1;
        if (access_fault !== expected) begin
            $error("%s: expected fault=%0b got=%0b", name, expected, access_fault);
            errors++;
        end
    endtask

    initial begin
        errors      = 0;
        addr        = 32'h0000_0000;
        access_type = `PMP_ACC_FETCH;
        access_size = `PMP_SIZE_4B;
        priv_mode   = `PRV_M;
        pmpcfg0     = 32'h0000_0000;
        pmpaddr0    = 32'h0000_0000;

        check_fault("pma low fetch", 1'b0);

        addr        = 32'h0000_FFFE;
        access_type = `PMP_ACC_LOAD;
        access_size = `PMP_SIZE_4B;
        check_fault("pma cross limit", 1'b1);

        addr        = 32'h0001_0000;
        access_size = `PMP_SIZE_1B;
        check_fault("pma over limit", 1'b1);

        priv_mode = `PRV_S;
        addr      = 32'h0000_0000;
        check_fault("pmp off allows teaching S-mode", 1'b0);

        pmpaddr0 = 32'h0000_0401;  // NAPOT 16-byte range: [0x1000, 0x1010)
        pmpcfg0  = {24'b0, (`PMP_A_NAPOT | `PMP_R | `PMP_X)};
        addr        = 32'h0000_1000;
        access_type = `PMP_ACC_LOAD;
        access_size = `PMP_SIZE_4B;
        check_fault("pmp napot load allowed", 1'b0);

        access_type = `PMP_ACC_STORE;
        check_fault("pmp napot store denied", 1'b1);

        addr        = 32'h0000_1010;
        access_type = `PMP_ACC_LOAD;
        check_fault("pmp napot no match denied", 1'b1);

        priv_mode = `PRV_M;
        check_fault("pmp M-mode bypass", 1'b0);

        pmpcfg0 = {24'b0, (`PMP_A_NAPOT | `PMP_R | `PMP_X | `PMP_L)};
        addr        = 32'h0000_1000;
        access_type = `PMP_ACC_STORE;
        check_fault("pmp locked M-mode denied", 1'b1);

        if (errors == 0) begin
            $display("[PASS] tb_PMP_PMA_Checker");
        end else begin
            $display("[FAIL] tb_PMP_PMA_Checker errors=%0d", errors);
        end
        $finish;
    end

endmodule
