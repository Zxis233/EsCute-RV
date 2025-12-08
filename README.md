# EsCute 极简五级流水线RV32I实现


本分支在主分支的基础上，将同步读异步写的DRAM更换为同步读写的DRAM，以适配部分FPGA的Block RAM，便于综合。

- [x] 实现RV32I指令集的五级流水线CPU  
- [x] 支持流水线停顿与数据前推  


## 部署方法

VSCode安装DIDE插件打开本工程后，会自动在user文件夹下生成data、sim、src三个子文件夹。等待分析完成即可。

最好使用Xilinx Vivado自带的`xvlog`作为主linter，`verible-verilog-linter`作为副linter。

## 目录层级

```
EsCute-RV
├── .vscode
│  └── property.json            # DIDE配置文件
├── filelist.f                  # 工程文件列表
├── README.md                   # 项目说明文件
└── user
   ├── data
   │  ├── asm
   │  │  └── Your.S             # 放置你的汇编文件
   │  └── hex
   │     └── Your.hex           # 放置你的数据文件
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
   │  ├── LoadStoreUnit.sv      # 访存单元模块          [FIXME] 未完成
   │  ├── MUL.sv                # 乘法运算模块          [FIXME] 未完成
   │  ├── NextPC_Generator.sv   # 下一条指令地址生成模块
   │  ├── PC.sv                 # 程序计数器模块
   │  ├── PR_IF_ID.sv           # IF/ID级  流水线寄存器模块
   │  ├── PR_ID_EX.sv           # ID/EX级  流水线寄存器模块
   │  ├── PR_EX_MEM.sv          # EX/MEM级 流水线寄存器模块
   │  ├── PR_MEM_WB.sv          # MEM/WB级 流水线寄存器模块
   │  └── RegisterF.sv          # 寄存器堆模块
   └── tools
     ├── clean.ps1              # 清理仿真生成文件脚本
     └── riscv_converter.py     # 简单汇编代码转换为机器码脚本 无标签跳转
```


## 后续工作

- [ ] 支持非对齐访存  
- [ ] 支持分支预测与延迟槽  
- [ ] 支持基本中断处理机制  
- [ ] 支持 M 扩展  
- [ ] 使用华莱士树乘法器优化乘法运算  
- [ ] 支持 Zicsr 扩展  
- [ ] 优化流水线结构以提升性能  
- [ ] 进行形式化验证  