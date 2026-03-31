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
TEST_DIR      := $(ISA_TB_DIR)/$(FOLDER)

ISA_TB_TOP        := $(ISA_TB_DIR)/test_tb.sv
VERILATOR_TB_TOP  := $(SIM_TB_DIR)/tb_Verilator.sv
COREMARK_TB       := $(SIM_TB_DIR)/coremark.sv
COREMARK_HEX      := $(SIM_DIR)/coremark/escute/coremark.hex

TESTCASE      ?= rv32ui-p-add
PRINT_INFO    ?= 0
WAV_TOOL      ?= gtkwave

RTL_FILES     := $(wildcard $(SRC_DIR)/*.sv)
RTL_FILES     := $(filter-out $(SRC_DIR)/Makefile, $(RTL_FILES))
ALL_TESTS     := $(basename $(notdir $(wildcard $(TEST_DIR)/*.hex)))

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

include $(SIM).mk
