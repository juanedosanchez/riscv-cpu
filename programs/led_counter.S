# Count 0..15 on the four Dock LEDs, about 5 steps per second at 27 MHz.

    .equ LED_ADDR, 0x10000000
    .equ RAM_TOP,  0x00010400
    .equ DELAY,    2700000          # 2 instructions per iteration

    li   sp, RAM_TOP
    li   s0, LED_ADDR
    li   s1, 0

loop:
    sw   s1, 0(s0)
    addi s1, s1, 1
    jal  ra, delay
    j    loop

# delay: busy-wait DELAY iterations (uses the stack to save s1 as a demo)
delay:
    addi sp, sp, -4
    sw   s1, 0(sp)
    li   s1, DELAY
1:
    addi s1, s1, -1
    bnez s1, 1b
    lw   s1, 0(sp)
    addi sp, sp, 4
    ret
