// See LICENSE for license details.

//*****************************************************************************
// zicfi.S
//-----------------------------------------------------------------------------
//
// Positive-path test for Zicfiss/Zicfilp on RV32:
// 1. Configure menvcfg/senvcfg in M-mode.
// 2. Set up ssp and enter S-mode.
// 3. Verify SSRDP / SSPUSH / SSPOPCHK.
// 4. Verify an indirect JALR lands on LPAD without trapping.
//

#include "riscv_test.h"
#include "test_macros.h"
#include "encoding.h"

#define ZICFI_ENVCFG_ENABLE 0x0000000c

// Use a non-zero LPAD tag so the x7 tag-compare path is exercised.
#define LPAD_TAG_IMM   0x000ab

#define INSN_LPAD_TAG      ((LPAD_TAG_IMM << 12) | 0x00000017)
#define INSN_SSRDP_A0      0xcdc01573
#define INSN_SSRDP_A1      0xcdc015f3
#define INSN_SSRDP_A2      0xcdc01673
#define INSN_SSPUSH_RA     0xce809073
#define INSN_SSPOPCHK_RA   0xcdc0c073

#define CSR_SSP ssp

RVTEST_RV32M
RVTEST_CODE_BEGIN

  .align 2
  .option norvc

  li TESTNUM, 2
  li t0, ZICFI_ENVCFG_ENABLE
  csrw CSR_MENVCFG, t0
  csrw CSR_SENVCFG, t0
  csrr t1, CSR_MENVCFG
  bne t0, t1, fail

  li TESTNUM, 3
  la t0, shadow_slot_end
  csrw CSR_SSP, t0

  li t1, MSTATUS_MPP
  csrc mstatus, t1
  li t1, (MSTATUS_MPP & -MSTATUS_MPP) * PRV_S
  csrs mstatus, t1
  la t1, supervisor_entry
  csrw mepc, t1
  mret

supervisor_entry:
  li TESTNUM, 4
  csrr s0, CSR_SSP
  la t0, shadow_slot_end
  bne s0, t0, fail

  li TESTNUM, 5
  .word INSN_SSRDP_A0
  bne a0, s0, fail

  li TESTNUM, 6
  li ra, 0x80
  .word INSN_SSPUSH_RA
  la t0, shadow_slot
  lw t1, 0(t0)
  bne t1, ra, fail

  li TESTNUM, 7
  .word INSN_SSRDP_A1
  la t0, shadow_slot
  bne a1, t0, fail

  li TESTNUM, 8
  .word INSN_SSPOPCHK_RA

  li TESTNUM, 9
  .word INSN_SSRDP_A2
  la t0, shadow_slot_end
  bne a2, t0, fail

  li TESTNUM, 10
  lui x7, LPAD_TAG_IMM
  la t1, lpad_target
  jalr zero, 0(t1)

after_lpad:
  li TESTNUM, 11
  li t0, 1
  bne s1, t0, fail

  RVTEST_PASS
  TEST_PASSFAIL

  .align 2
  .global mtvec_handler
mtvec_handler:
  j fail

  .align 2
lpad_target:
  .word INSN_LPAD_TAG
  li s1, 1
  j after_lpad

RVTEST_CODE_END

  .data
RVTEST_DATA_BEGIN

  .align 2
shadow_slot:
  .word 0

shadow_slot_end:

  TEST_DATA

RVTEST_DATA_END
