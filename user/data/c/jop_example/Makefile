RISCV_PREFIX := riscv64-unknown-elf-
CC           := $(RISCV_PREFIX)gcc
OBJDUMP      := $(RISCV_PREFIX)objdump

ARCH_FLAGS   := -march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32
COMMON_FLAGS := $(ARCH_FLAGS) -ffreestanding -fno-builtin -nostdlib -nostartfiles -O2 -Wall -Wextra
JOP_FLAGS    := # -fcf-protection=branch -fno-inline -fno-optimize-sibling-calls

TARGET       := jop_zicfilp_fail
ELF          := $(TARGET).elf
STEXT        := $(TARGET).SText
HEX          := ../../hex/$(TARGET).hex

.PHONY: all clean

all: $(ELF) $(STEXT) $(HEX)

$(ELF): start.S bad_target.S main.c link.ld
	$(CC) $(COMMON_FLAGS) $(JOP_FLAGS) -T link.ld start.S bad_target.S main.c -o $(ELF)

$(STEXT): $(ELF)
	$(OBJDUMP) -d $(ELF) > $(STEXT)

$(HEX): $(ELF)
	elf2hex 4 8192 $(ELF) > $(HEX)

clean:
	rm -f $(ELF) $(STEXT)
	rm -f $(HEX)
