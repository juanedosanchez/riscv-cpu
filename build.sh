#!/bin/bash

set -e

mkdir -p build

yosys -p \
"read_verilog src/pc.v src/instruction_mem.v src/decoder.v src/imm_gen.v \
   src/regfile.v src/alu.v src/cpu_core.v src/riscv_cpu.v src/top.v;
 hierarchy -top top;
 synth_gowin -top top -json build/cpu.json"

~/nextpnr/build/nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=src/tang_primer_20k.cst \
  --json build/cpu.json \
  --write build/cpu_pnr.json

gowin_pack \
  -d GW2A-18 \
  -o build/cpu.fs \
  build/cpu_pnr.json
