    .option norvc

    .section .text
    .align 2

    .globl call_bad_target_indirect
call_bad_target_indirect:
    la      x15, g_bad_fp
    lw      x15, 0(x15)
    jr      x15

    .globl bad_target
bad_target:
    addi    x10, x0, 99
    ret