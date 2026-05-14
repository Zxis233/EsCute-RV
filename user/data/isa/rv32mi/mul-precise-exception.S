#include "riscv_test.h"
#include "test_macros.h"

RVTEST_RV32M
RVTEST_CODE_BEGIN

  li TESTNUM, 2
  li x1, 7
  li x2, 9
  mul x5, x1, x2
  addi x6, x0, 1
  la x3, tdat
faulting_lw:
  lw x8, 1(x3)
  j fail

after_trap:
  li x9, 63
  bne x5, x9, fail
  li x10, 1
  bne x6, x10, fail
  RVTEST_PASS

fail:
  RVTEST_FAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  li x28, CAUSE_MISALIGNED_LOAD
  csrr x29, mcause
  bne x28, x29, fail
  csrr x28, mepc
  la x29, faulting_lw
  bne x28, x29, fail
  li x28, 63
  bne x5, x28, fail
  la x28, after_trap
  csrw mepc, x28
  mret

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

tdat:
  .word 0x04030201

RVTEST_DATA_END
