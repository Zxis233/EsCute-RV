`include "include/defines.svh"

// CSR（控制和状态寄存器）模块
// 实现 RV32I 的 Zicsr 扩展，并提供最小可工作的 M/S/U 特权支持。
// 当前不实现中断控制、分页翻译和 vectored trap，仅支持同步异常与 xRET。
module CSR (
    input  logic        clk,
    input  logic        rst_n,

    // CSR 指令接口
    input  logic        csr_we,
    input  logic [11:0] csr_addr,
    input  logic [31:0] csr_wdata,
    input  logic [ 2:0] csr_op,
    output logic [31:0] csr_rdata,

    // 异常/陷阱接口
    input  logic        exception_valid,
    input  logic [31:0] exception_pc,
    input  logic [31:0] exception_cause,
    input  logic [31:0] exception_tval,

    // xRET 接口
    input  logic        mret_valid,
    input  logic        sret_valid,

    // Shadow stack / landing pad 状态更新
    input  logic        ssp_update_valid,
    input  logic [31:0] ssp_update_data,
    input  logic        elp_update_valid,
    input  logic        elp_update_expected,

    // 陷阱输出
    output logic        trap_to_mmode,
    output logic [31:0] trap_target,
    output logic [31:0] xret_target,

    // 当前特权状态输出
    output logic [ 1:0] current_priv_mode,
    output logic        mstatus_tsr,
    output logic        mstatus_tvm,
    output logic        current_sse_enabled,
    output logic        current_lpe_enabled,
    output logic        elp_expected,
    output logic [31:0] ssp_value
);

    // 机器级 CSR
    logic [31:0] mstatus;
    logic [31:0] mstatush;
    logic [31:0] mtvec;
    logic [31:0] mepc;
    logic [31:0] mcause;
    logic [31:0] mscratch;
    logic [31:0] mtval;
    logic [31:0] mie;
    logic [31:0] mip;
    logic [31:0] misa;
    logic [31:0] medeleg;
    logic [31:0] mideleg;
    logic [31:0] menvcfg;
    logic [31:0] mseccfg;

    // 监督级 CSR
    logic [31:0] stvec;
    logic [31:0] sepc;
    logic [31:0] scause;
    logic [31:0] sscratch;
    logic [31:0] stval;
    logic [31:0] satp;
    logic [31:0] senvcfg;

    // Zicfiss/Zicfilp 状态
    logic [31:0] ssp;
    logic        elp_state;

    // 计数器
    logic [63:0] mcycle;

    // 当前特权级
    logic [ 1:0] priv_mode;

    // mstatus 位定义
    localparam integer SIE_BIT = 1;
    localparam integer MIE_BIT = 3;
    localparam integer SPIE_BIT = 5;
    localparam integer MPIE_BIT = 7;
    localparam integer SPP_BIT = 8;
    localparam integer MPP_LOW = 11;
    localparam integer MPP_HIGH = 12;
    localparam integer TVM_BIT = 20;
    localparam integer TSR_BIT = 22;
    localparam integer SPELP_BIT = `MSTATUS_SPELP_BIT;
    localparam integer MPELP_BIT = `MSTATUSH_MPELP_BIT;

    localparam logic [31:0] MSTATUS_WRITABLE_MASK = 32'h00F0_19AA;
    localparam logic [31:0] MSTATUSH_WRITABLE_MASK = 32'h0000_0200;
    localparam logic [31:0] SSTATUS_MASK = 32'h0080_0122;
    localparam logic [31:0] MENVCFG_WRITABLE_MASK = 32'h0000_000C;
    localparam logic [31:0] SENVCFG_WRITABLE_MASK = 32'h0000_000C;
    localparam logic [31:0] MSECCFG_WRITABLE_MASK = 32'h0000_0400;

    function automatic [31:0] align_trap_vector(input logic [31:0] value);
        begin
            align_trap_vector = {value[31:2], 2'b00};
        end
    endfunction

    function automatic [31:0] align_epc(input logic [31:0] value);
        begin
            align_epc = {value[31:2], 2'b00};
        end
    endfunction

    function automatic [31:0] compose_sstatus(input logic [31:0] mstatus_value);
        begin
            compose_sstatus = mstatus_value & SSTATUS_MASK;
        end
    endfunction

    function automatic [31:0] compose_senvcfg(
        input logic [31:0] menvcfg_value,
        input logic [31:0] senvcfg_value
    );
        logic [31:0] view_value;
        begin
            view_value = senvcfg_value & SENVCFG_WRITABLE_MASK;
            if (!menvcfg_value[`ENVCFG_SSE_BIT]) begin
                view_value[`ENVCFG_SSE_BIT] = 1'b0;
            end
            compose_senvcfg = view_value;
        end
    endfunction

    function automatic [31:0] sanitize_mstatus(input logic [31:0] new_value);
        logic [31:0] sanitized;
        begin
            sanitized = new_value & MSTATUS_WRITABLE_MASK;
            if (sanitized[MPP_HIGH:MPP_LOW] == 2'b10) begin
                sanitized[MPP_HIGH:MPP_LOW] = `PRV_U;
            end
            sanitize_mstatus = sanitized;
        end
    endfunction

    function automatic [31:0] sanitize_mstatush(input logic [31:0] new_value);
        begin
            sanitize_mstatush = new_value & MSTATUSH_WRITABLE_MASK;
        end
    endfunction

    function automatic [31:0] sanitize_menvcfg(input logic [31:0] new_value);
        begin
            sanitize_menvcfg = new_value & MENVCFG_WRITABLE_MASK;
        end
    endfunction

    function automatic [31:0] sanitize_senvcfg(
        input logic [31:0] new_value,
        input logic [31:0] menvcfg_value
    );
        logic [31:0] sanitized;
        begin
            sanitized = new_value & SENVCFG_WRITABLE_MASK;
            if (!menvcfg_value[`ENVCFG_SSE_BIT]) begin
                sanitized[`ENVCFG_SSE_BIT] = 1'b0;
            end
            sanitize_senvcfg = sanitized;
        end
    endfunction

    function automatic [31:0] sanitize_mseccfg(input logic [31:0] new_value);
        begin
            sanitize_mseccfg = new_value & MSECCFG_WRITABLE_MASK;
        end
    endfunction

    function automatic [31:0] update_sstatus_view(
        input logic [31:0] old_mstatus,
        input logic [31:0] new_sstatus
    );
        logic [31:0] merged;
        begin
            merged = old_mstatus;
            merged[SIE_BIT] = new_sstatus[SIE_BIT];
            merged[SPIE_BIT] = new_sstatus[SPIE_BIT];
            merged[SPP_BIT] = new_sstatus[SPP_BIT];
            merged[SPELP_BIT] = new_sstatus[SPELP_BIT];
            update_sstatus_view = merged;
        end
    endfunction

    function automatic logic shadow_stack_enabled(
        input logic [ 1:0] priv,
        input logic [31:0] menvcfg_value,
        input logic [31:0] senvcfg_value
    );
        begin
            unique case (priv)
                `PRV_S: shadow_stack_enabled = menvcfg_value[`ENVCFG_SSE_BIT];
                `PRV_U:
                shadow_stack_enabled = menvcfg_value[`ENVCFG_SSE_BIT] &&
                                       senvcfg_value[`ENVCFG_SSE_BIT];
                default: shadow_stack_enabled = 1'b0;
            endcase
        end
    endfunction

    function automatic logic landing_pad_enabled(
        input logic [ 1:0] priv,
        input logic [31:0] menvcfg_value,
        input logic [31:0] senvcfg_value,
        input logic [31:0] mseccfg_value
    );
        begin
            unique case (priv)
                `PRV_M: landing_pad_enabled = mseccfg_value[`MSECCFG_MLPE_BIT];
                `PRV_S: landing_pad_enabled = menvcfg_value[`ENVCFG_LPE_BIT];
                `PRV_U: landing_pad_enabled = senvcfg_value[`ENVCFG_LPE_BIT];
                default: landing_pad_enabled = 1'b0;
            endcase
        end
    endfunction

    function automatic logic take_delegated_trap(
        input logic [ 1:0] priv,
        input logic [31:0] cause,
        input logic [31:0] medeleg_value,
        input logic [31:0] mideleg_value
    );
        begin
            if (priv == `PRV_M) begin
                take_delegated_trap = 1'b0;
            end else if (cause[31]) begin
                take_delegated_trap = mideleg_value[cause[4:0]];
            end else begin
                take_delegated_trap = medeleg_value[cause[4:0]];
            end
        end
    endfunction

    logic [31:0] senvcfg_view;
    assign senvcfg_view = compose_senvcfg(menvcfg, senvcfg);

    // CSR 读取逻辑
    always_comb begin
        case (csr_addr)
            `CSR_SSP:                  csr_rdata = ssp;
            `CSR_SSTATUS:              csr_rdata = compose_sstatus(mstatus);
            `CSR_SIE:                  csr_rdata = mie & mideleg;
            `CSR_STVEC:                csr_rdata = stvec;
            `CSR_SENVCFG:              csr_rdata = senvcfg_view;
            `CSR_SSCRATCH:             csr_rdata = sscratch;
            `CSR_SEPC:                 csr_rdata = sepc;
            `CSR_SCAUSE:               csr_rdata = scause;
            `CSR_STVAL:                csr_rdata = stval;
            `CSR_SIP:                  csr_rdata = mip & mideleg;
            `CSR_SATP:                 csr_rdata = satp;
            `CSR_MSTATUS:              csr_rdata = mstatus;
            `CSR_MISA:                 csr_rdata = misa;
            `CSR_MEDELEG:              csr_rdata = medeleg;
            `CSR_MIDELEG:              csr_rdata = mideleg;
            `CSR_MIE:                  csr_rdata = mie;
            `CSR_MTVEC:                csr_rdata = mtvec;
            `CSR_MSTATUSH:             csr_rdata = mstatush;
            `CSR_MENVCFG:              csr_rdata = menvcfg;
            `CSR_MSCRATCH:             csr_rdata = mscratch;
            `CSR_MEPC:                 csr_rdata = mepc;
            `CSR_MCAUSE:               csr_rdata = mcause;
            `CSR_MTVAL:                csr_rdata = mtval;
            `CSR_MIP:                  csr_rdata = mip;
            `CSR_MSECCFG:              csr_rdata = mseccfg;
            `CSR_MCYCLE, `CSR_CYCLE:   csr_rdata = mcycle[31:0];
            `CSR_MCYCLEH, `CSR_CYCLEH: csr_rdata = mcycle[63:32];
            default:                   csr_rdata = 32'b0;
        endcase
    end

    // 根据操作类型计算新的 CSR 值
    logic [31:0] csr_new_value;
    always_comb begin
        case (csr_op)
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI: csr_new_value = csr_wdata;
            `FUNCT3_CSRRS, `FUNCT3_CSRRSI: csr_new_value = csr_rdata | csr_wdata;
            `FUNCT3_CSRRC, `FUNCT3_CSRRCI: csr_new_value = csr_rdata & (~csr_wdata);
            default:                       csr_new_value = csr_rdata;
        endcase
    end

    logic delegated_exception;
    assign delegated_exception = exception_valid &&
                                 take_delegated_trap(priv_mode, exception_cause, medeleg, mideleg);

    logic [1:0] mret_target_priv;
    logic [1:0] sret_target_priv;
    assign mret_target_priv = mstatus[MPP_HIGH:MPP_LOW];
    assign sret_target_priv = mstatus[SPP_BIT] ? `PRV_S : `PRV_U;

    // CSR 写入、异常进入和 xRET 恢复
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mstatus   <= 32'h0000_1800;
            mstatush  <= 32'h0000_0000;
            mtvec     <= 32'h0114_5140;
            mepc      <= 32'h0000_0000;
            mcause    <= 32'h0000_0000;
            mscratch  <= 32'h0000_0000;
            mtval     <= 32'h0000_0000;
            mie       <= 32'h0000_0000;
            mip       <= 32'h0000_0000;
            misa      <= 32'h4014_0100;  // RV32I + S + U
            medeleg   <= 32'h0000_0000;
            mideleg   <= 32'h0000_0000;
            menvcfg   <= 32'h0000_0000;
            mseccfg   <= 32'h0000_0000;
            stvec     <= 32'h0114_5140;
            senvcfg   <= 32'h0000_0000;
            sepc      <= 32'h0000_0000;
            scause    <= 32'h0000_0000;
            sscratch  <= 32'h0000_0000;
            stval     <= 32'h0000_0000;
            satp      <= 32'h0000_0000;
            ssp       <= 32'h0000_0000;
            elp_state <= 1'b0;
            priv_mode <= `PRV_M;
        end else if (exception_valid) begin
            if (delegated_exception) begin
                sepc <= align_epc(exception_pc);
                scause <= exception_cause;
                stval <= exception_tval;
                mstatus[SPIE_BIT] <= mstatus[SIE_BIT];
                mstatus[SIE_BIT] <= 1'b0;
                mstatus[SPP_BIT] <= (priv_mode == `PRV_S);
                mstatus[SPELP_BIT] <= elp_state;
                elp_state <= 1'b0;
                priv_mode <= `PRV_S;
            end else begin
                mepc <= align_epc(exception_pc);
                mcause <= exception_cause;
                mtval <= exception_tval;
                mstatus[MPIE_BIT] <= mstatus[MIE_BIT];
                mstatus[MIE_BIT] <= 1'b0;
                mstatus[MPP_HIGH:MPP_LOW] <= priv_mode;
                mstatush[MPELP_BIT] <= elp_state;
                elp_state <= 1'b0;
                priv_mode <= `PRV_M;
            end
        end else if (mret_valid) begin
            priv_mode <= mret_target_priv;
            mstatus[MIE_BIT] <= mstatus[MPIE_BIT];
            mstatus[MPIE_BIT] <= 1'b1;
            mstatus[MPP_HIGH:MPP_LOW] <= `PRV_U;
            elp_state <= landing_pad_enabled(mret_target_priv, menvcfg, senvcfg, mseccfg) ?
                         mstatush[MPELP_BIT] : 1'b0;
            mstatush[MPELP_BIT] <= 1'b0;
        end else if (sret_valid) begin
            priv_mode <= sret_target_priv;
            mstatus[SIE_BIT] <= mstatus[SPIE_BIT];
            mstatus[SPIE_BIT] <= 1'b1;
            mstatus[SPP_BIT] <= 1'b0;
            elp_state <= landing_pad_enabled(sret_target_priv, menvcfg, senvcfg, mseccfg) ?
                         mstatus[SPELP_BIT] : 1'b0;
            mstatus[SPELP_BIT] <= 1'b0;
        end else if (ssp_update_valid) begin
            ssp <= ssp_update_data;
        end else if (elp_update_valid) begin
            elp_state <= elp_update_expected;
        end else if (csr_we) begin
            case (csr_addr)
                `CSR_SSP:      ssp <= csr_new_value;
                `CSR_SSTATUS:  mstatus <= update_sstatus_view(mstatus, csr_new_value);
                `CSR_SIE:      mie <= (mie & ~mideleg) | (csr_new_value & mideleg);
                `CSR_STVEC:    stvec <= align_trap_vector(csr_new_value);
                `CSR_SENVCFG:  senvcfg <= sanitize_senvcfg(csr_new_value, menvcfg);
                `CSR_SSCRATCH: sscratch <= csr_new_value;
                `CSR_SEPC:     sepc <= align_epc(csr_new_value);
                `CSR_SCAUSE:   scause <= csr_new_value;
                `CSR_STVAL:    stval <= csr_new_value;
                `CSR_SIP:      mip <= (mip & ~mideleg) | (csr_new_value & mideleg);
                `CSR_SATP:     satp <= csr_new_value;
                `CSR_MSTATUS:  mstatus <= sanitize_mstatus(csr_new_value);
                `CSR_MEDELEG:  medeleg <= csr_new_value;
                `CSR_MIDELEG:  mideleg <= csr_new_value;
                `CSR_MIE:      mie <= csr_new_value;
                `CSR_MTVEC:    mtvec <= align_trap_vector(csr_new_value);
                `CSR_MSTATUSH: mstatush <= sanitize_mstatush(csr_new_value);
                `CSR_MENVCFG:  menvcfg <= sanitize_menvcfg(csr_new_value);
                `CSR_MSCRATCH: mscratch <= csr_new_value;
                `CSR_MEPC:     mepc <= align_epc(csr_new_value);
                `CSR_MCAUSE:   mcause <= csr_new_value;
                `CSR_MTVAL:    mtval <= csr_new_value;
                `CSR_MIP:      mip <= csr_new_value;
                `CSR_MSECCFG:  mseccfg <= sanitize_mseccfg(csr_new_value);
                default:       ;
            endcase
        end
    end

    // mcycle 计数器
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

    assign trap_to_mmode = exception_valid && !delegated_exception;
    assign trap_target = delegated_exception ? align_trap_vector(stvec) : align_trap_vector(mtvec);
    assign xret_target = mret_valid ? mepc : sepc;

    assign current_priv_mode = priv_mode;
    assign mstatus_tsr = mstatus[TSR_BIT];
    assign mstatus_tvm = mstatus[TVM_BIT];
    assign current_sse_enabled = shadow_stack_enabled(priv_mode, menvcfg, senvcfg_view);
    assign current_lpe_enabled = landing_pad_enabled(priv_mode, menvcfg, senvcfg_view, mseccfg);
    assign elp_expected = elp_state;
    assign ssp_value = ssp;

endmodule
