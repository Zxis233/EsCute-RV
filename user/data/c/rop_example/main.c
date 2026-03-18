typedef unsigned int u32;

volatile u32 g_stage;
volatile u32 g_status;
volatile u32 g_ssp_addr;
volatile u32 g_shadow_before;
volatile u32 g_shadow_after;

static inline u32 read_ssp(void)
{
    u32 value;
    asm volatile("ssrdp %0" : "=r"(value));
    return value;
}

__attribute__((noinline))
static u32 leaf_step(u32 x)
{
    g_stage = 1;
    return x + 1;
}

__attribute__((noinline))
u32 cause_shadow_mismatch(u32 x)
{
    volatile u32 *slot;
    u32 value;

    g_stage = 2;
    value = leaf_step(x);

    g_ssp_addr = read_ssp();
    slot = (volatile u32 *)g_ssp_addr;
    g_shadow_before = *slot;
    *slot = 0x13579bdfu;
    g_shadow_after = *slot;

    g_stage = 3;
    return value + 1;
}

__attribute__((noinline, noreturn))
void finish_fail(u32 code)
{
    g_status = 0xdead0000u | code;
    asm volatile(
        "mv x28, %0\n\t"
        "li x29, 1\n\t"
        "1: j 1b\n\t"
        :
        : "r"(code)
        : "x28", "x29", "memory"
    );
    __builtin_unreachable();
}

int main(void)
{
    g_status = 0x22220000u;
    g_stage = 0;

    // If this function returns, the compiler-generated SSPPOPCHK did not trap.
    (void)cause_shadow_mismatch(40);

    g_stage = 4;
    finish_fail(0x20);
}
