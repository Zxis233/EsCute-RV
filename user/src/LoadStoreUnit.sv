`include "include/defines.svh"

module LoadStoreUnit (
    input  logic [ 3:0] sl_type,
    input  logic [31:0] addr,
    input  logic [31:0] wdata,
    output logic [ 3:0] wstrb,    // 按位写使能
    output logic [31:0] rdata
);
    // [TODO] 不同的访存类型处理
    logic is_load, is_load_unsigned;
    always_comb begin
        is_load          = (sl_type[3] == 1'b0);
        is_load_unsigned = (sl_type[2] == 1'b1);
    end

    always_comb begin
        if (is_load) begin
            // 临时读取结果
            logic [ 7:0] b;
            logic [15:0] h;
            logic [31:0] raw;  // 未扩展前的“自然宽度数据”

            b   = 8'b0;
            h   = 16'b0;
            raw = 32'b0;

            case (sl_type[1:0])
                2'b01: begin  // MEM_LB/MEM_LBU
                    unique case (addr[1:0])
                        2'b00: b = wdata[7:0];
                        2'b01: b = wdata[15:8];
                        2'b10: b = wdata[23:16];
                        2'b11: b = wdata[31:24];
                        // default: b = 32'b0;
                    endcase
                    raw = {24'b0, b};
                end
                2'b10: begin  // MEM_LH/MEM_LHU
                    unique case (addr[1])
                        1'b0: h = wdata[15:0];
                        1'b1: h = wdata[31:16];
                        // default: h = 16'b0;
                    endcase
                    raw = {16'b0, h};
                end
                2'b11: begin  // MEM_LW
                    raw = wdata;
                end
                default: raw = 32'b0;  // MEM_NOP
            endcase

            // 符号扩展或零扩展
            if (is_load_unsigned) begin
                rdata = raw;  // 零扩展
            end else begin
                case (sl_type[1:0])
                    2'b01:   rdata = {{24{raw[7]}}, raw[7:0]};  // MEM_LB
                    2'b10:   rdata = {{16{raw[15]}}, raw[15:0]};  // MEM_LH
                    2'b11:   rdata = raw;  // MEM_LW
                    default: rdata = 32'b0;  // MEM_NOP
                endcase
            end

        end else begin
            // Store指令 直接传递数据
            // [TODO] 按位写使能
            rdata = wdata;

            case (sl_type[1:0])
                2'b01: begin  // MEM_SB
                    unique case (addr[1:0])
                        2'b00: wstrb = 4'b0001;
                        2'b01: wstrb = 4'b0010;
                        2'b10: wstrb = 4'b0100;
                        2'b11: wstrb = 4'b1000;
                        // default: wstrb = 4'b0000;
                    endcase
                end
                2'b10: begin  // MEM_SH
                    unique case (addr[1])
                        1'b0: wstrb = 4'b0011;
                        1'b1: wstrb = 4'b1100;
                        // default: wstrb = 4'b0000;
                    endcase
                end
                2'b11: begin  // MEM_SW
                    wstrb = 4'b1111;
                end
                default: wstrb = 4'b0000;  // MEM_NOP
            endcase
        end
    end

endmodule
