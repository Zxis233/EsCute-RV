`ifndef _DEFINES_V
`define _DEFINES_V

// `define DEBUG
// `define YOSYS 

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

    typedef enum logic [6:0] {
        OPCODE_RTYPE = 7'b0110011,
        OPCODE_ITYPE = 7'b0010011,
        OPCODE_BTYPE = 7'b1100011,
        OPCODE_JAL   = 7'b1101111,
        OPCODE_JALR  = 7'b1100111,
        OPCODE_STYPE = 7'b0100011,
        OPCODE_AUIPC = 7'b0010111,
        OPCODE_LUI   = 7'b0110111,
        OPCODE_LTYPE = 7'b0000011,
        OPCODE_ZICSR = 7'b1110011,
        OPCODE_FENCE = 7'b0001111,
        OPCODE_ZERO  = 7'b0000000
    } opcode_e;

// ================== Funct3 定义 ==================
    `define FUNCT3_ADD_SUB_MUL        3'h0
    `define FUNCT3_SLL_MULH           3'h1
    `define FUNCT3_SLT_MULHSU         3'h2
    `define FUNCT3_SLTU_MULHU         3'h3
    `define FUNCT3_XOR_DIV            3'h4
    `define FUNCT3_SRL_SRA_DIVU       3'h5
    `define FUNCT3_OR_REM             3'h6
    `define FUNCT3_AND_REMU           3'h7

    `define FUNCT3_BEQ                3'h0
    `define FUNCT3_BNE                3'h1
    `define FUNCT3_BLT                3'h4
    `define FUNCT3_BGE                3'h5
    `define FUNCT3_BLTU               3'h6
    `define FUNCT3_BGEU               3'h7

    `define FUNCT3_LB                 3'h0
    `define FUNCT3_LBU                3'h4
    `define FUNCT3_LH                 3'h1
    `define FUNCT3_LHU                3'h5
    `define FUNCT3_LW                 3'h2

    `define FUNCT3_SB                 3'h0
    `define FUNCT3_SH                 3'h1
    `define FUNCT3_SW                 3'h2

// ================== Funct7 定义 ==================
    `define FUNCT7_SLLI                 7'b0000000
    `define FUNCT7_SRLI                 7'b0000000
    `define FUNCT7_SRAI                 7'b0100000
    `define FUNCT7_ADD                  7'b0000000
    `define FUNCT7_SUB                  7'b0100000
    `define FUNCT7_SLL                  7'b0000000
    `define FUNCT7_SLT                  7'b0000000
    `define FUNCT7_SLTU                 7'b0000000
    `define FUNCT7_XOR                  7'b0000000
    `define FUNCT7_SRL                  7'b0000000
    `define FUNCT7_SRA                  7'b0100000
    `define FUNCT7_OR                   7'b0000000
    `define FUNCT7_AND                  7'b0000000

    `define FUNCT7_MUL                  7'b0000001
    `define FUNCT7_MULH                 7'b0000001
    `define FUNCT7_MULHSU               7'b0000001
    `define FUNCT7_MULHU                7'b0000001

// ================== WD_sel 定义 ==================
    `define WD_SEL_FROM_ALU             3'd0
    `define WD_SEL_FROM_DRAM            3'd1
    `define WD_SEL_FROM_PC4             3'd2
    `define WD_SEL_FROM_IEXT            3'd3
    `define WD_SEL_FROM_MUL             3'd4
    `define WD_SEL_FROM_CSR             3'd5   // 写回来自CSR
    `define WD_SEL_FROM_SSP             3'd6   // 写回来自 shadow stack pointer

// ================== ALUsrc 定义 ==================
    `define ALUSRC_RS2                  1'b0
    `define ALUSRC_IMM                  1'b1

// ================== ALUOp  定义 ==================
    `define ALU_NOP                     5'd0
    `define ALU_ADD                     5'd1
    `define ALU_SUB                     5'd2
    `define ALU_OR                      5'd3
    `define ALU_AND                     5'd4
    `define ALU_XOR                     5'd5
    `define ALU_SLL                     5'd6
    `define ALU_SRL                     5'd7
    `define ALU_SRA                     5'd8
    `define ALU_SLT                     5'd9
    `define ALU_SLTU                    5'd10
    `define ALU_RIGHT                   5'd11

//================== ALUOp  M定义 ==================
    `define ALU_MUL                     5'd12
    `define ALU_MULH                    5'd13
    `define ALU_MULHSU                  5'd14
    `define ALU_MULHU                   5'd15

    `define ALU_DIV                     5'd16
    `define ALU_DIVU                    5'd17
    `define ALU_REM                     5'd18
    `define ALU_REMU                    5'd19

// ================= ALUOp LS定义 ==================
    `define ALU_LB                      5'd21
    `define ALU_LBU                     5'd22
    `define ALU_LH                      5'd23
    `define ALU_LHU                     5'd24
    `define ALU_LW                      5'd25

    `define ALU_SB                      5'd26
    `define ALU_SH                      5'd27
    `define ALU_SW                      5'd28

// ================== Branch 定义 ==================
    `define BRANCH_NOP                  3'b000
    `define BRANCH_BEQ                  3'b011
    `define BRANCH_BNE                  3'b001
    `define BRANCH_BLT                  3'b100
    `define BRANCH_BGE                  3'b101
    `define BRANCH_BLTU                 3'b110
    `define BRANCH_BGEU                 3'b111
    `define BRANCH_JALR                 3'b010

