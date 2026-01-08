    .section .text.init
    .globl   _start
_start:
    la       sp, _stack_top

# 清 BSS（如果你没定义 __bss_start/__bss_end 就先不做）
# la t0, __bss_start
# la t1, __bss_end
# ...

    call     print_test
1:
    j        1b
