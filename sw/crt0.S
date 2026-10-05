# Startup code for main RAM programs (linked first, at address 0).

    .section .text.start, "ax"
    .globl _start
_start:
    la   sp, __stack_top

    # Clear .bss (RAM keeps old contents across resets and uploads)
    la   t0, __bss_start
    la   t1, __bss_end
1:
    bgeu t0, t1, 2f
    sw   zero, 0(t0)
    addi t0, t0, 4
    j    1b
2:
    call main

    # main returned: stop here
3:
    j    3b
