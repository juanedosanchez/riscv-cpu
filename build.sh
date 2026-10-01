#!/bin/bash
# Build an FPGA bitstream running a RISC-V program.
#
#   ./build.sh                       # programs/led_counter.S
#   ./build.sh programs/foo.S        # any self-contained RV32I program
#
# Output: build/cpu.fs
# Load:   openFPGALoader -b tangprimer20k build/cpu.fs

set -e

PROGRAM=${1:-programs/led_counter.S}

mkdir -p build

tools/asm2hex.py "$PROGRAM" build/program.hex

yosys -p \
"read_verilog src/pc.v src/instruction_mem.v src/data_mem.v src/decoder.v \
   src/imm_gen.v src/regfile.v src/alu.v src/cpu_core.v src/riscv_cpu.v src/top.v;
 hierarchy -top top;
 synth_gowin -top top -json build/cpu.json"

~/nextpnr/build/nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=src/tang_primer_20k.cst \
  --freq 27 \
  --json build/cpu.json \
  --write build/cpu_pnr.json

gowin_pack \
  -d GW2A-18 \
  -o build/cpu.fs \
  build/cpu_pnr.json
