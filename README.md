# EsCute 极简五级流水线RV32I实现

## 项目简介

- [x] 实现RV32I指令集的五级流水线CPU  
- [x] 支持流水线停顿与数据前推  
- [x] 支持 `NONE` / `STATIC` / `DYNAMIC_1bit` / `GSHARE` 分支预测
- [x] 支持 Zmmul 扩展  
- [x] 支持基础 U/S/M-Mode 与常用特权 CSR
- [x] 支持 Zicfiss / Zicfilp 已实现子集
- [x] 支持基本的异常处理机制
- [x] 通过官方[riscv-tests](https://github.com/riscv-software-src/riscv-tests) RV32I_Zicsr_Zmmul验证（不含`ECALL`与`EBRAK`指令，不含非对齐访存相关指令，仅实现非对齐访存异常）
- [x] 通过Coremark基准测试

当前已实现的 Zicfi 相关功能：
- `Zicfiss`：`SSRDP`、`SSPUSH`、`SSPOPCHK`、`ssp` CSR，以及 `menvcfg/senvcfg` 控制下的 shadow stack 使能
- `Zicfilp`：`LPAD`、`ELP` 状态跟踪、间接 `JALR` 后的软件检查、`software-check` 异常上报
- trap / xRET 对 `ELP` 的保存与恢复

当前未实现或仅做最小化建模的部分：
- `SSAMOSWAP.*` 尚未实现
- shadow stack 目前复用了普通 DRAM 路径，只实现了按字对齐检查与基本 fault 行为

关于 Zicfiss / Zicfilp 的详细实现分析、源码跳转和波形观察点，见 [CFI_Instruction.md](CFI_Instruction.md)。


## 目录层级

```
EsCute-RV
├── .vscode
│  └── property.json                  # DIDE配置文件
├── CFI_Instruction.md                # Zicfiss / Zicfilp 实现说明
├── filelist.f                        # 工程文件列表
├── README.md                         # 项目说明文件
├── Makefile                          # 自动化测试用 Makefile 文件   
├── coremark                          # CoreMark基准测试文件夹
│  ├── Makefile                       # CoreMark基准测试 Makefile 文件
│  └── escute
│     ├── soft_div.c                  # 软件除法函数实现文件
│     ├── core_portme.c               # CoreMark平台相关函数实现文件
│     ├── core_portme.h               # CoreMark平台相关函数声明文件
│     ├── ee_printf.h                 # CoreMark打印函数声明文件
│     └── core_portme.mak             # CoreMark平台相关Makefile文件
└── user
   ├── data
   │  └── isa                         # riscv-tests指令集测试
   │     ├── env                      # 测试用环境文件
   │     │  ├── encoding.h
   │     │  ├── link.ld               # 测试用链接脚本文件
   │     │  ├── riscv_test.h
   │     │  └── test_macros.h         # 自动化测试用 宏定义文件
   │     ├── generated                # 测试样例二进制文件与反编译文件
   │     ├── hex                      # 自动化测试用 机器码文件
   │     ├── Makefile                 # 自动化测试用 测试样例生成 Makefile
   │     ├── rv32ui                   # 自动化测试用 汇编代码文件
   │     ├── rv64ui                   # 自动化测试用 汇编代码文件
   │     ├── rv32mi                   # 自动化测试用 汇编代码文件 （机器模式指令测试，含 zicfi.S）
   │     ├── rv64mi                   # 自动化测试用 汇编代码文件 （机器模式指令测试）
   │     ├── test_tb.sv               # 自动化测试用 顶层仿真文件
   │     └── verilog                  # 自动化测试用 Verilog 反编译内存文件
   ├── sim
   │  ├── tb_CPU_TOP.sv               # 顶层CPU仿真文件
   │  ├── tb_Zicfi.sv                 # Zicfiss / Zicfilp 定向测试
   │  ├── simple_counter.sv           # 简单计数器模块
   │  └── tb_simple_counter.sv        # 简单计数器测试文件 用于测试环境是否正确
   └── src
      ├── include
      │  └── defines.svh              # 全局宏定义文件
      │
      ├── IROM.sv                     # 指令存储器模块
      ├── CPU_TOP.sv                  # CPU顶层模块
      ├── PC.sv                       # 程序计数器模块
      │
      ├── Decoder.sv                  # 指令译码模块
      ├── imm_extender.sv             # 立即数扩展模块
      ├── BPU.sv                      # 分支预测单元模块
      ├── Static_Predictor.sv         # 静态分支预测模块
      ├── Dynamic_1bit_Predictor.sv   # 1-bit动态分支预测模块
      ├── Dynamic_Gshare_Predictor.sv # GShare动态分支预测模块
      │
      ├── ALU.sv                      # 算术逻辑单元模块
      ├── MUL.sv                      # 乘法运算模块
      ├── CSR.sv                      # 控制状态寄存器模块
      ├── NextPC_Generator.sv         # 下一条指令地址生成模块
      │
      ├── DRAM.sv                     # 同步数据存储器模块
      ├── LoadUnit.sv                 # 读取单元模块
      ├── StoreUnit.sv                # 存储单元模块
      │
      ├── HazardUnit.sv               # 数据冒险处理模块
      ├── PR_IF_ID.sv                 # IF/ID级  流水线寄存器模块
      ├── PR_ID_EX.sv                 # ID/EX级  流水线寄存器模块
      ├── PR_EX_MEM.sv                # EX/MEM级 流水线寄存器模块
      ├── PR_MEM_WB.sv                # MEM/WB级 流水线寄存器模块
      └── RegisterF.sv                # 寄存器堆模块
      
```

## 分支预测说明

当前前端支持 4 种 BPU 模式，枚举定义见 [defines.svh](user/src/include/defines.svh)：

- `NONE (0)`：关闭分支预测，控制流统一在 EX 级解析并恢复
- `STATIC (1)`：静态预测，`JAL` 恒预测跳转，`JALR` 不预测，条件分支采用 `BTFNT`（Backward Taken, Forward Not Taken）
- `DYNAMIC_1bit (2)`：基于 PC 低位索引的 1-bit BHT，记录该分支最近一次真实结果
- `GSHARE (3)`：使用 `PC xor GHR` 索引的 GShare，PHT 为 2-bit 饱和计数器

相关实现文件：

- [BPU.sv](user/src/BPU.sv)：统一 BPU 封装与不同预测器切换入口
- [Static_Predictor.sv](user/src/Static_Predictor.sv)：静态预测器实现
- [Dynamic_1bit_Predictor.sv](user/src/Dynamic_1bit_Predictor.sv)：1-bit 动态预测器实现
- [Dynamic_Gshare_Predictor.sv](user/src/Dynamic_Gshare_Predictor.sv)：GShare 动态预测器实现
- [CPU_TOP.sv](user/src/CPU_TOP.sv)：前端 redirect、训练回写与 `mispredict_counter`
- [PR_ID_EX.sv](user/src/PR_ID_EX.sv)：把预测目标与 predictor metadata 从 ID 级带到 EX 级
- [HazardUnit.sv](user/src/HazardUnit.sv)：预测发射导致的 `flush_IF_ID` 以及 EX 级恢复冲刷

当前默认配置：

- `CPU_TOP` 默认 `BPU_TYPE = STATIC`
- `CPU_TOP` 内部默认 `BPU_INDEX_BITS = 8`
- `CPU_TOP` 内部默认 `BPU_META_BITS = 2`
- `GShare` 当前采用“非投机式” GHR 更新：GHR 在 EX 级按真实分支结果更新，不做投机更新与回滚

切换不同预测器时，可以直接在仿真命令里覆盖 `BPU_TYPE`：

```bash
make SIM=iverilog run TESTCASE=rv32ui-p-beq BPU_TYPE=0
make SIM=iverilog run TESTCASE=rv32ui-p-beq BPU_TYPE=1
make SIM=iverilog run TESTCASE=rv32ui-p-beq BPU_TYPE=2
make SIM=iverilog run TESTCASE=rv32ui-p-beq BPU_TYPE=3

make SIM=iverilog coremark_test BPU_TYPE=3
make SIM=verilator compile BPU_TYPE=3
```

如果需要 sweep `INDEX_BITS` / `META_BITS`，当前可以直接修改 [CPU_TOP.sv](user/src/CPU_TOP.sv) 中的 `BPU_INDEX_BITS` 与 `BPU_META_BITS` 两个 `localparam`。

关于统计信息：

- `mispredict_counter` 会在 [test_tb.sv](user/data/isa/test_tb.sv)、[coremark.sv](user/sim/coremark.sv) 和 [tb_Verilator.sv](user/sim/tb_Verilator.sv) 中输出
- `BPU_TYPE = NONE` 时该计数器保持为 `0`
- 启用 BPU 时，它可用于不同预测器之间的相对性能比较

## Zicfi 扩展说明

本仓库当前实现的 Zicfi 逻辑主要分布在以下文件：
- [defines.svh](user/src/include/defines.svh)：Zicfiss / Zicfilp 指令匹配、CSR 编号、异常号与 software-check 子码
- [Decoder.sv](user/src/Decoder.sv)：`LPAD`、`SSRDP`、`SSPUSH`、`SSPOPCHK` 的识别与控制信号生成
- [CPU_TOP.sv](user/src/CPU_TOP.sv)：LPAD 检查、shadow stack 地址生成、`ssp` / `ELP` 更新、异常优先级与流水线串行化
- [CSR.sv](user/src/CSR.sv)：`ssp`、`menvcfg`、`senvcfg`、`mstatush`、`mseccfg` 以及 trap / xRET 对 `ELP` 的保存恢复
- [zicfi.S](user/data/isa/rv32mi/zicfi.S)：基于 `riscv-tests` 风格的 Zicfi 正向汇编测试
- [tb_Zicfi.sv](user/sim/tb_Zicfi.sv)：无需工具链即可运行的定向仿真测试

当前实现的行为重点：
- `SSRDP` 从 `ssp` 读出 shadow stack pointer
- `SSPUSH` / `SSPOPCHK` 走专用 shadow stack 访存路径，并更新 `ssp`
- 间接 `JALR` 会设置 `ELP`，后续落点必须通过 `LPAD` 检查
- `LPAD` 或 `SSPOPCHK` 失败时，会上报 `software-check` 异常

建议阅读顺序：
1. [CFI_Instruction](CFI_Instruction.md)
2. [Decoder.sv](user/src/Decoder.sv)
3. [CPU_TOP.sv](user/src/CPU_TOP.sv)
4. [CSR.sv](user/src/CSR.sv)
5. [zicfi.S](user/data/isa/rv32mi/zicfi.S) 和 [tb_Zicfi.sv](user/sim/tb_Zicfi.sv)
6. [zicfi_rv32_test.S](user/data/asm/zicfi_rv32_test.S)

### Zicfi 测试入口

如果工具链支持 `zicfiss` / `zicfilp`，可以先生成并运行汇编测试：

```bash
make -C user/data/isa rv32mi-p-zicfi.dump
vvp prj/run/zicfi_check.vvp +TESTCASE=user/data/isa/hex/rv32mi-p-zicfi.hex +DUMPWAVE=1 +PRINT_INFO=0
```

如果只想快速验证 RTL，也可以直接跑定向测试：

```bash
iverilog -g2012 -Wall -s tb_Zicfi -I user/src -I user/src/include -o prj/run/tb_zicfi.vvp user/sim/tb_Zicfi.sv user/src/*.sv
vvp prj/run/tb_zicfi.vvp
```

## CoreMark性能测试结果 (On Verilator)

 |             分支预测类型 |  总Tick数 | 总周期数      |   错误预测数 | 基准速度比 |
 | -----------------------: | --------: | ------------- | -----------: | ---------: |
 |               无分支预测 | `5292624` | `53336415000` | `         /` |   `1.000x` |
 |             静态分支预测 | `5011712` | `50501545000` | `    163426` |   `1.056x` |
 |  1-bit(4I  )动态分支预测 | `5035325` | `50730805000` | `    167403` |   `1.051x` |
 |  1-bit(8I  )动态分支预测 | `4998735` | `50371755000` | `    142873` |   `1.059x` |
 | GShare(8I1M)动态分支预测 | `4971079` | `50093755000` | `    120647` |   `1.065x` |
 | GShare(8I2M)动态分支预测 | `4975420` | `50139215000` | `    124155` |   `1.064x` |
 | GShare(8I4M)动态分支预测 | `4984823` | `50232025000` | `    130558` |   `1.062x` |
 | GShare(8I8M)动态分支预测 | `4993908` | `50323525000` | `    138736` |   `1.060x` |


## 后续工作

- [ ] 支持 Zifenci 扩展
- [ ] 补充 Zicfiss / Zicfilp 的负例测试（LPAD fault、SSPOPCHK mismatch 等）
- [ ] 支持非对齐访存
- [ ] ~~使用华莱士树乘法器优化乘法运算~~
- [ ] 优化流水线结构以提升性能
- [ ] 进行形式化验证  
