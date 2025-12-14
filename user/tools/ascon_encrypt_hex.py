#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ascon-AEAD128 指令流加密工具

将正常的RISC-V hex文件转换为使用Ascon-AEAD128加密的hex文件
用于EsCute-RV CPU的指令流加密功能

使用方法:
    python ascon_encrypt_hex.py <input.hex> <output.hex> [--key KEY] [--nonce NONCE]
    python ascon_encrypt_hex.py --auto [--input-dir DIR] [--output-dir DIR]

参数:
    input.hex   - 输入的普通hex文件
    output. hex  - 输出的加密hex文件
    --key       - 128位密钥 (十六进制, 默认: 0123456789ABCDEF0123456789ABCDEF)
    --nonce     - 128位随机数 (十六进制, 默认:  FEDCBA9876543210FEDCBA9876543210)
    --auto      - 自动处理模式，批量处理目录下的所有hex文件
    --skip-after-line - 跳过指定行之后的内容（不加密，用于DRAM数据区）
"""

import sys
import argparse
import os
from pathlib import Path
from typing import List, Tuple, Optional


class AsconStreamCipher:
    """
    Ascon流加密器
    与Verilog实现保持一致，使用简化的CTR模式
    """

    # Ascon轮常量
    RC = [
        0x00000000000000f0,
        0x00000000000000e1,
        0x00000000000000d2,
        0x00000000000000c3,
        0x00000000000000b4,
        0x00000000000000a5,
    ]

    def __init__(self, key: bytes, nonce: bytes):
        """
        初始化加密器

        Args:
            key: 16字节密钥
            nonce: 16字节随机数
        """
        if len(key) != 16:
            raise ValueError("密钥必须是16字节 (128位)")
        if len(nonce) != 16:
            raise ValueError("随机数必须是16字节 (128位)")

        self.key = key
        self. nonce = nonce

    @staticmethod
    def _rotr64(x: int, n: int) -> int:
        """64位右旋转"""
        x = x & 0xFFFFFFFFFFFFFFFF
        return ((x >> n) | (x << (64 - n))) & 0xFFFFFFFFFFFFFFFF

    def _ascon_round(self, state: List[int], rc: int) -> List[int]:
        """
        Ascon单轮置换

        Args:
            state: 5个64位状态字
            rc: 轮常量

        Returns:
            更新后的状态
        """
        s = [x & 0xFFFFFFFFFFFFFFFF for x in state]

        # 添加轮常量
        s[2] ^= rc

        # S-box层
        s[0] ^= s[4]
        s[4] ^= s[3]
        s[2] ^= s[1]

        t = [0] * 5
        for i in range(5):
            t[i] = (~s[i] & 0xFFFFFFFFFFFFFFFF) & s[(i + 1) % 5]

        for i in range(5):
            s[i] ^= t[(i + 1) % 5]

        s[1] ^= s[0]
        s[0] ^= s[4]
        s[3] ^= s[2]
        s[2] = (~s[2]) & 0xFFFFFFFFFFFFFFFF

        # 线性扩散层
        result = [0] * 5
        result[0] = s[0] ^ self._rotr64(s[0], 19) ^ self._rotr64(s[0], 28)
        result[1] = s[1] ^ self._rotr64(s[1], 61) ^ self._rotr64(s[1], 39)
        result[2] = s[2] ^ self._rotr64(s[2], 1) ^ self._rotr64(s[2], 6)
        result[3] = s[3] ^ self._rotr64(s[3], 10) ^ self._rotr64(s[3], 17)
        result[4] = s[4] ^ self._rotr64(s[4], 7) ^ self._rotr64(s[4], 41)

        return result

    def _generate_keystream(self, block_counter: int) -> int:
        """
        生成32位密钥流

        Args:
            block_counter: 块计数器 (基于PC/4)

        Returns:
            32位密钥流
        """
        # 将密钥和随机数转换为整数
        key_int = int.from_bytes(self.key, 'big')
        nonce_int = int.from_bytes(self.nonce, 'big')

        # 初始化混合状态 (与Verilog实现一致)
        state = [
            ((key_int >> 96) << 32) | (block_counter & 0xFFFFFFFF),  # KEY[127:96], block_counter
            (key_int >> 32) & 0xFFFFFFFFFFFFFFFF,                     # KEY[95:32]
            ((key_int & 0xFFFFFFFF) << 32) | ((nonce_int >> 96) & 0xFFFFFFFF),  # KEY[31:0], NONCE[127:96]
            (nonce_int >> 32) & 0xFFFFFFFFFFFFFFFF,                   # NONCE[95:32]
            ((nonce_int & 0xFFFFFFFF) << 32) | 0xDEADBEEF,            # NONCE[31:0], 0xDEADBEEF
        ]

        # 执行6轮Ascon置换
        for i in range(6):
            state = self._ascon_round(state, self.RC[i])

        # 从最终状态提取32位密钥流
        keystream = ((state[0] >> 32) ^ (state[1] & 0xFFFFFFFF)) & 0xFFFFFFFF

        return keystream

    def encrypt_word(self, plaintext: int, address: int) -> int:
        """
        加密单个32位字

        Args:
            plaintext: 32位明文
            address: 字节地址

        Returns:
            32位密文
        """
        block_counter = address >> 2  # 字地址
        keystream = self._generate_keystream(block_counter)
        return (plaintext ^ keystream) & 0xFFFFFFFF

    def decrypt_word(self, ciphertext: int, address: int) -> int:
        """
        解密单个32位字 (与加密相同，因为是XOR操作)

        Args:
            ciphertext: 32位密文
            address: 字节地址

        Returns:
            32位明文
        """
        return self.encrypt_word(ciphertext, address)


def hex_str_to_bytes(hex_str: str) -> bytes:
    """将十六进制字符串转换为字节"""
    return bytes.fromhex(hex_str)


def read_hex_file(filename: str) -> List[Tuple[int, int, int]]:
    """
    读取hex文件

    Args:
        filename: 文件路径

    Returns:
        列表，每个元素是 (行号, 地址, 指令) 元组
    """
    instructions = []
    address = 0
    line_number = 0

    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line_number += 1
            line = line.strip()
            if not line or line.startswith('//') or line.startswith('#'):
                continue

            # 处理地址注释 @address 格式
            if line.startswith('@'):
                try:
                    address = int(line[1:], 16) * 4  # 转换为字节地址
                    continue
                except ValueError:
                    continue

            try:
                instr = int(line, 16)
                instructions.append((line_number, address, instr))
                address += 4
            except ValueError:
                continue

    return instructions


def write_hex_file(filename: str, instructions: List[Tuple[int, int, int]],
                   include_header: bool = True,
                   skip_after_line: Optional[int] = None):
    """
    写入hex文件

    Args:
        filename: 文件路径
        instructions: 列表，每个元素是 (行号, 地址, 指令) 元组
        include_header: 是否包含头部注释
        skip_after_line: 跳过的起始行号（该行之后的内容不加密）
    """
    with open(filename, 'w', encoding='utf-8') as f:
        if include_header:
            f. write("// Encrypted instruction file generated by ascon_encrypt_hex. py\n")
            f.write("// Ascon-AEAD128 stream cipher encryption\n")
            f.write(f"// Total instructions: {len(instructions)}\n")
            if skip_after_line:
                f.write(f"// Lines after {skip_after_line} are NOT encrypted (DRAM data)\n")
            f.write("//\n")

        for line_num, addr, instr in instructions:
            f.write(f"{instr:08x}\n")


def encrypt_hex_file(input_file: str, output_file: str,
                     key: bytes, nonce: bytes,
                     skip_after_line: Optional[int] = None,
                     verbose: bool = False):
    """
    加密hex文件

    Args:
        input_file: 输入文件路径
        output_file: 输出文件路径
        key: 16字节密钥
        nonce: 16字节随机数
        skip_after_line: 跳过的起始行号（该行之后的内容不加密）
        verbose: 是否打印详细信息
    """
    cipher = AsconStreamCipher(key, nonce)

    # 读取输入文件
    instructions = read_hex_file(input_file)

    if verbose:
        print(f"读取 {len(instructions)} 条指令")
        print(f"密钥: {key.hex().upper()}")
        print(f"随机数: {nonce.hex().upper()}")
        if skip_after_line:
            print(f"跳过行:  {skip_after_line} 之后不加密")
        print()

    # 加密每条指令
    encrypted_instructions = []
    encrypted_count = 0
    skipped_count = 0

    for line_num, addr, plaintext in instructions:
        # 检查是否需要跳过（DRAM数据区）
        if skip_after_line and line_num >= skip_after_line:
            # 不加密，保持原样
            encrypted_instructions.append((line_num, addr, plaintext))
            skipped_count += 1

            if verbose:
                print(f"[行{line_num: 04d}] [0x{addr:04x}] 0x{plaintext:08x} -> 0x{plaintext:08x} (跳过)")
        else:
            # 加密
            ciphertext = cipher.encrypt_word(plaintext, addr)
            encrypted_instructions.append((line_num, addr, ciphertext))
            encrypted_count += 1

            if verbose:
                print(f"[行{line_num:04d}] [0x{addr:04x}] 0x{plaintext:08x} -> 0x{ciphertext:08x}")

    # 写入输出文件
    write_hex_file(output_file, encrypted_instructions,
                   include_header=True, skip_after_line=skip_after_line)

    if verbose or True:  # 总是显示统计信息
        print(f"\n加密完成!")
        print(f"输入文件:  {input_file}")
        print(f"输出文件:  {output_file}")
        print(f"总指令数: {len(encrypted_instructions)}")
        print(f"已加密: {encrypted_count} 条")
        print(f"已跳过: {skipped_count} 条 (DRAM数据)")

    return len(encrypted_instructions)


def decrypt_hex_file(input_file: str, output_file: str,
                     key: bytes, nonce: bytes,
                     skip_after_line: Optional[int] = None,
                     verbose: bool = False):
    """
    解密hex文件 (用于验证)

    Args:
        input_file: 输入文件路径 (加密的hex文件)
        output_file: 输出文件路径 (解密的hex文件)
        key: 16字节密钥
        nonce: 16字节随机数
        skip_after_line: 跳过的起始行号（该行之后的内容不解密）
        verbose: 是否打印详细信息
    """
    cipher = AsconStreamCipher(key, nonce)

    # 读取输入文件
    instructions = read_hex_file(input_file)

    if verbose:
        print(f"读取 {len(instructions)} 条加密指令")
        print(f"密钥: {key.hex().upper()}")
        print(f"随机数:  {nonce.hex().upper()}")
        if skip_after_line:
            print(f"跳过行: {skip_after_line} 之后不解密")
        print()

    # 解密每条指令
    decrypted_instructions = []
    for line_num, addr, ciphertext in instructions:
        # 检查是否需要跳过
        if skip_after_line and line_num >= skip_after_line:
            plaintext = ciphertext  # 不解密
        else:
            plaintext = cipher.decrypt_word(ciphertext, addr)

        decrypted_instructions.append((line_num, addr, plaintext))

        if verbose:
            print(f"[行{line_num:04d}] [0x{addr:04x}] 0x{ciphertext: 08x} -> 0x{plaintext:08x}")

    # 写入输出文件
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("// Decrypted instruction file\n")
        for line_num, addr, instr in decrypted_instructions:
            f.write(f"{instr:08x}\n")

    print(f"\n解密完成!")
    print(f"输入文件: {input_file}")
    print(f"输出文件: {output_file}")
    print(f"指令数量: {len(decrypted_instructions)}")


def auto_process_directory(input_dir: str, output_dir: str,
                           key: bytes, nonce: bytes,
                           decrypt_mode: bool = False,
                           skip_after_line: Optional[int] = None,
                           verbose: bool = False):
    """
    自动批量处理目录下的所有hex文件

    Args:
        input_dir: 输入目录路径
        output_dir: 输出目录路径
        key: 16字节密钥
        nonce: 16字节随机数
        decrypt_mode: 是否为解密模式
        skip_after_line: 跳过的起始行号（该行之后的内容不加密）
        verbose: 是否显示详细信息
    """
    # 解析路径 (支持相对路径)
    script_dir = Path(__file__).parent
    input_path = (script_dir / input_dir).resolve()
    output_path = (script_dir / output_dir).resolve()

    # 检查输入目录是否存在
    if not input_path.exists():
        print(f"错误: 输入目录不存在: {input_path}")
        print(f"尝试的完整路径: {input_path. absolute()}")
        return False

    if not input_path.is_dir():
        print(f"错误:  输入路径不是目录: {input_path}")
        return False

    # 创建输出目录 (如果不存在)
    output_path.mkdir(parents=True, exist_ok=True)

    # 查找所有 .hex 文件 (包括子目录)
    hex_files = list(input_path.rglob("*.hex"))

    if not hex_files:
        print(f"警告: 在目录 {input_path} 中没有找到 .hex 文件")
        print(f"尝试列出目录内容:")
        try:
            for item in input_path.iterdir():
                print(f"  - {item.name} {'(目录)' if item.is_dir() else '(文件)'}")
        except Exception as e:
            print(f"  无法列出目录: {e}")
        return False

    # 显示处理信息
    mode_str = "解密" if decrypt_mode else "加密"
    print(f"=== 自动批量{mode_str}模式 ===")
    print(f"脚本目录: {script_dir. absolute()}")
    print(f"输入目录: {input_path.absolute()}")
    print(f"输出目录:  {output_path.absolute()}")
    print(f"找到 {len(hex_files)} 个 hex 文件")
    print(f"密钥: {key.hex().upper()}")
    print(f"随机数: {nonce.hex().upper()}")
    if skip_after_line:
        print(f"跳过行: {skip_after_line} 之后不加密 (DRAM数据)")
    print()

    # 处理每个文件
    success_count = 0
    fail_count = 0

    for hex_file in hex_files:
        # 保持相对路径结构
        relative_path = hex_file.relative_to(input_path)
        output_file = output_path / relative_path

        # 创建输出文件的父目录
        output_file.parent.mkdir(parents=True, exist_ok=True)

        input_file_str = str(hex_file)
        output_file_str = str(output_file)

        try:
            print(f"正在处理: {relative_path} ...  ", end='', flush=True)

            if decrypt_mode:
                decrypt_hex_file(input_file_str, output_file_str, key, nonce,
                                 skip_after_line=skip_after_line, verbose=False)
                print(f"完成")
            else:
                instr_count = encrypt_hex_file(input_file_str, output_file_str, key, nonce,
                                               skip_after_line=skip_after_line, verbose=False)
                print(f"完成")

            success_count += 1

        except Exception as e:
            print(f"失败: {e}")
            fail_count += 1

    # 显示统计信息
    print()
    print("=" * 50)
    print(f"处理完成!")
    print(f"成功: {success_count} 个文件")
    print(f"失败: {fail_count} 个文件")
    print(f"总计: {len(hex_files)} 个文件")
    print("=" * 50)

    return fail_count == 0


def generate_verilog_params(key: bytes, nonce: bytes):
    """
    生成Verilog参数字符串

    Args:
        key: 16字节密钥
        nonce:  16字节随机数
    """
    key_hex = key.hex().upper()
    nonce_hex = nonce.hex().upper()

    print("// Verilog参数 (用于ascon_stream_decrypt模块)")
    print(f"parameter logic [127:0] KEY   = 128'h{key_hex};")
    print(f"parameter logic [127:0] NONCE = 128'h{nonce_hex};")


def self_test():
    """
    自测试函数
    验证加密/解密的正确性
    """
    print("=== Ascon流加密自测试 ===\n")

    key = bytes.fromhex("0123456789ABCDEF0123456789ABCDEF")
    nonce = bytes.fromhex("FEDCBA9876543210FEDCBA9876543210")

    cipher = AsconStreamCipher(key, nonce)

    # 测试几个不同地址的指令
    test_cases = [
        (0x00000000, 0x00500093),  # addi x1, x0, 5
        (0x00000004, 0x00300113),  # addi x2, x0, 3
        (0x00000008, 0x002081b3),  # add  x3, x1, x2
        (0x0000000C, 0x40208233),  # sub  x4, x1, x2
        (0x00000010, 0x0020f2b3),  # and  x5, x1, x2
    ]

    print("测试加密/解密循环:")
    all_passed = True

    for addr, plaintext in test_cases:
        ciphertext = cipher.encrypt_word(plaintext, addr)
        decrypted = cipher.decrypt_word(ciphertext, addr)

        status = "✓ PASS" if decrypted == plaintext else "✗ FAIL"
        if decrypted != plaintext:
            all_passed = False

        print(f"[0x{addr:04x}] 明文: 0x{plaintext:08x} -> "
              f"密文: 0x{ciphertext:08x} -> "
              f"解密: 0x{decrypted:08x} [{status}]")

    print()
    if all_passed:
        print("✓ 所有测试通过!")
    else:
        print("✗ 测试失败!")

    return all_passed


def main():
    parser = argparse.ArgumentParser(
        description='Ascon-AEAD128 指令流加密工具',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
示例:
  # 加密单个hex文件
  python ascon_encrypt_hex.py program.hex encrypted. hex

  # 使用自定义密钥
  python ascon_encrypt_hex.py -k 00112233445566778899AABBCCDDEEFF program.hex out.hex

  # 加密但跳过2049行之后的内容（DRAM数据）
  python ascon_encrypt_hex. py --skip-after-line 2049 program.hex encrypted.hex

  # 自动批量处理模式 (使用默认路径)
  python ascon_encrypt_hex.py --auto

  # 自动批量处理并跳过DRAM数据
  python ascon_encrypt_hex.py --auto --skip-after-line 2049

  # 自动批量处理模式 (指定路径)
  python ascon_encrypt_hex.py --auto --input-dir ../data/isa/hex --output-dir ../data/isa/encrypted

  # 解密验证单个文件
  python ascon_encrypt_hex.py -d encrypted.hex decrypted.hex

  # 批量解密
  python ascon_encrypt_hex.py --auto -d --input-dir ../data/isa/encrypted --output-dir ../data/isa/decrypted

  # 运行自测试
  python ascon_encrypt_hex.py --test

  # 生成Verilog参数
  python ascon_encrypt_hex.py --gen-params -k YOUR_KEY -n YOUR_NONCE
        """
    )

    parser.add_argument('input', nargs='?', help='输入hex文件')
    parser.add_argument('output', nargs='?', help='输出hex文件')
    parser.add_argument('-k', '--key',
                        default='0123456789ABCDEF0123456789ABCDEF',
                        help='128位密钥 (32字符十六进制)')
    parser.add_argument('-n', '--nonce',
                        default='FEDCBA9876543210FEDCBA9876543210',
                        help='128位随机数 (32字符十六进制)')
    parser.add_argument('-d', '--decrypt', action='store_true',
                        help='解密模式 (用于验证)')
    parser.add_argument('-v', '--verbose', action='store_true',
                        help='显示详细信息')
    parser.add_argument('--test', action='store_true',
                        help='运行自测试')
    parser.add_argument('--gen-params', action='store_true',
                        help='生成Verilog参数')
    parser.add_argument('--auto', action='store_true',
                        help='自动批量处理模式')
    parser.add_argument('--input-dir',
                        default='../data/isa/hex',
                        help='自动模式的输入目录 (默认: ../data/isa/hex)')
    parser.add_argument('--output-dir',
                        default='../data/isa/encrypted',
                        help='自动模式的输出目录 (默认: ../data/isa/encrypted)')
    parser.add_argument('--skip-after-line', type=int, default=2049,
                        help='跳过指定行之后的内容（不加密，用于DRAM数据区）')

    args = parser.parse_args()

    # 运行自测试
    if args.test:
        success = self_test()
        sys.exit(0 if success else 1)

    # 解析密钥和随机数
    try:
        key = hex_str_to_bytes(args.key. replace('0x', '').replace('0X', ''))
        nonce = hex_str_to_bytes(args.nonce.replace('0x', '').replace('0X', ''))
    except ValueError as e:
        print(f"错误: 无效的十六进制字符串 - {e}")
        sys.exit(1)

    # 生成Verilog参数
    if args.gen_params:
        generate_verilog_params(key, nonce)
        sys.exit(0)

    # 自动批量处理模式
    if args. auto:
        success = auto_process_directory(
            args.input_dir,
            args.output_dir,
            key,
            nonce,
            decrypt_mode=args.decrypt,
            skip_after_line=args.skip_after_line,
            verbose=args.verbose
        )
        sys.exit(0 if success else 1)

    # 单文件模式 - 检查文件参数
    if not args.input or not args.output:
        parser.print_help()
        sys.exit(1)

    # 执行加密或解密
    try:
        if args.decrypt:
            decrypt_hex_file(args.input, args.output, key, nonce,
                             skip_after_line=args.skip_after_line, verbose=args.verbose)
        else:
            encrypt_hex_file(args.input, args.output, key, nonce,
                             skip_after_line=args.skip_after_line, verbose=args.verbose)
    except FileNotFoundError as e:
        print(f"错误: 文件未找到 - {e}")
        sys.exit(1)
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
