/*
 * 软件除法和取模实现
 * 适用于只有硬件乘法的 RISC-V CPU
 */

// 32位无符号除法（长除法算法）
unsigned int __udivsi3(unsigned int dividend, unsigned int divisor)
{
    unsigned int quotient  = 0;
    unsigned int remainder = dividend;
    int bit;

    if (divisor == 0)
        return 0;  // 除零保护

    // 找到最高位
    for (bit = 31; bit >= 0; bit--)
    {
        // 防止左移溢出：只有当 divisor <= (0xFFFFFFFF >> bit) 时才进行移位比较
        // 否则 divisor << bit 会溢出并产生错误结果
        if (divisor <= (0xFFFFFFFFU >> bit))
        {
            unsigned int shifted = divisor << bit;
            if (remainder >= shifted)
            {
                remainder -= shifted;
                quotient  |= (1U << bit);
            }
        }
    }

    return quotient;
}

// 32位无符号取模
unsigned int __umodsi3(unsigned int dividend, unsigned int divisor)
{
    unsigned int remainder = dividend;
    int bit;

    if (divisor == 0)
        return dividend;  // 除零保护

    for (bit = 31; bit >= 0; bit--)
    {
        // 防止左移溢出：只有当 divisor <= (0xFFFFFFFF >> bit) 时才进行移位比较
        if (divisor <= (0xFFFFFFFFU >> bit))
        {
            unsigned int shifted = divisor << bit;
            if (remainder >= shifted)
            {
                remainder -= shifted;
            }
        }
    }

    return remainder;
}

// 32位有符号除法
int __divsi3(int dividend, int divisor)
{
    int negative = 0;
    unsigned int result;

    // 处理符号
    if (dividend < 0)
    {
        dividend = -dividend;
        negative = !negative;
    }
    if (divisor < 0)
    {
        divisor  = -divisor;
        negative = !negative;
    }

    result = __udivsi3((unsigned int)dividend, (unsigned int)divisor);

    return negative ? -(int)result : (int)result;
}

// 32位有符号取模
int __modsi3(int dividend, int divisor)
{
    int sign = (dividend < 0) ? -1 : 1;
    unsigned int result;

    if (dividend < 0)
        dividend = -dividend;
    if (divisor < 0)
        divisor = -divisor;

    result = __umodsi3((unsigned int)dividend, (unsigned int)divisor);

    return sign * (int)result;
}

// 64位无符号除法（长除法算法）
unsigned long long __udivdi3(unsigned long long dividend, unsigned long long divisor)
{
    unsigned long long quotient  = 0;
    unsigned long long remainder = dividend;
    int bit;

    if (divisor == 0)
        return 0;  // 除零保护

    // 找到最高位
    for (bit = 63; bit >= 0; bit--)
    {
        // 防止左移溢出
        if (divisor <= (0xFFFFFFFFFFFFFFFFULL >> bit))
        {
            unsigned long long shifted = divisor << bit;
            if (remainder >= shifted)
            {
                remainder -= shifted;
                quotient  |= (1ULL << bit);
            }
        }
    }

    return quotient;
}

// 64位无符号取模
unsigned long long __umoddi3(unsigned long long dividend, unsigned long long divisor)
{
    unsigned long long remainder = dividend;
    int bit;

    if (divisor == 0)
        return dividend;  // 除零保护

    for (bit = 63; bit >= 0; bit--)
    {
        if (divisor <= (0xFFFFFFFFFFFFFFFFULL >> bit))
        {
            unsigned long long shifted = divisor << bit;
            if (remainder >= shifted)
            {
                remainder -= shifted;
            }
        }
    }

    return remainder;
}

// 64位有符号除法
long long __divdi3(long long dividend, long long divisor)
{
    int negative = 0;
    unsigned long long result;

    if (dividend < 0)
    {
        dividend = -dividend;
        negative = !negative;
    }
    if (divisor < 0)
    {
        divisor  = -divisor;
        negative = !negative;
    }

    result = __udivdi3((unsigned long long)dividend, (unsigned long long)divisor);

    return negative ? -(long long)result : (long long)result;
}

// 64位有符号取模
long long __moddi3(long long dividend, long long divisor)
{
    int sign = (dividend < 0) ? -1 : 1;
    unsigned long long result;

    if (dividend < 0)
        dividend = -dividend;
    if (divisor < 0)
        divisor = -divisor;

    result = __umoddi3((unsigned long long)dividend, (unsigned long long)divisor);

    return sign * (long long)result;
}