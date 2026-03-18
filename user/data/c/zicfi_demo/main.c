typedef unsigned int u32;

#define SHADOW_TOP 0x00003400u

extern u32 read_ssp(void);
extern void write_ssp(u32 value);
extern void shadow_push(u32 value);
extern void shadow_popchk(u32 value);
extern int call_lpad_target(int (*target)(int), int arg);
extern int lpad_target(int arg);
extern void finish_success(u32 pass_count) __attribute__((noreturn));
extern void finish_fail(u32 step) __attribute__((noreturn));

volatile u32 g_status;
volatile u32 g_fail_step;
volatile u32 g_ssp_before;
volatile u32 g_ssp_after_push;
volatile u32 g_ssp_after_pop;
volatile u32 g_shadow_word;
volatile u32 g_lpad_result;

static void check_eq(u32 actual, u32 expected, u32 step)
{
    if (actual != expected)
    {
        g_fail_step = step;
        finish_fail(step);
    }
}

int main(void)
{
    volatile u32* shadow_slot = (volatile u32*)(SHADOW_TOP - 4u);
    const u32 pushed_value    = 0x11223344u;

    g_status = 1;

    write_ssp(SHADOW_TOP);

    g_ssp_before = read_ssp();
    check_eq(g_ssp_before, SHADOW_TOP, 1);

    shadow_push(pushed_value);

    g_ssp_after_push = read_ssp();
    check_eq(g_ssp_after_push, SHADOW_TOP - 4u, 2);

    g_shadow_word = *shadow_slot;
    check_eq(g_shadow_word, pushed_value, 3);

    shadow_popchk(pushed_value);

    g_ssp_after_pop = read_ssp();
    check_eq(g_ssp_after_pop, SHADOW_TOP, 4);

    g_lpad_result = (u32)call_lpad_target(lpad_target, 41);
    check_eq(g_lpad_result, 48u, 5);

    g_status = 0x0000600du;
    finish_success(5);
}
