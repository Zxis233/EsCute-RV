OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
  /* 你的 CPU reset 从 0 开始取指 */
  . = 0x80000000;

  /* 启动入口，放在最前面 */
  .text.init : {
    *(.text.init)
  }

  /* 不要再 ALIGN(0x1000)！否则 .text 会被推到 0x1000 */
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

  _shadow_stack_top = 0x8000C000;
  _stack_top        = 0x8000FF00;
  _end              = .;
}

ASSERT(_end < _stack_top - 0x1000, "ERROR: program too large / stack overlap!");
ASSERT(_end < _shadow_stack_top - 0x1000, "ERROR: program too large / shadow stack overlap!");
ASSERT(_shadow_stack_top < _stack_top - 0x1000, "ERROR: shadow stack too close to regular stack!");
