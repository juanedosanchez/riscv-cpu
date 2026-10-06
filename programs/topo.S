# Topo: whack-a-mole on the four Dock buttons and LEDs.
#
#   button  S1/T3  S2/T2  S3/D7  S4/C7      (BUTTONS bit 0..3)
#   LED     N14    N16    A13    C13        (LED_REG bit 0..3)
#   Dock    LED3   LED2   LED1   LED0       (silkscreen names)
#
# Idle: LEDs alternate 0101/1010; press any button to start.
# A random LED (the mole) lights up; press the button under it before
# the time window ends. Each hit shrinks the window by 1/8 (down to
# WINDOW_MIN). A wrong button or a timeout is a miss: all LEDs flash.
# After LIVES misses the game is over: LEDs flash three times, then
# show the score (low 4 bits) until a button is pressed for a new game.
# The UART shows instructions at start-up and reports hits, misses and
# the final score, in Spanish (UTF-8).
#
# Registers kept across the game:
#   s0 = I/O base, s1 = random state, s2 = score, s3 = misses,
#   s4 = time window (cycles), s5 = current mole (one-hot), s6 = mole start time

    .equ IO,          0x10000000
    .equ LEDS,        0
    .equ UART_DATA,   4
    .equ UART_STATUS, 8
    .equ BUTTONS,     12
    .equ CYCLES,      16
    .equ TX_READY,    1

    .equ MS,           27000            # cycles per millisecond at 27 MHz
    .equ WINDOW_START, 1200 * MS
    .equ WINDOW_MIN,   300 * MS
    .equ GAP,          400 * MS         # dark time between moles
    .equ DEBOUNCE,     20 * MS          # buttons released for this long
    .equ BLINK,        250 * MS         # idle pattern period
    .equ FLASH,        120 * MS
    .equ LIVES,        3

    .text
    .globl main
main:
    li   s0, IO
    li   s1, 1
    la   a0, msg_title
    call puts

# Idle: alternate the LEDs until a button is pressed
idle:
    call wait_release
    li   s5, 0b0101
idle_step:
    sw   s5, LEDS(s0)
    lw   t3, CYCLES(s0)
    li   t4, BLINK
idle_poll:
    lw   t0, BUTTONS(s0)
    bnez t0, new_game
    lw   t1, CYCLES(s0)
    sub  t1, t1, t3
    bltu t1, t4, idle_poll
    xori s5, s5, 0xF
    j    idle_step

new_game:
    sw   zero, LEDS(s0)
    li   s2, 0
    li   s3, 0
    li   s4, WINDOW_START
    li   s5, 0
    la   a0, msg_go
    call puts

round:
    sw   zero, LEDS(s0)
    call wait_release
    li   a0, GAP
    call delay
    call wait_release

pick:
    call rand                       # a0 = 0..3
    li   t0, 1
    sll  a0, t0, a0
    beq  a0, s5, pick               # never the same mole twice in a row
    mv   s5, a0
    sw   s5, LEDS(s0)
    lw   s6, CYCLES(s0)

wait_hit:
    lw   t0, BUTTONS(s0)
    bnez t0, pressed
    lw   t1, CYCLES(s0)
    sub  t1, t1, s6
    bltu t1, s4, wait_hit
    la   a0, msg_late
    j    miss

pressed:
    bne  t0, s5, wrong

    addi s2, s2, 1                  # hit
    sw   zero, LEDS(s0)
    la   a0, msg_hit
    call puts
    mv   a0, s2
    call print_dec
    la   a0, msg_crlf
    call puts
    srli t0, s4, 3                  # window -= window / 8
    sub  s4, s4, t0
    li   t1, WINDOW_MIN
    bgeu s4, t1, round
    mv   s4, t1
    j    round

wrong:
    la   a0, msg_wrong

miss:
    call puts
    addi s3, s3, 1
    la   a0, msg_misses             # "Fallos: N de 3"
    call puts
    mv   a0, s3
    call print_dec
    la   a0, msg_of_lives
    call puts
    li   a0, 2
    call flash
    li   t0, LIVES
    blt  s3, t0, round

# Game over: flash, print and show the score until a button is pressed
    la   a0, msg_over
    call puts
    mv   a0, s2
    call print_dec
    la   a0, msg_again
    call puts
    li   a0, 3
    call flash
    andi t0, s2, 0xF
    sw   t0, LEDS(s0)
    call wait_release
1:
    lw   t0, BUTTONS(s0)
    beqz t0, 1b
    j    new_game

# rand: mix the cycle counter (player timing) into a 32-bit Galois LFSR,
# step it 8 times, return a0 = 0..3. Uses t0-t2.
rand:
    lw   t0, CYCLES(s0)
    xor  s1, s1, t0
    bnez s1, 1f
    li   s1, 1                      # the LFSR must not be zero
1:
    li   t2, 8
2:
    andi t0, s1, 1
    srli s1, s1, 1
    beqz t0, 3f
    li   t1, 0x80200003
    xor  s1, s1, t1