// ================== Jump   定义 ==================
    `define JUMP_NOP                    2'b00
    `define JUMP_JAL                    2'b01
    `define JUMP_JALR                   2'b10

// ================== MemOP  定义 ==================
    `define MEM_NOP                     4'b00_00
    `define MEM_LB                      4'b00_01
    `define MEM_LH                      4'b00_10
    `define MEM_LW                      4'b00_11
    `define MEM_LBU                     4'b01_01
    `define MEM_LHU                     4'b01_10
    `define MEM_SB                      4'b10_01
    `define MEM_SH                      4'b10_10
    `define MEM_SW                      4'b10_11
    `define MEM_SSPUSH                  4'b11_00
    `define MEM_SSPOPCHK                4'b11_01

// ================== CSR    定义 ==================
    `define CSR_SSP                    12'h011
    `define CSR_SSTATUS                12'h100
    `define CSR_SIE                    12'h104
    `define CSR_STVEC                  12'h105
    `define CSR_SCOUNTEREN             12'h106
    `define CSR_SENVCFG                12'h10A
    `define CSR_SSCRATCH               12'h140
    `define CSR_SEPC                   12'h141
    `define CSR_SCAUSE                 12'h142
    `define CSR_STVAL                  12'h143
    `define CSR_SIP                    12'h144
    `define CSR_SATP                   12'h180
    `define CSR_MSTATUS                12'h300
    `define CSR_MVENDORID              12'hF11
    `define CSR_MARCHID                12'hF12
    `define CSR_MIMPID                 12'hF13
    `define CSR_MHARTID                12'hF14
    `define CSR_MEDELEG                12'h302
    `define CSR_MIDELEG                12'h303
    `define CSR_MNSTATUS               12'h744
    `define CSR_MTVEC                  12'h305
    `define CSR_MSTATUSH               12'h310
    `define CSR_PMPCFG0                12'h3A0
    `define CSR_PMPADDR0               12'h3B0
    `define CSR_MEPC                   12'h341
    `define CSR_MCAUSE                 12'h342
    `define CSR_MIE                    12'h304
    `define CSR_MIP                    12'h344
    `define CSR_CYCLE                  12'hC00
    `define CSR_CYCLEH                 12'hC80
    `define CSR_INSTRET                12'hC02
    `define CSR_INSTRETH               12'hC82
    `define CSR_MISA                   12'h301
    `define CSR_MENVCFG                12'h30A
    `define CSR_MCOUNTEREN             12'h306
    `define CSR_MSCRATCH               12'h340
    `define CSR_MTVAL                  12'h343
    `define CSR_MCYCLE                 12'hB00
    `define CSR_MCYCLEH                12'hB80
    `define CSR_MSECCFG                12'h747

// ================== F3-CSR 定义 ==================
    `define FUNCT3_CSRRC                3'h3
    `define FUNCT3_CSRRCI               3'h7
    `define FUNCT3_CSRRS                3'h2
    `define FUNCT3_CSRRSI               3'h6
    `define FUNCT3_CSRRW                3'h1
    `define FUNCT3_CSRRWI               3'h5
    `define FUNCT3_CALL                 3'h0

// ================== Privilege 定义 ==================
    `define PRV_U                       2'b00
    `define PRV_S                       2'b01
    `define PRV_M                       2'b11

// ================== Exception Cause 定义 ==================
    `define EXC_INST_MISALIGNED        32'd0
    `define EXC_ILLEGAL_INSTR          32'd2
    `define EXC_BREAKPOINT             32'd3
    `define EXC_LOAD_MISALIGNED        32'd4
    `define EXC_LOAD_ACCESS_FAULT      32'd5
    `define EXC_STORE_MISALIGNED       32'd6
    `define EXC_STORE_ACCESS_FAULT     32'd7
    `define EXC_ECALL_U                32'd8
    `define EXC_ECALL_S                32'd9
    `define EXC_ECALL_M                32'd11
    `define EXC_SOFTWARE_CHECK         32'd18

// ================== Software-Check 定义 ==================
    `define SOFTCHK_LPAD_FAULT         32'd2
    `define SOFTCHK_SHADOW_STACK_FAULT 32'd3

// ================== Zicfilp/Zicfiss 定义 ==================
    `define MATCH_LPAD                 32'h0000_0017
    `define  MASK_LPAD                 32'h0000_0FFF
    `define MATCH_SSPUSH               32'hCE00_4073
    `define MASK_SSPUSH                32'hFE0F_FFFF
    `define MATCH_SSPOPCHK             32'hCDC0_4073
    `define  MASK_SSPOPCHK             32'hFFF0_7FFF
    `define MATCH_SSRDP                32'hCDC0_4073
    `define MASK_SSRDP                 32'hFFFF_F07F

    `define ENVCFG_LPE_BIT                2
    `define ENVCFG_SSE_BIT                3
    `define MSECCFG_MLPE_BIT              10
    `define MSTATUS_SPELP_BIT             23
    `define MSTATUSH_MPELP_BIT            9

    typedef enum logic [1:0] {
        NONE         = 0,
        STATIC       = 1,
        DYNAMIC_1bit = 2,
        GSHARE       = 3
    } bpu_type_e;

//verilog_format: on



`endif
