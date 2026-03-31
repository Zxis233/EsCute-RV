RISCV_PREFIX := riscv32-unknown-elf-
CC           := $(RISCV_PREFIX)gcc
OBJDUMP      := $(RISCV_PREFIX)objdump

ARCH_FLAGS   := -march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -nostdlib -nostartfiles -O2 -Wall -Wextra
AUTO_CFI_FLAGS := -fcf-protection=full -fno-inline -fno-optimize-sibling-calls

TARGET       := zicfi_c_demo
ELF          := $(TARGET).elf
STEXT        := $(TARGET).SText
HEX          := ../../hex/$(TARGET).hex

AUTO_TARGET  := zicfi_c_auto
AUTO_ELF     := $(AUTO_TARGET).elf
AUTO_STEXT   := $(AUTO_TARGET).SText
AUTO_HEX     := ../../hex/$(AUTO_TARGET).hex

.PHONY: all clean

all: $(ELF) $(STEXT) $(HEX) auto

$(ELF): start.S cfi_helpers.S main.c link.ld
	$(CC) $(COMMON_FLAGS) -T link.ld start.S cfi_helpers.S main.c -o $(ELF)

$(STEXT): $(ELF)
	$(OBJDUMP) -d $(ELF) > $(STEXT)

$(HEX): $(ELF)
	elf2hex 4 8192 $(ELF) > $(HEX)

auto: $(AUTO_ELF) $(AUTO_STEXT) $(AUTO_HEX)

$(AUTO_ELF): start.S main_auto.c link.ld
	$(CC) $(COMMON_FLAGS) $(AUTO_CFI_FLAGS) -T link.ld start.S main_auto.c -o $(AUTO_ELF)

$(AUTO_STEXT): $(AUTO_ELF)
	$(OBJDUMP) -d $(AUTO_ELF) > $(AUTO_STEXT)

$(AUTO_HEX): $(AUTO_ELF)
	elf2hex 4 8192 $(AUTO_ELF) > $(AUTO_HEX)

clean:
	rm -f $(ELF) $(STEXT)
	rm -f $(AUTO_ELF) $(AUTO_STEXT)
	rm -f $(HEX)
	rm -f $(AUTO_HEX)
