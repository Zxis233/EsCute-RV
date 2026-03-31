#=======================================================================
# Makefile for riscv-tests/isa
#-----------------------------------------------------------------------

XLEN ?= 32

src_dir ?= .
src_root := $(patsubst %/,%,$(src_dir))
generated_dir := $(src_root)/generated
hex_dir := $(src_root)/hex
verilog_dir := $(src_root)/verilog

include $(src_dir)/rv32ui/Makefrag
include $(src_dir)/rv32mi/Makefrag
include $(src_dir)/rv32si/Makefrag

default: all

#--------------------------------------------------------------------
# Build rules
#--------------------------------------------------------------------

RISCV_PREFIX ?= riscv32-unknown-elf-
RISCV_GCC ?= $(RISCV_PREFIX)gcc
RISCV_GCC_OPTS ?= -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles
RISCV_OBJDUMP ?= $(RISCV_PREFIX)objdump --disassemble-all --disassemble-zeroes --section=.text --section=.text.startup --section=.text.init --section=.data
RISCV_OBJCOPY ?= $(RISCV_PREFIX)objcopy -O verilog 
RISCV_SIM ?= spike

vpath %.S $(src_dir)

#------------------------------------------------------------
# Build assembly tests

%.dump: %
	$(RISCV_OBJDUMP) $< > $@
	$(RISCV_OBJCOPY) $<   $<.verilog
	sed -i 's/@800/@000/g' $<.verilog
	sed -i 's/@00002FB8/@00002000/g' $<.verilog
	mkdir -p $(verilog_dir)
	mv $<.verilog $(verilog_dir)/
	@mkdir -p $(hex_dir)
	@base=$$(basename $< .elf); \
	elf2hex 4 16384 $< > $(hex_dir)/$${base}.hex
# 	@rm -f $<.verilog


%.out: %
	$(RISCV_SIM) --isa=rv64gch_ziccid_zfh_zicboz_svnapot_zicntr_zba_zbb_zbc_zbs --misaligned $< 2> $@

%.out32: %
	$(RISCV_SIM) --isa=rv32gc_ziccid_zfh_zicboz_svnapot_zicntr_zba_zbb_zbc_zbs --misaligned $< 2> $@

define compile_template

$$($(1)_p_tests): $(1)-p-%: $(1)/%.S
	$$(RISCV_GCC) $(2) $$(RISCV_GCC_OPTS) -I$(src_dir)/env -T$(src_dir)env/link.ld $$< -o $$@
$(1)_tests += $$($(1)_p_tests)


$(1)_tests_dump = $$(addsuffix .dump, $$($(1)_tests))

$(1): $$($(1)_tests_dump)

.PHONY: $(1)

COMPILER_SUPPORTS_$(1) := $$(shell $$(RISCV_GCC) $(2) -c -x c /dev/null -o /dev/null 2> /dev/null; echo $$$$?)

ifeq ($$(COMPILER_SUPPORTS_$(1)),0)
tests += $$($(1)_tests)
endif

endef

$(eval $(call compile_template,rv32ui,-march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32 -fcf-protection=full -fno-inline -fno-optimize-sibling-calls))
$(eval $(call compile_template,rv32mi,-march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32 -fcf-protection=full -fno-inline -fno-optimize-sibling-calls))
$(eval $(call compile_template,rv32si,-march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32 -fcf-protection=full -fno-inline -fno-optimize-sibling-calls))

tests_dump = $(addsuffix .dump, $(tests))
tests_hex = $(addsuffix .hex, $(tests))
tests_out = $(addsuffix .out, $(filter rv64%,$(tests)))
tests32_out = $(addsuffix .out32, $(filter rv32%,$(tests)))

run: $(tests_out) $(tests32_out)

junk += $(tests) $(tests_dump) $(tests_hex) $(tests_out) $(tests32_out)

#------------------------------------------------------------
# Default

all: $(tests_dump)

#------------------------------------------------------------
# Clean up

clean:
	rm -rf $(junk)
	@for dir in "$(generated_dir)" "$(hex_dir)" "$(verilog_dir)"; do \
		if [ -d "$$dir" ]; then rm -rf "$$dir"/* "$$dir"/.[!.]* "$$dir"/..?* 2>/dev/null || true; fi; \
	done
