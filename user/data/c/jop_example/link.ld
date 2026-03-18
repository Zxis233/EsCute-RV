OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;

  .text.init : {
    *(.text.init)
  }

  .text : {
    *(.text .text.*)
    *(.rodata .rodata.*)
  }

  .data : {
    *(.data .data.*)
  }

  .bss : {
    *(.bss .bss.*)
    *(COMMON)
  }

  _stack_top = 0x0000FF00;
  _end = .;
}

ASSERT(_end < _stack_top - 0x1000, "ERROR: program too large / stack overlap!");
