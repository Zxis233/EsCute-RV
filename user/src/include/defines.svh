`ifndef _DEFINES_V
`define _DEFINES_V 

// 临时文件路径
`define VCD_FILEPATH "prj/icarus/wave.vcd"

// verilog_format: off

// ANSI 颜色定义
// `define COLORFUL

`ifdef COLORFUL

    `define ASSERT(x, y) \
    if ((x)!=(y)) begin \
        $display("ASSERT \033[1;31mFAILED\033[0m! Time=\033[34m%0t\033[0m", $time); \
        $stop; \
    end

    `define ASSERT_ECHO(x, y) \
    if ((x)!=(y)) begin \
        $display("ASSERT \033[1;31mFAILED\033[0m! Time=\033[34m%0t\033[0m", $time); \
        // $stop; \
        $finish; \
    end else begin \
        $display("ASSERT \033[1;32mSUCCEED\033[0m! Time=\033[34m%0t\033[0m", $time); \
    end

    `define ASSERT_NONPAUSE(x, y) \
    if ((x)!=(y)) begin \
        $display("ASSERT \033[1;31mFAILED\033[0m! Time=\033[34m%0t\033[0m", $time); \
    end else begin \
        $display("ASSERT \033[1;32mSUCCEED\033[0m! Time=\033[34m%0t\033[0m", $time); \
    end

    `define ASSERT_NO \
    begin \
        $display("ASSERT \033[1;31mFAILED\033[0m! Time=\033[34m%0t\033[0m", $time); \
        $stop; \
    end

`else

    `define ASSERT(x, y) \
    if ((x)!=(y)) begin \
        $display("ASSERT FAILED! Time=%0t", $time); \
        $stop; \
    end

    `define ASSERT_ECHO(x, y) \
    if ((x)!=(y)) begin \
        $display("ASSERT FAILED! Time=%0t", $time); \
        $finish; \
    end else begin \
        $display("ASSERT SUCCEED! Time=%0t", $time); \
    end

    `define ASSERT_NONPAUSE(x, y) \
    if ((x)!=(y)) begin \
        $display("ASSERT FAILED! Time=%0t", $time); \
    end else begin \
        $display("ASSERT SUCCEED! Time=%0t", $time); \
    end

    `define ASSERT_NO \
    begin \
        $display("ASSERT FAILED! Time%0t", $time); \
        $stop; \
    end

`endif

// 配置选项
`define INITIAL_PC 32'h0000_0000  // 初始PC地址
// `define INITIAL_PC 32'h8000_0000

// verilog_format: off
// ================== 指令集 定义 ==================
    `define OPCODE_RTYPE        7'b0110011
    `define OPCODE_ITYPE        7'b0010011
    `define OPCODE_BTYPE        7'b1100011

    `define OPCODE_JAL          7'b1101111
    `define OPCODE_JALR         7'b1100111

    `define OPCODE_STYPE        7'b0100011

    `define OPCODE_AUIPC        7'b0010111
    `define OPCODE_LUI          7'b0110111

    `define OPCODE_LTYPE        7'b0000011
    `define OPCODE_ZICSR        7'b1110011
    `define OPCODE_ZERO         7'b0000000

// ================== Funct3 定义 ==================
    `define FUNCT3_ADD_SUB_MUL  3'h0
    `define FUNCT3_SLL_MULH     3'h1
    `define FUNCT3_SLT_MULHSU   3'h2
    `define FUNCT3_SLTU_MULHU   3'h3
    `define FUNCT3_XOR_DIV      3'h4
    `define FUNCT3_SRL_SRA_DIVU 3'h5
    `define FUNCT3_OR_REM       3'h6
    `define FUNCT3_AND_REMU     3'h7

    `define FUNCT3_BEQ          3'h0
    `define FUNCT3_BNE          3'h1
    `define FUNCT3_BLT          3'h4
    `define FUNCT3_BGE          3'h5
    `define FUNCT3_BLTU         3'h6
    `define FUNCT3_BGEU         3'h7

    `define FUNCT3_LB           3'h0
    `define FUNCT3_LBU          3'h4
    `define FUNCT3_LH           3'h1
    `define FUNCT3_LHU          3'h5
    `define FUNCT3_LW           3'h2

    `define FUNCT3_SB           3'h0
    `define FUNCT3_SH           3'h1
    `define FUNCT3_SW           3'h2

// ================== Funct7 定义 ==================
    `define FUNCT7_SLLI         7'b0000000
    `define FUNCT7_SRLI         7'b0000000
    `define FUNCT7_SRAI         7'b0100000
    `define FUNCT7_ADD          7'b0000000
    `define FUNCT7_SUB          7'b0100000
    `define FUNCT7_SLL          7'b0000000
    `define FUNCT7_SLT          7'b0000000
    `define FUNCT7_SLTU         7'b0000000
    `define FUNCT7_XOR          7'b0000000
    `define FUNCT7_SRL          7'b0000000
    `define FUNCT7_SRA          7'b0100000
    `define FUNCT7_OR           7'b0000000
    `define FUNCT7_AND          7'b0000000

    `define FUNCT7_MUL          7'b0000001
    `define FUNCT7_MULH         7'b0000001
    `define FUNCT7_MULHSU       7'b0000001
    `define FUNCT7_MULHU        7'b0000001

