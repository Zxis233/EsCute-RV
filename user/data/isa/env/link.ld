OUTPUT_ARCH( "riscv" )
ENTRY(_start)

SECTIONS
{
  . = 0x00000000;
  .text.init : { *(.text.init) }
  . = ALIGN(0x1000);
  .tohost : { *(.tohost) }
  . = ALIGN(0x1000);
  .text : { *(.text .text.*) }
  . = ALIGN(0x1000);
  .data : { *(.data .data.*) }
  .rodata : { *(.rodata .rodata.*) }
  .bss : { *(.bss .bss.*) }
  _end = .;
}

