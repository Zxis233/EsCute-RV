# ========================================
# RV32I Complete Test Suite (No Pseudo Instructions)
# Testing all RV32I instructions without misaligned access
# ========================================

    .text
    .globl   _start

_start:
# ========================================
# 1. Test ADDI - Add Immediate
# ========================================
    addi     x1, x0, 100                                        # x1 = 0 + 100 = 100 (0x64)
    addi     x2, x0, 200                                        # x2 = 0 + 200 = 200 (0xC8)
    addi     x3, x1, 50                                         # x3 = 100 + 50 = 150 (0x96)
    addi     x4, x0, -10                                        # x4 = 0 + (-10) = -10 (0xFFFFFFF6)

# ========================================
# 2. Test ADD - Add Register
# ========================================
    add      x5, x1, x2                                         # x5 = 100 + 200 = 300 (0x12C)
    add      x6, x3, x4                                         # x6 = 150 + (-10) = 140 (0x8C)

# ========================================
# 3. Test SUB - Subtract
# ========================================
    sub      x7, x2, x1                                         # x7 = 200 - 100 = 100 (0x64)
    sub      x8, x1, x2                                         # x8 = 100 - 200 = -100 (0xFFFFFF9C)

# ========================================
# 4. Test SLTI - Set Less Than Immediate (Signed)
# ========================================
    slti     x9, x1, 101                                        # x9 = (100 < 101) = 1
    slti     x10, x1, 99                                        # x10 = (100 < 99) = 0
    slti     x11, x4, 0                                         # x11 = (-10 < 0) = 1

# ========================================
# 5. Test SLTIU - Set Less Than Immediate (Unsigned)
# ========================================
    sltiu    x12, x1, 101                                       # x12 = (100 < 101) = 1
    sltiu    x13, x4, 10                                        # x13 = (0xFFFFFFF6 < 10) = 0 (unsigned compare)

# ========================================
# 6. Test SLT - Set Less Than (Signed)
# ========================================
    slt      x14, x1, x2                                        # x14 = (100 < 200) = 1
    slt      x15, x2, x1                                        # x15 = (200 < 100) = 0
    slt      x16, x4, x1                                        # x16 = (-10 < 100) = 1

# ========================================
# 7. Test SLTU - Set Less Than (Unsigned)
# ========================================
    sltu     x17, x1, x2                                        # x17 = (100 < 200) = 1
    sltu     x18, x4, x1                                        # x18 = (0xFFFFFFF6 < 100) = 0 (unsigned)

# ========================================
# 8. Test Logical Operations - ANDI, ORI, XORI
# ========================================
    addi     x19, x0, 255                                       # x19 = 255 (0xFF)
    andi     x20, x19, 15                                       # x20 = 255 & 15 = 15 (0x0F)
    ori      x21, x20, 240                                      # x21 = 15 | 240 = 255 (0xFF)
    xori     x22, x21, 170                                      # x22 = 255 ^ 170 = 85 (0x55)

# ========================================
# 9. Test Logical Operations - AND, OR, XOR
# ========================================
    addi     x23, x0, 60                                        # x23 = 60 (0x3C = 0b00111100)
    addi     x24, x0, 51                                        # x24 = 51 (0x33 = 0b00110011)
    and      x25, x23, x24                                      # x25 = 60 & 51 = 48 (0x30)
    or       x26, x23, x24                                      # x26 = 60 | 51 = 63 (0x3F)
    xor      x27, x23, x24                                      # x27 = 60 ^ 51 = 15 (0x0F)

# ========================================
# 10. Test Shift Operations - SLLI, SRLI, SRAI
# ========================================
    addi     x28, x0, 8                                         # x28 = 8 (0x08)
    slli     x29, x28, 2                                        # x29 = 8 << 2 = 32 (0x20)
    srli     x30, x29, 1                                        # x30 = 32 >> 1 = 16 (0x10)
    addi     x31, x0, -8                                        # x31 = -8 (0xFFFFFFF8)
    srai     x1, x31, 1                                         # x1 = -8 >> 1 = -4 (0xFFFFFFFC, arithmetic shift)

