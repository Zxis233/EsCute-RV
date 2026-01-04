// LoadUnit模块 - 专门用于WB级的Load操作
// 负责处理LB/LH/LW/LBU/LHU的字节提取和符号扩展
module LoadUnit (
    input  logic [ 3:0] sl_type,      // 存取类型
    input  logic [31:0] addr,         // 地址（用于计算字节偏移）
    input  logic [31:0] load_data_i,  // 从DRAM读取的原始数据
    output logic [31:0] load_data_o   // 处理后的数据
);

    logic is_load_unsigned;
    assign is_load_unsigned = (sl_type[2] == 1'b1);

    always_comb begin
        logic [31:0] raw;
        raw         = 32'b0;
        load_data_o = 32'b0;

        // 根据 sl_type 和 addr 偏移提取数据
        case (sl_type[1:0])
            2'b01: begin  // byte
                raw = (load_data_i >> (addr[1:0] * 8)) & 32'h000000FF;
            end
            2'b10: begin  // half
                raw = (load_data_i >> (addr[1] * 16)) & 32'h0000FFFF;
            end
            2'b11: begin  // word
                raw = load_data_i;
            end
            default: raw = 32'b0;
        endcase

        // 符号扩展或零扩展
        if (is_load_unsigned) begin
            load_data_o = raw;  // 零扩展
        end else begin
            case (sl_type[1:0])
                2'b01:   load_data_o = {{24{raw[7]}}, raw[7:0]};  // LB
                2'b10:   load_data_o = {{16{raw[15]}}, raw[15:0]};  // LH
                2'b11:   load_data_o = raw;  // LW
                default: load_data_o = 32'b0;
            endcase
        end
    end

`ifdef DEBUG
    logic [31:0] sl_type_ascii;
    logic [ 1:0] select_bits;
    assign select_bits = addr[1:0];
    always_comb begin
        case (sl_type)
            `MEM_LB:  sl_type_ascii = "LB  ";
            `MEM_LH:  sl_type_ascii = "LH  ";
            `MEM_LW:  sl_type_ascii = "LW  ";
            `MEM_LBU: sl_type_ascii = "LBU ";
            `MEM_LHU: sl_type_ascii = "LHU ";
            default:  sl_type_ascii = "----";
        endcase
    end
`endif

endmodule
