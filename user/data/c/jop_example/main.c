typedef unsigned int u32;

volatile u32 g_stage;
volatile u32 g_status;
int (* volatile g_bad_fp)(void);

extern int bad_target(void);
extern int call_bad_target_indirect(void);

__attribute__((noinline))
static int do_indirect_call(void)
{
    g_stage = 1;

    return call_bad_target_indirect();
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
    g_status = 0x11110000u;
    g_stage = 0;
    g_bad_fp = bad_target;

    // If control reaches bad_target, Zicfilp should raise a software-check
    // before the first instruction executes, so returning here means failure.
    (void)do_indirect_call();

    g_stage = 2;
    finish_fail(0x20);
}
