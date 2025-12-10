# ========================================
# RISC-V CPU 自动化测试 Makefile
# ========================================

# 扩展名
EXT		  	 := hex

# 目录定义
SIM_DIR      := $(shell pwd)
RUN_DIR      := ${SIM_DIR}/prj/run
SRC_DIR      := ${SIM_DIR}/user/src
SIM_TB_DIR   := ${SIM_DIR}/user/data/isa
TEST_DIR     := ${SIM_DIR}/user/data/isa/${EXT}

# 顶层测试文件
TB_TOP       := ${SIM_TB_DIR}/test_tb.sv

# 测试配置
TESTCASE     := rv32ui-p-add

# 仿真选项
DUMPWAVE     := 0
PRINT_INFO   := 0

# 仿真工具配置
SIM_TOOL     := iverilog
WAV_TOOL     := gtkwave

# 获取所有源文件
RTL_FILES    := $(wildcard ${SRC_DIR}/*.sv)
RTL_FILES    := $(filter-out ${SRC_DIR}/Makefile, ${RTL_FILES})
TB_FILES     := ${TB_TOP}

# iverilog 编译选项
ifeq ($(SIM_TOOL),iverilog)
    SIM_OPTIONS := -g2012 -Wall
    SIM_OPTIONS += -I ${SRC_DIR}
    SIM_OPTIONS += -I ${SRC_DIR}/include
    SIM_OPTIONS += -o ${RUN_DIR}/test_tb.vvp
    SIM_EXEC    := vvp ${RUN_DIR}/test_tb.vvp
endif

# VCS 编译选项 (备选)
ifeq ($(SIM_TOOL),vcs)
    SIM_OPTIONS := -sverilog -full64 -debug_access+all
    SIM_OPTIONS += -timescale=1ns/1ps
    SIM_OPTIONS += +incdir+${SRC_DIR}
    SIM_OPTIONS += +incdir+${SRC_DIR}/include
    SIM_OPTIONS += -o ${RUN_DIR}/simv
    SIM_EXEC    := ${RUN_DIR}/simv
endif

# 波形文件
WAV_FILE     := ${RUN_DIR}/wave.vcd

# 所有测试用例 (从 ${EXT} 目录获取)
ALL_TESTS    := $(basename $(notdir $(wildcard ${TEST_DIR}/*.${EXT})))

# ========================================
# 主要目标
# ========================================

.PHONY: all clean compile run wave help list_tests regress

all: run

help:
	@echo "=========================================="
	@echo "RISC-V CPU 自动化测试 Makefile"
	@echo "=========================================="
	@echo "使用方法:"
	@echo "  make run              - 编译并运行默认测试"
	@echo "  make compile          - 仅编译"
	@echo "  make wave             - 查看波形"
	@echo "  make list_tests       - 列出所有可用测试"
	@echo "  make regress          - 运行所有测试用例"
	@echo "  make clean            - 清理生成文件"
	@echo ""
	@echo "运行特定测试:"
	@echo "  make run TESTCASE=<test_name>"
	@echo ""
	@echo "示例:"
	@echo "  make run TESTCASE=simple_test"
	@echo "  make run TESTCASE=full_test DUMPWAVE=0"
	@echo "=========================================="

list_tests:
	@echo "可用的测试用例:"
	@for test in $(ALL_TESTS); do echo "  - $$test"; done

# ========================================
# 编译
# ========================================

${RUN_DIR}:
	@echo "创建运行目录: ${RUN_DIR}"
	@mkdir -p ${RUN_DIR}

compile: ${RUN_DIR}
	@echo "========================================"
	@echo "编译仿真文件..."
	@echo "仿真工具: ${SIM_TOOL}"
	@echo "源文件目录: ${SRC_DIR}"
	@echo "测试文件: ${TB_TOP}"
	@echo "========================================"
	${SIM_TOOL} ${SIM_OPTIONS} ${TB_FILES} ${RTL_FILES}
	@echo "编译完成!"

# ========================================
# 运行仿真
# ========================================

run:
	@echo "========================================"
	@echo "运行测试: ${TESTCASE}"
	@echo "测试文件: ${TEST_DIR}/${TESTCASE}.${EXT}"
	@echo "========================================"
	@if [ ! -f "${TEST_DIR}/${TESTCASE}.${EXT}" ]; then \
		echo "错误: 测试文件不存在: ${TEST_DIR}/${TESTCASE}.${EXT}"; \
		echo "请使用 'make list_tests' 查看可用测试"; \
		exit 1; \
	fi
	@${SIM_TOOL} ${SIM_OPTIONS} ${TB_FILES} ${RTL_FILES} > /dev/null 2>&1
	@cd ${RUN_DIR} && \
		${SIM_EXEC} \
		+TESTCASE=${TEST_DIR}/${TESTCASE}.${EXT} \
		+DUMPWAVE=${DUMPWAVE} \
		+PRINT_INFO=${PRINT_INFO} \
# 		2>&1 | tee ${TESTCASE}.log
# 	@echo "========================================"
# 	@echo "测试完成! 日志文件: ${RUN_DIR}/${TESTCASE}.log"
# 	@echo "========================================"

# ========================================
# 波形查看
# ========================================

wave:
	@if [ ! -f "${WAV_FILE}" ]; then \
		echo "错误: 波形文件不存在: ${WAV_FILE}"; \
		echo "请先运行 'make run' 生成波形"; \
		exit 1; \
	fi
	@echo "打开波形文件: ${WAV_FILE}"
	${WAV_TOOL} ${WAV_FILE} &

# ========================================
# 回归测试 (运行所有测试用例)
# ========================================

regress_prepare:
	@echo "准备回归测试..."
	@make compile
	@rm -f ${RUN_DIR}/*.log
	@rm -f ${RUN_DIR}/regress_summary.txt

regress_run:
	@echo "========================================"
	@echo "运行回归测试 (共 $(words $(ALL_TESTS)) 个测试)"
	@echo "========================================"
	@for test in $(ALL_TESTS); do \
		echo ">>> 测试: $$test"; \
		make run TESTCASE=$$test DUMPWAVE=0 PRINT_INFO=0 2>&1 | grep -E "\[PASS\]|\[FAIL\]" | tee -a ${RUN_DIR}/regress_summary.txt; \
	done
	@echo "========================================"
	@echo "测试完成! 汇总文件: ${RUN_DIR}/regress_summary.txt"
	@echo "========================================"

regress_collect:
	@echo ""
	@echo "========================================"
	@echo "回归测试汇总"
	@echo "========================================"
	@if [ -f ${RUN_DIR}/regress_summary.txt ]; then \
		cat ${RUN_DIR}/regress_summary.txt; \
		echo "========================================"; \
		echo "总计: $(words $(ALL_TESTS)) 个测试"; \
		echo "通过: $$(grep -c PASS ${RUN_DIR}/regress_summary.txt)"; \
		echo "失败: $$(grep -c FAIL ${RUN_DIR}/regress_summary.txt)"; \
		echo "========================================"; \
	else \
		echo "没有找到测试结果"; \
	fi

regress_clear:
	@clear

regress: regress_prepare regress_clear regress_run regress_collect

# ========================================
# 清理
# ========================================

clean:
	@echo "清理生成文件..."
	@rm -rf ${RUN_DIR}
	@rm -f *.vvp *.vcd *.log
	@echo "清理完成!"

# ========================================
# 调试信息
# ========================================

debug_info:
	@echo "========================================"
	@echo "调试信息"
	@echo "========================================"
	@echo "SIM_DIR:     ${SIM_DIR}"
	@echo "RUN_DIR:     ${RUN_DIR}"
	@echo "SRC_DIR:     ${SRC_DIR}"
	@echo "TEST_DIR:    ${TEST_DIR}"
	@echo "TB_TOP:      ${TB_TOP}"
	@echo "TESTCASE:    ${TESTCASE}"
	@echo "TESTCASE:    ${TESTCASE}"
	@echo "SIM_TOOL:    ${SIM_TOOL}"
	@echo "=========================================="
	@echo "RTL 文件:"
	@for f in $(RTL_FILES); do echo "  $$f"; done
	@echo "=========================================="
	@echo "测试用例:"
	@for t in $(ALL_TESTS); do echo "  $$t"; done
	@echo "=========================================="