3:
    addi t2, t2, -1
    bnez t2, 2b
    andi a0, s1, 3
    ret

# delay: wait a0 cycles. Uses t0, t1.
delay:
    lw   t0, CYCLES(s0)
1:
    lw   t1, CYCLES(s0)
    sub  t1, t1, t0
    bltu t1, a0, 1b
    ret

# wait_release: return once no button has been pressed for DEBOUNCE.
# Uses t0-t2.
wait_release:
    lw   t0, CYCLES(s0)
    li   t2, DEBOUNCE
1:
    lw   t1, BUTTONS(s0)
    bnez t1, wait_release
    lw   t1, CYCLES(s0)
    sub  t1, t1, t0
    bltu t1, t2, 1b
    ret

# flash: flash all LEDs a0 times, leave them off.
flash:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s7, 0(sp)
    mv   s7, a0
1:
    li   t0, 0xF
    sw   t0, LEDS(s0)
    li   a0, FLASH
    call delay
    sw   zero, LEDS(s0)
    li   a0, FLASH
    call delay
    addi s7, s7, -1
    bnez s7, 1b
    lw   s7, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# putc: send byte a0. Uses t0.
putc:
    lw   t0, UART_STATUS(s0)
    andi t0, t0, TX_READY
    beqz t0, putc
    sw   a0, UART_DATA(s0)
    ret

# puts: send the NUL-terminated string at a0.
puts:
    addi sp, sp, -8
    sw   ra, 4(sp)
    sw   s7, 0(sp)
    mv   s7, a0
1:
    lbu  a0, 0(s7)
    beqz a0, 2f
    call putc
    addi s7, s7, 1
    j    1b
2:
    lw   s7, 0(sp)
    lw   ra, 4(sp)
    addi sp, sp, 8
    ret

# print_dec: print a0 (0..9999) in decimal, by repeated subtraction
# (no M extension).
print_dec:
    addi sp, sp, -16
    sw   ra, 12(sp)
    sw   s7, 8(sp)
    sw   s8, 4(sp)
    sw   s9, 0(sp)
    mv   s7, a0                     # remaining value
    la   s8, powers_of_10
    li   s9, 0                      # 1 once a digit has been printed
1:
    lw   t0, 0(s8)
    beqz t0, 4f
    li   a0, '0'
2:
    bltu s7, t0, 3f
    sub  s7, s7, t0
    addi a0, a0, 1
    j    2b
3:
    addi s8, s8, 4
    li   t1, '0'
    bne  a0, t1, 5f                 # non-zero digit: print
    bnez s9, 5f                     # zero after a printed digit: print
    li   t1, 1
    bne  t0, t1, 1b                 # leading zero: skip (except last digit)
5:
    li   s9, 1
    call putc
    j    1b
4:
    lw   s9, 0(sp)
    lw   s8, 4(sp)
    lw   s7, 8(sp)
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

    .section .rodata
    .p2align 2
powers_of_10: .word 1000, 100, 10, 1, 0

msg_title:
    .ascii "\r\n"
    .ascii "=== TOPO - ¡Golpea al topo! ===\r\n"
    .ascii "\r\n"
    .ascii "Cada LED tiene su botón:\r\n"
    .ascii "  S4 -> LED0\r\n"
    .ascii "  S3 -> LED1\r\n"
    .ascii "  S2 -> LED2\r\n"
    .ascii "  S1 -> LED3\r\n"
    .ascii "\r\n"
    .ascii "Cómo jugar:\r\n"
    .ascii "  1. Mientras los LED parpadean, pulsa cualquier botón para empezar.\r\n"
    .ascii "  2. Se enciende un LED: es el topo. Pulsa su botón antes de que\r\n"
    .ascii "     se esconda.\r\n"
    .ascii "  3. Cada acierto suma un punto y te da menos tiempo\r\n"
    .ascii "     (de 1,2 s a 0,3 s).\r\n"
    .ascii "  4. Si pulsas otro botón o tardas demasiado, es un fallo y\r\n"
    .ascii "     parpadean todos los LED.\r\n"
    .ascii "  5. Con 3 fallos se acaba la partida. Los LED muestran tus puntos\r\n"
    .ascii "     en binario: LED0 = 8, LED1 = 4, LED2 = 2, LED3 = 1.\r\n"
    .ascii "  6. Pulsa cualquier botón para jugar otra vez. S0 reinicia la placa.\r\n"
    .ascii "\r\n"
    .asciz "Pulsa cualquier botón para empezar.\r\n"
msg_go:       .asciz "\r\n¡A jugar!\r\n"
msg_hit:      .asciz "¡Golpe! Puntos: "
msg_late:     .asciz "¡Demasiado lento! "
msg_wrong:    .asciz "¡Botón equivocado! "
msg_misses:   .asciz "Fallos: "
msg_of_lives: .asciz " de 3\r\n"
msg_over:     .asciz "\r\nFin de la partida. Puntos: "
msg_again:    .asciz "\r\nPulsa cualquier botón para jugar otra vez.\r\n"
msg_crlf:     .asciz "\r\n"