# ========================================
# 11. Test Shift Operations - SLL, SRL, SRA
# ========================================
    addi     x2, x0, 16                                         # x2 = 16
    addi     x3, x0, 2                                          # x3 = 2 (shift amount)
    sll      x4, x2, x3                                         # x4 = 16 << 2 = 64 (0x40)
    srl      x5, x4, x3                                         # x5 = 64 >> 2 = 16 (0x10)
    addi     x6, x0, -16                                        # x6 = -16 (0xFFFFFFF0)
    sra      x7, x6, x3                                         # x7 = -16 >> 2 = -4 (0xFFFFFFFC)

# ========================================
# 12. Test LUI - Load Upper Immediate
# ========================================
    lui      x8, 0x12345                                        # x8 = 0x12345000
    lui      x9, 0xFFFFF                                        # x9 = 0xFFFFF000

# ========================================
# 13. Test AUIPC - Add Upper Immediate to PC
# ========================================
    auipc    x10, 0                                             # x10 = current PC + 0
    auipc    x11, 1                                             # x11 = current PC + 0x1000

# ========================================
# 14. Test Memory Operations - Store and Load
# Setup memory base address
# ========================================
    lui      x12, 0x10000                                       # x12 = 0x10000000 (memory base)

# Store values
    addi     x13, x0, 0x7F                                      # x13 = 127
    sb       x13, 0(x12)                                        # Store byte: mem[0x10000000] = 0x7F

    addi     x14, x0, 0x123                                     # x14 = 0x1234
    sh       x14, 4(x12)                                        # Store halfword: mem[0x10000004] = 0x1234

    lui      x15, 0xABCDE                                       # x15 = 0xABCDE000
    addi     x15, x15, 0x789                                    # x15 = 0xABCDE789
    sw       x15, 8(x12)                                        # Store word: mem[0x10000008] = 0xABCDE789

# Load values
    lb       x16, 0(x12)                                        # x16 = sign-extend(0x7F) = 0x7F
    lbu      x17, 0(x12)                                        # x17 = zero-extend(0x7F) = 0x7F

    addi     x18, x0, -1                                        # x18 = 0xFFFFFFFF
    sb       x18, 1(x12)                                        # Store 0xFF at offset 1
    lb       x19, 1(x12)                                        # x19 = sign-extend(0xFF) = 0xFFFFFFFF
    lbu      x20, 1(x12)                                        # x20 = zero-extend(0xFF) = 0xFF

    lh       x21, 4(x12)                                        # x21 = sign-extend(0x1234) = 0x1234
    lhu      x22, 4(x12)                                        # x22 = zero-extend(0x1234) = 0x1234

    addi     x23, x0, -1                                        # x23 = 0xFFFFFFFF
    sh       x23, 6(x12)                                        # Store 0xFFFF at offset 6
    lh       x24, 6(x12)                                        # x24 = sign-extend(0xFFFF) = 0xFFFFFFFF
    lhu      x25, 6(x12)                                        # x25 = zero-extend(0xFFFF) = 0xFFFF

    lw       x26, 8(x12)                                        # x26 = 0xABCDE789

# ========================================
# 15. Test Branch Instructions - BEQ
# ========================================
    addi     x27, x0, 10                                        # x27 = 10
    addi     x28, x0, 10                                        # x28 = 10
    beq      x27, x28, branch_eq_taken                          # Should branch (10 == 10)
    addi     x29, x0, 99                                        # x29 = 99 (SHOULD NOT EXECUTE)

branch_eq_taken:
    addi     x29, x0, 1                                         # x29 = 1 (branch taken marker)

    addi     x27, x0, 10                                        # x27 = 10
    addi     x28, x0, 20                                        # x28 = 20
    beq      x27, x28, branch_eq_not_taken                      # Should not branch
    addi     x30, x0, 1                                         # x30 = 1 (not taken marker)

branch_eq_not_taken:

# ========================================
# 16. Test Branch Instructions - BNE
# ========================================
    addi     x1, x0, 5                                          # x1 = 5
    addi     x2, x0, 10                                         # x2 = 10
    bne      x1, x2, branch_ne_taken                            # Should branch (5 != 10)
    addi     x3, x0, 99                                         # x3 = 99 (SHOULD NOT EXECUTE)

branch_ne_taken:
    addi     x3, x0, 1                                          # x3 = 1 (branch taken marker)

