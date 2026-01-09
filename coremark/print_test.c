#include <stdarg.h>
#include <stddef.h>
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
    __asm__ volatile("csrr %0, mcycle" : "=r"(cycles));
    return cycles;
}


#define ZEROPAD   (1 << 0) /* Pad with zero */
#define SIGN      (1 << 1) /* Unsigned/signed long */
#define PLUS      (1 << 2) /* Show plus */
#define SPACE     (1 << 3) /* Spacer */
#define LEFT      (1 << 4) /* Left justified */
#define HEX_PREP  (1 << 5) /* 0x */
#define UPPERCASE (1 << 6) /* 'ABCDEF' */

#define is_digit(c) ((c) >= '0' && (c) <= '9')

typedef size_t ee_size_t;

static char* digits       = "0123456789abcdefghijklmnopqrstuvwxyz";
static char* upper_digits = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static ee_size_t strnlen(const char* s, ee_size_t count);

static ee_size_t
strnlen(const char* s, ee_size_t count)
{
    const char* sc;
    for (sc = s; *sc != '\0' && count--; ++sc);
    return sc - s;
}

static int
skip_atoi(const char** s)
{
    int i = 0;
    while (is_digit(**s))
        i = i * 10 + *((*s)++) - '0';
    return i;
}

static char*
number(char* str, long num, int base, int size, int precision, int type)
{
    char c, sign, tmp[66];
    char* dig = digits;
    int i;

    if (type & UPPERCASE)
        dig = upper_digits;
    if (type & LEFT)
        type &= ~ZEROPAD;
    if (base < 2 || base > 36)
        return 0;

    c    = (type & ZEROPAD) ? '0' : ' ';
    sign = 0;
    if (type & SIGN)
    {
        if (num < 0)
        {
            sign = '-';
            num  = -num;
            size--;
        }
        else if (type & PLUS)
        {
            sign = '+';
            size--;
        }
        else if (type & SPACE)
        {
            sign = ' ';
            size--;
        }
    }

    if (type & HEX_PREP)
    {
        if (base == 16)
            size -= 2;
        else if (base == 8)
            size--;
    }

    i = 0;

    if (num == 0)
        tmp[i++] = '0';
    else
    {
        while (num != 0)
        {
            tmp[i++] = dig[((unsigned long)num) % (unsigned)base];
            num      = ((unsigned long)num) / (unsigned)base;
        }
    }

    if (i > precision)
        precision = i;
    size -= precision;
    if (!(type & (ZEROPAD | LEFT)))
        while (size-- > 0)
            *str++ = ' ';
    if (sign)
        *str++ = sign;

    if (type & HEX_PREP)
    {
        if (base == 8)
            *str++ = '0';
        else if (base == 16)
        {
            *str++ = '0';
            *str++ = digits[33];
        }
    }

    if (!(type & LEFT))
        while (size-- > 0)
            *str++ = c;
    while (i < precision--)
        *str++ = '0';
    while (i-- > 0)
        *str++ = tmp[i];
    while (size-- > 0)
        *str++ = ' ';

    return str;
}

static char*
eaddr(char* str, unsigned char* addr, int size, int precision, int type)
{
    char tmp[24];
    char* dig = digits;
    int i, len;

    if (type & UPPERCASE)
        dig = upper_digits;
    len = 0;
    for (i = 0; i < 6; i++)
    {
        if (i != 0)
            tmp[len++] = ':';
        tmp[len++] = dig[addr[i] >> 4];
        tmp[len++] = dig[addr[i] & 0x0F];
    }

    if (!(type & LEFT))
        while (len < size--)
            *str++ = ' ';
    for (i = 0; i < len; ++i)
        *str++ = tmp[i];
    while (len < size--)
        *str++ = ' ';

    return str;
}

