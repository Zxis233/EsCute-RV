# CFI 样例分析 (By ChatGPT)

本文档整理了项目中三个“受控负例/边界”样例：

- `user/data/c/jop_example`：用于验证 `Zicfilp`
- `user/data/c/rop_example`：用于验证 `Zicfiss`
- `user/data/c/cop_example`：用于验证合法 landing-pad 目标下的 COP 边界

这里的目标不是实现可复用的攻击链，而是在一个可控环境里直接构造“控制流已经被篡改”的后果，用来验证当前 CPU 的 CFI 机制是否能按预期拦截。

## 1. ROP 与 JOP 的基本原理

### 1.1 ROP

ROP（Return-Oriented Programming）的核心思路是：

- 攻击者先获得一次可以篡改控制数据的能力，例如覆盖返回地址
- 随后不再跳到一整段新代码，而是把程序已有代码片段（gadgets）串起来执行
- 这些 gadgets 往往都以 `ret` 结束，因此攻击者只需要不断伪造返回地址即可驱动控制流

对本项目而言，`Zicfiss` 的作用就是保护“返回控制流”：

- 函数入口处把期望返回地址压入 shadow stack
- 函数退出时用 `sspopchk` 检查 shadow stack 中的地址是否和实际准备返回的地址一致
- 如果不一致，就触发 `software-check` 异常

### 1.2 JOP

JOP（Jump-Oriented Programming）的核心思路是：

- 不依赖 `ret`
- 利用 `jalr` / `jr` 这类间接跳转把已有代码片段串起来
- 目标通常是某个函数中间位置，或者某个本来不该作为间接跳转入口的地址

对本项目而言，`Zicfilp` 的作用就是保护“间接跳转目标”：

- 在发起间接跳转后，CPU 会把 `ELP` 置为“期待看到合法 landing pad”
- 跳转目标如果不是 `LPAD`，就触发 `software-check` 异常

### 1.3 COP

COP（Call-Oriented Programming）可以理解成使用间接调用把控制流导向另一个“看起来合法”的函数入口。

对本项目而言，它和 JOP 的区别是：

- JOP 样例跳到没有 `LPAD` 的非法入口，应该被 `Zicfilp` 拦截。
- COP 样例跳到编译器插桩后的合法函数入口，入口有 `LPAD`，因此 `Zicfilp` 只能确认 landing pad 合法，不能判断语义上是不是预期 callee。

## 2. 测试样例总览

### 2.1 JOP 样例

源码位置：

- [user/data/c/jop_example/main.c](user/data/c/jop_example/main.c)
- [user/data/c/jop_example/bad_target.S](user/data/c/jop_example/bad_target.S)
- [user/data/c/jop_example/start.S](user/data/c/jop_example/start.S)
- [user/data/c/jop_example/Makefile](user/data/c/jop_example/Makefile)

实现思路：

- `main()` 把 `bad_target` 放进全局函数指针 `g_bad_fp`
- `do_indirect_call()` 调用汇编 helper 发起一次真正的间接跳转
- 汇编 helper 固定使用 `a5` 作为 `JALR` 基址，避免 `rs1` 落在 `x1/x5/x7`
- `bad_target` 的第一条指令故意不是 `LPAD`
- `start.S` 中的 `m_trap_vector` 检查：
  - `mcause == 18`
  - `mtval == 2`
  - `mepc == bad_target`

### 2.2 ROP 样例

源码位置：

- [user/data/c/rop_example/main.c](user/data/c/rop_example/main.c)
- [user/data/c/rop_example/start.S](user/data/c/rop_example/start.S)
- [user/data/c/rop_example/Makefile](user/data/c/rop_example/Makefile)

实现思路：

- `cause_shadow_mismatch()` 被设计成一个非 leaf 函数，使编译器在开启 `Zicfiss` 插桩时自动插入 `sspush/sspopchk`
- 函数中先正常调用 `leaf_step()`
- 随后用 `ssrdp` 读取当前 `ssp`
- 再把当前 shadow slot 直接改写成 `0x13579bdf`
- 当函数执行到自动生成的 `sspopchk` 时，shadow stack 中的值与真实返回地址不一致，因此触发 `software-check`
- `start.S` 中的 `m_trap_vector` 检查：
  - `mcause == 18`
  - `mtval == 3`

### 2.3 COP 样例

源码位置：

- [user/data/c/cop_example/main.c](user/data/c/cop_example/main.c)
- [user/data/c/cop_example/call_helper.S](user/data/c/cop_example/call_helper.S)
- [user/data/c/cop_example/start.S](user/data/c/cop_example/start.S)
- [user/data/c/cop_example/Makefile](user/data/c/cop_example/Makefile)

