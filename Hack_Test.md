# CFI 样例分析 (By ChatGPT)

本文档整理了项目中两个“受控负例”样例：

- `user/data/c/jop_example`：用于验证 `Zicfilp`
- `user/data/c/rop_example`：用于验证 `Zicfiss`

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

## 2. 测试样例总览

### 2.1 JOP 样例

源码位置：

- [user/data/c/jop_example/main.c](user/data/c/jop_example/main.c)
- [user/data/c/jop_example/bad_target.S](user/data/c/jop_example/bad_target.S)
- [user/data/c/jop_example/start.S](user/data/c/jop_example/start.S)
- [user/data/c/jop_example/Makefile](user/data/c/jop_example/Makefile)

实现思路：

- `main()` 把 `bad_target` 放进全局函数指针 `g_bad_fp`
- `do_indirect_call()` 通过这个函数指针发起一次真正的间接跳转
- 为了匹配当前 RTL，函数指针被强制绑定到 `a5`，避免 `rs1` 落在 `x1/x5/x7`
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

## 3. “开启/关闭 CFI”在本文中的含义

这里要特别说明一件事：

- 本文的“开启 CFI”指开启编译器自动插桩，也就是开启 `-fcf-protection`
- 本文的“关闭 CFI”指去掉 `-fcf-protection`
- `start.S` 里打开 `menvcfg/senvcfg` 的硬件配置没有关闭

因此：

- `JOP` 的“关闭 CFI”并不等于“完全关闭硬件 landing pad 检查”
- `ROP` 的“关闭 CFI”也不等于“完全不支持 shadow stack CSR”，而是“编译器不再自动插入 `sspush/sspopchk`”

这也是两个样例在 on/off 对比时表现不同的根本原因。

## 4. 编译方式

本文结果使用了 4 个单独编译的变体：

- `jop_zicfilp_on`
- `jop_zicfilp_off`
- `rop_zicfiss_on`
- `rop_zicfiss_off`

对应命令如下：

```bash
wsl zsh -ilc "cd /mnt/e/MyRV_DIDE/user/data/c/jop_example && make clean && make TARGET=jop_zicfilp_on JOP_FLAGS='-fcf-protection=branch -fno-inline -fno-optimize-sibling-calls'"
wsl zsh -ilc "cd /mnt/e/MyRV_DIDE/user/data/c/jop_example && make clean && make TARGET=jop_zicfilp_off JOP_FLAGS=''"
wsl zsh -ilc "cd /mnt/e/MyRV_DIDE/user/data/c/rop_example && make clean && make TARGET=rop_zicfiss_on ROP_FLAGS='-fcf-protection=return -fno-inline -fno-optimize-sibling-calls'"
wsl zsh -ilc "cd /mnt/e/MyRV_DIDE/user/data/c/rop_example && make clean && make TARGET=rop_zicfiss_off ROP_FLAGS=''"
```

仿真时统一使用 `tb_CPU_TOP`，只切换 `+TESTCASE` 指向不同的 `hex` 文件。

说明：

- `tb_CPU_TOP` 只打印非零寄存器，因此 `x29 = 0` 的成功态不会显示出来
- 本文引用的日志来自：
  - [prj/run/jop_zicfilp_on.log](prj/run/jop_zicfilp_on.log)
  - [prj/run/jop_zicfilp_off.log](prj/run/jop_zicfilp_off.log)
  - [prj/run/rop_zicfiss_on.log](prj/run/rop_zicfiss_on.log)
  - [prj/run/rop_zicfiss_off.log](prj/run/rop_zicfiss_off.log)

## 5. 程序实现细节

### 5.1 JOP 样例程序实现

`main.c` 中的关键路径：

1. `g_bad_fp = bad_target`
2. `do_indirect_call()` 从 `g_bad_fp` 取出目标地址
3. 通过 `a5` 执行间接跳转
4. 目标地址落到 `bad_target`
5. 因为 `bad_target` 没有 `LPAD`，触发 `Zicfilp` trap

打开编译器插桩后的反汇编可以看到：

- [user/data/c/jop_example/jop_zicfilp_on.SText](user/data/c/jop_example/jop_zicfilp_on.SText)
- `main` 入口带 `lpad 0`
- `do_indirect_call` 中保留了真正的 `jalr a5`
- `bad_target` 仍然没有 `LPAD`

关闭编译器插桩后的反汇编可以看到：

- [user/data/c/jop_example/jop_zicfilp_off.SText](user/data/c/jop_example/jop_zicfilp_off.SText)
- `main` 入口不再有 `lpad`
- `do_indirect_call` 仍然是一次间接跳转，只是变成了 `jr a5`
- `bad_target` 依旧没有 `LPAD`

也就是说，JOP 样例里“关闭编译器插桩”并没有让攻击成功，因为：

- 运行时硬件的 `LPE` 依然打开
- 间接跳转目标仍然是一个没有 `LPAD` 的非法入口
- 因此硬件依旧会触发 `LPAD fault`