static char*
iaddr(char* str, unsigned char* addr, int size, int precision, int type)
{
    char tmp[24];
    int i, n, len;

    len = 0;
    for (i = 0; i < 4; i++)
    {
        if (i != 0)
            tmp[len++] = '.';
        n = addr[i];

        if (n == 0)
            tmp[len++] = digits[0];
        else
        {
            if (n >= 100)
            {
                tmp[len++] = digits[n / 100];
                n          = n % 100;
                tmp[len++] = digits[n / 10];
                n          = n % 10;
            }
            else if (n >= 10)
            {
                tmp[len++] = digits[n / 10];
                n          = n % 10;
            }

            tmp[len++] = digits[n];
        }
    }

    if (!(type & LEFT))
        while (len < size--)
            *str++ = ' ';
    for (i = 0; i < len; ++i)
        *str++ = tmp[i];
    while (len < size--)
        *str++ = ' ';

    return str;
}

static int
ee_vsprintf(char* buf, const char* fmt, va_list args)
{
    int len;
    unsigned long num;
    int i, base;
    char* str;
    char* s;

    int flags;        // Flags to number()

    int field_width;  // Width of output field
    int precision;    // Min. # of digits for integers; max number of chars for
                      // from string
    int qualifier;    // 'h', 'l', or 'L' for integer fields

    for (str = buf; *fmt; fmt++)
    {
        if (*fmt != '%')
        {
            *str++ = *fmt;
            continue;
        }

        // Process flags
        flags = 0;
    repeat:
        fmt++;  // This also skips first '%'
        switch (*fmt)
        {
        case '-':
            flags |= LEFT;
            goto repeat;
        case '+':
            flags |= PLUS;
            goto repeat;
        case ' ':
            flags |= SPACE;
            goto repeat;
        case '#':
            flags |= HEX_PREP;
            goto repeat;
        case '0':
            flags |= ZEROPAD;
            goto repeat;
        }

        // Get field width
        field_width = -1;
        if (is_digit(*fmt))
            field_width = skip_atoi(&fmt);
        else if (*fmt == '*')
        {
            fmt++;
            field_width = va_arg(args, int);
            if (field_width < 0)
            {
                field_width  = -field_width;
                flags       |= LEFT;
            }
        }

        // Get the precision
        precision = -1;
        if (*fmt == '.')
        {
            ++fmt;
            if (is_digit(*fmt))
                precision = skip_atoi(&fmt);
            else if (*fmt == '*')
            {
                ++fmt;
                precision = va_arg(args, int);
            }
            if (precision < 0)
                precision = 0;
        }

        // Get the conversion qualifier
        qualifier = -1;
        if (*fmt == 'l' || *fmt == 'L')
        {
            qualifier = *fmt;
            fmt++;
        }

        // Default base
        base = 10;

        switch (*fmt)
        {
        case 'c':
            if (!(flags & LEFT))
                while (--field_width > 0)
                    *str++ = ' ';
            *str++ = (unsigned char)va_arg(args, int);
            while (--field_width > 0)
                *str++ = ' ';
            continue;

        case 's':
            s = va_arg(args, char*);
            if (!s)
                s = "<NULL>";
            len = strnlen(s, precision);
            if (!(flags & LEFT))
                while (len < field_width--)
                    *str++ = ' ';
            for (i = 0; i < len; ++i)
                *str++ = *s++;
            while (len < field_width--)
                *str++ = ' ';
            continue;

        case 'p':
            if (field_width == -1)
            {
                field_width  = 2 * sizeof(void*);
                flags       |= ZEROPAD;
            }
            str = number(str,
                         (unsigned long)va_arg(args, void*),
                         16,
                         field_width,
                         precision,
                         flags);
            continue;

        case 'A':
            flags |= UPPERCASE;

        case 'a':
            if (qualifier == 'l')
                str = eaddr(str,
                            va_arg(args, unsigned char*),
                            field_width,
                            precision,
                            flags);
            else
                str = iaddr(str,
                            va_arg(args, unsigned char*),
                            field_width,
                            precision,
                            flags);
            continue;

        // Integer number formats - set up the flags and "break"
        case 'o':
            base = 8;
            break;

        case 'X':
            flags |= UPPERCASE;

        case 'x':
            base = 16;
            break;

        case 'd':
        case 'i':
            flags |= SIGN;

        case 'u':
            break;

#if HAS_FLOAT

        case 'f':
            str = flt(str,
                      va_arg(args, double),
                      field_width,
                      precision,
                      *fmt,
                      flags | SIGN);
            continue;

#endif

        default:
            if (*fmt != '%')
                *str++ = '%';
            if (*fmt)
                *str++ = *fmt;
            else
                --fmt;
            continue;
        }

        if (qualifier == 'l')
            num = va_arg(args, unsigned long);
        else if (flags & SIGN)
            num = va_arg(args, int);
        else
            num = va_arg(args, unsigned int);

        str = number(str, num, base, field_width, precision, flags);
    }

    *str = '\0';
    return str - buf;
}

