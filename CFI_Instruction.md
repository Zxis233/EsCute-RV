# Zicfiss / Zicfilp 实现讲解 (By ChatGPT)

这份文档不是复述规范，而是解释这个仓库里的实现是怎么跑起来的，方便你一边看源码一边理解数据流、控制流和异常流。

说明：
- 文中的源码跳转都直接链接到文件；我在文字里附了关键行号，便于你在 IDE 里快速定位。
- 这里讲的是当前仓库里的“已实现子集”，不是完整特权规范。

## 1. 先看这个核到底实现了什么

关键定义在 [defines.svh](user/src/include/defines.svh)（约 `L144-L299`）：
- 新增写回选择 `WD_SEL_FROM_SSP`，说明 `SSRDP` 的结果不是走普通 ALU/Load/CSR 路径，而是直接把 `ssp` 写回寄存器。
- 新增访存类型 `MEM_SSPUSH` / `MEM_SSPOPCHK`，说明 `SSPUSH` / `SSPOPCHK` 被建模成特殊的 store/load 类指令。
- 新增 CSR：`ssp`、`senvcfg`、`menvcfg`、`mstatush`、`mseccfg`。
- 新增异常：`EXC_SOFTWARE_CHECK = 18`。
- 新增 software-check 子码：`LPAD fault = 2`，`shadow stack fault = 3`。
- 新增指令匹配：`LPAD`、`SSPUSH`、`SSPOPCHK`、`SSRDP`。
- 新增使能位：`ENVCFG_LPE_BIT`、`ENVCFG_SSE_BIT`、`MSECCFG_MLPE_BIT`、`MSTATUS_SPELP_BIT`、`MSTATUSH_MPELP_BIT`。

从这里可以先建立一个总图：
- `Zicfiss` 负责 shadow stack，也就是 `ssp`、`SSRDP`、`SSPUSH`、`SSPOPCHK`。
- `Zicfilp` 负责 landing pad，也就是 `LPAD`、`ELP` 状态、间接跳转后的 software-check。

## 2. 解码阶段做了什么

核心在 [Decoder.sv](user/src/Decoder.sv)。

### 2.1 指令识别

在 [Decoder.sv](user/src/Decoder.sv) `L56-L68`：
- `is_lpad_internal` 用 `MATCH_LPAD/MASK_LPAD` 识别 `LPAD`。
- `is_sspush_internal` 识别 `SSPUSH`。
- `is_ssrdp_encoding` 先识别 `SSRDP` 的编码形状。
- `is_ssrdp_internal` 要求 `rd != x0`，也就是把 `SSRDP rd=x0` 作为保留非法编码。
- `is_sspopchk_internal` 通过排除 `SSRDP` 后，再用 `MATCH_SSPOPCHK/MASK_SSPOPCHK` 识别 `SSPOPCHK`。

这一步很重要，因为这三个 shadow-stack 指令的 opcode 看起来都像 system/CSR 指令。如果不先在 decoder 里把它们单独摘出来，后面就会被错误地当成 CSR。

### 2.2 寄存器使用与写回语义

在 [Decoder.sv](user/src/Decoder.sv) `L83-L97`：
- `SSPUSH` / `SSPOPCHK` 被视为使用 `rs1`。
- `SSRDP` 不使用源寄存器，只写回目的寄存器。
- `LPAD` 不使用寄存器操作数。

这点和普通 `store/load` 习惯不一样，后面看数据通路时要一直记住：
- `SSPUSH` 存的是 `rs1` 的值。
- `SSPOPCHK` 比较的也是 `rs1` 的值。

在 [Decoder.sv](user/src/Decoder.sv) `L136-L197`：
- `SSRDP` 的 `wd_sel` 走 `WD_SEL_FROM_SSP`。
- `SSRDP` 会打开 `rf_we`。
- `LPAD` / `SSPUSH` / `SSPOPCHK` 不写通用寄存器。

在 [Decoder.sv](user/src/Decoder.sv) `L200-L201` 和 `L292-L321`：
- `SSPUSH` 会把 `dram_we` 打开。
- `SSPUSH` / `SSPOPCHK` 分别映射到 `MEM_SSPUSH` / `MEM_SSPOPCHK`。

