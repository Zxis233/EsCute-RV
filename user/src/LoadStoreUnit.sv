// LoadStoreUnit模块横跨MEM和WB级
// [HACK] 拆分为两部分以简化综合后设计
module LoadStoreUnit (
    input  logic [ 3:0] sl_type,
    input  logic [31:0] addr,
    input  logic [31:0] load_data_i,
    output logic [31:0] load_data_o,
    input  logic [31:0] store_data_i,
    output logic [31:0] store_data_o,
    input  logic        dram_we,
    output logic [ 3:0] wstrb          // 按位写使能
);
    // [TODO] 不同的访存类型处理
    logic is_load, is_load_unsigned;
    always_comb begin
        is_load          = (sl_type[3] == 1'b0);
        is_load_unsigned = (sl_type[2] == 1'b1);
    end

    always_comb begin
        // 默认值，保证所有组合输出都有驱动，避免锁存
        wstrb        = 4'b0000;
        load_data_o  = 32'b0;
        store_data_o = 32'b0;

        if (is_load) begin
            // 临时变量（也可以放在模块层）
            logic [31:0] raw;
            raw = 32'b0;
            // 提取 raw，根据 sl_type 和 addr 偏移
            case (sl_type[1:0])
                2'b01: begin  // byte
                    // 右移到最低位再掩码
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

            // 扩展
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

        end else if (dram_we) begin
            logic [15:0] half_byte;
            logic [ 4:0] shift;  // 移位量 0, 8, 16, 24
            shift = 4'b0;
            unique case (sl_type[1:0])
                2'b01: begin  // SB
                    logic [7:0] byte_val;

                    half_byte = store_data_i[7:0];  // 只关心最低 8 位
                    shift     = {addr[1:0], 3'b000};  // addr[1:0] * 8

                    // 写使能
                    unique case (addr[1:0])
                        2'b00:   wstrb = 4'b0001;
                        2'b01:   wstrb = 4'b0010;
                        2'b10:   wstrb = 4'b0100;
                        2'b11:   wstrb = 4'b1000;
                        default: wstrb = 4'b0000;
                    endcase

                    // 把 byte_val 放到对应 byte lane
                    store_data_o = ({24'b0, half_byte[7:0]} << shift);
                end

                2'b10: begin  // SH
                    logic [15:0] half_val;

                    half_byte = store_data_i[15:0];  // 只关心最低 16 位
                    shift     = {addr[1], 4'b0000};  // addr[1] ? 16 : 0

                    // 写使能
                    unique case (addr[1])
                        1'b0:    wstrb = 4'b0011;
                        1'b1:    wstrb = 4'b1100;
                        default: wstrb = 4'b0000;
                    endcase

                    // 把 half_val 放到低/高 halfword
                    store_data_o = ({16'b0, half_byte} << shift);
                end

                2'b11: begin  // SW
                    wstrb        = 4'b1111;
                    store_data_o = store_data_i;  // 直接写整个 word
                    half_byte    = 16'b0;
                end

                default: begin
                    wstrb        = 4'b0000;
                    store_data_o = 32'b0;
                    half_byte    = 16'b0;
                end
            endcase
        end else begin
            // 非 load/非 store：保持默认 wstrb=0, store_data_o 已初始化为 0
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
            `MEM_SB:  sl_type_ascii = "SB  ";
            `MEM_SH:  sl_type_ascii = "SH  ";
            `MEM_SW:  sl_type_ascii = "SW  ";
            default:  sl_type_ascii = "UNKN";
        endcase
    end
`endif

endmodule
