typedef unsigned int u32;

volatile u32 g_stage;
volatile u32 g_status;
volatile u32 g_result;
volatile u32 g_expected_result;
int (* volatile g_call_fp)(int);

extern int call_via_fp(int arg);

__attribute__((noinline))
int legit_target(int x)
{
    g_stage = 1;
    return x + 7;
}

__attribute__((noinline))
int cop_target(int x)
{
    g_stage = 2;
    return x + 13;
}

__attribute__((noinline))
static void corrupt_dispatch_pointer(void)
{
    g_stage = 3;
    g_call_fp = cop_target;
}

__attribute__((noinline, noreturn))
void finish_observed(u32 code)
{
    g_status = 0xc0f00000u | code;
    asm volatile(
        "mv x28, %0\n\t"
        "li x29, 2\n\t"
        "1: j 1b\n\t"
        :
        : "r"(code)
        : "x28", "x29", "memory"
    );
    __builtin_unreachable();
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
    g_status = 0x33330000u;
    g_stage = 0;
    g_result = 0;
    g_expected_result = 47;
    g_call_fp = legit_target;

    corrupt_dispatch_pointer();
    g_result = (u32)call_via_fp(40);

    if ((g_stage == 2) && (g_result == 53)) {
        finish_observed(0x40);
    }

    if (g_result == g_expected_result) {
        finish_fail(0x21);
    }

    finish_fail(0x22);
}