实现思路：

- `main()` 先把 `g_call_fp` 设置为 `legit_target`
- `corrupt_dispatch_pointer()` 再把它改成 `cop_target`
- `call_via_fp()` 用汇编固定执行 `jalr ra, 0(a5)`，形成一次真实间接调用
- `CFI_INSERT=1` 时，`cop_target` 入口有 `LPAD`，所以 `Zicfilp` 不会拦截
- `CFI_INSERT=0, ZICFI_RUNTIME_ENABLE=1` 时，`cop_target` 入口没有 `LPAD`，会触发 `LPAD fault`

## 3. 当前开关含义

现在样例把两个容易混淆的开关拆开：

- `CFI_INSERT=1/0`：控制编译器是否加 `-fcf-protection` 插桩。
- `ZICFI_RUNTIME_ENABLE=1/0`：控制启动代码是否把 `menvcfg/senvcfg` 写成 `0x0c`。

因此可以分别观察：

- 编译器是否生成 `LPAD`、`SSPUSH`、`SSPOPCHK`。
- CPU 在运行时是否真的启用 `Zicfilp/Zicfiss` 检查。

这里仍然保留 `-march=rv32i_zicsr_zmmul_zicfiss_zicfilp`，因为源码和启动代码里需要汇编器识别相关 CSR 与指令编码。真正的运行时开关由 `menvcfg/senvcfg` 决定。

## 4. 编译方式

每个样例可以一次生成 4 个变体：

```bash
cd user/data/c/jop_example && make matrix
cd user/data/c/cop_example && make matrix
cd user/data/c/rop_example && make matrix
```

生成的 `hex` 位于 `user/data/hex/`：

- `jop_zicfilp_cfi_off_rt_off.hex`
- `jop_zicfilp_cfi_off_rt_on.hex`
- `jop_zicfilp_cfi_on_rt_off.hex`
- `jop_zicfilp_cfi_on_rt_on.hex`
- `cop_zicfilp_cfi_off_rt_off.hex`
- `cop_zicfilp_cfi_off_rt_on.hex`
- `cop_zicfilp_cfi_on_rt_off.hex`
- `cop_zicfilp_cfi_on_rt_on.hex`
- `rop_zicfiss_cfi_off_rt_off.hex`
- `rop_zicfiss_cfi_off_rt_on.hex`
- `rop_zicfiss_cfi_on_rt_off.hex`
- `rop_zicfiss_cfi_on_rt_on.hex`

也可以单独编译一个变体：

```bash
make CFI_INSERT=1 ZICFI_RUNTIME_ENABLE=1
make CFI_INSERT=0 ZICFI_RUNTIME_ENABLE=0
```

仿真时统一使用 `tb_CPU_TOP`，只切换 `+TESTCASE` 指向对应的 `hex` 文件。

如果要用 Verilator 一次跑完 12 组并保存 FST 波形，可以直接运行：

```bash
user/tools/run_cfi_matrix_verilator.sh
```

默认输出：

- `prj/verilator/cfi_matrix/waves/<case>.fst`
- `prj/verilator/cfi_matrix/logs/<case>.log`
- `prj/verilator/cfi_matrix/summary.txt`

常用选项：

```bash
user/tools/run_cfi_matrix_verilator.sh --skip-build
user/tools/run_cfi_matrix_verilator.sh --dry-run
OUT_DIR=/tmp/cfi_waves user/tools/run_cfi_matrix_verilator.sh
```

这些 C 裸机样例最终会停在自旋循环里，所以 `tb_Verilator` 可能以 `[EROR] TimeOut!` 结束；脚本默认只要求仿真退出并生成波形，不把这个 timeout 当成脚本失败。

说明：

- `tb_CPU_TOP` 只打印非零寄存器，因此 `x29 = 0` 的成功态不会显示出来
- 原有 `on.log/off.log` 是拆分运行时开关前的历史快照，不覆盖新的四象限矩阵：
  - [user/data/c/jop_example/on.log](user/data/c/jop_example/on.log)
  - [user/data/c/jop_example/off.log](user/data/c/jop_example/off.log)
  - [user/data/c/rop_example/on.log](user/data/c/rop_example/on.log)
  - [user/data/c/rop_example/off.log](user/data/c/rop_example/off.log)

## 5. 程序实现细节

### 5.1 JOP 样例程序实现

`main.c` 中的关键路径：

1. `g_bad_fp = bad_target`
2. `do_indirect_call()` 调用汇编 helper
3. 汇编 helper 从 `g_bad_fp` 取出目标地址，并固定通过 `a5` 执行 `jr a5`
4. 目标地址落到 `bad_target`
5. 因为 `bad_target` 没有 `LPAD`，触发 `Zicfilp` trap

