`include "include/defines.svh"

// CSR（控制和状态寄存器）模块
// 实现 RV32I 的 Zicsr 扩展
// 支持机器级 CSR 和基本的特权模式切换
module CSR (
    input logic clk,
    input logic rst_n,

    // CSR 指令接口
    input  logic        csr_we,           // CSR 写使能
    input  logic [11:0] csr_addr,         // CSR 地址
    input  logic [31:0] csr_wdata,        // 写入 CSR 的数据
    input  logic [ 2:0] csr_op,           // CSR 操作类型（funct3）
    output logic [31:0] csr_rdata,        // 从 CSR 读取的数据
    // 异常/陷阱接口
    input  logic        exception_valid,  // 异常发生
    input  logic [31:0] exception_pc,     // 引发异常的指令的 PC
    input  logic [31:0] exception_cause,  // 异常原因代码
    input  logic [31:0] exception_tval,   // 异常陷阱值（例如非法指令编码）
    // MRET 接口
    input  logic        mret_valid,       // 执行 MRET 指令
    // 陷阱输出
    output logic        trap_to_mmode,    // 信号重定向到陷阱处理程序
    output logic [31:0] trap_target,      // 陷阱处理程序地址（mtvec）
    output logic [31:0] mret_target       // 从陷阱返回的地址（mepc）
);

    // 机器级 CSR
    // mstatus - 机器状态寄存器
    logic [31:0] mstatus;
    // mtvec - 机器陷阱向量基地址
    logic [31:0] mtvec;
    // mepc - 机器异常程序计数器
    logic [31:0] mepc;
    // mcause - 机器原因寄存器
    logic [31:0] mcause;
    // mscratch - 机器暂存寄存器
    logic [31:0] mscratch;
    // mtval - 机器陷阱值寄存器
    logic [31:0] mtval;
    // mie - 机器中断使能
    logic [31:0] mie;
    // mip - 机器中断挂起
    logic [31:0] mip;
    // MISA
    logic [31:0] misa;
    // mcycle - 机器周期计数器（64 位，分为低位和高位）
    logic [63:0] mcycle;
    // MISA 硬编码为 RV32I，支持 Zicsr 和 Zmmul
    // always_comb begin
    //     misa = 32'h4000_0110;  // RV32I（基础 ISA）+ Zicsr + Zmmul
    // end

    // mstatus 位位置
    localparam integer MIE_BIT = 3;  // 机器中断使能
    localparam integer MPIE_BIT = 7;  // 机器先前中断使能
    localparam integer MPP_LOW = 11;  // 机器先前特权（低位）
    localparam integer MPP_HIGH = 12;  // 机器先前特权（高位）

    // CSR 读取逻辑
    always_comb begin
        case (csr_addr)
            `CSR_MSTATUS:              csr_rdata = mstatus;
            `CSR_MTVEC:                csr_rdata = mtvec;
            `CSR_MEPC:                 csr_rdata = mepc;
            `CSR_MCAUSE:               csr_rdata = mcause;
            `CSR_MIE:                  csr_rdata = mie;
            `CSR_MIP:                  csr_rdata = mip;
            `CSR_MSCRATCH:             csr_rdata = mscratch;  // mscratch
            `CSR_MTVAL:                csr_rdata = mtval;  // mtval
            `CSR_MISA:                 csr_rdata = misa;
            `CSR_MCYCLE, `CSR_CYCLE:   csr_rdata = mcycle[31:0];  // mcycle 低 32 位
            `CSR_MCYCLEH, `CSR_CYCLEH: csr_rdata = mcycle[63:32];  // mcycle 高 32 位
            default:                   csr_rdata = 32'b0;
        endcase
    end

    // 根据操作类型计算新的 CSR 值
    logic [31:0] csr_new_value;
    always_comb begin
        case (csr_op)
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI: csr_new_value = csr_wdata;  // 写入
            `FUNCT3_CSRRS, `FUNCT3_CSRRSI: csr_new_value = csr_rdata | csr_wdata;  // 设置位
            `FUNCT3_CSRRC, `FUNCT3_CSRRCI: csr_new_value = csr_rdata & (~csr_wdata);  // 清除位
            default:                       csr_new_value = csr_rdata;
        endcase
    end

    // CSR 写入逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位值
            mstatus  <= 32'h0000_1800;  // MPP = 11（机器模式）
            mtvec    <= 32'h0114_5140;  // 默认陷阱处理程序地址 
            mepc     <= 32'h0000_0000;
            mcause   <= 32'h0000_0000;
            mscratch <= 32'h0000_0000;
            mtval    <= 32'h0000_0000;
            mie      <= 32'h0000_0000;
            mip      <= 32'h0000_0000;
            misa     <= 32'h4000_0100;  // RV32I
        end else if (exception_valid) begin
            // 异常发生时：保存状态并更新 CSR
            mepc                      <= exception_pc;
            mcause                    <= exception_cause;
            // 保存陷阱值（非法指令编码或地址）
            mtval                     <= exception_tval;
            // 更新 mstatus：保存 MIE 到 MPIE，将 MPP 设置为当前特权（目前始终为 M 模式）
            mstatus[MPIE_BIT]         <= mstatus[MIE_BIT];  // MPIE = MIE
            mstatus[MIE_BIT]          <= 1'b0;  // 禁用中断
            mstatus[MPP_HIGH:MPP_LOW] <= 2'b11;  // MPP = 机器模式
        end else if (mret_valid) begin
            // 执行 MRET 时：恢复状态
            mstatus[MIE_BIT] <= mstatus[MPIE_BIT];  // MIE = MPIE
            mstatus[MPIE_BIT] <= 1'b1;  // MPIE = 1
            mstatus[MPP_HIGH:MPP_LOW] <=
                2'b11;  // MPP = 机器模式（因为我们仅支持 M 模式）
        end else if (csr_we) begin
            // 正常 CSR 写入
            case (csr_addr)
                `CSR_MSTATUS:  mstatus <= csr_new_value & 32'h0000_1888;  // 屏蔽可写位
                `CSR_MTVEC:    mtvec <= {csr_new_value[31:2], 2'b00};  // 对齐到 4 字节
                `CSR_MEPC:     mepc <= {csr_new_value[31:2], 2'b00};  // 对齐到 4 字节
                `CSR_MCAUSE:   mcause <= csr_new_value;
                `CSR_MIE:      mie <= csr_new_value;
                `CSR_MSCRATCH: mscratch <= csr_new_value;  // mscratch
                `CSR_MTVAL:    mtval <= csr_new_value;  // mtval
                `CSR_MISA:     misa <= misa;  // 只读
                default:       ;
            endcase
        end
    end

    // mcycle 计数器 - 无条件每个时钟周期递增
    // 注意：这是一个简化实现，不支持 mcountinhibit。
    // 计数器始终运行，除非通过 CSR 指令显式写入。
    // mcycle 可通过 CSR 指令（MCYCLE/MCYCLEH）写入
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mcycle <= 64'h0;
        end else if (csr_we && csr_addr == `CSR_MCYCLE) begin
            mcycle[31:0] <= csr_new_value;
        end else if (csr_we && csr_addr == `CSR_MCYCLEH) begin
            mcycle[63:32] <= csr_new_value;
        end else begin
            mcycle <= mcycle + 64'h1;
        end
    end

    // 陷阱和返回信号
    assign trap_to_mmode = exception_valid;
    assign trap_target   = {mtvec[31:2], 2'b00};  // 使用直接模式（MODE=0）
    assign mret_target   = mepc;

endmodule