### 2.3 从 CSR 空间里“抢出来”

在 [Decoder.sv](user/src/Decoder.sv) `L337-L370`：
- 如果是 `SSPUSH` / `SSPOPCHK` / `SSRDP`，`is_csr_instr = 0`。

也就是说，这些指令虽然编码上长得像 system/CSR，但进入本核以后，已经被重定向成专用 CFI 指令，不再走普通 CSR 执行路径。

### 2.4 非法指令策略

在 [Decoder.sv](user/src/Decoder.sv) `L478-L500`：
- `SSPUSH` / `SSPOPCHK` / `SSRDP(rd!=x0)` 是合法的。
- `SSRDP rd=x0` 被明确判成非法。

这和实现风格是一致的：保留编码不悄悄当 NOP，而是尽早触发异常。

## 3. Zicfilp：这个核里 LPAD 是怎么工作的

主逻辑在 [CPU_TOP.sv](user/src/CPU_TOP.sv)。

### 3.1 x7 为什么会参与 LPAD

在 [RegisterF.sv](user/src/RegisterF.sv) `L19-L21`、`L47-L52`：
- 寄存器堆新增了 `x7_o` 端口，专门把 `x7` 导出来。

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L251-L265`：
- `x7_effective_ID` 不是简单读寄存器堆，而是把乘法器回写、WB 前递、MEM 前递、EX 前递都考虑进去。

这说明当前实现不是“静态地拿 x7”，而是想在 ID 级做 LPAD 检查时看到“最新值”。这一步是为了避免：
- 前一条指令刚写了 `x7`
- 下一条就是 `LPAD`
- 结果比较时拿到旧值

### 3.2 LPAD pass 条件

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L279-L284`：
- `LPAD` 必须字对齐。
- 若 `instr[31:12] == 0`，直接放行。
- 否则要求 `instr[31:12] == x7_effective_ID[31:12]`。

这说明本核当前的 LPAD 验证规则是：
- 支持 `LPAD 0` 的“零标签”路径。
- 也支持用 `x7` 上半 20 位参与标签匹配。

你在测试汇编里专门用了非零 tag，就是为了确认第二条路径真的通了，见 [zicfi.S](user/data/isa/rv32mi/zicfi.S) `L20-L23` 和 `L87-L90`。

### 3.3 ELP 是什么时候置位、什么时候清掉的

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L629-L641`：
- 当 EX 级是 `JALR`
- 当前特权级 `LPE` 已启用
- 且 `rs1` 不是 `x1/x5/x7`
- 且当前 EX 级没有异常

这时：
- `elp_update_valid = 1`
- `elp_update_expected = 1`

等于是说：某些间接跳转会把“下一条必须是 LPAD”这个期待写进 CSR 状态机。

随后，如果 ID 级 `LPAD` 检查通过：
- `lpad_pass_ID = 1`
- 同时又会触发一次 `elp_update_valid`
- 但这次 `elp_update_expected = 0`

于是 `ELP` 被清空，表示 landing pad 验证已经完成。

### 3.4 不通过时怎么报错

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L283-L284`、`L522-L537`、`L570-L573`：
- 如果 `current_lpe_enabled && elp_expected && !lpad_pass_ID`
- 就在 ID 级产生 `software_check_exception_ID`
- 异常号是 `EXC_SOFTWARE_CHECK`
- `tval` 是 `SOFTCHK_LPAD_FAULT`

这意味着本核的 `Zicfilp` 检查点在 ID 级，而不是 EX/MEM/WB。

这样做的好处是：
- 更早拦住非法落点
- 不会让错误目标继续往后面流水

## 4. Zicfiss：shadow stack 是怎么工作的

### 4.1 `ssp` 从哪里来

在 [CSR.sv](user/src/CSR.sv) `L73-L75`：
- `ssp` 和 `elp_state` 都是 CSR 模块内部状态。

在 [CSR.sv](user/src/CSR.sv) `L245-L276`：
- `CSR_SSP` 可以读。

在 [CSR.sv](user/src/CSR.sv) `L364-L370`：
- `ssp_update_valid` 为真时，CSR 会直接更新 `ssp`。
- 普通 CSR 写 `CSR_SSP` 时，也能直接改 `ssp`。

