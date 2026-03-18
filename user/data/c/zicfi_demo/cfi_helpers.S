    .option norvc

    .equ LPAD_TAG_IMM,      0x000ab
    .equ INSN_LPAD_TAG,     ((LPAD_TAG_IMM << 12) | 0x00000017)
    .equ INSN_SSRDP_A0,     0xcdc04573
    .equ INSN_SSPUSH_A0,    0xcea04073
    .equ INSN_SSPOPCHK_A0,  0xcdc54073

    .section .text
    .align 2

    .globl read_ssp
read_ssp:
    .word   INSN_SSRDP_A0
    ret

    .globl write_ssp
write_ssp:
    csrw    ssp, a0
    ret

    .globl shadow_push
shadow_push:
    .word   INSN_SSPUSH_A0
    ret

    .globl shadow_popchk
shadow_popchk:
    .word   INSN_SSPOPCHK_A0
    ret

    .globl call_lpad_target
call_lpad_target:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    lui     x7, LPAD_TAG_IMM
    mv      t1, a0
    mv      a0, a1
    jalr    ra, 0(t1)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

    .globl lpad_target
lpad_target:
    .word   INSN_LPAD_TAG
    addi    a0, a0, 7
    ret

    .globl finish_success
finish_success:
    mv      x28, a0
    li      x29, 0
1:
    j       1b

    .globl finish_fail
finish_fail:
    mv      x28, a0
    li      x29, 1
2:
    j       2b
