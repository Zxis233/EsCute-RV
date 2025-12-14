// Ascon-AEAD128 解密模块
// 用于CPU指令流解密
`include "include/defines.svh"

// ============================================================================
// 简化的Ascon解密模块 - 用于流水线取指级
// 使用CTR模式进行流式解密，无需完整的AEAD标签验证
// ============================================================================

module ascon_decrypt #(
    parameter [127:0] KEY   = 128'h0123456789ABCDEF0123456789ABCDEF,
    parameter [127:0] NONCE = 128'hFEDCBA9876543210FEDCBA9876543210
) (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        decrypt_enable,   // 全局解密使能
    input  wire [31:0] pc,               // 程序计数器
    input  wire [31:0] encrypted_instr,  // 加密指令
    output wire [31:0] decrypted_instr   // 解密指令
);

    // 轮常量
    localparam [63:0] RC_0 = 64'h00000000000000f0;
    localparam [63:0] RC_1 = 64'h00000000000000e1;
    localparam [63:0] RC_2 = 64'h00000000000000d2;
    localparam [63:0] RC_3 = 64'h00000000000000c3;
    localparam [63:0] RC_4 = 64'h00000000000000b4;
    localparam [63:0] RC_5 = 64'h00000000000000a5;

    wire [31:0] block_counter;
    assign block_counter = pc >> 2;  // 字地址

    // 状态变量 - 使用独立的64位wire而非数组
    wire [63:0] s0_init, s1_init, s2_init, s3_init, s4_init;

    // 初始化状态
    assign s0_init = {KEY[127:96], block_counter};
    assign s1_init = KEY[95:32];
    assign s2_init = {KEY[31:0], NONCE[127:96]};
    assign s3_init = NONCE[95:32];
    assign s4_init = {NONCE[31:0], 32'hDEADBEEF};

    // 右旋转函数宏 - 使用define实现
    `define ROTR64(x, n) ({x[(n)-1:0], x[63:(n)]})

    // ========== 轮1 ==========
    wire [63:0] r1_t0, r1_t1, r1_t2, r1_t3, r1_t4;
    wire [63:0] r1_s0, r1_s1, r1_s2, r1_s3, r1_s4;
    wire [63:0] r1_u0, r1_u1, r1_u2, r1_u3, r1_u4;
    wire [63:0] r1_o0, r1_o1, r1_o2, r1_o3, r1_o4;

    assign r1_t0 = s0_init;
    assign r1_t1 = s1_init;
    assign r1_t2 = s2_init ^ RC_0;
    assign r1_t3 = s3_init;
    assign r1_t4 = s4_init;

    assign r1_s0 = r1_t0 ^ r1_t4;
    assign r1_s1 = r1_t1;
    assign r1_s2 = r1_t2 ^ r1_t1;
    assign r1_s3 = r1_t3;
    assign r1_s4 = r1_t4 ^ r1_t3;

    assign r1_u0 = r1_s0 ^ (~r1_s1 & r1_s2);
    assign r1_u1 = r1_s1 ^ (~r1_s2 & r1_s3);
    assign r1_u2 = r1_s2 ^ (~r1_s3 & r1_s4);
    assign r1_u3 = r1_s3 ^ (~r1_s4 & r1_s0);
    assign r1_u4 = r1_s4 ^ (~r1_s0 & r1_s1);

    wire [63:0] r1_v0, r1_v1, r1_v2, r1_v3, r1_v4;
    assign r1_v1 = r1_u1 ^ r1_u0;
    assign r1_v3 = r1_u3 ^ r1_u2;
    assign r1_v0 = r1_u0 ^ r1_u4;
    assign r1_v2 = ~r1_u2;
    assign r1_v4 = r1_u4;

    assign r1_o0 = r1_v0 ^ `ROTR64(r1_v0, 19) ^ `ROTR64(r1_v0, 28);
    assign r1_o1 = r1_v1 ^ `ROTR64(r1_v1, 61) ^ `ROTR64(r1_v1, 39);
    assign r1_o2 = r1_v2 ^ `ROTR64(r1_v2, 1) ^ `ROTR64(r1_v2, 6);
    assign r1_o3 = r1_v3 ^ `ROTR64(r1_v3, 10) ^ `ROTR64(r1_v3, 17);
    assign r1_o4 = r1_v4 ^ `ROTR64(r1_v4, 7) ^ `ROTR64(r1_v4, 41);

    // ========== 轮2 ==========
    wire [63:0] r2_t0, r2_t1, r2_t2, r2_t3, r2_t4;
    wire [63:0] r2_s0, r2_s1, r2_s2, r2_s3, r2_s4;
    wire [63:0] r2_u0, r2_u1, r2_u2, r2_u3, r2_u4;
    wire [63:0] r2_o0, r2_o1, r2_o2, r2_o3, r2_o4;

    assign r2_t0 = r1_o0;
    assign r2_t1 = r1_o1;
    assign r2_t2 = r1_o2 ^ RC_1;
    assign r2_t3 = r1_o3;
    assign r2_t4 = r1_o4;

    assign r2_s0 = r2_t0 ^ r2_t4;
    assign r2_s1 = r2_t1;
    assign r2_s2 = r2_t2 ^ r2_t1;
    assign r2_s3 = r2_t3;
    assign r2_s4 = r2_t4 ^ r2_t3;

    assign r2_u0 = r2_s0 ^ (~r2_s1 & r2_s2);
    assign r2_u1 = r2_s1 ^ (~r2_s2 & r2_s3);
    assign r2_u2 = r2_s2 ^ (~r2_s3 & r2_s4);
    assign r2_u3 = r2_s3 ^ (~r2_s4 & r2_s0);
    assign r2_u4 = r2_s4 ^ (~r2_s0 & r2_s1);

    wire [63:0] r2_v0, r2_v1, r2_v2, r2_v3, r2_v4;
    assign r2_v1 = r2_u1 ^ r2_u0;
    assign r2_v3 = r2_u3 ^ r2_u2;
    assign r2_v0 = r2_u0 ^ r2_u4;
    assign r2_v2 = ~r2_u2;
    assign r2_v4 = r2_u4;

    assign r2_o0 = r2_v0 ^ `ROTR64(r2_v0, 19) ^ `ROTR64(r2_v0, 28);
    assign r2_o1 = r2_v1 ^ `ROTR64(r2_v1, 61) ^ `ROTR64(r2_v1, 39);
    assign r2_o2 = r2_v2 ^ `ROTR64(r2_v2, 1) ^ `ROTR64(r2_v2, 6);
    assign r2_o3 = r2_v3 ^ `ROTR64(r2_v3, 10) ^ `ROTR64(r2_v3, 17);
    assign r2_o4 = r2_v4 ^ `ROTR64(r2_v4, 7) ^ `ROTR64(r2_v4, 41);

    // ========== 轮3 ==========
    wire [63:0] r3_t0, r3_t1, r3_t2, r3_t3, r3_t4;
    wire [63:0] r3_s0, r3_s1, r3_s2, r3_s3, r3_s4;
    wire [63:0] r3_u0, r3_u1, r3_u2, r3_u3, r3_u4;
    wire [63:0] r3_o0, r3_o1, r3_o2, r3_o3, r3_o4;

    assign r3_t0 = r2_o0;
    assign r3_t1 = r2_o1;
    assign r3_t2 = r2_o2 ^ RC_2;
    assign r3_t3 = r2_o3;
    assign r3_t4 = r2_o4;

    assign r3_s0 = r3_t0 ^ r3_t4;
    assign r3_s1 = r3_t1;
    assign r3_s2 = r3_t2 ^ r3_t1;
    assign r3_s3 = r3_t3;
    assign r3_s4 = r3_t4 ^ r3_t3;

    assign r3_u0 = r3_s0 ^ (~r3_s1 & r3_s2);
    assign r3_u1 = r3_s1 ^ (~r3_s2 & r3_s3);
    assign r3_u2 = r3_s2 ^ (~r3_s3 & r3_s4);
    assign r3_u3 = r3_s3 ^ (~r3_s4 & r3_s0);
    assign r3_u4 = r3_s4 ^ (~r3_s0 & r3_s1);

    wire [63:0] r3_v0, r3_v1, r3_v2, r3_v3, r3_v4;
    assign r3_v1 = r3_u1 ^ r3_u0;
    assign r3_v3 = r3_u3 ^ r3_u2;
    assign r3_v0 = r3_u0 ^ r3_u4;
    assign r3_v2 = ~r3_u2;
    assign r3_v4 = r3_u4;

    assign r3_o0 = r3_v0 ^ `ROTR64(r3_v0, 19) ^ `ROTR64(r3_v0, 28);
    assign r3_o1 = r3_v1 ^ `ROTR64(r3_v1, 61) ^ `ROTR64(r3_v1, 39);
    assign r3_o2 = r3_v2 ^ `ROTR64(r3_v2, 1) ^ `ROTR64(r3_v2, 6);
    assign r3_o3 = r3_v3 ^ `ROTR64(r3_v3, 10) ^ `ROTR64(r3_v3, 17);
    assign r3_o4 = r3_v4 ^ `ROTR64(r3_v4, 7) ^ `ROTR64(r3_v4, 41);

    // ========== 轮4 ==========
    wire [63:0] r4_t0, r4_t1, r4_t2, r4_t3, r4_t4;
    wire [63:0] r4_s0, r4_s1, r4_s2, r4_s3, r4_s4;
    wire [63:0] r4_u0, r4_u1, r4_u2, r4_u3, r4_u4;
    wire [63:0] r4_o0, r4_o1, r4_o2, r4_o3, r4_o4;

    assign r4_t0 = r3_o0;
    assign r4_t1 = r3_o1;
    assign r4_t2 = r3_o2 ^ RC_3;
    assign r4_t3 = r3_o3;
    assign r4_t4 = r3_o4;

    assign r4_s0 = r4_t0 ^ r4_t4;
    assign r4_s1 = r4_t1;
    assign r4_s2 = r4_t2 ^ r4_t1;
    assign r4_s3 = r4_t3;
    assign r4_s4 = r4_t4 ^ r4_t3;

    assign r4_u0 = r4_s0 ^ (~r4_s1 & r4_s2);
    assign r4_u1 = r4_s1 ^ (~r4_s2 & r4_s3);
    assign r4_u2 = r4_s2 ^ (~r4_s3 & r4_s4);
    assign r4_u3 = r4_s3 ^ (~r4_s4 & r4_s0);
    assign r4_u4 = r4_s4 ^ (~r4_s0 & r4_s1);

    wire [63:0] r4_v0, r4_v1, r4_v2, r4_v3, r4_v4;
    assign r4_v1 = r4_u1 ^ r4_u0;
    assign r4_v3 = r4_u3 ^ r4_u2;
    assign r4_v0 = r4_u0 ^ r4_u4;
    assign r4_v2 = ~r4_u2;
    assign r4_v4 = r4_u4;

    assign r4_o0 = r4_v0 ^ `ROTR64(r4_v0, 19) ^ `ROTR64(r4_v0, 28);
    assign r4_o1 = r4_v1 ^ `ROTR64(r4_v1, 61) ^ `ROTR64(r4_v1, 39);
    assign r4_o2 = r4_v2 ^ `ROTR64(r4_v2, 1) ^ `ROTR64(r4_v2, 6);
    assign r4_o3 = r4_v3 ^ `ROTR64(r4_v3, 10) ^ `ROTR64(r4_v3, 17);
    assign r4_o4 = r4_v4 ^ `ROTR64(r4_v4, 7) ^ `ROTR64(r4_v4, 41);

    // ========== 轮5 ==========
    wire [63:0] r5_t0, r5_t1, r5_t2, r5_t3, r5_t4;
    wire [63:0] r5_s0, r5_s1, r5_s2, r5_s3, r5_s4;
    wire [63:0] r5_u0, r5_u1, r5_u2, r5_u3, r5_u4;
    wire [63:0] r5_o0, r5_o1, r5_o2, r5_o3, r5_o4;

    assign r5_t0 = r4_o0;
    assign r5_t1 = r4_o1;
    assign r5_t2 = r4_o2 ^ RC_4;
    assign r5_t3 = r4_o3;
    assign r5_t4 = r4_o4;

    assign r5_s0 = r5_t0 ^ r5_t4;
    assign r5_s1 = r5_t1;
    assign r5_s2 = r5_t2 ^ r5_t1;
    assign r5_s3 = r5_t3;
    assign r5_s4 = r5_t4 ^ r5_t3;

    assign r5_u0 = r5_s0 ^ (~r5_s1 & r5_s2);
    assign r5_u1 = r5_s1 ^ (~r5_s2 & r5_s3);
    assign r5_u2 = r5_s2 ^ (~r5_s3 & r5_s4);
    assign r5_u3 = r5_s3 ^ (~r5_s4 & r5_s0);
    assign r5_u4 = r5_s4 ^ (~r5_s0 & r5_s1);

    wire [63:0] r5_v0, r5_v1, r5_v2, r5_v3, r5_v4;
    assign r5_v1 = r5_u1 ^ r5_u0;
    assign r5_v3 = r5_u3 ^ r5_u2;
    assign r5_v0 = r5_u0 ^ r5_u4;
    assign r5_v2 = ~r5_u2;
    assign r5_v4 = r5_u4;

    assign r5_o0 = r5_v0 ^ `ROTR64(r5_v0, 19) ^ `ROTR64(r5_v0, 28);
    assign r5_o1 = r5_v1 ^ `ROTR64(r5_v1, 61) ^ `ROTR64(r5_v1, 39);
    assign r5_o2 = r5_v2 ^ `ROTR64(r5_v2, 1) ^ `ROTR64(r5_v2, 6);
    assign r5_o3 = r5_v3 ^ `ROTR64(r5_v3, 10) ^ `ROTR64(r5_v3, 17);
    assign r5_o4 = r5_v4 ^ `ROTR64(r5_v4, 7) ^ `ROTR64(r5_v4, 41);

    // ========== 轮6 ==========
    wire [63:0] r6_t0, r6_t1, r6_t2, r6_t3, r6_t4;
    wire [63:0] r6_s0, r6_s1, r6_s2, r6_s3, r6_s4;
    wire [63:0] r6_u0, r6_u1, r6_u2, r6_u3, r6_u4;
    wire [63:0] r6_o0, r6_o1, r6_o2, r6_o3, r6_o4;

    assign r6_t0 = r5_o0;
    assign r6_t1 = r5_o1;
    assign r6_t2 = r5_o2 ^ RC_5;
    assign r6_t3 = r5_o3;
    assign r6_t4 = r5_o4;

    assign r6_s0 = r6_t0 ^ r6_t4;
    assign r6_s1 = r6_t1;
    assign r6_s2 = r6_t2 ^ r6_t1;
    assign r6_s3 = r6_t3;
    assign r6_s4 = r6_t4 ^ r6_t3;

    assign r6_u0 = r6_s0 ^ (~r6_s1 & r6_s2);
    assign r6_u1 = r6_s1 ^ (~r6_s2 & r6_s3);
    assign r6_u2 = r6_s2 ^ (~r6_s3 & r6_s4);
    assign r6_u3 = r6_s3 ^ (~r6_s4 & r6_s0);
    assign r6_u4 = r6_s4 ^ (~r6_s0 & r6_s1);

    wire [63:0] r6_v0, r6_v1, r6_v2, r6_v3, r6_v4;
    assign r6_v1 = r6_u1 ^ r6_u0;
    assign r6_v3 = r6_u3 ^ r6_u2;
    assign r6_v0 = r6_u0 ^ r6_u4;
    assign r6_v2 = ~r6_u2;
    assign r6_v4 = r6_u4;

    assign r6_o0 = r6_v0 ^ `ROTR64(r6_v0, 19) ^ `ROTR64(r6_v0, 28);
    assign r6_o1 = r6_v1 ^ `ROTR64(r6_v1, 61) ^ `ROTR64(r6_v1, 39);
    assign r6_o2 = r6_v2 ^ `ROTR64(r6_v2, 1) ^ `ROTR64(r6_v2, 6);
    assign r6_o3 = r6_v3 ^ `ROTR64(r6_v3, 10) ^ `ROTR64(r6_v3, 17);
    assign r6_o4 = r6_v4 ^ `ROTR64(r6_v4, 7) ^ `ROTR64(r6_v4, 41);

    // 从最终状态提取32位密钥流
    wire [31:0] keystream;
    assign keystream       = r6_o0[63:32] ^ r6_o1[31:0];

    // 解密: 密文 XOR 密钥流
    assign decrypted_instr = decrypt_enable ? (encrypted_instr ^ keystream) : encrypted_instr;

    `undef ROTR64

endmodule
