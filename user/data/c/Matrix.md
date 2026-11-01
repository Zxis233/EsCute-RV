| 测试 | CFI_INSERT | ZICFI_RUNTIME_ENABLE | 预期行为                                                                          |
| ---- | ---------- | -------------------- | --------------------------------------------------------------------------------- |
| JOP  | 0          | 0                    | 不触发 LPAD fault，跳到 bad_target 后返回，最后 finish_fail(0x20)                 |
| JOP  | 0          | 1                    | 触发 LPAD fault，因为 bad_target 没有 LPAD                                        |
| JOP  | 1          | 0                    | 不触发 LPAD fault，运行时 LPE=0，最后 finish_fail(0x20)                           |
| JOP  | 1          | 1                    | 触发 LPAD fault，因为目标仍是无 LPAD 的 bad_target                                |
| COP  | 0          | 0                    | 不触发 LPAD fault，运行时 LPE=0，进入 finish_observed(0x40)                       |
| COP  | 0          | 1                    | 触发 LPAD fault，因为 cop_target 没有自动插入 LPAD                                |
| COP  | 1          | 0                    | 不触发 LPAD fault，运行时 LPE=0，进入 finish_observed(0x40)                       |
| COP  | 1          | 1                    | 不触发 LPAD fault，因为 cop_target 是合法 landing pad，进入 finish_observed(0x40) |
| ROP  | 0          | 0                    | 不触发 shadow-stack fault，最后 finish_fail(0x20)                                 |
| ROP  | 0          | 1                    | 不触发 shadow-stack fault，因为没有自动 sspush/sspopchk，最后 finish_fail(0x20)   |
| ROP  | 1          | 0                    | 不触发 shadow-stack fault，运行时 SSE=0，最后 finish_fail(0x20)                   |
| ROP  | 1          | 1                    | 触发 shadow-stack fault，因为 shadow slot 被篡改且返回时执行 sspopchk             |