# ========================================
# 17. Test Branch Instructions - BLT (Signed)
# ========================================
    addi     x4, x0, 5                                          # x4 = 5
    addi     x5, x0, 10                                         # x5 = 10
    blt      x4, x5, branch_lt_taken                            # Should branch (5 < 10)
    addi     x6, x0, 99                                         # x6 = 99 (SHOULD NOT EXECUTE)

branch_lt_taken:
    addi     x6, x0, 1                                          # x6 = 1 (branch taken marker)

    addi     x7, x0, -5                                         # x7 = -5
    addi     x8, x0, 3                                          # x8 = 3
    blt      x7, x8, branch_lt_neg_taken                        # Should branch (-5 < 3)
    addi     x9, x0, 99                                         # x9 = 99 (SHOULD NOT EXECUTE)

branch_lt_neg_taken:
    addi     x9, x0, 1                                          # x9 = 1 (branch taken marker)

# ========================================
# 18. Test Branch Instructions - BGE (Signed)
# ========================================
    addi     x10, x0, 10                                        # x10 = 10
    addi     x11, x0, 5                                         # x11 = 5
    bge      x10, x11, branch_ge_taken                          # Should branch (10 >= 5)
    addi     x12, x0, 99                                        # x12 = 99 (SHOULD NOT EXECUTE)

branch_ge_taken:
    addi     x12, x0, 1                                         # x12 = 1 (branch taken marker)

# ========================================
# 19. Test Branch Instructions - BLTU (Unsigned)
# ========================================
    addi     x13, x0, 5                                         # x13 = 5
    addi     x14, x0, 10                                        # x14 = 10
    bltu     x13, x14, branch_ltu_taken                         # Should branch (5 < 10 unsigned)
    addi     x15, x0, 99                                        # x15 = 99 (SHOULD NOT EXECUTE)

branch_ltu_taken:
    addi     x15, x0, 1                                         # x15 = 1 (branch taken marker)

# ========================================
# 20. Test Branch Instructions - BGEU (Unsigned)
# ========================================
    addi     x16, x0, 10                                        # x16 = 10
    addi     x17, x0, 5                                         # x17 = 5
    bgeu     x16, x17, branch_geu_taken                         # Should branch (10 >= 5 unsigned)
    addi     x18, x0, 99                                        # x18 = 99 (SHOULD NOT EXECUTE)

branch_geu_taken:
    addi     x18, x0, 1                                         # x18 = 1 (branch taken marker)

# ========================================
# 21. Test JAL - Jump and Link
# ========================================
    jal      x19, jal_target                                    # x19 = return address, jump to jal_target
    addi     x20, x0, 99                                        # x20 = 99 (SHOULD NOT EXECUTE)

jal_target:
    addi     x20, x0, 1                                         # x20 = 1 (jump successful)

# ========================================
# 22. Test JALR - Jump and Link Register
# ========================================
    auipc    x21, 0                                             # x21 = current PC
    addi     x21, x21, 16                                       # x21 = PC + 16 (target address)
    jalr     x22, x21, 0                                        # x22 = return address, jump to x21
    addi     x23, x0, 99                                        # x23 = 99 (SHOULD NOT EXECUTE)

jalr_target:
    addi     x23, x0, 1                                         # x23 = 1 (jump successful)

# ========================================
# 23. Test Complex Data Dependencies
# ========================================
    addi     x24, x0, 1                                         # x24 = 1
    addi     x24, x24, 2                                        # x24 = 3
    addi     x24, x24, 3                                        # x24 = 6
    addi     x24, x24, 4                                        # x24 = 10

# ========================================
# 24. Test Edge Cases
# ========================================
# Maximum positive immediate
    addi     x25, x0, 2047                                      # x25 = 2047 (0x7FF, max 12-bit signed)

# Maximum negative immediate
    addi     x26, x0, -2048                                     # x26 = -2048 (0xFFFFF800)

# Overflow test
    lui      x27, 0x7FFFF                                       # x27 = 0x7FFFF000
    addi     x27, x27, 0x7FF                                    # x27 = 0x7FFFF7FF (near max positive)
    addi     x28, x0, 1                                         # x28 = 1
    add      x29, x27, x28                                      # x29 = overflow result

