# EsCute 极简五级流水线RV32I实现


本分支在Zmmul的基础上，添加了[CSR.sv](user/src/CSR.sv)模块，用于支持CSR相关指令以及常见的机器模式CSR寄存器读写，并移植了CoreMark基准测试以测试性能与验证完整性。

- [x] 实现RV32I指令集的五级流水线CPU  
- [x] 支持流水线停顿与数据前推  
- [x] 支持 Zmmul 扩展  
- [x] 支持基本的异常处理机制
- [x] 通过官方[riscv-tests](https://github.com/riscv-software-src/riscv-tests) RV32I_Zicsr_Zmmul验证（不含`ECALL`与`EBRAK`指令，不含非对齐访存相关指令，仅实现非对齐访存异常）
- [x] 通过Coremark基准测试


## 目录层级

```
EsCute-RV
├── .vscode
│  └── property.json            # DIDE配置文件
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
   │     ├── rv32mi             # 自动化测试用 汇编代码文件 （机器模式指令测试）
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

## CoreMark性能测试结果

```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 4598265
Total time (secs): 229
Iterations/Sec   : 0
Iterations       : 10
Compiler version : GCC15.1.0
Compiler flags   : -O2 -g -DPERFORMANCE_RUN=1  
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xfcaf
Correct operation validated. See README.md for run and reporting rules.
46317325000| [PASS] |  Finished  
```


## 后续工作

- [ ] 支持 Zifenci 扩展
- [ ] 支持分支预测与延迟槽  
- [ ] 支持非对齐访存
- [ ] 使用华莱士树乘法器优化乘法运算  
- [ ] 优化流水线结构以提升性能  
- [ ] 进行形式化验证  