在 [CSR.sv](user/src/CSR.sv) `L419-L422`：
- `ssp` 通过 `ssp_value` 输出给顶层。

### 4.2 哪些特权级真的打开了 shadow stack

在 [CSR.sv](user/src/CSR.sv) `L193-L207`：
- `S` 模式：`current_sse_enabled = menvcfg.SSE`
- `U` 模式：`current_sse_enabled = menvcfg.SSE && senvcfg.SSE`
- 其他模式默认 `0`

这点要特别注意：
- 按当前代码，`M` 模式下 `Zicfiss` 没有打开。
- 所以 `SSPUSH` / `SSPOPCHK` 的有效执行场景是 `S/U`，不是 `M`。

这也是为什么测试程序先在 M 模式配置，再 `mret` 进入 S 模式执行 shadow stack 指令，见 [zicfi.S](user/data/isa/rv32mi/zicfi.S) `L45-L55`。

### 4.3 `SSRDP`

`SSRDP` 的路径最短：
- decoder 识别成 `WD_SEL_FROM_SSP`，[Decoder.sv](user/src/Decoder.sv) `L138-L163`
- EX 级在写回 mux 中把 `ssp_value` 送去写回，[CPU_TOP.sv](user/src/CPU_TOP.sv) `L679-L687`

所以可以把它理解成一个“读 shadow stack pointer 到 GPR”的专用 move 指令。

### 4.4 `SSPUSH`

`SSPUSH` 的关键路径在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L454-L459`、`L625-L628`、`L718-L725`、`L734-L740`：
- 进入 EX 后，如果 `current_sse_enabled=1`，`shadow_mem_active_EX` 拉高。
- 地址不再用普通 ALU 结果，而是强制改成 `ssp_value - 4`。
- 同时 `ssp_update_valid=1`，`ssp_update_data=shadow_addr_EX`。
- EX/MEM 流水线保存的地址也被替换成这个 shadow 地址。
- 到 MEM 级，`StoreUnit` 把它当成整字写（`wstrb=1111`），见 [StoreUnit.sv](user/src/StoreUnit.sv) `L19-L23`。

而真正被写进 shadow stack 的数据，不是常规 store 的 `rs2`，而是当前实现里从 `rs1` 送下来的被保护值，见 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L675-L689` 和 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L734-L740`。

要点是：
- `SSPUSH` 不只是“写内存”
- 它还会同步推进 `ssp`
- 这两个动作分别落在访存路径和 CSR 状态路径上

### 4.5 `SSPOPCHK`

`SSPOPCHK` 的路径更像“load + compare + 条件更新”。

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L454-L459`：
- 如果启用 SSE，地址直接取 `ssp_value`。

在 [LoadUnit.sv](user/src/LoadUnit.sv) `L20-L22`：
- `MEM_SSPOPCHK` 直接把整字原样读出来，不做 byte/halfword 提取。

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L621-L628`：
- WB 级比较 `load_data_WB` 和 `rf_wd_WB_from_ALU`
- 相等：`sspopchk_success_WB=1`，`ssp += 4`
- 不等：`sspopchk_fault_WB=1`

这里 `rf_wd_WB_from_ALU` 本质上就是前面从 `rs1` 送下来的被保护值，所以可以把 `SSPOPCHK` 理解成：
- 从 `ssp` 指向的位置读一个字。
- 用它和当前 `rs1` 的值做相等性检查。
- 成功才把 `ssp` 弹回去。

这里有一个很值得学习的实现点：
- `SSPUSH` 的地址检查和 `ssp` 下降在前面
- `SSPOPCHK` 的成功与否必须等内存数据回来，所以放在 WB 再决定是否把 `ssp` 加回去

### 4.6 Shadow stack 访存是如何被“串行化”的

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L803-L807`：
- 只要 EX/MEM/WB 里还有 `SSPUSH` / `SSPOPCHK`
- `shadow_serialize_EX/MEM/WB` 就会拉高

在 [HazardUnit.sv](user/src/HazardUnit.sv) `L191-L201`：
- 这些信号被汇总成 `shadow_serialize_hazard`
- 然后直接并入 `any_hazard`
- 最终导致 `keep_pc`、`stall_IF_ID`、`flush_ID_EX`