# Zero register test
    addi     x0, x0, 100                                        # x0 should remain 0
    add      x30, x0, x0                                        # x30 = 0

# ========================================
# 25. Final Test - Load/Store with Computed Address
# ========================================
    lui      x31, 0x10000                                       # x31 = 0x10000000
    addi     x1, x0, 100                                        # x1 = 100 (offset)
    add      x2, x31, x1                                        # x2 = 0x10000000 + 100
    addi     x3, x0, 0x55A                                      # x3 = 0x55A
    sw       x3, 0(x2)                                          # Store at computed address
    lw       x4, 0(x2)                                          # x4 = 0x55A (load back)

# ========================================
# 26. Test MUL Instructions - Basic Operations
# ========================================
    addi     x5, x0, 5                                          # x5 = 5
    addi     x6, x0, 6                                          # x6 = 6
    mul      x7, x5, x6                                         # x7 = 5 * 6 = 30 (0x1E)

    addi     x8, x0, -3                                         # x8 = -3
    addi     x9, x0, 4                                          # x9 = 4
    mul      x10, x8, x9                                        # x10 = -3 * 4 = -12 (0xFFFFFFF4)

    addi     x11, x0, -5                                        # x11 = -5
    addi     x12, x0, -6                                        # x12 = -6
    mul      x13, x11, x12                                      # x13 = -5 * -6 = 30 (0x1E)

# ========================================
# 27. Test MULH - Signed High Multiplication
# ========================================
    lui      x14, 0x40000                                       # x14 = 0x40000000 (large positive)
    addi     x15, x0, 4                                         # x15 = 4
    mulh     x16, x14, x15                                      # x16 = high bits of (0x40000000 * 4)

    lui      x17, 0x80000                                       # x17 = 0x80000000 (large negative)
    addi     x18, x0, 2                                         # x18 = 2
    mulh     x19, x17, x18                                      # x19 = high bits of (0x80000000 * 2)

# ========================================
# 28. Test MULHU - Unsigned High Multiplication
# ========================================
    lui      x20, 0x80000                                       # x20 = 0x80000000
    addi     x21, x0, 2                                         # x21 = 2
    mulhu    x22, x20, x21                                      # x22 = high bits unsigned (0x80000000 * 2)

    addi     x23, x0, -1                                        # x23 = 0xFFFFFFFF
    addi     x24, x0, -1                                        # x24 = 0xFFFFFFFF
    mulhu    x25, x23, x24                                      # x25 = high bits of (0xFFFFFFFF * 0xFFFFFFFF)

# ========================================
# 29. Test MULHSU - Signed x Unsigned High Multiplication
# ========================================
    addi     x26, x0, -1                                        # x26 = -1 (0xFFFFFFFF)
    addi     x27, x0, 1                                         # x27 = 1
    mulhsu   x28, x26, x27                                      # x28 = high bits of (-1 * 1 unsigned)

    lui      x29, 0x40000                                       # x29 = 0x40000000
    addi     x30, x0, 4                                         # x30 = 4
    mulhsu   x31, x29, x30                                      # x31 = high bits of (0x40000000 * 4)

# ========================================
# 30. Test MUL Data Hazards - RAW (Read After Write)
# ========================================
    addi     x5, x0, 7                                          # x5 = 7
    addi     x6, x0, 8                                          # x6 = 8
    mul      x7, x5, x6                                         # x7 = 7 * 8 = 56
    mul      x8, x7, x5                                         # RAW hazard: x8 = 56 * 7 = 392 (0x188)
    mul      x9, x8, x6                                         # RAW hazard: x9 = 392 * 8 = 3136 (0xC40)

# ========================================
# 31. Test MUL with ALU Instructions - Mixed Hazards
# ========================================
    addi     x10, x0, 3                                         # x10 = 3
    addi     x11, x0, 4                                         # x11 = 4
    mul      x12, x10, x11                                      # x12 = 3 * 4 = 12
    addi     x13, x12, 5                                        # RAW hazard: x13 = 12 + 5 = 17
    mul      x14, x13, x10                                      # RAW hazard: x14 = 17 * 3 = 51 (0x33)

