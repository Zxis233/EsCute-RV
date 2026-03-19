# EsCute 极简五级流水线RV32I实现


本分支在 Zmmul 的基础上，补充了 [CSR.sv](user/src/CSR.sv) 模块与基础特权级支持，用于实现 CSR 相关指令、基本的 U/S/M-Mode，以及 Zicfiss / Zicfilp 控制流完整性扩展，并移植了 CoreMark 基准测试以测试性能与验证完整性。

- [x] 实现RV32I指令集的五级流水线CPU  
- [x] 支持流水线停顿与数据前推  
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
│  └── property.json            # DIDE配置文件
├── CFI_Instruction.md          # Zicfiss / Zicfilp 实现说明
├── filelist.f                  # 工程文件列表
├── README.md                   # 项目说明文件
├── Makefile                    # 自动化测试用 Makefile 文件   
├── coremark                    # CoreMark基准测试文件夹
│  ├── Makefile                 # CoreMark基准测试 Makefile 文件
│  └── escute
│     ├── soft_div.c            # 软件除法函数实现文件
│     ├── core_portme.c         # CoreMark平台相关函数实现文件
│     ├── core_portme.h         # CoreMark平台相关函数声明文件
│     ├── ee_printf.h           # CoreMark打印函数声明文件
│     └── core_portme.mak       # CoreMark平台相关Makefile文件
└── user
   ├── data
   │  └── isa                   # riscv-tests指令集测试
   │     ├── env                # 测试用环境文件
   │     │  ├── encoding.h
   │     │  ├── link.ld         # 测试用链接脚本文件
   │     │  ├── riscv_test.h
   │     │  └── test_macros.h   # 自动化测试用 宏定义文件
   │     ├── generated          # 测试样例二进制文件与反编译文件
   │     ├── hex                # 自动化测试用 机器码文件
   │     ├── Makefile           # 自动化测试用 测试样例生成 Makefile
   │     ├── rv32ui             # 自动化测试用 汇编代码文件
   │     ├── rv64ui             # 自动化测试用 汇编代码文件
   │     ├── rv32mi             # 自动化测试用 汇编代码文件 （机器模式指令测试，含 zicfi.S）
   │     ├── rv64mi             # 自动化测试用 汇编代码文件 （机器模式指令测试）
   │     ├── test_tb.sv         # 自动化测试用 顶层仿真文件
   │     └── verilog            # 自动化测试用 Verilog 反编译内存文件
   ├── sim
   │  ├── simple_counter.sv     # 简单计数器测试模块 用于测试环境是否正确
   │  ├── tb_CPU_TOP.sv         # 顶层CPU仿真文件
   │  ├── tb_ALU.sv             # ALU模块测试文件
   │  ├── tb_Decoder.sv         # Decoder模块测试文件
   │  ├── tb_DRAM.sv            # DRAM模块测试文件 
   │  ├── tb_imm_extender.sv    # 立即数扩展模块测试文件
   │  ├── tb_PC.sv              # PC模块测试文件
   │  ├── tb_RegisterF.sv       # 寄存器堆模块测试文件
   │  ├── tb_Zicfi.sv           # Zicfiss / Zicfilp 定向测试
   │  └── tb_simple_counter.sv  # 简单计数器测试文件
   ├── src
   │  ├── include
   │  │  └── defines.svh        # 全局宏定义文件
   │  ├── Makefile              # 仿真用Makefile
   │  ├── ALU.sv                # 算术逻辑单元模块
   │  ├── CPU_TOP.sv            # CPU顶层模块
   │  ├── CSR.sv                # 控制状态寄存器模块
   │  ├── Decoder.sv            # 指令译码模块
   │  ├── DRAM.sv               # 同步数据存储器模块
   │  ├── HazardUnit.sv         # 数据冒险处理模块
   │  ├── imm_extender.sv       # 立即数扩展模块
   │  ├── IROM.sv               # 指令存储器模块
   │  ├── LoadUnit.sv           # 读取单元模块
   │  ├── StoreUnit.sv          # 存储单元模块
   │  ├── MUL.sv                # 乘法运算模块
   │  ├── NextPC_Generator.sv   # 下一条指令地址生成模块
   │  ├── PC.sv                 # 程序计数器模块
   │  ├── PR_IF_ID.sv           # IF/ID级  流水线寄存器模块
   │  ├── PR_ID_EX.sv           # ID/EX级  流水线寄存器模块
   │  ├── PR_EX_MEM.sv          # EX/MEM级 流水线寄存器模块
   │  ├── PR_MEM_WB.sv          # MEM/WB级 流水线寄存器模块
   │  └── RegisterF.sv          # 双端口寄存器堆模块
   └── tools
      ├── clean.ps1              # 清理仿真生成文件脚本
      ├── riscv_converter.py     # 简单汇编代码转换为机器码脚本 无标签跳转
      └── regname_converter.py   # 寄存器名称转换脚本
```

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

如果只想快速验证 RTL，也可以直接跑定向测试台：

```bash
iverilog -g2012 -Wall -s tb_Zicfi -I user/src -I user/src/include -o prj/run/tb_zicfi.vvp user/sim/tb_Zicfi.sv user/src/*.sv
vvp prj/run/tb_zicfi.vvp
```

## CoreMark性能测试结果

```
_end=0x000030c0 stack_top=0x0000ff00 sp=0x0000f6a0
Now Time: 0x00000000000004d7
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 5184678
Total time (secs): 10
Iterations/Sec   : 1
Iterations       : 10
Compiler version : GCC15.2.0
Compiler flags   : -O2 -g -DPERFORMANCE_RUN=1  
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xfcaf
Correct operation validated. See README.md for run and reporting rules.
Now Time: 0x00000000004fb6cc
52248755000| [PASS] |  Finished
```


## 后续工作

- [ ] 支持 Zifenci 扩展
- [ ] 补充 Zicfiss / Zicfilp 的负例测试（LPAD fault、SSPOPCHK mismatch 等）
- [ ] 支持分支预测与延迟槽  
- [ ] 支持非对齐访存
- [ ] 使用华莱士树乘法器优化乘法运算  
- [ ] 优化流水线结构以提升性能  
- [ ] 进行形式化验证  
