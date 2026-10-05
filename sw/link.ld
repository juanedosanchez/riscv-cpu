/* Main RAM programs: code, data and stack all live in the 16 KB RAM at 0.
   The image (text + rodata + data) is loaded by the bitstream or the
   bootloader; .bss is cleared by crt0. The stack grows down from the top. */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    RAM (rwx) : ORIGIN = 0x00000000, LENGTH = 16K
}

SECTIONS
{
    .text : {
        KEEP(*(.text.start))
        *(.text .text.*)
    } > RAM

    .rodata : ALIGN(4) {
        *(.rodata .rodata.* .srodata .srodata.*)
    } > RAM

    .data : ALIGN(4) {
        *(.data .data.* .sdata .sdata.*)
    } > RAM

    .bss (NOLOAD) : ALIGN(4) {
        __bss_start = .;
        *(.bss .bss.* .sbss .sbss.* COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > RAM

    __stack_top = ORIGIN(RAM) + LENGTH(RAM);

    /DISCARD/ : {
        *(.comment) *(.note .note.*) *(.riscv.attributes) *(.eh_frame*)
    }
}

ASSERT(__bss_end <= __stack_top - 1024, "less than 1 KB left for the stack")