# ========================================
# 32. Test Load-Use with MUL - Memory to MUL Hazard
# ========================================
    lui      x15, 0x10000                                       # x15 = 0x10000000
    addi     x16, x0, 9                                         # x16 = 9
    sw       x16, 12(x15)                                       # Store 9 to memory

    lw       x17, 12(x15)                                       # Load x17 = 9
    addi     x18, x0, 5                                         # x18 = 5
    mul      x19, x17, x18                                      # Load-Use hazard: x19 = 9 * 5 = 45 (0x2D)

# ========================================
# 33. Test MUL to Store - MUL Result to Memory
# ========================================
    addi     x20, x0, 11                                        # x20 = 11
    addi     x21, x0, 12                                        # x21 = 12
    mul      x22, x20, x21                                      # x22 = 11 * 12 = 132 (0x84)
    sw       x22, 16(x15)                                       # Store MUL result to memory
    lw       x23, 16(x15)                                       # Load back: x23 = 132

# ========================================
# 34. Test Load-MUL-Store Chain
# ========================================
    addi     x24, x0, 6                                         # x24 = 6
    sw       x24, 20(x15)                                       # Store 6 to memory

    lw       x25, 20(x15)                                       # Load: x25 = 6
    addi     x26, x0, 7                                         # x26 = 7
    mul      x27, x25, x26                                      # Load-Use + MUL: x27 = 6 * 7 = 42 (0x2A)
    sw       x27, 24(x15)                                       # Store result
    lw       x28, 24(x15)                                       # Load back: x28 = 42

# ========================================
# 35. Test Multiple Consecutive MUL Operations
# ========================================
    addi     x29, x0, 2                                         # x29 = 2
    mul      x30, x29, x29                                      # x30 = 2 * 2 = 4
    mul      x31, x30, x29                                      # RAW: x31 = 4 * 2 = 8
    mul      x1, x31, x29                                       # RAW: x1 = 8 * 2 = 16
    mul      x2, x1, x29                                        # RAW: x2 = 16 * 2 = 32 (0x20)

# ========================================
# 36. Test MUL with Branch
# ========================================
    addi     x3, x0, 3                                          # x3 = 3
    addi     x4, x0, 5                                          # x4 = 5
    mul      x5, x3, x4                                         # x5 = 3 * 5 = 15
    addi     x6, x0, 15                                         # x6 = 15
    beq      x5, x6, mul_branch_taken                           # Branch if MUL result is correct
    addi     x7, x0, 99                                         # x7 = 99 (SHOULD NOT EXECUTE)

mul_branch_taken:
    addi     x7, x0, 1                                          # x7 = 1 (branch taken, MUL correct)

# ========================================
# 37. Test MUL Zero Cases
# ========================================
    addi     x8, x0, 100                                        # x8 = 100
    mul      x9, x8, x0                                         # x9 = 100 * 0 = 0
    mul      x10, x0, x8                                        # x10 = 0 * 100 = 0

# ========================================
# 38. Test MUL with Maximum Values
# ========================================
    addi     x11, x0, -1                                        # x11 = 0xFFFFFFFF
    addi     x12, x0, -1                                        # x12 = 0xFFFFFFFF
    mul      x13, x11, x12                                      # x13 = low 32 bits of (-1 * -1) = 1
    mulh     x14, x11, x12                                      # x14 = high 32 bits (signed)
    mulhu    x15, x11, x12                                      # x15 = high 32 bits (unsigned)

# ========================================
# 39. Test Complex Load-Use-MUL Pattern
# ========================================
    lui      x16, 0x10000                                       # x16 = 0x10000000
    addi     x17, x0, 13                                        # x17 = 13
    addi     x18, x0, 14                                        # x18 = 14
    sw       x17, 28(x16)                                       # Store 13
    sw       x18, 32(x16)                                       # Store 14

    lw       x19, 28(x16)                                       # Load: x19 = 13
    lw       x20, 32(x16)                                       # Load: x20 = 14
    mul      x21, x19, x20                                      # Double load-use: x21 = 13 * 14 = 182 (0xB6)

# ========================================
# 40. Test MUL with Forwarding from Different Stages
# ========================================
    addi     x22, x0, 4                                         # x22 = 4
    addi     x23, x0, 9                                         # x23 = 9
    add      x24, x22, x23                                      # x24 = 4 + 9 = 13
    mul      x25, x24, x22                                      # MUL uses ADD result: x25 = 13 * 4 = 52 (0x34)
    sub      x26, x25, x23                                      # SUB uses MUL result: x26 = 52 - 9 = 43 (0x2B)

