# ========================================
# RISC-V CPU 自动化测试 Makefile
# ========================================

SIM ?= iverilog
SUPPORTED_SIMS := iverilog verilator

ifeq ($(filter $(SIM),$(SUPPORTED_SIMS)),)
$(error 不支持的 SIM='$(SIM)'，可选值: $(SUPPORTED_SIMS))
endif

FOLDER        ?= hex

SIM_DIR       := $(abspath $(CURDIR))
SRC_DIR       := $(SIM_DIR)/user/src
SIM_TB_DIR    := $(SIM_DIR)/user/sim
ISA_TB_DIR    := $(SIM_DIR)/user/data/isa
ASM_DIR       := $(SIM_DIR)/user/data/asm
TEST_DIR      := $(ISA_TB_DIR)/$(FOLDER)
ASM_BUILD_DIR := $(SIM_DIR)/prj/asm

ISA_TB_TOP        := $(ISA_TB_DIR)/test_tb.sv
VERILATOR_TB_TOP  := $(SIM_TB_DIR)/tb_Verilator.sv
COREMARK_TB       := $(SIM_TB_DIR)/coremark.sv
COREMARK_HEX      := $(SIM_DIR)/coremark/escute/coremark.hex

TESTCASE      ?= rv32ui-p-add
PRINT_INFO    ?= 0
WAV_TOOL      ?= surfer

ASM           ?= JOP
ARCH          ?= rv32i_zicsr_zmmul_zicfiss_zicfilp
ABI           ?= $(if $(filter rv64%,$(ARCH)),lp64,ilp32)
RISCV_PREFIX  ?= riscv32-unknown-elf-
RISCV_GCC     ?= $(RISCV_PREFIX)gcc
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump
ELF2HEX       ?= elf2hex
ASM_LINKER    ?= $(ASM_DIR)/link.ld
ASM_HEX_DEPTH ?= 16384
ASM_GCC_OPTS  ?= -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles
ASM_EXTRA_FLAGS ?=
ASM_ARCH_FLAGS  ?= -march=$(ARCH) -mabi=$(ABI)

RTL_FILES     := $(wildcard $(SRC_DIR)/*.sv)
RTL_FILES     := $(filter-out $(SRC_DIR)/Makefile, $(RTL_FILES))
ALL_TESTS     := $(basename $(notdir $(wildcard $(TEST_DIR)/*.hex)))
ALL_ASM_TESTS := $(basename $(notdir $(wildcard $(ASM_DIR)/*.S)))

ASM_HAS_PATH   := $(findstring /,$(ASM))
ASM_HAS_SUFFIX := $(filter %.S %.s,$(ASM))

ifeq ($(ASM_HAS_PATH),)
ifeq ($(ASM_HAS_SUFFIX),)
ASM_SRC       := $(ASM_DIR)/$(ASM).S
else
ASM_SRC       := $(ASM_DIR)/$(ASM)
endif
else
ifeq ($(ASM_HAS_SUFFIX),)
ASM_SRC       := $(abspath $(ASM).S)
else
ASM_SRC       := $(abspath $(ASM))
endif
endif

ASM_NAME      := $(basename $(notdir $(ASM_SRC)))
ASM_ELF       := $(ASM_BUILD_DIR)/$(ASM_NAME).elf
ASM_DUMP      := $(ASM_BUILD_DIR)/$(ASM_NAME).dump
ASM_HEX       := $(ASM_BUILD_DIR)/$(ASM_NAME).hex

ifeq ($(suffix $(TESTCASE)),.hex)
ifneq ($(findstring /,$(TESTCASE)),)
TEST_HEX      := $(abspath $(TESTCASE))
else
TEST_HEX      := $(TEST_DIR)/$(TESTCASE)
endif
else
TEST_HEX      := $(TEST_DIR)/$(TESTCASE).hex
endif

.DEFAULT_GOAL := help

.PHONY: asm_list asm_compile asm_clean FORCE

asm_list:
	@echo "user/data/asm 下可用的汇编程序:"
	@for test in $(ALL_ASM_TESTS); do echo "  - $$test"; done

FORCE:

$(ASM_BUILD_DIR):
	@mkdir -p $(ASM_BUILD_DIR)

$(ASM_HEX): FORCE $(ASM_SRC) $(ASM_LINKER) | $(ASM_BUILD_DIR)
	@echo "========================================"
	@echo "编译自定义汇编程序..."
	@echo "源文件: $(ASM_SRC)"
	@echo "架构:   $(ARCH)"
	@echo "ABI:    $(ABI)"
	@echo "链接脚本: $(ASM_LINKER)"
	@echo "输出:   $(ASM_HEX)"
	@echo "========================================"
	$(RISCV_GCC) $(ASM_ARCH_FLAGS) $(ASM_GCC_OPTS) $(ASM_EXTRA_FLAGS) -T $(ASM_LINKER) $(ASM_SRC) -o $(ASM_ELF)
	$(RISCV_OBJDUMP) -d $(ASM_ELF) > $(ASM_DUMP)
	$(ELF2HEX) 4 $(ASM_HEX_DEPTH) $(ASM_ELF) > $(ASM_HEX)
	@echo "汇编程序已生成: $(ASM_HEX)"

asm_compile: $(ASM_HEX)

asm_clean:
	@echo "清理自定义汇编生成文件..."
	@rm -rf $(ASM_BUILD_DIR)

clean: asm_clean

include $(SIM).mk
