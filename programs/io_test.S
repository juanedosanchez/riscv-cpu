# Buttons and cycle counter test. Used by tb/io_tb.v.
#   a0 = difference between two back-to-back cycle counter reads
#        (2: a load takes two cycles)
#   then copies the buttons to the LEDs forever

    .equ IO,      0x10000000
    .equ BUTTONS, 12
    .equ CYCLES,  16

    .text
    .globl main
main:
    li   s0, IO
    lw   t0, CYCLES(s0)
    lw   t1, CYCLES(s0)
    sub  a0, t1, t0

loop:
    lw   t2, BUTTONS(s0)
    sw   t2, 0(s0)
    j    loop