# ==========================================
    nop
    nop

# 初始化寄存器
    li       x1, 10
    li       x2, 20
    li       x3, 5
    li       x4, 3
    li       x5, 100
    li       x6, 7
    li       x7, 0
    li       x8, 0
    li       x9, 0
    li       x10, 0

# ==========================================
# 测试1：RAW冒险 - 紧邻依赖（最严重的冒险）
# ==========================================
test_raw_immediate:
    mul      x11, x1, x2                                        # x11 = 10 * 20 = 200 (4级流水线)
    add      x12, x11, x3                                       # 立即使用x11，需要等待4个周期 x12=205
    sub      x13, x11, x4                                       # 再次使用x11 x13 = 197
    or       x14, x11, x5                                       # 第三次使用x11 x14 = 200 | 100 = 236

# ==========================================
# 测试2：RAW冒险 - 间隔1条指令
# ==========================================
test_raw_one_gap:
    mul      x15, x2, x3                                        # x15 = 20 * 5 = 100
    nop                                                         # 间隔1条指令
    add      x16, x15, x4                                       # 使用x15，仍需暂停

# ==========================================
# 测试3：RAW冒险 - 间隔2条指令
# ==========================================
test_raw_two_gaps:
    mul      x17, x3, x4                                        # x17 = 5 * 3 = 15
    nop
    nop                                                         # 间隔2条指令
    add      x18, x17, x5                                       # 使用x17，仍需暂停

# ==========================================
# 测试4：RAW冒险 - 间隔3条指令
# ==========================================
test_raw_three_gaps:
    mul      x19, x4, x5                                        # x19 = 3 * 100 = 300
    nop
    nop
    nop                                                         # 间隔3条指令
    add      x20, x19, x6                                       # 使用x19，刚好不需要暂停

# ==========================================
# 测试5：连续乘法指令 - 结构冒险
# ==========================================
test_consecutive_mul:
    mul      x21, x1, x2                                        # 第1个乘法
    mul      x22, x3, x4                                        # 第2个乘法（可能造成结构冒险）
    mul      x23, x5, x6                                        # 第3个乘法
    mul      x24, x1, x3                                        # 第4个乘法
    mul      x25, x2, x4                                        # 第5个乘法

# ==========================================
# 测试6：乘法结果的链式依赖
# ==========================================
test_chain_dependency:
    mul      x26, x1, x2                                        # x26 = 10 * 20 = 200
    mul      x27, x26, x3                                       # x27 = 200 * 5 = 1000（依赖x26）
    mul      x28, x27, x4                                       # x28 = 1000 * 3 = 3000（依赖x27）
    add      x29, x28, x1                                       # 使用最终结果

# ==========================================
# 测试7：乘法与分支指令混合
# ==========================================
test_mul_with_branch:
    mul      x30, x1, x2                                        # 乘法指令
    beq      x1, x2, skip1                                      # 条件分支（不跳转）
    add      x31, x30, x3                                       # 使用乘法结果
skip1:
    mul      x7, x3, x4                                         # 另一个乘法
    bne      x7, x0, skip2                                      # 条件分支（会跳转）
    add      x8, x7, x1                                         # 不应该执行
skip2:
    add      x9, x7, x2                                         # 使用x7

# ==========================================
# 测试8：乘法与加载/存储指令混合
# ==========================================
test_mul_with_mem:
    la       x10, data_section                                  # 加载数据地址
    mul      x11, x1, x3                                        # 乘法指令
    sw       x11, 0(x10)                                        # 存储乘法结果
    lw       x12, 0(x10)                                        # 加载数据
    mul      x13, x12, x3                                       # 使用加载的数据做乘法

# ==========================================
# 测试9：WAR冒险（写后读）
# ==========================================
test_war_hazard:
    mul      x14, x1, x15                                       # 读x15
    add      x15, x2, x3                                        # 写x15（在乘法完成前）
    or       x16, x14, x4                                       # 使用x14

