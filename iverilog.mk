# ========================================
# RISC-V CPU Icarus Verilog 自动化测试配置
# ========================================

ifeq ($(origin DUMPWAVE), undefined)
DUMPWAVE := 0
endif

RUN_DIR         := $(SIM_DIR)/prj/iverilog
WAVE_DIR        := $(SIM_DIR)/prj/icarus
TB_TOP          := $(ISA_TB_TOP)
TB_MODULE       := test_tb
COREMARK_TOP    := coremark

IVERILOG        ?= iverilog
VVP             ?= vvp
IVERILOG_FLAGS  := -g2012 -Wall
IVERILOG_FLAGS  += -I $(SRC_DIR)
IVERILOG_FLAGS  += -I $(SRC_DIR)/include
IVERILOG_PARAM_FLAGS :=
COREMARK_IVERILOG_PARAM_FLAGS :=

ifneq ($(strip $(BPU_TYPE)),)
IVERILOG_PARAM_FLAGS += -P$(TB_MODULE).BPU_TYPE=$(BPU_TYPE)
COREMARK_IVERILOG_PARAM_FLAGS += -P$(COREMARK_TOP).BPU_TYPE=$(BPU_TYPE)
endif

SIM_BIN         := $(RUN_DIR)/$(TB_MODULE).vvp
COREMARK_BIN    := $(RUN_DIR)/$(COREMARK_TOP).vvp
WAV_FILE        := $(WAVE_DIR)/wave.vcd
COREMARK_WAVE   := $(WAVE_DIR)/coremark.vcd
REGRESS_SUMMARY := $(RUN_DIR)/regress_summary_$(FOLDER)_iverilog.txt

.PHONY: all help list_tests compile run coremark_compile coremark_test wave regress regress_prepare regress_run regress_collect clean

all: compile help regress

help:
	@echo "=========================================="
	@echo "RISC-V CPU 自动化测试 Makefile"
	@echo "=========================================="
	@echo "当前仿真器: Icarus Verilog (SIM=$(SIM))"
	@echo "配置文件:   iverilog.mk"
	@echo ""
	@echo "使用方法:"
	@echo "  make SIM=$(SIM) run           - 编译并运行默认测试"
	@echo "  make SIM=$(SIM) compile       - 仅编译测试台"
	@echo "  make SIM=$(SIM) wave          - 查看波形"
	@echo "  make SIM=$(SIM) list_tests    - 列出所有可用测试"
	@echo "  make SIM=$(SIM) regress       - 运行所有测试用例"
	@echo "  make SIM=$(SIM) coremark_test - 运行 CoreMark"
	@echo "  make SIM=$(SIM) clean         - 清理生成文件"
	@echo ""
	@echo "运行特定测试:"
	@echo "  make SIM=$(SIM) run TESTCASE=<test_name>"
	@echo ""
	@echo "切换仿真器:"
	@echo "  make SIM=iverilog run"
	@echo "  make SIM=verilator run"
	@echo "=========================================="

list_tests:
	@echo "可用的测试用例:"
	@for test in $(ALL_TESTS); do echo "  - $$test"; done

$(RUN_DIR):
	@mkdir -p $(RUN_DIR)

$(WAVE_DIR):
	@mkdir -p $(WAVE_DIR)

$(SIM_BIN): $(TB_TOP) $(RTL_FILES) | $(RUN_DIR) $(WAVE_DIR)
	@echo "========================================"
	@echo "编译 Icarus Verilog 测试台..."
	@echo "顶层模块: $(TB_MODULE)"
	@echo "测试文件: $(TB_TOP)"
	@echo "输出目录: $(RUN_DIR)"
	@echo "========================================"
	$(IVERILOG) $(IVERILOG_FLAGS) $(IVERILOG_PARAM_FLAGS) -o $(SIM_BIN) $(TB_TOP) $(RTL_FILES)
	@echo "编译完成: $(SIM_BIN)"

compile: $(SIM_BIN)

