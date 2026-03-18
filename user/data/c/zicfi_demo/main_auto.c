typedef unsigned int u32;

volatile u32 g_status;
volatile u32 g_result;
volatile u32 g_stage;
int (* volatile g_fp)(int);

__attribute__((noinline))
static int leaf_add7(int x)
{
    g_stage = 1;
    return x + 7;
}

__attribute__((noinline))
static int nonleaf_wrap(int x)
{
    g_stage = 2;
    return leaf_add7(x) + 1;
}

__attribute__((noinline))
static int apply_indirect(int arg)
{
    g_stage = 3;
    return g_fp(arg) + 2;
}

__attribute__((noinline, noreturn))
void finish_success(u32 pass_count)
{
    g_status = 0x0000600d;
    g_result = pass_count;
    asm volatile(
        "mv x28, %0\n\t"
        "li x29, 0\n\t"
        "1: j 1b\n\t"
        :
        : "r"(pass_count)
        : "x28", "x29", "memory"
    );
    __builtin_unreachable();
}

__attribute__((noinline, noreturn))
void finish_fail(u32 step)
{
    g_status = 0xdead0000u | step;
    g_result = step;
    asm volatile(
        "mv x28, %0\n\t"
        "li x29, 1\n\t"
        "1: j 1b\n\t"
        :
        : "r"(step)
        : "x28", "x29", "memory"
    );
    __builtin_unreachable();
}

int main(void)
{
    g_fp = nonleaf_wrap;
    int value = apply_indirect(40);

    g_stage = 4;
    if (value != 50) {
        finish_fail(1);
    }

    finish_success(1);
}
