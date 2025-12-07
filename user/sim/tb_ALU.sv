`timescale 1ns / 1ps
`define DEBUG 

`include "../src/ALU.sv"

module tb_ALU;

    localparam int XLEN = 32;

    // 驱动 DUT 的输入
    logic [     3:0] alu_op;
    logic [XLEN-1:0] src1;
    logic [XLEN-1:0] src2;

    // DUT 输出
    logic [XLEN-1:0] alu_result;
    logic            zero;
    logic            sign;
    logic            alu_unsigned;

    // 实例化待测 ALU
    ALU #(
        .XLEN(XLEN)
    ) dut (
        .alu_op      (alu_op),
        .src1        (src1),
        .src2        (src2),
        .imm         (src2),
        .alu_src2_sel(1'b0),
        .alu_result  (alu_result),
        .zero        (zero),
        .sign        (sign),
        .alu_unsigned(alu_unsigned)
    );

    logic [64-1:0] aluop_ascii;

    always_comb begin
        aluop_ascii = dut.aluop_ascii;
    end

    // ===============================
    // 参考模型：根据 alu_op/src1/src2 计算期望结果
    // ===============================
    function automatic [XLEN-1:0] alu_model(input logic [3:0] op, input logic [XLEN-1:0] a,
                                            input logic [XLEN-1:0] b);
        begin
            unique case (op)
                `ALU_NOP:   alu_model = '0;
                `ALU_ADD:   alu_model = a + b;
                `ALU_SUB:   alu_model = a - b;
                `ALU_OR:    alu_model = a | b;
                `ALU_AND:   alu_model = a & b;
                `ALU_XOR:   alu_model = a ^ b;
                `ALU_SLL:   alu_model = a << b[4:0];
                `ALU_SRL:   alu_model = a >> b[4:0];
                `ALU_SRA:   alu_model = $signed(a) >>> b[4:0];
                `ALU_SLT:   alu_model = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
                `ALU_SLTU:  alu_model = (a < b) ? 32'd1 : 32'd0;
                `ALU_RIGHT: alu_model = b;  // 与 ALU 中的实现一致
                default:    alu_model = '0;  // 未实现的 op 都视为 NOP
            endcase
        end
    endfunction

    // ===============================
    // 跑一个测试用例 + 使用断言检查
    // ===============================
    task automatic run_one_case(input logic [3:0] op, input logic [XLEN-1:0] a,
                                input logic [XLEN-1:0] b);
        logic [XLEN-1:0] exp_res;
        logic            exp_zero;
        logic            exp_sign;
        logic            exp_unsigned;
        begin
            // 驱动输入
            alu_op = op;
            src1   = a;
            src2   = b;

            // 组合逻辑给一点时间稳定
            #1;

            // 计算期望值
            exp_res      = alu_model(op, a, b);
            // exp_zero     = (exp_res == '0 | alu_op == `ALU_NOP);
            exp_zero     = exp_res == '0;
            exp_sign     = exp_res[XLEN-1];
            exp_unsigned = (a < b);  // 和 ALU 里 alu_unsigned = (src1 < src2) 保持一致

            // 方便观察的输出
            $display("====================================================");
            // $display("op=%0d src1=%h src2=%h", op, a, b);
            $display("op=%0d(%s) src1=%h src2=%h", op, aluop_ascii, a, b);
            $display("exp_res=%h act_res=%h", exp_res, alu_result);
            $display("exp_zero=%0b act_zero=%0b", exp_zero, zero);
            $display("exp_sign=%0b act_sign=%0b", exp_sign, sign);
            $display("exp_uns =%0b act_uns =%0b", exp_unsigned, alu_unsigned);

            // 使用你 defines.svh 里的断言宏
            // 失败时会打印 "ASSERT FAILED!" 并 $stop
            `ASSERT_ECHO(alu_result, exp_res);
            `ASSERT_ECHO(zero, exp_zero);
            `ASSERT_ECHO(sign, exp_sign);
            `ASSERT_ECHO(alu_unsigned, exp_unsigned);
        end
    endtask

    integer i;

    // ===============================
    // 主测试流程
    // ===============================
    initial begin
        // 初始化输入
        alu_op = '0;
        src1   = '0;
        src2   = '0;

        // ---------- 定向测试 ----------
        // 可根据需要再加更多边界情况
        run_one_case(`ALU_NOP, 32'h0000_0000, 32'h0000_0000);
        run_one_case(`ALU_ADD, 32'd1, 32'd2);
        run_one_case(`ALU_ADD, 32'h7fff_ffff, 32'd1);
        run_one_case(`ALU_SUB, 32'd5, 32'd3);
        run_one_case(`ALU_SUB, 32'd1, 32'd2);
        run_one_case(`ALU_OR, 32'hffff_0000, 32'h0f0f_0f0f);
        run_one_case(`ALU_AND, 32'hffff_0000, 32'h0f0f_0f0f);
        run_one_case(`ALU_XOR, 32'hffff_0000, 32'h0f0f_0f0f);
        run_one_case(`ALU_SLL, 32'h0000_0001, 32'd4);
        run_one_case(`ALU_SRL, 32'h8000_0000, 32'd4);
        run_one_case(`ALU_SRA, 32'h8000_0000, 32'd4);
        run_one_case(`ALU_SLT, 32'hffff_ffff, 32'd1);  // -1 < 1
        run_one_case(`ALU_SLTU, 32'h0000_0001, 32'hffff_ffff);
        run_one_case(`ALU_RIGHT, 32'h1234_5678, 32'h89ab_cdef);

        // ---------- 随机测试 ----------
        for (i = 0; i < 20; i = i + 1) begin
            logic [     3:0] op_rand;
            logic [XLEN-1:0] a_rand;
            logic [XLEN-1:0] b_rand;

            op_rand =
                $urandom_range(`ALU_NOP, `ALU_RIGHT);  // 只在已实现的 op 范围内随机
            a_rand = $urandom();
            b_rand = $urandom();

            run_one_case(op_rand, a_rand, b_rand);
        end

        $display("******** ALU ASSERT TEST FINISHED ********");
        $finish;
    end

    initial begin
        #10000;
        $display("******** ALU TEST TIMEOUT ********");
        $finish;
    end

endmodule
