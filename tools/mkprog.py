#!/usr/bin/env python3
"""Build a program for the CPU from C and/or assembly sources.

Usage:
  tools/mkprog.py -o build/NAME source.c [more.S ...]          # main RAM program
  tools/mkprog.py --boot -o build/boot programs/boot.S         # boot ROM

Main RAM programs are linked with sw/link.ld at address 0, together with
sw/crt0.S (sets up the stack, clears .bss, calls main) and sw/runtime.c
(software multiply/divide, memset/memcpy). Outputs:
  NAME.elf, NAME.bin             linked program / raw image (for upload.py)
  NAME.lane0.hex .. lane3.hex    byte lanes for src/main_mem.v (16 KB)

Boot ROM programs are linked with sw/boot.ld at 0x10000 without crt0.
Output: NAME.hex, one 32-bit word per line (1 KB).

Tools: clang (Homebrew LLVM) and ld.lld. ld.lld is found via $LD_LLD,
then Zig (`zig ld.lld`, in ~/tools/zig-*), then PATH.
"""

import argparse
import glob
import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SW = os.path.join(ROOT, "sw")

RAM_WORDS = 4096        # 16 KB, src/main_mem.v
BOOT_WORDS = 256        # 1 KB,  src/boot_rom.v
NOP = 0x00000013

CFLAGS = [
    "--target=riscv32-unknown-elf", "-march=rv32i", "-mabi=ilp32",
    "-mno-relax", "-ffreestanding", "-fno-builtin", "-nostdlib",
    "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
    "-msmall-data-limit=0", "-O2", "-Wall", "-I" + SW,
]


def die(message):
    sys.exit(f"mkprog: {message}")


def llvm_tool(name):
    try:
        prefix = subprocess.run(["brew", "--prefix", "llvm"], capture_output=True,
                                text=True, check=True).stdout.strip()
        candidate = os.path.join(prefix, "bin", name)
        if os.path.exists(candidate):
            return [candidate]
    except (OSError, subprocess.CalledProcessError):
        pass
    found = shutil.which(name)
    if found:
        return [found]
    die(f"cannot find {name} (install LLVM, e.g. `brew install llvm`)")


def linker():
    if os.environ.get("LD_LLD"):
        return os.environ["LD_LLD"].split()
    zigs = sorted(glob.glob(os.path.expanduser("~/tools/zig-*/zig")))
    if zigs:
        return [zigs[-1], "ld.lld"]
    if shutil.which("zig"):
        return [shutil.which("zig"), "ld.lld"]
    if shutil.which("ld.lld"):
        return [shutil.which("ld.lld")]
    die("cannot find ld.lld (set $LD_LLD, or unpack Zig into ~/tools)")


def run(cmd):
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stdout + result.stderr)
        die("command failed: " + " ".join(cmd))
    return result.stdout


def write_words(path, words):
    with open(path, "w") as f:
        for word in words:
            f.write(f"{word:08x}\n")


def write_bytes(path, data):
    with open(path, "w") as f:
        for byte in data:
            f.write(f"{byte:02x}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("sources", nargs="+")
    parser.add_argument("-o", "--output", required=True, help="output prefix, e.g. build/program")
    parser.add_argument("--boot", action="store_true", help="build for the boot ROM")
    args = parser.parse_args()

    clang = llvm_tool("clang")
    objcopy = llvm_tool("llvm-objcopy")
    size_tool = llvm_tool("llvm-size")

    out = args.output
    os.makedirs(os.path.dirname(os.path.abspath(out)), exist_ok=True)

    sources = list(args.sources)
    if not args.boot:
        sources = [os.path.join(SW, "crt0.S"), os.path.join(SW, "runtime.c")] + sources

    objects = []
    for index, source in enumerate(sources):
        obj = f"{out}.{index}.{os.path.basename(source)}.o"
        run(clang + CFLAGS + ["-c", source, "-o", obj])
        objects.append(obj)

    script = os.path.join(SW, "boot.ld" if args.boot else "link.ld")
    elf = out + ".elf"
    run(linker() + ["-T", script, "--gc-sections", "-o", elf] + objects)
    for obj in objects:
        os.remove(obj)

    binary = out + ".bin"
    run(objcopy + ["-O", "binary", elf, binary])
    with open(binary, "rb") as f:
        data = f.read()

    capacity = (BOOT_WORDS if args.boot else RAM_WORDS) * 4
    if len(data) > capacity:
        die(f"image is {len(data)} bytes, memory holds {capacity}")

    if args.boot:
        data += b"\x00" * (-len(data) % 4)
        words = [int.from_bytes(data[i:i + 4], "little") for i in range(0, len(data), 4)]
        write_words(out + ".hex", words + [NOP] * (BOOT_WORDS - len(words)))
    else:
        image = data + b"\x00" * (capacity - len(data))
        for lane in range(4):
            write_bytes(f"{out}.lane{lane}.hex", image[lane::4])

    sizes = run(size_tool + [elf]).splitlines()[-1].split()
    text, rodata_data, bss = sizes[0], sizes[1], sizes[2]
    kind = "boot ROM" if args.boot else "RAM"
    print(f"mkprog: {out} ({kind}): image {len(data)} of {capacity} bytes "
          f"[text {text}, data {rodata_data}, bss {bss}]")


if __name__ == "__main__":
    main()