这表示当前实现选择了“简单而稳”的策略：
- shadow stack 指令不和普通流水线深度重叠优化
- 而是显式串行化，优先保证状态一致性

## 5. CSR 状态机是怎么把两类扩展接起来的

这一块在 [CSR.sv](user/src/CSR.sv)。

### 5.1 使能位视图

在 [CSR.sv](user/src/CSR.sv) `L121-L132`：
- `senvcfg` 的读视图不是原值，而是 `compose_senvcfg(...)`
- 如果 `menvcfg.SSE=0`，那么 `senvcfg.SSE` 读出来也会被压成 0

这说明当前实现里，`menvcfg` 是更高一级的闸门。

### 5.2 ELP 的 trap 保存/恢复

在 [CSR.sv](user/src/CSR.sv) `L326-L367`：
- 发生 delegated trap 进 S 时，把旧 `elp_state` 存到 `mstatus.SPELP`
- 发生 trap 进 M 时，把旧 `elp_state` 存到 `mstatush.MPELP`
- 无论进 S 还是进 M，进入 trap 时 `elp_state` 都清 0
- `mret` / `sret` 时，如果目标特权级允许 LPE，再从 `MPELP/SPELP` 恢复

所以 `ELP` 不是一个“只在流水线里飞一拍”的信号，而是一个真正跨 trap / xRET 生命周期保存的特权状态。

### 5.3 `ssp` / `elp` 的外部更新口

在 [CSR.sv](user/src/CSR.sv) `L364-L367`：
- `ssp_update_valid` 和 `elp_update_valid` 的优先级高于普通 CSR 写

这保证了：
- `SSPUSH` / `SSPOPCHK` 这种架构语义，不会被同周期普通 CSR 指令抢掉
- `ELP` 作为控制流状态机，可以由流水线直接驱动

## 6. 异常优先级和实现边界

### 6.1 本核当前的优先级

