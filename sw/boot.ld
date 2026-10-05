/* Boot ROM: 1 KB at 0x10000, fetch only. The CPU cannot read the boot
   ROM with loads, so the bootloader must not use .rodata or .data. */

OUTPUT_ARCH(riscv)
ENTRY(_start)

MEMORY
{
    BOOT (rx) : ORIGIN = 0x00010000, LENGTH = 1K
}

SECTIONS
{
    .text : {
        *(.text .text.*)
    } > BOOT

    .rodata : { *(.rodata .rodata.* .srodata .srodata.*) } > BOOT
    .data   : { *(.data .data.* .sdata .sdata.*) } > BOOT
    .bss    : { *(.bss .bss.* .sbss .sbss.* COMMON) } > BOOT

    /DISCARD/ : {
        *(.comment) *(.note .note.*) *(.riscv.attributes) *(.eh_frame*)
    }
}

ASSERT(SIZEOF(.rodata) == 0 && SIZEOF(.data) == 0 && SIZEOF(.bss) == 0,
       "the bootloader cannot use rodata/data/bss (boot ROM is fetch-only)")
