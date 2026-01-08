#include <stdint.h>

#define TOHOST (*(volatile uint32_t*)0x0D000720)

static inline void putch(char c)
{
    TOHOST = (uint32_t)(uint8_t)c;
}

static void puts(const char* s)
{
    while (*s) putch(*s++);
}

static void exit_sim(uint32_t code)
{
    TOHOST = code;  // code=1 => PASS
    while (1)
    {
    }  // 保险起见，避免继续跑
}

static void print_hex32(uint32_t x)
{
    const char* hex = "0123456789ABCDEF";
    putch('0');
    putch('x');
    for (int i = 28; i >= 0; i -= 4)
    {
        putch(hex[(x >> i) & 0xF]);
    }
    putch('\n');
}

/* Read mcycle CSR (cycle counter) - returns lower 32 bits */
static inline uint32_t read_mcycle(void)
{
    uint32_t cycles;
    __asm__ volatile ("csrr %0, mcycle" : "=r"(cycles));
    return cycles;
}


int print_test(void)
{
    puts("=== RV32I CPU PRINT TEST ===\n");
    puts("abcdefghijklmnopqrstuvwxyz\n");
    puts("0123456789\n");
    puts("!@#$%^&*()_+-=[]{};':,.<>/?\n");
    puts("HELLO!\n\n");
    puts("=== MATH TEST ===\n");

    uint32_t a = 123;
    uint32_t b = 456;

    uint32_t sum  = a + b;
    uint32_t diff = b - a;
    uint32_t prod = a * b;         // RV32I 支持 mul 吗？如果你实现了 zmmul 则 OK
    uint32_t mix  = (a << 5) ^ b;  // 位运算示例（最稳）

    puts("a =");
    print_hex32(a);
    puts("b =");
    print_hex32(b);

    puts("a+b =");
    print_hex32(sum);
    puts("b-a =");
    print_hex32(diff);
    puts("a*b =");
    print_hex32(prod);
    puts("(a<<5)^b =");
    print_hex32(mix);

    puts("\n=== MCYCLE CSR TEST ===\n");
    uint32_t cycle1 = read_mcycle();
    puts("mcycle (start) = ");
    print_hex32(cycle1);

    // Do some work
    volatile uint32_t dummy = 0;
    for (int i = 0; i < 100; i++) {
        dummy += i;
    }

    uint32_t cycle2 = read_mcycle();
    puts("mcycle (after loop) = ");
    print_hex32(cycle2);

    uint32_t cycles_elapsed = cycle2 - cycle1;
    puts("cycles elapsed = ");
    print_hex32(cycles_elapsed);

    if (cycles_elapsed > 0) {
        puts("MCYCLE CSR TEST PASSED!\n");
    } else {
        puts("MCYCLE CSR TEST FAILED!\n");
        exit_sim(2);  // FAIL
    }

    exit_sim(1);  // ✅ 打印完通知结束
}


int math_test(void)
{
    exit_sim(1);
}