在 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L534-L584`：
1. `SSPOPCHK` mismatch（WB 级 software-check）
2. EX 级异常（取址/访存未对齐、shadow access fault、ecall）
3. ID 级 LPAD software-check
4. ID 级非法指令

这个优先级很合理，因为：
- `SSPOPCHK` 的真假只有 WB 才知道
- LPAD 检查又比普通非法指令更“专门”

### 6.2 当前实现的边界

从代码看，当前版本是“最小可工作实现”，不是完整 spec：
- 没有实现 `SSAMOSWAP.*`
- shadow stack 存储被建模在普通 DRAM 上，不是特殊页类型
- `shadow_access_fault_EX` 只检查字对齐，[CPU_TOP.sv](user/src/CPU_TOP.sv) `L514`
- `LPAD` 检查使用 `x7` 的高 20 位比较，是这个实现的具体策略

所以学习时最好把这份代码理解成：
- “规范思想的一个工程化裁剪版”
- 重点是你能看到架构语义怎样映射到流水线和 CSR

## 7. 测试程序怎么验证这套逻辑

### 7.1 汇编自测

测试程序在 [zicfi.S](user/data/isa/rv32mi/zicfi.S)。

执行顺序非常适合拿来对照波形：
- `L38-L43`：M 模式写 `menvcfg/senvcfg`
- `L45-L47`：初始化 `ssp`
- `L49-L55`：把 `MPP` 改成 `S`，然后 `mret`
- `L57-L85`：在 S 模式依次测 `SSRDP`、`SSPUSH`、`SSPOPCHK`
- `L87-L90`：设置 `x7` tag，执行一次间接 `jalr`
- `L106-L109`：目标地址以 `LPAD` 开头

这份测试故意把 `LPAD` 做成非零 tag，不是 `LPAD 0`，就是为了确认 `x7` 比较路径也成立。

### 7.2 直接 ROM 测试台

更容易读懂的定向测试在 [tb_Zicfi.sv](user/sim/tb_Zicfi.sv)。

它的优点是：
- 不依赖 toolchain
- 指令 ROM 手写，地址和行为更直观
- 结束条件就是检查 `x10/x11/x12/ssp/elp/mem[15]`

可以先看 [tb_Zicfi.sv](user/sim/tb_Zicfi.sv) `L32-L56` 的 ROM 布局，再对照 [tb_Zicfi.sv](user/sim/tb_Zicfi.sv) `L80-L105` 的最终断言。

## 8. 看波形时建议关注哪些点

如果你想把“规范概念”和“RTL 实现”真正对应起来，建议把波形按下面分组：

### 8.1 Zicfilp

优先看这些信号：
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `current_lpe_enabled`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `elp_expected`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `jump_type_EX`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `elp_update_valid`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `elp_update_expected`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `is_lpad_instr_ID`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `lpad_pass_ID`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `software_check_exception_ID`

你应该看到的节奏是：
1. 间接 `jalr` 进入 EX
2. `elp_update_expected` 被置 1
3. 下一拍 `elp_expected` 真的变 1
4. 目标 `LPAD` 在 ID 级被识别
5. `lpad_pass_ID` 拉高
6. `elp_expected` 被清回 0

### 8.2 Zicfiss

优先看这些信号：
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `current_sse_enabled`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `ssp_value`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `shadow_mem_active_EX`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `shadow_addr_EX`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `ssp_update_valid`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `ssp_update_data`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `sspopchk_success_WB`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `sspopchk_fault_WB`

你应该看到的节奏是：
1. `SSRDP` 把当前 `ssp` 读到 GPR
2. `SSPUSH` 使 `shadow_addr_EX = ssp - 4`
3. `ssp_update_valid` 拉高，`ssp` 下降
4. `SSPOPCHK` 在 WB 比较 load 结果和原寄存器值
5. 若比较成功，`ssp` 加回 4

### 8.3 用 `zicfi_rv32_test.S` 逐段对照

如果你现在跑的是裸机程序 [zicfi_rv32_test.S](user/data/asm/zicfi_rv32_test.S)，最省事的办法不是盯整段波形，而是按 [zicfi_rv32_test.SText](user/data/asm/zicfi_rv32_test.SText) 里的标签地址分段看。

建议同时拉出这些信号：
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `pc_ID`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `pc_EX`
- [CSR.sv](user/src/CSR.sv) `current_priv_mode`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `ssp_value`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `elp_expected`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `exception_cause`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `exception_tval`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `lpad_pass_ID`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `software_check_exception_ID`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `shadow_mem_active_EX`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `shadow_access_fault_EX`
- [CPU_TOP.sv](user/src/CPU_TOP.sv) `sspopchk_success_WB`
- [CSR.sv](user/src/CSR.sv) `mcause`
- [CSR.sv](user/src/CSR.sv) `scause`
- [CSR.sv](user/src/CSR.sv) `mepc`
- [CSR.sv](user/src/CSR.sv) `sepc`

还要先记住一个实现细节：
- 这份程序一开始把 `7/8/18` 委托给了 S-mode，所以 S/U 段很多 trap 更新的是 `scause`，不是 `mcause`，见 [zicfi_rv32_test.S](user/data/asm/zicfi_rv32_test.S) `L129-L133`。

| 阶段                           | 关键 PC                                           | `ssp_value` 预期                       | `elp_expected` 预期                                                                                               | `cause` 预期                                                              |
| ------------------------------ | ------------------------------------------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| M `LPAD` 正例                  | `0x5c-0x64 -> 0x438 -> 0x68`                      | 不变                                   | `jalr` 后 `0 -> 1`；`0x438` 命中 `lpad` 后 `1 -> 0`                                                               | 无 trap；`mcause/scause` 不变                                             |
| M `LPAD` 负例                  | `0x7c-0xa8 -> 0x468 -> 0x3b0 -> 0x450 -> 0xac`    | 不变                                   | `jalr` 后 `0 -> 1`；进入 `mtvec` 时 live `ELP` 清 0 并存到 `MPELP`；`mret` 回 `0x450` 时恢复成 1；`lpad` 再清回 0 | `mcause=18`，`mepc=0x468`，`mtval=2`                                      |
| 进入 S-mode                    | `0xd8-0x104 -> 0x108`                             | 不变                                   | 应为 0                                                                                                            | 只是 `mret`，无新 trap                                                    |
| S `LPAD` 正例                  | `0x114-0x11c -> 0x440 -> 0x120`                   | 不变                                   | `0 -> 1 -> 0`                                                                                                     | 无 trap；`scause` 不变                                                    |
| S `LPAD` 负例                  | `0x134-0x160 -> 0x470 -> 0x3ec -> 0x458 -> 0x164` | 不变                                   | `jalr` 后变 1；进入 `stvec` 时 live `ELP` 清 0 并存到 `SPELP`；`sret` 到 `0x458` 时恢复成 1；`lpad` 再清 0        | `scause=18`，`sepc=0x470`，`stval=2`                                      |
| S `SSRDP/SSPUSH/SSPOPCHK` 正例 | `0x190-0x1c8`                                     | `0x1020 -> 0x101c -> 0x1020`           | 始终 0                                                                                                            | 无 trap；`sspopchk_success_WB=1`                                          |
| S `SSPUSH` 非对齐 fault        | `0x1dc-0x210 -> 0x3ec -> 0x214`                   | 先写成 `0x1022`；fault 后保持 `0x1022` | 0                                                                                                                 | `scause=7`，`sepc=0x210`，`stval=0x101e`                                  |
| 进入 U-mode                    | `0x248-0x264 -> 0x268`                            | 保持上一值，直到后面重新写 `ssp`       | 应为 0                                                                                                            | 只是 `sret`，无新 trap                                                    |
| U `LPAD` 正例                  | `0x268-0x270 -> 0x448 -> 0x274`                   | 不变                                   | `0 -> 1 -> 0`                                                                                                     | 无 trap                                                                   |
| U `LPAD` 负例                  | `0x288-0x2b4 -> 0x478 -> 0x3ec -> 0x460 -> 0x2b8` | 不变                                   | `jalr` 后变 1；进入 S trap 时清 0 并存 `SPELP`；`sret` 到 `0x460` 时恢复 1；`lpad` 再清 0                         | `scause=18`，`sepc=0x478`，`stval=2`                                      |
| U `SSRDP/SSPUSH/SSPOPCHK` 正例 | `0x2e4-0x31c`                                     | `0x1030 -> 0x102c -> 0x1030`           | 0                                                                                                                 | 无 trap；`sspopchk_success_WB=1`                                          |
| U `SSPUSH` 非对齐 fault        | `0x330-0x364 -> 0x3ec -> 0x368`                   | 先写成 `0x1032`；fault 后保持 `0x1032` | 0                                                                                                                 | `scause=7`，`sepc=0x364`，`stval=0x102e`                                  |
| U `ecall` 返回 S               | `0x394 -> 0x3ec -> 0x428 -> 0x398 -> 0x4b0`       | 不变                                   | 0                                                                                                                 | `scause=8`；S trap handler 把 `sepc` 改写到 `0x398`，然后回 S 进入 `done` |
| 结束自旋                       | `0x4b0`                                           | 保持最后值                             | 0                                                                                                                 | 无新 trap；PC 固定在 `0x4b0`                                              |

这张表里有两个容易误判的点：
- `mcause/scause` 是 CSR 状态，不会自动清零，所以更适合和 [CPU_TOP.sv](user/src/CPU_TOP.sv) `exception_cause` 一起看。
- `SSPOPCHK` 成功时的 `ssp += 4` 发生在 WB 路径，和 `SSPUSH` 在 EX 路径推进 `ssp` 不是同一拍，见 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L621-L628` 和 [CPU_TOP.sv](user/src/CPU_TOP.sv) `L625-L628`。

## 9. 一句话总结

这个仓库里的 Zicfiss / Zicfilp 实现，本质上做了三件事：
- 在 decoder 里把 CFI 指令从普通 system/CSR 路径里分流出来
- 在 pipeline 里为它们单独安排了状态更新、异常优先级和串行化策略
- 在 CSR 里把 `ssp` / `ELP` 变成真正跨特权级、跨 trap 生命周期的架构状态

如果你是“学习工作原理”，最值得抓住的不是每条语句，而是这三条主线：
- `LPAD` 是“控制流验证”
- `SSPUSH/SSPOPCHK` 是“返回地址完整性验证”
- `ELP/ssp` 则是把这两类验证接进特权状态机的桥