### 5.2 ROP 样例程序实现

`main.c` 中的关键路径：

1. 调用 `cause_shadow_mismatch(40)`
2. `cause_shadow_mismatch()` 先调用 `leaf_step()`，成为一个非 leaf 函数
3. 用 `ssrdp` 读取当前 `ssp`
4. 直接修改当前 shadow slot
5. 函数返回时，如果编译器插入了 `sspopchk`，就会触发 `shadow stack fault`

打开编译器插桩后的反汇编可以看到：

- [user/data/c/rop_example/rop_zicfiss_on.SText](user/data/c/rop_example/rop_zicfiss_on.SText)
- `cause_shadow_mismatch` 入口有 `sspush ra`
- 尾部有 `sspopchk t0`
- `main` 本身也有 `sspush ra`

关闭编译器插桩后的反汇编可以看到：

- [user/data/c/rop_example/rop_zicfiss_off.SText](user/data/c/rop_example/rop_zicfiss_off.SText)
- `cause_shadow_mismatch` 仍然会执行手写的 `ssrdp`
- 但已经没有自动生成的 `sspush`
- 也没有自动生成的 `sspopchk`
- 因此函数会正常 `ret`，不会因为 shadow slot 被改写而触发硬件检查

这说明 `Zicfiss` 的防护点不在“读到 `ssp`”本身，而在编译器是否把返回路径改造成 `shadow stack push/pop-check`。

## 6. 运行结果对比

### 6.1 汇总表

| 样例 | 编译方式 | 关键反汇编特征                                                 | 最终结果                                      | 关键寄存器                            |
| ---- | -------- | -------------------------------------------------------------- | --------------------------------------------- | ------------------------------------- |
| JOP  | CFI on   | `main` 有 `lpad`，间接跳转为 `jalr a5`，`bad_target` 无 `LPAD` | 触发 `LPAD fault`                             | `x5=18`, `x6=0xcc`, `x7=2`, `x28=1`   |
| JOP  | CFI off  | `main` 无 `lpad`，间接跳转为 `jr a5`，`bad_target` 无 `LPAD`   | 仍然触发 `LPAD fault`                         | `x5=18`, `x6=0xcc`, `x7=2`, `x28=1`   |
| ROP  | CFI on   | `cause_shadow_mismatch` 有 `sspush` 和 `sspopchk`              | 触发 `shadow stack fault`                     | `x5=18`, `x6=0x134`, `x7=3`, `x28=1`  |
| ROP  | CFI off  | 只有手写 `ssrdp`，没有 `sspush/sspopchk`                       | 不触发 CFI trap，程序落到 `finish_fail(0x20)` | `x28=0x20`, `x29=1`, `x15=0xdead0020` |

### 6.2 JOP on

日志：

- [prj/run/jop_zicfilp_on.log](prj/run/jop_zicfilp_on.log)

结论：

- 命中 `mcause = 18`
- `mepc = 0x000000cc`，即 `bad_target`
- `mtval = 2`
- `x28 = 1`

说明：

- 这是一个标准的 `Zicfilp LPAD fault`

### 6.3 JOP off

日志：

- [prj/run/jop_zicfilp_off.log](prj/run/jop_zicfilp_off.log)

结论：

- 结果与 `JOP on` 相同

说明：

- 这不是编译器插桩失效，而是本样例的非法目标本来就没有 `LPAD`
- 只要运行时 `LPE` 打开，硬件仍然会把这个目标视为非法 landing pad

### 6.4 ROP on

日志：

- [prj/run/rop_zicfiss_on.log](prj/run/rop_zicfiss_on.log)

结论：

- 命中 `mcause = 18`
- `mepc = 0x00000134`，即 `sspopchk t0`
- `mtval = 3`
- `x28 = 1`

说明：

- 这是一个标准的 `Zicfiss shadow stack fault`

### 6.5 ROP off

日志：

- [prj/run/rop_zicfiss_off.log](prj/run/rop_zicfiss_off.log)

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
   - 因此在这个 JOP 负例里，关闭编译器插桩后仍然会 trap

2. `Zicfiss` 的检查点是“函数返回时有没有做 shadow stack 比对”
   - 这依赖编译器是否插入 `sspush/sspopchk`
   - 一旦关闭返回插桩，ROP 样例就不再触发 CFI trap，而是正常返回到失败路径

3. 因此对于软件栈保护来说：
   - `Zicfilp` 更像是“硬件在目标端做准入检查”
   - `Zicfiss` 更像是“编译器与硬件协作，在返回路径上显式插入检查点”

如果要继续扩展测试，下一步最值得做的是：

- 再补一个“完全关闭运行时 CFI 开关”的版本  
  即在 `start.S` 中同时清掉 `menvcfg/senvcfg` 的相关位
- 这样就可以把“关闭编译器插桩”和“关闭硬件 CFI 执行逻辑”两种场景分开比较