打开编译器插桩后的反汇编可以看到：

- `jop_zicfilp_cfi_on_rt_on.SText`
- `main` 入口带 `lpad 0`
- `call_bad_target_indirect` 中保留了真正的 `jr a5`
- `bad_target` 仍然没有 `LPAD`

关闭编译器插桩后的反汇编可以看到：

- `jop_zicfilp_cfi_off_rt_on.SText`
- `main` 入口不再有 `lpad`
- `call_bad_target_indirect` 仍然是一次固定的 `jr a5`
- `bad_target` 依旧没有 `LPAD`

也就是说，JOP 样例里只关闭编译器插桩不会让非法跳转通过，因为：

- 运行时硬件的 `LPE` 依然打开
- 间接跳转目标仍然是一个没有 `LPAD` 的非法入口
- 因此硬件依旧会触发 `LPAD fault`

### 5.2 ROP 样例程序实现

`main.c` 中的关键路径：

1. 调用 `cause_shadow_mismatch(40)`
2. `cause_shadow_mismatch()` 先调用 `leaf_step()`，成为一个非 leaf 函数
3. 当 `ZICFI_RUNTIME_ENABLE=1` 时，用 `ssrdp` 读取当前 `ssp`
4. 当运行时 CFI 打开时，直接修改当前 shadow slot
5. 函数返回时，如果编译器插入了 `sspopchk`，就会触发 `shadow stack fault`

当 `ZICFI_RUNTIME_ENABLE=0` 时，C 代码会跳过 `ssrdp` 和 shadow-slot 写入，避免在 RTL 返回 `ssp=0` 时访问地址 0。

打开编译器插桩后的反汇编可以看到：

- `rop_zicfiss_cfi_on_rt_on.SText`
- `cause_shadow_mismatch` 入口有 `sspush ra`
- 尾部有 `sspopchk t0`
- `main` 本身也有 `sspush ra`

关闭编译器插桩后的反汇编可以看到：

- `rop_zicfiss_cfi_off_rt_on.SText`
- `cause_shadow_mismatch` 仍然会执行手写的 `ssrdp`
- 但已经没有自动生成的 `sspush`
- 也没有自动生成的 `sspopchk`
- 因此函数会正常 `ret`，不会因为 shadow slot 被改写而触发硬件检查

这说明 `Zicfiss` 的防护点不在“读到 `ssp`”本身，而在编译器是否把返回路径改造成 `shadow stack push/pop-check`。

### 5.3 COP 样例程序实现

`main.c` 中的关键路径：

1. `g_call_fp = legit_target`
2. `corrupt_dispatch_pointer()` 把 `g_call_fp` 改成 `cop_target`
3. `call_via_fp()` 从 `g_call_fp` 取出目标地址
4. 通过 `a5` 执行 `jalr ra, 0(a5)`
5. 如果 `cop_target` 有合法 `LPAD`，控制流不会被 `Zicfilp` 拦截，程序最后进入 `finish_observed(0x40)`

打开编译器插桩后的反汇编可以看到：

- `cop_zicfilp_cfi_on_rt_on.SText`
- `legit_target` 和 `cop_target` 入口都有 `lpad 0`
- `call_via_fp` 固定使用 `jalr a5`

关闭编译器插桩后的反汇编可以看到：

- `cop_zicfilp_cfi_off_rt_on.SText`
- `cop_target` 入口没有 `lpad`
- `call_via_fp` 仍然固定使用 `jalr a5`

因此 COP 样例和 JOP 的关键区别是：`CFI_INSERT=1, ZICFI_RUNTIME_ENABLE=1` 时，目标函数入口对 `Zicfilp` 来说是合法 landing pad，所以不会触发 `LPAD fault`。

## 6. 运行结果对比

### 6.1 汇总表

