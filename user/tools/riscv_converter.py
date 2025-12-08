#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
RISC-V 汇编与机器码转换工具
支持 RV32I 基础指令集的汇编和反汇编
"""

import sys
import re
from typing import Optional, Dict, List, Tuple
from enum import Enum


class InstType(Enum):
    """RISC-V指令类型"""
    R_TYPE = "R"
    I_TYPE = "I"
    S_TYPE = "S"
    B_TYPE = "B"
    U_TYPE = "U"
    J_TYPE = "J"


class Instruction:
    """指令信息类"""
    def __init__(self, name: str, inst_type: InstType, opcode: int, funct3: int = 0, funct7: int = 0):
        self.name = name
        self.type = inst_type
        self.opcode = opcode
        self.funct3 = funct3
        self.funct7 = funct7


# RISC-V RV32I 基础指令集
INSTRUCTIONS = [
    # R-type
    Instruction("add", InstType.R_TYPE, 0x33, 0x0, 0x00),
    Instruction("sub", InstType.R_TYPE, 0x33, 0x0, 0x20),
    Instruction("sll", InstType.R_TYPE, 0x33, 0x1, 0x00),
    Instruction("slt", InstType.R_TYPE, 0x33, 0x2, 0x00),
    Instruction("sltu", InstType.R_TYPE, 0x33, 0x3, 0x00),
    Instruction("xor", InstType.R_TYPE, 0x33, 0x4, 0x00),
    Instruction("srl", InstType.R_TYPE, 0x33, 0x5, 0x00),
    Instruction("sra", InstType.R_TYPE, 0x33, 0x5, 0x20),
    Instruction("or", InstType.R_TYPE, 0x33, 0x6, 0x00),
    Instruction("and", InstType.R_TYPE, 0x33, 0x7, 0x00),
    
    # I-type (算术/逻辑)
    Instruction("addi", InstType.I_TYPE, 0x13, 0x0, 0x00),
    Instruction("slti", InstType.I_TYPE, 0x13, 0x2, 0x00),
    Instruction("sltiu", InstType.I_TYPE, 0x13, 0x3, 0x00),
    Instruction("xori", InstType.I_TYPE, 0x13, 0x4, 0x00),
    Instruction("ori", InstType.I_TYPE, 0x13, 0x6, 0x00),
    Instruction("andi", InstType.I_TYPE, 0x13, 0x7, 0x00),
    Instruction("slli", InstType.I_TYPE, 0x13, 0x1, 0x00),
    Instruction("srli", InstType.I_TYPE, 0x13, 0x5, 0x00),
    Instruction("srai", InstType.I_TYPE, 0x13, 0x5, 0x20),
    
    # I-type (load)
    Instruction("lb", InstType.I_TYPE, 0x03, 0x0, 0x00),
    Instruction("lh", InstType.I_TYPE, 0x03, 0x1, 0x00),
    Instruction("lw", InstType.I_TYPE, 0x03, 0x2, 0x00),
    Instruction("lbu", InstType.I_TYPE, 0x03, 0x4, 0x00),
    Instruction("lhu", InstType.I_TYPE, 0x03, 0x5, 0x00),
    
    # I-type (jalr)
    Instruction("jalr", InstType.I_TYPE, 0x67, 0x0, 0x00),
    
    # S-type
    Instruction("sb", InstType.S_TYPE, 0x23, 0x0, 0x00),
    Instruction("sh", InstType.S_TYPE, 0x23, 0x1, 0x00),
    Instruction("sw", InstType.S_TYPE, 0x23, 0x2, 0x00),
    
    # B-type
    Instruction("beq", InstType.B_TYPE, 0x63, 0x0, 0x00),
    Instruction("bne", InstType.B_TYPE, 0x63, 0x1, 0x00),
    Instruction("blt", InstType.B_TYPE, 0x63, 0x4, 0x00),
    Instruction("bge", InstType.B_TYPE, 0x63, 0x5, 0x00),
    Instruction("bltu", InstType.B_TYPE, 0x63, 0x6, 0x00),
    Instruction("bgeu", InstType.B_TYPE, 0x63, 0x7, 0x00),
    
    # U-type
    Instruction("lui", InstType.U_TYPE, 0x37, 0x0, 0x00),
    Instruction("auipc", InstType.U_TYPE, 0x17, 0x0, 0x00),
    
    # J-type
    Instruction("jal", InstType.J_TYPE, 0x6F, 0x0, 0x00),
]

# 创建指令查找字典
INST_BY_NAME: Dict[str, Instruction] = {inst.name: inst for inst in INSTRUCTIONS}

# 寄存器ABI名称映射
REG_NAMES = [
    "zero", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
    "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
    "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
    "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
]

REG_NAME_TO_NUM: Dict[str, int] = {name: i for i, name in enumerate(REG_NAMES)}


def get_reg_num(reg_str: str) -> int:
    """获取寄存器编号"""
    reg_str = reg_str.strip()
    
    # 处理 x0-x31 格式
    if reg_str.startswith('x'):
        try:
            return int(reg_str[1:])
        except ValueError:
            return -1
    
    # 处理寄存器ABI名称
    return REG_NAME_TO_NUM.get(reg_str, -1)


def parse_immediate(imm_str: str) -> int:
    """解析立即数（支持十进制和十六进制）"""
    imm_str = imm_str.strip()
    try:
        if imm_str.startswith(('0x', '0X')):
            return int(imm_str, 16)
        return int(imm_str)
    except ValueError:
        return 0


def sign_extend(value: int, bits: int) -> int:
    """符号扩展"""
    sign_bit = 1 << (bits - 1)
    if value & sign_bit:
        return value | (~((1 << bits) - 1))
    return value


def asm_to_hex(asm_line: str) -> Optional[int]:
    """将汇编指令转换为机器码"""
    # 移除注释
    if '#' in asm_line:
        asm_line = asm_line[:asm_line.index('#')]
    
    # 去除空白
    asm_line = asm_line.strip()
    if not asm_line:
        return None
    
    # 解析指令
    parts = asm_line.split()
    if not parts:
        return None
    
    inst_name = parts[0].lower()
    
    # 特殊处理 nop 伪指令 (nop = addi x0, x0, 0)
    if inst_name == 'nop':
        return 0x00000013
    
    inst = INST_BY_NAME.get(inst_name)
    
    if not inst:
        return None
    
    try:
        # 解析操作数
        if len(parts) > 1:
            operands = ' '.join(parts[1:])
        else:
            return None
        
        if inst.type == InstType.R_TYPE:
            # 格式: add rd, rs1, rs2
            match = re.match(r'(\w+)\s*,\s*(\w+)\s*,\s*(\w+)', operands)
            if not match:
                return None
            rd = get_reg_num(match.group(1))
            rs1 = get_reg_num(match.group(2))
            rs2 = get_reg_num(match.group(3))
            
            # 检查是否所有寄存器都有效
            if rd < 0 or rs1 < 0 or rs2 < 0:
                return None
            
            machine_code = (inst.funct7 << 25) | (rs2 << 20) | (rs1 << 15) | \
                          (inst.funct3 << 12) | (rd << 7) | inst.opcode
            return machine_code
        
        elif inst.type == InstType.I_TYPE:
            if inst.opcode == 0x03 or inst.opcode == 0x67:  # Load instructions or jalr
                # 格式: lw rd, offset(rs1) 或 jalr rd, offset(rs1)
                match = re.match(r'(\w+)\s*,\s*(-?\w+)\s*\(\s*(\w+)\s*\)', operands)
                if not match:
                    return None
                rd = get_reg_num(match.group(1))
                offset = parse_immediate(match.group(2))
                rs1 = get_reg_num(match.group(3))
                
                imm = offset & 0xFFF
                machine_code = (imm << 20) | (rs1 << 15) | (inst.funct3 << 12) | \
                              (rd << 7) | inst.opcode
                return machine_code
            
            else:
                # 格式: addi rd, rs1, imm
                match = re.match(r'(\w+)\s*,\s*(\w+)\s*,\s*(-?\w+)', operands)
                if not match:
                    return None
                rd = get_reg_num(match.group(1))
                rs1 = get_reg_num(match.group(2))
                imm = parse_immediate(match.group(3))
                
                if inst_name in ['slli', 'srli', 'srai']:
                    # 移位指令特殊处理
                    shamt = imm & 0x1F
                    machine_code = (inst.funct7 << 25) | (shamt << 20) | (rs1 << 15) | \
                                  (inst.funct3 << 12) | (rd << 7) | inst.opcode
                else:
                    imm = imm & 0xFFF
                    machine_code = (imm << 20) | (rs1 << 15) | (inst.funct3 << 12) | \
                                  (rd << 7) | inst.opcode
                return machine_code
        
        elif inst.type == InstType.S_TYPE:
            # 格式: sw rs2, offset(rs1)
            match = re.match(r'(\w+)\s*,\s*(-?\w+)\s*\(\s*(\w+)\s*\)', operands)
            if not match:
                return None
            rs2 = get_reg_num(match.group(1))
            offset = parse_immediate(match.group(2))
            rs1 = get_reg_num(match.group(3))
            
            imm_11_5 = (offset >> 5) & 0x7F
            imm_4_0 = offset & 0x1F
            machine_code = (imm_11_5 << 25) | (rs2 << 20) | (rs1 << 15) | \
                          (inst.funct3 << 12) | (imm_4_0 << 7) | inst.opcode
            return machine_code
        
        elif inst.type == InstType.B_TYPE:
            # 格式: beq rs1, rs2, offset
            match = re.match(r'(\w+)\s*,\s*(\w+)\s*,\s*(-?\w+)', operands)
            if not match:
                return None
            rs1 = get_reg_num(match.group(1))
            rs2 = get_reg_num(match.group(2))
            offset = parse_immediate(match.group(3))
            
            imm_12 = (offset >> 12) & 0x1
            imm_10_5 = (offset >> 5) & 0x3F
            imm_4_1 = (offset >> 1) & 0xF
            imm_11 = (offset >> 11) & 0x1
            
            machine_code = (imm_12 << 31) | (imm_10_5 << 25) | (rs2 << 20) | \
                          (rs1 << 15) | (inst.funct3 << 12) | (imm_4_1 << 8) | \
                          (imm_11 << 7) | inst.opcode
            return machine_code
        
        elif inst.type == InstType.U_TYPE:
            # 格式: lui rd, imm
            match = re.match(r'(\w+)\s*,\s*(-?\w+)', operands)
            if not match:
                return None
            rd = get_reg_num(match.group(1))
            imm = parse_immediate(match.group(2))
            
            # U型指令的立即数是高20位，需要左移12位放到[31:12]
            machine_code = ((imm & 0xFFFFF) << 12) | (rd << 7) | inst.opcode
            return machine_code
        
        elif inst.type == InstType.J_TYPE:
            # 格式: jal rd, offset
            match = re.match(r'(\w+)\s*,\s*(-?\w+)', operands)
            if not match:
                return None
            rd = get_reg_num(match.group(1))
            offset = parse_immediate(match.group(2))
            
            imm_20 = (offset >> 20) & 0x1
            imm_10_1 = (offset >> 1) & 0x3FF
            imm_11 = (offset >> 11) & 0x1
            imm_19_12 = (offset >> 12) & 0xFF
            
            machine_code = (imm_20 << 31) | (imm_10_1 << 21) | (imm_11 << 20) | \
                          (imm_19_12 << 12) | (rd << 7) | inst.opcode
            return machine_code
    
    except Exception as e:
        print(f"解析错误: {e}")
        return None
    
    return None


def hex_to_asm(machine_code: int, aligned: bool = True) -> str:
    """将机器码反汇编为汇编指令"""
    opcode = machine_code & 0x7F
    rd = (machine_code >> 7) & 0x1F
    funct3 = (machine_code >> 12) & 0x7
    rs1 = (machine_code >> 15) & 0x1F
    rs2 = (machine_code >> 20) & 0x1F
    funct7 = (machine_code >> 25) & 0x7F
    
    # 查找匹配的指令
    inst = None
    for instruction in INSTRUCTIONS:
        if instruction.opcode == opcode:
            if instruction.type == InstType.R_TYPE:
                if instruction.funct3 == funct3 and instruction.funct7 == funct7:
                    inst = instruction
                    break
            elif instruction.type in [InstType.U_TYPE, InstType.J_TYPE]:
                # U型和J型指令只需要匹配opcode
                inst = instruction
                break
            elif instruction.funct3 == funct3:
                inst = instruction
                break
    
    if not inst:
        return "unknown"
    
    try:
        if inst.type == InstType.R_TYPE:
            if aligned:
                return f"{inst.name:<6} x{rd:<2}, x{rs1:<2}, x{rs2}"
            else:
                return f"{inst.name} x{rd}, x{rs1}, x{rs2}"
        
        elif inst.type == InstType.I_TYPE:
            imm = sign_extend((machine_code >> 20) & 0xFFF, 12)
            
            # 特殊处理 nop 伪指令 (addi x0, x0, 0)
            if inst.name == 'addi' and rd == 0 and rs1 == 0 and imm == 0:
                return 'nop'
            
            if inst.opcode == 0x03 or inst.opcode == 0x67:  # Load or jalr
                if aligned:
                    return f"{inst.name:<6} x{rd:<2}, {imm:4}(x{rs1})"
                else:
                    return f"{inst.name} x{rd}, {imm}(x{rs1})"
            elif inst.name in ['slli', 'srli', 'srai']:
                shamt = rs2  # 对于移位指令，shamt在rs2位置
                if aligned:
                    return f"{inst.name:<6} x{rd:<2}, x{rs1:<2}, {shamt}"
                else:
                    return f"{inst.name} x{rd}, x{rs1}, {shamt}"
            else:
                if aligned:
                    return f"{inst.name:<6} x{rd:<2}, x{rs1:<2}, {imm:5}"
                else:
                    return f"{inst.name} x{rd}, x{rs1}, {imm}"
        
        elif inst.type == InstType.S_TYPE:
            imm = sign_extend(((funct7 << 5) | rd), 12)
            if aligned:
                return f"{inst.name:<6} x{rs2:<2}, {imm:4}(x{rs1})"
            else:
                return f"{inst.name} x{rs2}, {imm}(x{rs1})"
        
        elif inst.type == InstType.B_TYPE:
            imm_12 = (machine_code >> 31) & 0x1
            imm_11 = (machine_code >> 7) & 0x1
            imm_10_5 = (machine_code >> 25) & 0x3F
            imm_4_1 = (machine_code >> 8) & 0xF
            
            imm = (imm_12 << 12) | (imm_11 << 11) | (imm_10_5 << 5) | (imm_4_1 << 1)
            imm = sign_extend(imm, 13)
            if aligned:
                return f"{inst.name:<6} x{rs1:<2}, x{rs2:<2}, {imm:5}"
            else:
                return f"{inst.name} x{rs1}, x{rs2}, {imm}"
        
        elif inst.type == InstType.U_TYPE:
            imm = (machine_code >> 12) & 0xFFFFF
            if aligned:
                return f"{inst.name:<6} x{rd:<2}, 0x{imm:05x}"
            else:
                return f"{inst.name} x{rd}, 0x{imm:x}"
        
        elif inst.type == InstType.J_TYPE:
            imm_20 = (machine_code >> 31) & 0x1
            imm_19_12 = (machine_code >> 12) & 0xFF
            imm_11 = (machine_code >> 20) & 0x1
            imm_10_1 = (machine_code >> 21) & 0x3FF
            
            imm = (imm_20 << 20) | (imm_19_12 << 12) | (imm_11 << 11) | (imm_10_1 << 1)
            imm = sign_extend(imm, 21)
            if aligned:
                return f"{inst.name:<6} x{rd:<2}, {imm:>10}"
            else:
                return f"{inst.name} x{rd}, {imm}"
    
    except Exception as e:
        return f"error: {e}"
    
    return "unknown"


def asm_file_to_hex(input_file: str, output_file: str):
    """将汇编文件转换为hex文件"""
    try:
        with open(input_file, 'r', encoding='utf-8') as fin:
            lines = fin.readlines()
        
        with open(output_file, 'w', encoding='utf-8') as fout:
            count = 0
            for line in lines:
                hex_code = asm_to_hex(line)
                if hex_code is not None:
                    fout.write(f"{hex_code:08x}\n")
                    count += 1
        
        print(f"成功转换 {count} 条指令到 {output_file}")
    
    except FileNotFoundError:
        print(f"错误: 无法打开输入文件 {input_file}")
    except Exception as e:
        print(f"错误: {e}")


def hex_file_to_asm(input_file: str, output_file: str, aligned: bool = True):
    """将hex文件转换为汇编文件"""
    try:
        with open(input_file, 'r', encoding='utf-8') as fin:
            lines = fin.readlines()
        
        with open(output_file, 'w', encoding='utf-8') as fout:
            count = 0
            pc = 0
            for line in lines:
                line = line.strip()
                if not line:
                    continue
                try:
                    hex_code = int(line, 16)
                    asm_str = hex_to_asm(hex_code, aligned)
                    fout.write(f"[0x{pc:04x}]  {hex_code:08x}    {asm_str}\n")
                    count += 1
                    pc += 4
                except ValueError:
                    continue
        
        print(f"成功转换 {count} 条指令到 {output_file}")
    
    except FileNotFoundError:
        print(f"错误: 无法打开输入文件 {input_file}")
    except Exception as e:
        print(f"错误: {e}")


def interactive_mode():
    """交互模式"""
    print("RISC-V 转换工具 - 交互模式")
    print("输入 'q' 退出, 'm' 切换模式\n")
    
    print("选择模式:")
    print("1. 汇编 -> hex")
    print("2. hex -> 汇编")
    choice = input("选择: ").strip()
    
    if choice == '1':
        mode = 'asm2hex'
        print("\n汇编 -> hex 模式")
        print("输入汇编指令 (例: addi x1, x0, 5)")
        print("输入 'q' 退出, 'm' 切换模式\n")
    elif choice == '2':
        mode = 'hex2asm'
        print("\nhex -> 汇编 模式")
        print("输入hex (例: 00500093)")
        print("输入 'q' 退出, 'm' 切换模式\n")
    else:
        print("无效选择\n")
        return
    
    while True:
        if mode == 'asm2hex':
            user_input = input("汇编 > ").strip()
            if user_input.lower() == 'q':
                break
            elif user_input.lower() == 'm':
                mode = 'hex2asm'
                print("\n切换到 hex -> 汇编 模式")
                print("输入hex (例: 00500093)")
                print("输入 'q' 退出, 'm' 切换模式\n")
                continue
            
            hex_code = asm_to_hex(user_input)
            if hex_code is not None:
                print(f"  -> {hex_code:08x}\n")
            else:
                print("  -> 无法解析该指令\n")
        
        elif mode == 'hex2asm':
            user_input = input("hex > ").strip()
            if user_input.lower() == 'q':
                break
            elif user_input.lower() == 'm':
                mode = 'asm2hex'
                print("\n切换到 汇编 -> hex 模式")
                print("输入汇编指令 (例: addi x1, x0, 5)")
                print("输入 'q' 退出, 'm' 切换模式\n")
                continue
            
            try:
                hex_code = int(user_input, 16)
                asm_str = hex_to_asm(hex_code, aligned=False)
                print(f"  -> {asm_str}\n")
            except ValueError:
                print("  -> 无效的hex格式\n")


def print_usage():
    """打印使用说明"""
    print("RISC-V 汇编与机器码转换工具")
    print("\n用法:")
    print("  汇编转hex: python riscv_converter.py -a2h <input.asm> <output.hex>")
    print("  hex转汇编: python riscv_converter.py -h2a <input.hex> <output.asm>")
    print("  交互模式:   python riscv_converter.py -i")
    print("\n示例:")
    print("  python riscv_converter.py -a2h program.asm program.hex")
    print("  python riscv_converter.py -h2a test_program.hex output.asm")
    print("  python riscv_converter.py -i")


def main():
    """主函数"""
    if len(sys.argv) < 2:
        print_usage()
        sys.exit(1)

    mode = sys.argv[1]

    # 检查是否启用自动路径前缀模式
    use_auto_dir = False
    asm_dir_prefix = '..\\data\\asm\\'
    hex_dir_prefix = '..\\data\\hex\\'
    if '--auto-dir' in sys.argv:
        use_auto_dir = True
        sys.argv.remove('--auto-dir')

    def get_a2h_in_path(path):
        if use_auto_dir:
            return asm_dir_prefix + path
        else:
            return path

    def get_a2h_out_path(path):
        if use_auto_dir:
            return hex_dir_prefix + path
        else:
            return path

    def get_h2a_in_path(path):
        if use_auto_dir:
            return hex_dir_prefix + path
        else:
            return path

    def get_h2a_out_path(path):
        if use_auto_dir:
            return asm_dir_prefix + path
        else:
            return path

    if mode == '-i':
        interactive_mode()
    elif mode == '-a2h' and len(sys.argv) == 4:
        asm_file_to_hex(get_a2h_in_path(sys.argv[2]), get_a2h_out_path(sys.argv[3]))
    elif mode == '-h2a' and len(sys.argv) == 4:
        hex_file_to_asm(get_h2a_in_path(sys.argv[2]), get_h2a_out_path(sys.argv[3]))
    else:
        print_usage()
        sys.exit(1)


if __name__ == '__main__':
    main()