run: compile
	@echo "========================================"
	@echo "运行测试: $(TESTCASE)"
	@echo "测试文件: $(TEST_HEX)"
	@echo "========================================"
	@if [ ! -f "$(TEST_HEX)" ]; then \
		echo "错误: 测试文件不存在: $(TEST_HEX)"; \
		echo "请使用 'make SIM=$(SIM) list_tests' 查看可用测试"; \
		exit 1; \
	fi
	@cd $(RUN_DIR) && \
		$(VVP) $(SIM_BIN) \
		+TESTCASE=$(TEST_HEX) \
		+DUMPWAVE=$(DUMPWAVE) \
		+PRINT_INFO=$(PRINT_INFO)

$(COREMARK_BIN): $(COREMARK_TB) $(RTL_FILES) | $(RUN_DIR) $(WAVE_DIR)
	@echo "========================================"
	@echo "编译 Icarus Verilog CoreMark 测试台..."
	@echo "顶层模块: $(COREMARK_TOP)"
	@echo "测试文件: $(COREMARK_TB)"
	@echo "输出目录: $(RUN_DIR)"
	@echo "========================================"
	$(IVERILOG) $(IVERILOG_FLAGS) $(COREMARK_IVERILOG_PARAM_FLAGS) -o $(COREMARK_BIN) $(COREMARK_TB) $(RTL_FILES)
	@echo "编译完成: $(COREMARK_BIN)"

coremark_compile: $(COREMARK_BIN)

coremark_test: clean coremark_compile
	@echo "========================================"
	@echo "运行测试: CoreMark Benchmark"
	@echo "测试文件: $(COREMARK_HEX)"
	@echo "========================================"
	@cd $(RUN_DIR) && \
		$(VVP) $(COREMARK_BIN) \
		+TESTCASE=$(COREMARK_HEX) \
		+DUMPWAVE=$(DUMPWAVE) \
		+PRINT_INFO=$(PRINT_INFO) \
		+WAVEFILE=$(COREMARK_WAVE)

wave:
	@if [ ! -f "$(WAV_FILE)" ]; then \
		echo "错误: 波形文件不存在: $(WAV_FILE)"; \
		echo "请先运行 'make SIM=$(SIM) run' 生成波形"; \
		exit 1; \
	fi
	$(WAV_TOOL) $(WAV_FILE) &

regress_prepare: compile
	@rm -f $(REGRESS_SUMMARY)

regress_run:
	@echo "========================================"
	@echo "运行回归测试 (共 $(words $(ALL_TESTS)) 个测试)"
	@echo "========================================"
	@for test in $(ALL_TESTS); do \
		echo ">>> 测试: $$test"; \
		cd $(RUN_DIR) && \
			$(VVP) $(SIM_BIN) \
			+TESTCASE=$(TEST_DIR)/$$test.hex \
			+DUMPWAVE=0 \
			+PRINT_INFO=0 \
			2>&1 | grep -E "\[PASS\]|\[FAIL\]|\[EROR\]" | tee -a $(REGRESS_SUMMARY); \
	done
	@echo "========================================"
	@echo "测试完成! 汇总文件: $(REGRESS_SUMMARY)"
	@echo "========================================"

regress_collect:
	@echo ""
	@echo "==========================================="
	@echo "               回归测试汇总"
	@echo "==========================================="
	@if [ -f $(REGRESS_SUMMARY) ]; then \
		cat $(REGRESS_SUMMARY); \
		echo "==========================================="; \
		echo "总计: $(words $(ALL_TESTS)) 个测试"; \
		PASS_COUNT=$$(grep -c "\[PASS\]" $(REGRESS_SUMMARY) || true); \
		FAIL_COUNT=$$(grep -c "\[FAIL\]" $(REGRESS_SUMMARY) || true); \
		EROR_COUNT=$$(grep -c "\[EROR\]" $(REGRESS_SUMMARY) || true); \
		echo "通过: $$PASS_COUNT"; \
		echo "失败: $$FAIL_COUNT"; \
		echo "错误: $$EROR_COUNT"; \
		echo "==========================================="; \
	else \
		echo "没有找到测试结果"; \
	fi

regress: clean compile regress_prepare regress_run regress_collect

clean:
	@echo "清理 Icarus Verilog 生成文件..."
	@rm -rf $(RUN_DIR)
	@rm -rf $(WAVE_DIR)
