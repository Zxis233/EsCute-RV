`include "include/defines.svh"

// CSR (Control and Status Register) Module
// Implements Zicsr extension for RV32I
// Supports machine-level CSRs and basic privilege mode switching
module CSR (
    input logic clk,
    input logic rst_n,

    // CSR instruction interface
    input  logic        csr_we,     // CSR write enable
    input  logic [11:0] csr_addr,   // CSR address
    input  logic [31:0] csr_wdata,  // Data to write to CSR
    input  logic [ 2:0] csr_op,     // CSR operation type (funct3)
    output logic [31:0] csr_rdata,  // Data read from CSR

    // Exception/trap interface
    input logic exception_valid,  // Exception occurred
    input logic [31:0] exception_pc,  // PC of the instruction causing exception
    input logic [31:0] exception_cause,  // Exception cause code
    input logic [31:0]
        exception_tval,  // Exception trap value (e.g., illegal instruction encoding)
    // MRET interface
    input logic mret_valid,  // MRET instruction executed

    // Trap output
    output logic        trap_to_mmode,  // Signal to redirect to trap handler
    output logic [31:0] trap_target,    // Trap handler address (mtvec)
    output logic [31:0] mret_target     // Return address from trap (mepc)
);

    // Machine-level CSRs
    // mstatus - Machine Status Register
    logic [31:0] mstatus;
    // mtvec - Machine Trap-Vector Base Address
    logic [31:0] mtvec;
    // mepc - Machine Exception Program Counter
    logic [31:0] mepc;
    // mcause - Machine Cause Register
    logic [31:0] mcause;
    // mscratch - Machine Scratch Register
    logic [31:0] mscratch;
    // mtval - Machine Trap Value Register
    logic [31:0] mtval;
    // mie - Machine Interrupt Enable
    logic [31:0] mie;
    // mip - Machine Interrupt Pending
    logic [31:0] mip;
    // MISA
    logic [31:0] misa;
    // mcycle - Machine Cycle Counter (64-bit, split into low and high)
    logic [63:0] mcycle;
    // MISA is hardcoded for RV32I with Zicsr and Zmmul
    // always_comb begin
    //     misa = 32'h4000_0110;  // RV32I (base ISA) + Zicsr + Zmmul
    // end

    // mstatus bit positions
    localparam integer MIE_BIT = 3;  // Machine Interrupt Enable
    localparam integer MPIE_BIT = 7;  // Machine Previous Interrupt Enable
    localparam integer MPP_LOW = 11;  // Machine Previous Privilege (low bit)
    localparam integer MPP_HIGH = 12;  // Machine Previous Privilege (high bit)

    // CSR read logic
    always_comb begin
        case (csr_addr)
            `CSR_MSTATUS:  csr_rdata = mstatus;
            `CSR_MTVEC:    csr_rdata = mtvec;
            `CSR_MEPC:     csr_rdata = mepc;
            `CSR_MCAUSE:   csr_rdata = mcause;
            `CSR_MIE:      csr_rdata = mie;
            `CSR_MIP:      csr_rdata = mip;
            `CSR_MSCRATCH: csr_rdata = mscratch;  // mscratch
            `CSR_MTVAL:    csr_rdata = mtval;  // mtval
            `CSR_MISA:     csr_rdata = misa;
            `CSR_MCYCLE,
            `CSR_CYCLE:    csr_rdata = mcycle[31:0];   // mcycle low 32 bits
            `CSR_MCYCLEH,
            `CSR_CYCLEH:   csr_rdata = mcycle[63:32];  // mcycle high 32 bits
            default:       csr_rdata = 32'b0;
        endcase
    end

    // Calculate new CSR value based on operation type
    logic [31:0] csr_new_value;
    always_comb begin
        case (csr_op)
            `FUNCT3_CSRRW, `FUNCT3_CSRRWI: csr_new_value = csr_wdata;  // Write
            `FUNCT3_CSRRS, `FUNCT3_CSRRSI: csr_new_value = csr_rdata | csr_wdata;  // Set bits
            `FUNCT3_CSRRC, `FUNCT3_CSRRCI: csr_new_value = csr_rdata & (~csr_wdata);  // Clear bits
            default: csr_new_value = csr_rdata;
        endcase
    end

    // CSR write logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset values
            mstatus  <= 32'h0000_1800;  // MPP = 11 (Machine mode)
            mtvec    <= 32'h0000_0000;  // Default trap handler at 0
            mepc     <= 32'h0000_0000;
            mcause   <= 32'h0000_0000;
            mscratch <= 32'h0000_0000;
            mtval    <= 32'h0000_0000;
            mie      <= 32'h0000_0000;
            mip      <= 32'h0000_0000;
            misa     <= 32'h4000_0100;  // RV32I
        end else if (exception_valid) begin
            // On exception: save state and update CSRs
            mepc                      <= exception_pc;
            mcause                    <= exception_cause;
            // Save trap value (illegal instruction encoding or address)
            mtval                     <= exception_tval;
            // Update mstatus: save MIE to MPIE, set MPP to current privilege (always M-mode for now)
            mstatus[MPIE_BIT]         <= mstatus[MIE_BIT];  // MPIE = MIE
            mstatus[MIE_BIT]          <= 1'b0;  // Disable interrupts
            mstatus[MPP_HIGH:MPP_LOW] <= 2'b11;  // MPP = Machine mode
        end else if (mret_valid) begin
            // On MRET: restore state
            mstatus[MIE_BIT]          <= mstatus[MPIE_BIT];  // MIE = MPIE
            mstatus[MPIE_BIT]         <= 1'b1;  // MPIE = 1
            mstatus[MPP_HIGH:MPP_LOW] <= 2'b11;  // MPP = Machine (since we only support M-mode)
        end else if (csr_we) begin
            // Normal CSR write
            case (csr_addr)
                `CSR_MSTATUS:  mstatus <= csr_new_value & 32'h0000_1888;  // Mask writable bits
                `CSR_MTVEC:    mtvec <= {csr_new_value[31:2], 2'b00};  // Align to 4 bytes
                `CSR_MEPC:     mepc <= {csr_new_value[31:2], 2'b00};  // Align to 4 bytes
                `CSR_MCAUSE:   mcause <= csr_new_value;
                `CSR_MIE:      mie <= csr_new_value;
                `CSR_MSCRATCH: mscratch <= csr_new_value;  // mscratch
                `CSR_MTVAL:    mtval <= csr_new_value;  // mtval
                `CSR_MISA:     misa <= misa;  // Read-only
                default:       ;
            endcase
        end
    end

    // mcycle counter - increments every clock cycle
    // mcycle can be written via CSR instructions (MCYCLE/MCYCLEH)
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

    // Trap and return signals
    assign trap_to_mmode = exception_valid;
    assign trap_target   = {mtvec[31:2], 2'b00};  // Use direct mode (MODE=0)
    assign mret_target   = mepc;

endmodule
