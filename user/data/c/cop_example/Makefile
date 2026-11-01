RISCV_PREFIX := riscv32-unknown-elf-
CC           := $(RISCV_PREFIX)gcc
OBJDUMP      := $(RISCV_PREFIX)objdump

ARCH_FLAGS   := -march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -nostdlib -nostartfiles -O2 -Wall -Wextra
CFI_INSERT   ?= 1
ZICFI_RUNTIME_ENABLE ?= 1

CFI_STABLE_FLAGS := -fno-inline -fno-optimize-sibling-calls

ifeq ($(CFI_INSERT),1)
COP_FLAGS ?= -fcf-protection=branch $(CFI_STABLE_FLAGS)
CFI_SUFFIX := cfi_on
else
COP_FLAGS ?=
CFI_SUFFIX := cfi_off
endif

ifeq ($(ZICFI_RUNTIME_ENABLE),1)
RT_SUFFIX := rt_on
else
RT_SUFFIX := rt_off
endif

CPPFLAGS += -DZICFI_RUNTIME_ENABLE=$(ZICFI_RUNTIME_ENABLE)

TARGET       ?= cop_zicfilp_$(CFI_SUFFIX)_$(RT_SUFFIX)
ELF          := $(TARGET).elf
STEXT        := $(TARGET).SText
HEX_DIR      := ../../hex
HEX          := $(HEX_DIR)/$(TARGET).hex

MATRIX_TARGETS := \
	cop_zicfilp_cfi_off_rt_off \
	cop_zicfilp_cfi_off_rt_on \
	cop_zicfilp_cfi_on_rt_off \
	cop_zicfilp_cfi_on_rt_on

.PHONY: all matrix $(MATRIX_TARGETS) clean

all: $(ELF) $(STEXT) $(HEX)

matrix: $(MATRIX_TARGETS)

cop_zicfilp_cfi_off_rt_off:
	$(MAKE) TARGET=$@ CFI_INSERT=0 ZICFI_RUNTIME_ENABLE=0

cop_zicfilp_cfi_off_rt_on:
	$(MAKE) TARGET=$@ CFI_INSERT=0 ZICFI_RUNTIME_ENABLE=1

cop_zicfilp_cfi_on_rt_off:
	$(MAKE) TARGET=$@ CFI_INSERT=1 ZICFI_RUNTIME_ENABLE=0

cop_zicfilp_cfi_on_rt_on:
	$(MAKE) TARGET=$@ CFI_INSERT=1 ZICFI_RUNTIME_ENABLE=1

$(ELF): start.S call_helper.S main.c link.ld
	$(CC) $(COMMON_FLAGS) $(CPPFLAGS) $(COP_FLAGS) -T link.ld start.S call_helper.S main.c -o $(ELF)

$(STEXT): $(ELF)
	$(OBJDUMP) -d $(ELF) > $(STEXT)

$(HEX): $(ELF)
	mkdir -p $(HEX_DIR)
	elf2hex 4 8192 $(ELF) > $(HEX)

clean:
	rm -f $(ELF) $(STEXT)
	rm -f $(addsuffix .elf,$(MATRIX_TARGETS))
	rm -f $(addsuffix .SText,$(MATRIX_TARGETS))
	rm -f $(HEX_DIR)/cop_zicfilp_*.hex
