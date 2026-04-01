# ========================================
# RISC-V CPU Verilator 自动化测试配置
# ========================================

ifeq ($(origin DUMPWAVE), undefined)
DUMPWAVE := 0
endif

RUN_DIR         := $(SIM_DIR)/prj/verilator
OBJ_DIR         := $(RUN_DIR)/obj_dir
COREMARK_OBJ    := $(RUN_DIR)/coremark_obj_dir
TB_TOP          := $(VERILATOR_TB_TOP)
TB_MODULE       := tb_Verilator
COREMARK_TOP    := coremark

VERILATOR       ?= verilator
JOBS            ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)

VERILATOR_WARNINGS := -Wno-fatal -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-PINCONNECTEMPTY
VERILATOR_FLAGS    := -sv --timing --binary --build --trace -j $(JOBS)
VERILATOR_FLAGS    += -I$(SRC_DIR) -I$(SRC_DIR)/include
VERILATOR_FLAGS    += $(VERILATOR_WARNINGS)
VERILATOR_PARAM_FLAGS :=

ifneq ($(strip $(BPU_TYPE)),)
VERILATOR_PARAM_FLAGS += -GBPU_TYPE=$(BPU_TYPE)
endif

SIM_BIN         := $(OBJ_DIR)/V$(TB_MODULE)
COREMARK_BIN    := $(COREMARK_OBJ)/V$(COREMARK_TOP)
WAV_FILE        := $(RUN_DIR)/wave.vcd
COREMARK_WAVE   := $(RUN_DIR)/coremark.vcd
REGRESS_SUMMARY := $(RUN_DIR)/regress_summary_$(FOLDER)_verilator.txt

.PHONY: all help list_tests compile run coremark_compile coremark_test wave regress regress_prepare regress_run regress_collect clean

all: compile help regress

help:
	@echo "=========================================="
	@echo "RISC-V CPU 自动化测试 Makefile"
	@echo "=========================================="
	@echo "当前仿真器: Verilator (SIM=$(SIM))"
	@echo "配置文件:   verilator.mk"
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

$(SIM_BIN): $(TB_TOP) $(RTL_FILES) | $(RUN_DIR)
	@echo "========================================"
	@echo "编译 Verilator 测试台..."
	@echo "顶层模块: $(TB_MODULE)"
	@echo "测试文件: $(TB_TOP)"
	@echo "输出目录: $(OBJ_DIR)"
	@echo "========================================"
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_PARAM_FLAGS) \
		--top-module $(TB_MODULE) \
		-Mdir $(OBJ_DIR) \
		$(TB_TOP) $(RTL_FILES)
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
	@$(SIM_BIN) \
		+TESTCASE=$(TEST_HEX) \
		+DUMPWAVE=$(DUMPWAVE) \
		+PRINT_INFO=$(PRINT_INFO) \
		+WAVEFILE=$(WAV_FILE)

$(COREMARK_BIN): $(COREMARK_TB) $(RTL_FILES) | $(RUN_DIR)
	@echo "========================================"
	@echo "编译 Verilator CoreMark 测试台..."
	@echo "顶层模块: $(COREMARK_TOP)"
	@echo "测试文件: $(COREMARK_TB)"
	@echo "输出目录: $(COREMARK_OBJ)"
	@echo "========================================"
	$(VERILATOR) $(VERILATOR_FLAGS) $(VERILATOR_PARAM_FLAGS) \
		--top-module $(COREMARK_TOP) \
		-Mdir $(COREMARK_OBJ) \
		$(COREMARK_TB) $(RTL_FILES)
	@echo "编译完成: $(COREMARK_BIN)"

coremark_compile: $(COREMARK_BIN)

coremark_test: clean coremark_compile
	@echo "========================================"
	@echo "运行测试: CoreMark Benchmark"
	@echo "测试文件: $(COREMARK_HEX)"
	@echo "========================================"
	@$(COREMARK_BIN) \
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
		$(SIM_BIN) \
			+TESTCASE=$(TEST_DIR)/$$test.hex \
			+DUMPWAVE=0 \
			+PRINT_INFO=0 \
			+WAVEFILE=$(RUN_DIR)/$$test.vcd \
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
	@echo "清理 Verilator 生成文件..."
	@rm -rf $(RUN_DIR)
