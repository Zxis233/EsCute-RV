`include "include/defines.svh"

// StoreUnit模块 - 专门用于MEM级的Store操作
// 负责处理SB/SH/SW的字节对齐和写使能生成
module StoreUnit (
    input  logic [ 3:0] sl_type,       // 存取类型
    input  logic [31:0] addr,          // 地址（用于计算字节偏移）
    input  logic [31:0] store_data_i,  // 要存储的数据（来自rs2）
    output logic [31:0] store_data_o,  // 对齐后的数据
    input  logic        dram_we,       // 写使能输入
    output logic [ 3:0] wstrb          // 按位写使能
);

    always_comb begin
        // 默认值
        wstrb        = 4'b0000;
        store_data_o = 32'b0;

        if (dram_we) begin
            if (sl_type == `MEM_SSPUSH) begin
                wstrb        = 4'b1111;
                store_data_o = store_data_i;
            end else begin
                unique case (sl_type[1:0])
                2'b01: begin  // SB
                    logic [4:0] shift;
                    shift = {addr[1:0], 3'b000};  // addr[1:0] * 8

                    // 写使能
                    unique case (addr[1:0])
                        2'b00:   wstrb = 4'b0001;
                        2'b01:   wstrb = 4'b0010;
                        2'b10:   wstrb = 4'b0100;
                        2'b11:   wstrb = 4'b1000;
                        default: wstrb = 4'b0000;
                    endcase

                    // 把 byte 放到对应 byte lane
                    store_data_o = ({24'b0, store_data_i[7:0]} << shift);
                end

                2'b10: begin  // SH
                    logic [4:0] shift;
                    shift = {addr[1], 4'b0000};  // addr[1] ? 16 : 0

                    // 写使能
                    unique case (addr[1])
                        1'b0:    wstrb = 4'b0011;
                        1'b1:    wstrb = 4'b1100;
                        default: wstrb = 4'b0000;
                    endcase

                    // 把 halfword 放到对应位置
                    store_data_o = ({16'b0, store_data_i[15:0]} << shift);
                end

                2'b11: begin  // SW
                    wstrb        = 4'b1111;
                    store_data_o = store_data_i;
                end

                default: begin
                    wstrb        = 4'b0000;
                    store_data_o = 32'b0;
                end
                endcase
            end
        end
    end

`ifdef DEBUG
    logic [31:0] sl_type_ascii;
    always_comb begin
        case (sl_type)
            `MEM_SB:     sl_type_ascii = "SB  ";
            `MEM_SH:     sl_type_ascii = "SH  ";
            `MEM_SW:     sl_type_ascii = "SW  ";
            `MEM_SSPUSH: sl_type_ascii = "SSPU";
            default:     sl_type_ascii = "----";
        endcase
    end
`endif

endmodule
