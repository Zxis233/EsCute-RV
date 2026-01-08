#include <stdint.h>

extern volatile uint32_t tohost;

int _write(int fd, const void *buf, int len) {
    const char *p = (const char*)buf;
    for (int i = 0; i < len; i++) {
        tohost = (uint32_t)p[i];   // 写到 tohost：testbench 捕获并打印
    }
    return len;
}
