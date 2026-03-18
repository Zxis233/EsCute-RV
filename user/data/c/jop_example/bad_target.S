    .option norvc

    .section .text
    .align 2
    .globl bad_target
bad_target:
    addi    a0, zero, 99
    ret
