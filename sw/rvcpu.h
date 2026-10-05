// Hardware access for programs running on this CPU (see src/riscv_cpu.v).
#ifndef RVCPU_H
#define RVCPU_H

#include <stdint.h>

#define LED_REG      (*(volatile uint32_t *)0x10000000)
#define UART_DATA    (*(volatile uint32_t *)0x10000004)
#define UART_STATUS  (*(volatile uint32_t *)0x10000008)

#define UART_TX_READY 0x1
#define UART_RX_VALID 0x2

static inline void led_set(uint32_t value) { LED_REG = value; }

static inline void uart_putc(char c)
{
    while (!(UART_STATUS & UART_TX_READY))
        ;
    UART_DATA = (uint8_t)c;
}

static inline int uart_has_data(void) { return (UART_STATUS & UART_RX_VALID) != 0; }

static inline char uart_getc(void)
{
    while (!uart_has_data())
        ;
    return (char)UART_DATA;
}

static inline void uart_puts(const char *s)
{
    while (*s) {
        if (*s == '\n')
            uart_putc('\r');
        uart_putc(*s++);
    }
}

static inline void uart_put_hex(uint32_t value)
{
    for (int shift = 28; shift >= 0; shift -= 4)
        uart_putc("0123456789abcdef"[(value >> shift) & 0xF]);
}

static inline void uart_put_dec(uint32_t value)
{
    char buffer[11];
    int i = 0;
    do {
        buffer[i++] = (char)('0' + value % 10);
        value /= 10;
    } while (value);
    while (i)
        uart_putc(buffer[--i]);
}

#endif
