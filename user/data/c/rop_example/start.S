    .option norvc

    .equ ZICFI_ENVCFG_ENABLE, 0x0000000c
    .equ MSTATUS_MPP_MASK,    0x00001800
    .equ MSTATUS_MPP_S,       0x00000800
    .equ SHADOW_TOP,          0x00003400
    .equ SOFTCHK_EXCEPTION,   18
    .equ SHADOW_FAULT_TVAL,   3

    .section .text.init
    .globl _start
_start:
    la      sp, _stack_top

    la      t0, m_trap_vector
    csrw    mtvec, t0

    li      t0, ZICFI_ENVCFG_ENABLE
    csrw    menvcfg, t0
    csrw    senvcfg, t0

    li      t0, SHADOW_TOP
    csrw    ssp, t0

    li      t0, MSTATUS_MPP_MASK
    csrc    mstatus, t0
    li      t0, MSTATUS_MPP_S
    csrs    mstatus, t0

    la      t0, s_mode_entry
    csrw    mepc, t0
    mret

s_mode_entry:
    la      sp, _stack_top
    call    main

    li      a0, 32
    tail    finish_fail

    .align 2
    .globl m_trap_vector
m_trap_vector:
    csrr    t0, mcause
    csrr    t1, mepc
    csrr    t2, mtval

    mv      x5, t0
    mv      x6, t1
    mv      x7, t2

    li      t3, SOFTCHK_EXCEPTION
    bne     t0, t3, trap_fail_cause

    li      t3, SHADOW_FAULT_TVAL
    bne     t2, t3, trap_fail_tval

    li      x28, 1
    li      x29, 0
1:
    j       1b

trap_fail_cause:
    li      x28, 0xe1
    li      x29, 1
2:
    j       2b

trap_fail_tval:
    li      x28, 0xe2
    li      x29, 1
3:
    j       3b
