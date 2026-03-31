    .option  norvc

    .equ     ZICFI_ENVCFG_ENABLE, 0x0000000c
    .equ     MSTATUS_MPP_MASK,    0x00001800
    .equ     MSTATUS_MPP_S,       0x00000800
    .equ     TOHOST_ADDR,         0x8d000720

    .section .text.init
    .globl   _start
_start:
    la       sp, _stack_top

    la       t0, m_trap_vector
    csrw     mtvec, t0

    li       t0, ZICFI_ENVCFG_ENABLE
    csrw     menvcfg, t0
    csrw     senvcfg, t0

    la       t0, _shadow_stack_top
    csrw     ssp, t0

    li       t0, MSTATUS_MPP_MASK
    csrc     mstatus, t0
    li       t0, MSTATUS_MPP_S
    csrs     mstatus, t0

    la       t0, s_mode_entry
    csrw     mepc, t0
    mret

s_mode_entry:
    la       sp, _stack_top
    call     main
1:
    j        1b

    .align   2
m_trap_vector:
    csrr     x5, mcause
    csrr     x6, mepc
    csrr     x7, mtval

    li       t0, TOHOST_ADDR
    li       t1, 2
    sw       t1, 0(t0)
2:
    j        2b
