// Runtime helpers the compiler may call. The CPU has no M extension, so
// clang turns *, / and % into calls to these; it may also emit memset /
// memcpy / memmove for struct copies and array initialization.
#include <stddef.h>
#include <stdint.h>

uint32_t __mulsi3(uint32_t a, uint32_t b)
{
    uint32_t result = 0;
    while (b) {
        if (b & 1)
            result += a;
        a <<= 1;
        b >>= 1;
    }
    return result;
}

static uint32_t udivmod(uint32_t n, uint32_t d, uint32_t *remainder)
{
    uint32_t quotient = 0;
    uint32_t rest = 0;

    if (d == 0) {                       // RISC-V semantics: q = ~0, r = n
        *remainder = n;
        return 0xFFFFFFFF;
    }

    for (int bit = 31; bit >= 0; bit--) {
        rest = (rest << 1) | ((n >> bit) & 1);
        if (rest >= d) {
            rest -= d;
            quotient |= 1u << bit;
        }
    }

    *remainder = rest;
    return quotient;
}

uint32_t __udivsi3(uint32_t n, uint32_t d)
{
    uint32_t r;
    return udivmod(n, d, &r);
}

uint32_t __umodsi3(uint32_t n, uint32_t d)
{
    uint32_t r;
    udivmod(n, d, &r);
    return r;
}

int32_t __divsi3(int32_t n, int32_t d)
{
    uint32_t r;
    uint32_t q = udivmod(n < 0 ? -(uint32_t)n : (uint32_t)n,
                         d < 0 ? -(uint32_t)d : (uint32_t)d, &r);
    if (d == 0)
        return -1;
    return ((n < 0) != (d < 0)) ? -(int32_t)q : (int32_t)q;
}

int32_t __modsi3(int32_t n, int32_t d)
{
    uint32_t r;
    udivmod(n < 0 ? -(uint32_t)n : (uint32_t)n,
            d < 0 ? -(uint32_t)d : (uint32_t)d, &r);
    if (d == 0)
        return n;
    return n < 0 ? -(int32_t)r : (int32_t)r;
}

void *memset(void *dest, int value, size_t count)
{
    volatile uint8_t *p = dest;         // volatile: keep clang from calling memset
    while (count--)
        *p++ = (uint8_t)value;
    return dest;
}

void *memcpy(void *dest, const void *src, size_t count)
{
    volatile uint8_t *d = dest;
    const uint8_t *s = src;
    while (count--)
        *d++ = *s++;
    return dest;
}

void *memmove(void *dest, const void *src, size_t count)
{
    volatile uint8_t *d = dest;
    const uint8_t *s = src;
    if (d < s) {
        while (count--)
            *d++ = *s++;
    }
    else {
        d += count;
        s += count;
        while (count--)
            *--d = *--s;
    }
    return dest;
}
