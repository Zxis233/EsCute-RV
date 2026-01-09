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
        if (remainder >= (divisor << bit))
        {
            remainder -= (divisor << bit);
            quotient  |= (1U << bit);
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
        if (remainder >= (divisor << bit))
        {
            remainder -= (divisor << bit);
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