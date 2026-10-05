# UART bootloader, runs from the boot ROM (0x10000) after every reset.
#
# 1. Prints "RVBOOT\r\n".
# 2. Waits about 0.5 s for a command byte:
#      'L' <length:u32 LE> <length bytes> <checksum:u32 LE>
#          load the bytes into RAM at address 0. The checksum is the
#          32-bit sum of all bytes. Replies 'K' and runs the program,
#          or replies 'E' and starts over.
#      'R' run the program already in RAM.
#    Any other byte is ignored. On timeout it runs the program in RAM.
# 3. Runs the program by jumping to address 0.
#
# The boot ROM is fetch-only, so this code uses no data in memory: the
# banner is built from immediates, and state lives only in registers.

    .equ IO,          0x10000000
    .equ UART_DATA,   4
    .equ UART_STATUS, 8
    .equ RAM_SIZE,    16384
    .equ TIMEOUT,     2250000       # ~6 cycles per poll at 27 MHz -> ~0.5 s

    .text
    .globl _start
_start:
    li   s0, IO

    li   a0, 'R'
    jal  ra, putc
    li   a0, 'V'
    jal  ra, putc
    li   a0, 'B'
    jal  ra, putc
    li   a0, 'O'
    jal  ra, putc
    li   a0, 'O'
    jal  ra, putc
    li   a0, 'T'
    jal  ra, putc
    li   a0, '\r'
    jal  ra, putc
    li   a0, '\n'
    jal  ra, putc

    li   s4, TIMEOUT
wait_command:
    lw   t0, UART_STATUS(s0)
    andi t0, t0, 2
    bnez t0, command
    addi s4, s4, -1
    bnez s4, wait_command
    j    run

command:
    lw   a0, UART_DATA(s0)
    li   t0, 'L'
    beq  a0, t0, load
    li   t0, 'R'
    beq  a0, t0, run
    j    wait_command

load:
    jal  ra, get_u32
    mv   s1, a0                     # s1 = length
    li   t0, RAM_SIZE
    bgtu s1, t0, error

    li   s2, 0                      # s2 = address
    li   s3, 0                      # s3 = checksum
load_byte:
    beq  s2, s1, load_done
    jal  ra, getc
    sb   a0, 0(s2)
    add  s3, s3, a0
    addi s2, s2, 1
    j    load_byte

load_done:
    jal  ra, get_u32
    bne  a0, s3, error

    li   a0, 'K'
    jal  ra, putc
    j    run

error:
    li   a0, 'E'
    jal  ra, putc
    j    _start

run:
    jr   zero                       # jump to address 0

# a0 = next received byte (blocking)
getc:
    lw   t0, UART_STATUS(s0)
    andi t0, t0, 2
    beqz t0, getc
    lw   a0, UART_DATA(s0)
    ret

# send the byte in a0 (waits for the transmitter)
putc:
    lw   t0, UART_STATUS(s0)
    andi t0, t0, 1
    beqz t0, putc
    sw   a0, UART_DATA(s0)
    ret

# a0 = little-endian 32-bit value from the next 4 bytes
get_u32:
    mv   t3, ra
    li   t1, 0                      # value
    li   t2, 0                      # shift
1:
    jal  ra, getc
    sll  a0, a0, t2
    or   t1, t1, a0
    addi t2, t2, 8
    li   t4, 32
    bne  t2, t4, 1b
    mv   a0, t1
    mv   ra, t3
    ret
