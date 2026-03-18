# ===== Toolchain (hardcoded) =====
OUTFLAG = -o
OBJOUT  = -o
OFLAG   = -o
COUT    = -c

# RISC-V toolchain
CC = riscv64-unknown-elf-gcc
LD = riscv64-unknown-elf-gcc
AS = riscv64-unknown-elf-as

# ===== RV32 baremetal flags =====
PORT_CFLAGS = -O2 -g
ARCH_FLAGS  = -march=rv32i_zicsr_zmmul_zicfiss_zicfilp -mabi=ilp32

# freestanding / no libc
BAREMETAL_FLAGS = -ffreestanding -fno-builtin -nostdlib -nostartfiles

# include paths + CoreMark flag string
FLAGS_STR = "$(PORT_CFLAGS) $(XCFLAGS) $(XLFLAGS) $(LFLAGS_END)"
CFLAGS = $(PORT_CFLAGS) $(ARCH_FLAGS) $(BAREMETAL_FLAGS) \
         -I$(PORT_DIR) -I. -DFLAGS_STR=\"$(FLAGS_STR)\"

# ===== Linker script & startup =====
# 注意：这里把你的 start.S 和 link.ld 硬编码加入
LFLAGS     = $(ARCH_FLAGS) $(BAREMETAL_FLAGS) -T link.ld start.S
LFLAGS_END =

# ===== Port sources =====
PORT_SRCS = core_portme.c \
            ee_printf.c \
            soft_div.c

PORT_OBJS = core_portme.o \
            ee_printf.o \
            soft_div.o

vpath %.c $(PORT_DIR)
vpath %.s $(PORT_DIR)

# ===== Output format =====
OEXT = .o
EXE  = .elf   # ✅ 必须是 ELF，方便 elf2hex

SEPARATE_COMPILE = 1
ASFLAGS = $(ARCH_FLAGS)

# ===== Compile rules =====
$(OPATH)$(PORT_DIR)/%$(OEXT) : %.c
	$(CC) $(CFLAGS) $(XCFLAGS) $(COUT) $< $(OBJOUT) $@

$(OPATH)%$(OEXT) : %.c
	$(CC) $(CFLAGS) $(XCFLAGS) $(COUT) $< $(OBJOUT) $@

$(OPATH)$(PORT_DIR)/%$(OEXT) : %.s
	$(AS) $(ASFLAGS) $< $(OBJOUT) $@

.PHONY : port_prebuild port_postbuild port_prerun port_postrun port_preload port_postload
port_pre% port_post% :

OPATH = ./
MKDIR = mkdir -p

LOAD = elf2hex 4 8192 $(OUTFILE) > $(PORT_DIR)/coremark.hex && riscv64-unknown-elf-objdump -d $(OUTFILE) > $(PORT_DIR)/coremark.SText
# RUN = cd ../ && make coremark_test TESTCASE=coremark 
RUN = TRUE