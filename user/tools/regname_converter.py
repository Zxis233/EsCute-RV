#!/usr/bin/env python3
"""
convert_riscv_regs.py

将 RISC-V 反汇编文本中的 ABI 寄存器名（例如 a0..a7, t0..t6, s0..s11, gp, sp, ra, tp, zero, fp）
替换为对应的 xN 形式（例如 x10..x17, x5..x7/x28..x31, x8..x27, x3, x2, x1, x4, x0, x8）。

改动点：
- 不再替换紧随冒号的标识符（例如 "a0:"、"a4:"）——这些通常是标签，不是寄存器使用。
  实现方式：在正则中加入负向前瞻 (?!:)，确保匹配的寄存器名后面不是 ":"。
- 仍然使用单词边界匹配，避免修改地址或十六进制字面量。

用法同之前说明（支持从文件或 stdin 读取，支持 --inplace、-o/--output 等）。
"""

import re
import sys
import argparse
from pathlib import Path

# ABI 名称 -> xN 映射
ABI_TO_X = {
    "zero": "x0",
    "ra": "x1",
    "sp": "x2",
    "gp": "x3",
    "tp": "x4",
    "t0": "x5",
    "t1": "x6",
    "t2": "x7",
    "s0": "x8",
    "fp": "x8",
    "s1": "x9",
    "a0": "x10",
    "a1": "x11",
    "a2": "x12",
    "a3": "x13",
    "a4": "x14",
    "a5": "x15",
    "a6": "x16",
    "a7": "x17",
    "s2": "x18",
    "s3": "x19",
    "s4": "x20",
    "s5": "x21",
    "s6": "x22",
    "s7": "x23",
    "s8": "x24",
    "s9": "x25",
    "s10": "x26",
    "s11": "x27",
    "t3": "x28",
    "t4": "x29",
    "t5": "x30",
    "t6": "x31",
}

# 按键长度降序排序构造正则，避免部分匹配冲突（例如 s10 与 s1）
abi_names_sorted = sorted(ABI_TO_X.keys(), key=lambda s: -len(s))

# 正则：
#  - \b(...)\b : 匹配完整单词（寄存器名）
#  - (?!:)     : 确保单词后面不是冒号（即跳过像 "a0:" 这样的标签）
pattern = re.compile(r'\b(' + '|'.join(re.escape(name) for name in abi_names_sorted) + r')\b(?!:)')

def replace_regs(text: str) -> str:
    """
    在文本中把 ABI 寄存器名替换为 xN，返回替换后的文本。
    跳过后面紧跟 ':' 的标识符（标签）。
    """
    def repl(match: re.Match) -> str:
        name = match.group(1)
        return ABI_TO_X.get(name, name)
    return pattern.sub(repl, text)

def process_stream(in_stream, out_stream):
    for line in in_stream:
        out_stream.write(replace_regs(line))

def main(argv):
    parser = argparse.ArgumentParser(description="Replace RISC-V ABI register names with xN form.")
    parser.add_argument('inputs', nargs='*', help="Input file(s). Use '-' or omit to read from stdin.")
    parser.add_argument('-o', '--output', help="Write output to this file (only valid when one input or reading from stdin).")
    parser.add_argument('--inplace', action='store_true', help="Modify files in place. If set, inputs must be one or more real files (not '-')")
    args = parser.parse_args(argv)

    inputs = args.inputs or ['-']

    if args.inplace and args.output:
        parser.error("Can't use --inplace and --output together.")

    if args.inplace:
        # In-place modify each file
        for fname in inputs:
            if fname == '-':
                parser.error("Cannot use '-' with --inplace")
            p = Path(fname)
            if not p.is_file():
                parser.error(f"Input file not found: {fname}")
            text = p.read_text(encoding='utf-8')
            new_text = replace_regs(text)
            p.write_text(new_text, encoding='utf-8')
        return 0

    # If output specified, only allow single input or '-'
    if args.output:
        if len(inputs) > 1 and inputs[0] != '-':
            parser.error("When using -o/--output, provide only one input file or read from stdin ('-').")
        # determine input stream
        if inputs[0] == '-':
            in_stream = sys.stdin
        else:
            in_stream = open(inputs[0], 'r', encoding='utf-8')
        with in_stream:
            out_path = Path(args.output)
            out_path.write_text(replace_regs(in_stream.read()), encoding='utf-8')
        return 0

    # No output file, write to stdout. If multiple input files, concatenate outputs.
    out_stream = sys.stdout
    for fname in inputs:
        if fname == '-':
            process_stream(sys.stdin, out_stream)
        else:
            with open(fname, 'r', encoding='utf-8') as f:
                process_stream(f, out_stream)
    return 0

if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))