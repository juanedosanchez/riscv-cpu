#!/usr/bin/env python3
"""Assemble an RV32I .S file into a $readmemh image for instruction_mem.v.

Usage: tools/asm2hex.py program.S out.hex [--depth WORDS]

Uses LLVM's assembler (llvm-mc), with compressed instructions and linker
relaxation disabled. The program is placed at address 0 and must be
self-contained: only the .text section is used, and any relocation left
for a linker (e.g. `la`, `call`, or references to .data) is an error.
Use `li` for constants and `jal`/`j` for calls and jumps.

The image is padded with NOPs (addi x0, x0, 0) up to --depth words.

llvm-mc is found via $LLVM_MC, then Homebrew LLVM, then PATH.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile

NOP = 0x00000013


def find_tool(name):
    env = os.environ.get(name.upper().replace("-", "_"))  # e.g. LLVM_MC
    if env:
        return env
    try:
        prefix = subprocess.run(["brew", "--prefix", "llvm"], capture_output=True,
                                text=True, check=True).stdout.strip()
        candidate = os.path.join(prefix, "bin", name)
        if os.path.exists(candidate):
            return candidate
    except (OSError, subprocess.CalledProcessError):
        pass
    found = shutil.which(name)
    if found:
        return found
    sys.exit(f"asm2hex: cannot find {name} (install LLVM, e.g. `brew install llvm`)")


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr)
        sys.exit(f"asm2hex: command failed: {' '.join(cmd)}")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("output")
    parser.add_argument("--depth", type=int, default=1024,
                        help="instruction ROM depth in words (default 1024)")
    args = parser.parse_args()

    llvm_mc = find_tool("llvm-mc")
    llvm_objdump = find_tool("llvm-objdump")
    llvm_objcopy = find_tool("llvm-objcopy")

    with tempfile.TemporaryDirectory() as tmp:
        obj = os.path.join(tmp, "program.o")
        binary = os.path.join(tmp, "program.bin")

        run([llvm_mc, "-triple=riscv32", "-mattr=-c,-relax", "-filetype=obj",
             "-o", obj, args.source])

        relocations = [line for line in run([llvm_objdump, "-r", obj]).splitlines()
                       if "R_RISCV" in line]
        if relocations:
            sys.stderr.write("\n".join(relocations) + "\n")
            sys.exit("asm2hex: unresolved relocations; the program must not need a "
                     "linker (avoid la/call/.data references)")

        run([llvm_objcopy, "-O", "binary", "--only-section=.text", obj, binary])

        with open(binary, "rb") as f:
            data = f.read()

    if len(data) % 4:
        data += b"\x00" * (4 - len(data) % 4)

    words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]

    if len(words) > args.depth:
        sys.exit(f"asm2hex: program is {len(words)} words, ROM holds {args.depth}")

    words += [NOP] * (args.depth - len(words))

    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    with open(args.output, "w") as f:
        for word in words:
            f.write(f"{word:08x}\n")

    print(f"asm2hex: {args.source} -> {args.output} "
          f"({len(data) // 4} instructions, padded to {args.depth})")


if __name__ == "__main__":
    main()
