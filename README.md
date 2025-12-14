# EsCute 极简五级流水线RV32I实现


本分支在 LSU 的基础上，添加了[ascon_decrypt.sv](user/src/ascon_decrypt.sv)模块，用于加密指令的解密，增强安全性。

## 目录层级

```
EsCute-RV
├── .vscode
│  └── property.json            # DIDE配置文件
├── filelist.f                  # 工程文件列表
├── README.md                   # 项目说明文件
├── Makefile                    # 自动化测试用 Makefile 文件   
└── user
   ├── data ...
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
   │  ├── CSR.sv                # 控制状态寄存器模块    [FIXME] 未完成
   │  ├── Decoder.sv            # 指令译码模块
   │  ├── DRAM.sv               # 同步数据存储器模块
   │  ├── HazardUnit.sv         # 数据冒险处理模块
   │  ├── imm_extender.sv       # 立即数扩展模块
   │  ├── IROM.sv               # 指令存储器模块
   │  ├── LoadStoreUnit.sv      # 访存单元模块
   │  ├── MUL.sv                # 乘法运算模块          [FIXME] 未完成
   │  ├── NextPC_Generator.sv   # 下一条指令地址生成模块
   │  ├── ascon_decrypt.sv      # ASCON解密模块
   │  ├── PC.sv                 # 程序计数器模块
   │  ├── PR_IF_ID.sv           # IF/ID级  流水线寄存器模块
   │  ├── PR_ID_EX.sv           # ID/EX级  流水线寄存器模块
   │  ├── PR_EX_MEM.sv          # EX/MEM级 流水线寄存器模块
   │  ├── PR_MEM_WB.sv          # MEM/WB级 流水线寄存器模块
   │  └── RegisterF.sv          # 寄存器堆模块
   └── tools
      ├── clean.ps1              # 清理仿真生成文件脚本
      ├── riscv_converter.py     # 简单汇编代码转换为机器码脚本 无标签跳转
      ├── ascon_encrypt_hex.py   # hex 文件加密脚本
      └── regname_converter.py   # 寄存器名称转换脚本
```