static void print_hex32(uint32_t v, int width)
{
    static const char* hex = "0123456789abcdef";
    if (width <= 0)
        width = 8;
    for (int i = (width - 1) * 4; i >= 0; i -= 4)
        putch(hex[(v >> i) & 0xF]);
}

static void print_udec32(uint32_t x)
{
    char buf[16];
    int i = 0;

    if (x == 0)
    {
        putch('0');
        return;
    }

    while (x)
    {
        buf[i++]  = '0' + (x % 10);
        x        /= 10;
    }
    while (i--) putch(buf[i]);
}

static void print_dec32(int32_t v)
{
    if (v < 0)
    {
        putch('-');
        print_udec32((uint32_t)(-v));
    }
    else
    {
        print_udec32((uint32_t)v);
    }
}

int ee_printf(const char* fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);

    while (*fmt)
    {
        if (*fmt != '%')
        {
            putch(*fmt++);
            continue;
        }

        fmt++;  // skip '%'

        // "%%"
        if (*fmt == '%')
        {
            putch('%');
            fmt++;
            continue;
        }

        // 解析可选 '0'
        int zero_pad = 0;
        if (*fmt == '0')
        {
            zero_pad = 1;
            fmt++;
        }

        // 解析宽度
        int width = 0;
        while (*fmt >= '0' && *fmt <= '9')
        {
            width = width * 10 + (*fmt - '0');
            fmt++;
        }

        // ✅ 解析长度修饰符：只支持 'l'
        int is_long = 0;
        if (*fmt == 'l')
        {
            is_long = 1;
            fmt++;
        }

        char f = *fmt++;

        switch (f)
        {
        case 'c':
        {
            char c = (char)va_arg(ap, int);
            putch(c);
            break;
        }
        case 's':
        {
            const char* s = va_arg(ap, const char*);
            if (!s)
                s = "(null)";
            while (*s) putch(*s++);
            break;
        }
        case 'x':
        {
            uint32_t v;
            if (is_long)
                v = (uint32_t)va_arg(ap, unsigned long);  // RV32: 32-bit
            else
                v = (uint32_t)va_arg(ap, unsigned int);

            if (width == 0)
                width = 8;
            print_hex32(v, width);
            break;
        }
        case 'u':
        {
            uint32_t v;
            if (is_long)
                v = (uint32_t)va_arg(ap, unsigned long);
            else
                v = (uint32_t)va_arg(ap, unsigned int);

            print_udec32(v);
            break;
        }
        case 'd':
        {
            int32_t v;
            if (is_long)
                v = (int32_t)va_arg(ap, long);
            else
                v = (int32_t)va_arg(ap, int);

            print_dec32(v);
            break;
        }
        default:
            // unknown specifier
            putch('%');
            if (is_long)
                putch('l');
            putch(f);
            break;
        }
    }

    va_end(ap);
    return 0;
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
    for (int i = 0; i < 100; i++)
    {
        dummy += i;
    }

    uint32_t cycle2 = read_mcycle();
    puts("mcycle (after loop) = ");
    print_hex32(cycle2);

    uint32_t cycles_elapsed = cycle2 - cycle1;
    puts("cycles elapsed = ");
    print_hex32(cycles_elapsed);

    if (cycles_elapsed > 0)
    {
        puts("MCYCLE CSR TEST PASSED!\n");
    }
    else
    {
        puts("MCYCLE CSR TEST FAILED!\n");
        exit_sim(2);  // FAIL
    }

    my_printf("Formatted number test: %d, %u, %x, %X, %o\n", 12345, 12345, 0xABCD, 0xABCD, 012345);
    my_printf("List sort 1: %04x\n", 0xbeef);

    exit_sim(1);  // ✅ 打印完通知结束
}

int math_test(void)
{
    exit_sim(1);
}