| 样例 | `CFI_INSERT` | `ZICFI_RUNTIME_ENABLE` | 关键反汇编特征 | 预期结果 |
| ---- | ------------ | ---------------------- | -------------- | -------- |
| JOP  | 0 | 0 | 无自动 `lpad`，helper 固定 `jr a5` | 不触发 `LPAD fault`，落到 `finish_fail(0x20)` |
| JOP  | 0 | 1 | 无自动 `lpad`，helper 固定 `jr a5`，`bad_target` 无 `LPAD` | 触发 `LPAD fault` |
| JOP  | 1 | 0 | C 函数入口有自动 `lpad`，但运行时 `LPE=0` | 不触发 `LPAD fault`，落到 `finish_fail(0x20)` |
| JOP  | 1 | 1 | C 函数入口有自动 `lpad`，helper 固定 `jr a5`，`bad_target` 无 `LPAD` | 触发 `LPAD fault` |
| COP  | 0 | 0 | `cop_target` 无 `lpad`，但运行时 `LPE=0` | 不触发 `LPAD fault`，进入 `finish_observed(0x40)` |
| COP  | 0 | 1 | `cop_target` 无 `lpad`，helper 固定 `jalr a5` | 触发 `LPAD fault` |
| COP  | 1 | 0 | `cop_target` 有 `lpad`，但运行时 `LPE=0` | 不触发 `LPAD fault`，进入 `finish_observed(0x40)` |
| COP  | 1 | 1 | `cop_target` 有合法 `lpad`，helper 固定 `jalr a5` | 不触发 `LPAD fault`，进入 `finish_observed(0x40)` |
| ROP  | 0 | 0 | 无 `sspush/sspopchk`，且跳过手写 `ssrdp` | 不触发 shadow-stack fault，落到 `finish_fail(0x20)` |
| ROP  | 0 | 1 | 手写 `ssrdp` 和 shadow-slot 改写存在，但无 `sspopchk` | 不触发 shadow-stack fault，落到 `finish_fail(0x20)` |
| ROP  | 1 | 0 | 有自动 `sspush/sspopchk`，但运行时 `SSE=0` | 不触发 shadow-stack fault，落到 `finish_fail(0x20)` |
| ROP  | 1 | 1 | 有自动 `sspush/sspopchk`，且 shadow slot 被改写 | 触发 `shadow stack fault` |

下面的 `on.log/off.log` 是旧的两组历史日志，适合对照异常形态，但不代表新的四象限完整结果。

### 6.2 JOP on

日志：

  - [user/data/c/jop_example/on.log](user/data/c/jop_example/on.log)


结论：

- 命中 `mcause = 18`
- `mepc = 0x000000cc`，即 `bad_target`
- `mtval = 2`
- `x28 = 1`

说明：

- 这是一个标准的 `Zicfilp LPAD fault`

### 6.3 JOP off

日志：

  - [user/data/c/jop_example/off.log](user/data/c/jop_example/off.log)


结论：

- 结果与 `JOP on` 相同

说明：

- 这不是编译器插桩失效，而是本样例的非法目标本来就没有 `LPAD`
- 只要运行时 `LPE` 打开，硬件仍然会把这个目标视为非法 landing pad

### 6.4 ROP on

日志：

  - [user/data/c/rop_example/on.log](user/data/c/rop_example/on.log)


结论：

- 命中 `mcause = 18`
- `mepc = 0x00000134`，即 `sspopchk t0`
- `mtval = 3`
- `x28 = 1`

说明：

- 这是一个标准的 `Zicfiss shadow stack fault`

### 6.5 ROP off

日志：

  - [user/data/c/rop_example/off.log](user/data/c/rop_example/off.log)


结论：

- 没有触发 `software-check`
- 程序正常回到 `main()`
- 最后落入 `finish_fail(0x20)`

关键寄存器：

- `x28 = 0x20`
- `x29 = 1`
- `x15 = 0xdead0020`

说明：

- 关闭编译器返回保护后，虽然代码仍能读取并改写 `ssp` 指向的位置
- 但因为函数尾部不存在 `sspopchk`
- 所以 CPU 没有任何机会检测 shadow stack 是否被篡改

## 7. 结论

从这两个样例可以总结出当前实现的特点：

1. `Zicfilp` 的检查点是“间接跳转目标是否合法”
   - 只要运行时 `LPE` 打开，跳到一个没有 `LPAD` 的目标就会被拦截
   - 因此在这个 JOP 负例里，`CFI_INSERT=0, ZICFI_RUNTIME_ENABLE=1` 仍然会 trap

2. `Zicfiss` 的检查点是“函数返回时有没有做 shadow stack 比对”
   - 这依赖编译器是否插入 `sspush/sspopchk`
   - 一旦关闭返回插桩，ROP 样例就不再触发 shadow-stack fault，而是正常返回到失败路径
   - 如果运行时 `SSE=0`，即便编译器插入了 `sspush/sspopchk`，当前 RTL 也会把它们按未启用路径处理

3. 因此对于软件栈保护来说：
   - `Zicfilp` 更像是“硬件在目标端做准入检查”
   - `Zicfiss` 更像是“编译器与硬件协作，在返回路径上显式插入检查点”
   - COP 样例说明：当被劫持目标本身拥有合法 `LPAD` 时，`Zicfilp` 不会按语义区分“是不是原本期望的函数”

现在四象限矩阵已经能把“关闭编译器插桩”和“关闭硬件 CFI 执行逻辑”分开比较。
