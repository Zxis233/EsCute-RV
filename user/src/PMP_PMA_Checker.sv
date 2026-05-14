`include "include/defines.svh"

module PMP_PMA_Checker #(
    parameter logic [31:0] PMA_BASE  = `PMA_LOW_MEM_BASE,
    parameter logic [31:0] PMA_LIMIT = `PMA_LOW_MEM_LIMIT
) (
    input  logic [31:0] addr,
    input  logic [ 1:0] access_type,
    input  logic [ 1:0] access_size,
    input  logic [ 1:0] priv_mode,
    input  logic [31:0] pmpcfg0,
    input  logic [31:0] pmpaddr0,
    output logic        access_fault
);

    function automatic [5:0] count_trailing_ones(input logic [31:0] value);
        integer i;
        logic   still_counting;
        begin
            count_trailing_ones = 6'd0;
            still_counting      = 1'b1;
            for (i = 0; i < 32; i = i + 1) begin
                if (still_counting && value[i]) begin
                    count_trailing_ones = count_trailing_ones + 6'd1;
                end else begin
                    still_counting = 1'b0;
                end
            end
        end
    endfunction

    logic [ 7:0] cfg0;
    logic [ 7:0] pmp_a;
    logic [32:0] access_bytes;
    logic [32:0] access_end_ext;
    logic        pma_ok;

    assign cfg0 = pmpcfg0[7:0];
    assign pmp_a = cfg0 & `PMP_A_MASK;

    always_comb begin
        unique case (access_size)
            `PMP_SIZE_1B: access_bytes = 33'd1;
            `PMP_SIZE_2B: access_bytes = 33'd2;
            default:      access_bytes = 33'd4;
        endcase
    end

    assign access_end_ext = {1'b0, addr} + access_bytes - 33'd1;
    assign pma_ok = ({1'b0, addr} >= {1'b0, PMA_BASE}) &&
                    (access_end_ext < {1'b0, PMA_LIMIT});

    logic [ 5:0] napot_ones;
    logic [31:0] napot_mask;
    logic [31:0] napot_base;
    logic [32:0] tor_top_ext;
    logic [32:0] na4_base_ext;
    logic [32:0] na4_limit_ext;
    logic [32:0] napot_base_ext;
    logic [32:0] napot_limit_ext;
    logic        pmp_active;
    logic        pmp_match;
    logic        pmp_perm_ok;
    logic        pmp_applies;

    assign napot_ones = count_trailing_ones(pmpaddr0);
    assign tor_top_ext = ({1'b0, pmpaddr0} << 2);
    assign na4_base_ext = {1'b0, pmpaddr0[29:0], 2'b00};
    assign na4_limit_ext = na4_base_ext + 33'd4;
    assign napot_base_ext = {1'b0, napot_base};
    assign napot_limit_ext = {1'b0, napot_base} + {1'b0, napot_mask} + 33'd1;
    assign pmp_active = (pmp_a != `PMP_A_OFF);
    assign pmp_applies = (priv_mode != `PRV_M) || ((cfg0 & `PMP_L) != 8'b0);

    always_comb begin
        if (napot_ones >= 6'd29) begin
            napot_mask = 32'hFFFF_FFFF;
        end else begin
            napot_mask = (32'h1 << (napot_ones + 6'd3)) - 32'h1;
        end
        napot_base = (pmpaddr0 << 2) & ~napot_mask;
    end

    always_comb begin
        unique case (pmp_a)
            `PMP_A_TOR: begin
                pmp_match = ({1'b0, addr} < tor_top_ext) &&
                            (access_end_ext < tor_top_ext);
            end
            `PMP_A_NA4: begin
                pmp_match = ({1'b0, addr} >= na4_base_ext) &&
                            (access_end_ext < na4_limit_ext);
            end
            `PMP_A_NAPOT: begin
                if (napot_ones >= 6'd29) begin
                    pmp_match = 1'b1;
                end else begin
                    pmp_match = ({1'b0, addr} >= napot_base_ext) &&
                                (access_end_ext < napot_limit_ext);
                end
            end
            default: pmp_match = 1'b0;
        endcase
    end

    always_comb begin
        unique case (access_type)
            `PMP_ACC_FETCH: pmp_perm_ok = ((cfg0 & `PMP_X) != 8'b0);
            `PMP_ACC_LOAD:  pmp_perm_ok = ((cfg0 & `PMP_R) != 8'b0);
            `PMP_ACC_STORE: pmp_perm_ok = ((cfg0 & `PMP_W) != 8'b0);
            default:        pmp_perm_ok = 1'b0;
        endcase
    end

    always_comb begin
        if (!pma_ok) begin
            access_fault = 1'b1;
        end else if (!pmp_active) begin
            access_fault = 1'b0;
        end else if (!pmp_applies) begin
            access_fault = 1'b0;
        end else if (pmp_match) begin
            access_fault = !pmp_perm_ok;
        end else begin
            access_fault = (priv_mode != `PRV_M);
        end
    end

endmodule
