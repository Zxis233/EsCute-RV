    .option norvc

    .section .text
    .align 2

    .globl call_via_fp
call_via_fp:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    la      a5, g_call_fp
    lw      a5, 0(a5)
    jalr    ra, 0(a5)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