// ================== WD_sel 定义 ==================
    `define WD_SEL_FROM_ALU     2'd0
    `define WD_SEL_FROM_DRAM    2'd1
    `define WD_SEL_FROM_PC4     2'd2
    `define WD_SEL_FROM_IEXT    2'd3

// ================== ALUsrc 定义 ==================
    `define ALUSRC_RS2          1'b0
    `define ALUSRC_IMM          1'b1

// ================== ALUOp  定义 ==================
    `define ALU_NOP             4'd0
    `define ALU_ADD             4'd1
    `define ALU_SUB             4'd2
    `define ALU_OR              4'd3
    `define ALU_AND             4'd4
    `define ALU_XOR             4'd5
    `define ALU_SLL             4'd6
    `define ALU_SRL             4'd7
    `define ALU_SRA             4'd8
    `define ALU_SLT             4'd9
    `define ALU_SLTU            4'd10
    `define ALU_RIGHT           4'd11

//================== ALUOp  M定义 ==================
    `define ALU_MUL             4'd12
    `define ALU_MULH            4'd13
    `define ALU_MULHSU          4'd14
    `define ALU_MULHU           4'd15

    `define ALU_DIV             5'd16
    `define ALU_DIVU            5'd17
    `define ALU_REM             5'd18
    `define ALU_REMU            5'd19

// ================= ALUOp LS定义 ==================
    `define ALU_LB              5'd21
    `define ALU_LBU             5'd22
    `define ALU_LH              5'd23
    `define ALU_LHU             5'd24
    `define ALU_LW              5'd25

    `define ALU_SB              5'd26
    `define ALU_SH              5'd27
    `define ALU_SW              5'd28

// ================== Branch 定义 ==================
    `define BRANCH_NOP          3'b000
    `define BRANCH_BEQ          3'b011
    `define BRANCH_BNE          3'b001
    `define BRANCH_BLT          3'b100
    `define BRANCH_BGE          3'b101
    `define BRANCH_BLTU         3'b110
    `define BRANCH_BGEU         3'b111
    `define BRANCH_JALR         3'b010

// ================== Jump   定义 ==================
    `define JUMP_NOP            2'b00
    `define JUMP_JAL            2'b01
    `define JUMP_JALR           2'b10

// ================== MemOP  定义 ==================
    `define MEM_NOP             4'b00_00
    `define MEM_LB              4'b00_01
    `define MEM_LH              4'b00_10
    `define MEM_LW              4'b00_11
    `define MEM_LBU             4'b01_01
    `define MEM_LHU             4'b01_10
    `define MEM_SB              4'b10_01
    `define MEM_SH              4'b10_10
    `define MEM_SW              4'b10_11

// ================== CSR    定义 ==================
    `define CSR_MSTATUS        12'h300
    `define CSR_MTVEC          12'h305
    `define CSR_MEPC           12'h341
    `define CSR_MCAUSE         12'h342
    `define CSR_MIE            12'h304
    `define CSR_MIP            12'h344
    `define CSR_CYCLE          12'hC00
    `define CSR_CYCLEH         12'hC80
    `define CSR_INSTRET        12'hC02
    `define CSR_INSTRETH       12'hC82

// ================== F3-CSR 定义 ==================
    `define FUNCT3_CSRRC        3'h3
    `define FUNCT3_CSRRCI       3'h7
    `define FUNCT3_CSRRS        3'h2
    `define FUNCT3_CSRRSI       3'h6
    `define FUNCT3_CSRRW        3'h1
    `define FUNCT3_CSRRWI       3'h5
    `define FUNCT3_CALL         3'h0

//verilog_format: on


`endif
