// C demo: print over UART, do some arithmetic (software mul/div), then
// echo typed characters and show how many were typed on the LEDs.
#include "rvcpu.h"

static const char *names[] = { "zero", "one", "two", "three" };

static uint32_t factorial(uint32_t n)
{
    return n <= 1 ? 1 : n * factorial(n - 1);
}

static uint32_t counter;            // .bss: cleared by crt0

int main(void)
{
    uart_puts("Hello from RISC-V!\n");

    for (uint32_t n = 1; n <= 10; n++) {
        uart_puts("  ");
        uart_put_dec(n);
        uart_puts("! = ");
        uart_put_dec(factorial(n));
        uart_puts("\n");
    }

    uart_puts("  1000000 / 7 = ");
    uart_put_dec(1000000 / 7);
    uart_puts(" remainder ");
    uart_put_dec(1000000 % 7);
    uart_puts("\n  names[2] = ");
    uart_puts(names[2]);
    uart_puts("\nType something (echoed back; LEDs count characters):\n");

    for (;;) {
        char c = uart_getc();
        if (c == '\r')
            uart_puts("\n");
        else
            uart_putc(c);
        counter++;
        led_set(counter);
    }
}
