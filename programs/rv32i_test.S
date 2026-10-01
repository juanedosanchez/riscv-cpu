# Self-checking RV32I test. Runs in simulation (tb/rv32i_tb.v, tb/top_tb.v)
# and on the board.
#
# Registers reserved by the test harness:
#   t6 (x31)  number of the current check
#   t5 (x30)  result: 0 while running, 0x600D = pass, 0xBAD = fail
#   t4 (x29)  scratch for expected values
#
# On the board:
#   pass -> all four LEDs on, steady
#   fail -> the failing check number (low 4 bits) blinks on the LEDs

    .equ LED_ADDR, 0x10000000
    .equ RAM_BASE, 0x00010000

# Check that \reg == \value
.macro CHECK reg, value
    addi t6, t6, 1
    li   t4, \value
    bne  \reg, t4, fail
.endm

# Check that \ra == \rb
.macro CHECKR ra, rb
    addi t6, t6, 1
    bne  \ra, \rb, fail
.endm

# The branch must be taken
.macro TAKEN op, ra, rb
    addi t6, t6, 1
    \op  \ra, \rb, 1f
    j    fail
1:
.endm

# The branch must not be taken
.macro NOT_TAKEN op, ra, rb
    addi t6, t6, 1
    \op  \ra, \rb, fail
.endm

start:
    li   t6, 0
    li   t5, 0

# ---- x0 ----------------------------------------------------------------
    addi x0, x0, 5
    CHECK x0, 0

# ---- LUI / AUIPC -------------------------------------------------------
    lui  a1, 0x12345
    CHECK a1, 0x12345000

    jal  a2, 1f                 # a2 = address of the auipc below
1:
    auipc a1, 0
    CHECKR a1, a2

    jal  a2, 1f
1:
    auipc a1, 1                 # a1 = a2 + 0x1000
    lui  t3, 1
    add  t3, t3, a2
    CHECKR a1, t3

# ---- Register-register ALU ---------------------------------------------
    li   a1, -7
    li   a2, 3

    add  a3, a1, a2
    CHECK a3, -4
    sub  a3, a1, a2
    CHECK a3, -10
    and  a3, a1, a2
    CHECK a3, 1
    or   a3, a1, a2
    CHECK a3, -5
    xor  a3, a1, a2
    CHECK a3, -6
    sll  a3, a1, a2
    CHECK a3, -56
    srl  a3, a1, a2
    CHECK a3, 0x1FFFFFFF
    sra  a3, a1, a2
    CHECK a3, -1
    slt  a3, a1, a2
    CHECK a3, 1
    slt  a3, a2, a1
    CHECK a3, 0
    sltu a3, a1, a2
    CHECK a3, 0
    sltu a3, a2, a1
    CHECK a3, 1

    li   a4, 35                 # shift amounts use only the low 5 bits
    sll  a3, a2, a4
    CHECK a3, 24

# ---- Register-immediate ALU --------------------------------------------
    addi  a3, a1, 10
    CHECK a3, 3
    slti  a3, a1, -6
    CHECK a3, 1
    slti  a3, a1, -8
    CHECK a3, 0
    sltiu a3, a2, -1
    CHECK a3, 1
    xori  a3, a1, -1
    CHECK a3, 6
    ori   a3, a2, 0x10
    CHECK a3, 0x13
    andi  a3, a1, 0xF0
    CHECK a3, 0xF0
    slli  a3, a2, 4
    CHECK a3, 48
    srli  a3, a1, 28
    CHECK a3, 0xF
    srai  a3, a1, 1
    CHECK a3, -4

# ---- Loads and stores --------------------------------------------------
    li   s0, RAM_BASE
    li   a1, 0x89ABCDEF
    sw   a1, 0(s0)

    lw   a3, 0(s0)
    CHECK a3, 0x89ABCDEF
    lb   a3, 0(s0)
    CHECK a3, 0xFFFFFFEF
    lbu  a3, 0(s0)
    CHECK a3, 0xEF
    lbu  a3, 1(s0)
    CHECK a3, 0xCD
    lb   a3, 3(s0)
    CHECK a3, 0xFFFFFF89
    lh   a3, 0(s0)
    CHECK a3, 0xFFFFCDEF
    lhu  a3, 2(s0)
    CHECK a3, 0x89AB
    lh   a3, 2(s0)
    CHECK a3, 0xFFFF89AB

    li   a4, 0x55
    sb   a4, 1(s0)
    lw   a3, 0(s0)
    CHECK a3, 0x89AB55EF

    li   a4, 0x1234
    sh   a4, 2(s0)
    lw   a3, 0(s0)
    CHECK a3, 0x123455EF

    addi a5, s0, 8              # negative offset, second word
    sw   a1, -4(a5)
    lw   a3, 4(s0)
    CHECK a3, 0x89ABCDEF
    lw   a3, 0(s0)              # first word unchanged
    CHECK a3, 0x123455EF

# ---- LED register read-back --------------------------------------------
    li   s1, LED_ADDR
    li   a1, 0xA
    sw   a1, 0(s1)
    lw   a3, 0(s1)
    CHECK a3, 0xA

# ---- Branches ----------------------------------------------------------
    li   a1, -7
    li   a2, 3

    TAKEN     beq,  a1, a1
    NOT_TAKEN beq,  a1, a2
    TAKEN     bne,  a1, a2
    NOT_TAKEN bne,  a1, a1
    TAKEN     blt,  a1, a2
    NOT_TAKEN blt,  a2, a1
    TAKEN     bge,  a2, a1
    TAKEN     bge,  a1, a1
    NOT_TAKEN bge,  a1, a2
    TAKEN     bltu, a2, a1
    NOT_TAKEN bltu, a1, a2
    TAKEN     bgeu, a1, a2
    NOT_TAKEN bgeu, a2, a1

    li   a3, 0                  # backward branch: count to 5
    li   a4, 5
1:
    addi a3, a3, 1
    bne  a3, a4, 1b
    CHECK a3, 5

# ---- JAL / JALR --------------------------------------------------------
    jal  ra, set_42
    CHECK a3, 42

    jal  a2, 1f                 # a2 = address of the jalr
1:
    jalr a3, 12(a2)             # jump to a2 + 12, a3 = a2 + 4
    j    fail
    j    fail
    addi t3, a2, 4
    CHECKR a3, t3

    jal  a2, 1f
1:
    jalr x0, 13(a2)             # target bit 0 is cleared: a2 + 12
    j    fail
    j    fail
    addi t6, t6, 1              # reached the right target

# ---- Done --------------------------------------------------------------
pass:
    li   s1, LED_ADDR
    li   a1, 0xF
    sw   a1, 0(s1)
    li   t5, 0x600D
pass_loop:
    j    pass_loop

fail:
    li   t5, 0xBAD
    li   s1, LED_ADDR
fail_loop:
    sw   t6, 0(s1)
    jal  ra, delay
    sw   zero, 0(s1)
    jal  ra, delay
    j    fail_loop

set_42:
    li   a3, 42
    ret

# About 0.2 s at 27 MHz
delay:
    li   t3, 2700000
1:
    addi t3, t3, -1
    bnez t3, 1b
    ret