# ==========================================
# 测试10：WAW冒险（写后写）
# ==========================================
test_waw_hazard:
    mul      x17, x1, x2                                        # 第1次写x17
    add      x17, x3, x4                                        # 第2次写x17（可能在乘法完成前）
    sub      x18, x17, x5                                       # 使用x17（应该是add的结果）

# ==========================================
# 测试11：多个源操作数同时产生RAW冒险
# ==========================================
test_dual_raw:
    mul      x19, x1, x2                                        # x19 = 10 * 20
    mul      x20, x3, x4                                        # x20 = 5 * 3
    add      x21, x19, x20                                      # 同时依赖x19和x20

# ==========================================
# 测试12：乘法器阻塞后续指令队列
# ==========================================
test_queue_blocking:
    mul      x22, x1, x2                                        # 乘法指令1 x22 = 200
    add      x23, x3, x4                                        # 普通指令1（可能被阻塞）x23 = 8
    sub      x24, x5, x6                                        # 普通指令2（可能被阻塞）x24 = 93
    mul      x25, x7, x8                                        # 乘法指令2（可能被阻塞）x25 = 0
    or       x26, x9, x10                                       # 普通指令3（可能被阻塞）x26 = 4535
    and      x27, x23, x24                                      # 依赖前面的结果 x27 = x23 & x24

# ==========================================
# 测试13：循环中的乘法指令
# ==========================================
test_mul_in_loop:
    li       x28, 5                                             # 循环计数器
    li       x29, 0                                             # 累加器
loop_start:
    mul      x30, x28, x1                                       # 循环内乘法
    add      x29, x29, x30                                      # 累加结果（RAW冒险）
    addi     x28, x28, -1                                       # 计数器减1
    bne      x28, x0, loop_start                                # 如果不为0则继续循环

# ==========================================
# 测试14：最坏情况 - 复杂交织
# ==========================================
test_worst_case:
    mul      x1, x2, x3                                         # 乘法1 x1=100
    add      x4, x1, x5                                         # 立即使用（RAW） x4=200
    mul      x6, x1, x7                                         # 乘法2，依赖乘法1（RAW） x6 = 1500
    sub      x8, x6, x9                                         # 立即使用乘法2（RAW）x8=1465
    mul      x10, x4, x8                                        # 乘法3，依赖两个前序结果 x9=200*1465=293000
    or       x11, x10, x12                                      # 立即使用乘法3（RAW） x11=293000|50 = 293050

# ==========================================
# 测试15：x0寄存器特殊情况
# ==========================================
test_zero_register:
    mul      x0, x1, x2                                         # 写入x0（应该被忽略）
    add      x13, x0, x3                                        # 使用x0（永远是0）
    mul      x14, x0, x4                                        # x0作为源操作数

# ==========================================
# 测试16：MULH/MULHU/MULHSU指令（如果支持）
# ==========================================
test_mulh_variants:
    mulh     x15, x1, x2                                        # 有符号高位乘法
    add      x16, x15, x3                                       # 立即使用（RAW）
    mulhu    x17, x4, x5                                        # 无符号高位乘法
    add      x18, x17, x6                                       # 立即使用（RAW）
    mulhsu   x19, x1, x5                                        # 有符号-无符号高位乘法
    add      x20, x19, x7                                       # 立即使用（RAW）

# ==========================================
# 测试17：交替执行模式
# ==========================================
test_alternate_pattern:
    mul      x21, x1, x2                                        # 乘法
    add      x22, x3, x4                                        # 算术
    mul      x23, x5, x6                                        # 乘法
    sub      x24, x7, x8                                        # 算术
    mul      x25, x9, x10                                       # 乘法
    or       x26, x11, x12                                      # 逻辑

# ==========================================
# 测试18：前递（Forwarding）测试
# ==========================================
test_forwarding:
    mul      x27, x1, x2                                        # 乘法指令
    nop                                                         # 如果有前递，减少暂停
    nop
    nop                                                         # 3个nop后
    add      x28, x27, x3                                       # 测试前递是否工作

# ========================================
# End of Test - Infinite Loop
# ========================================
end_loop:
    beq      x0, x0, end_loop                                   # Infinite loop

# ==========================================
# 数据段
# ==========================================
    .section .data
data_section:
    .word    0
    .word    0
    .word    0
    .word    0