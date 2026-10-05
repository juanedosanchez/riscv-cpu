#!/bin/bash
# Build the FPGA bitstream: bootloader in the boot ROM, plus a program
# preloaded in RAM (run after the bootloader's 0.5 s upload window).
#
#   ./build.sh                          # preload programs/led_counter.S
#   ./build.sh programs/hello.c         # preload any program (.S or .c)
#
# Output: build/cpu.fs
# Load:   openFPGALoader -b tangprimer20k build/cpu.fs
#
# Programs can also be sent over UART without rebuilding:
#   tools/upload.py programs/hello.c

set -e

PROGRAM=${1:-programs/led_counter.S}

mkdir -p build

tools/mkprog.py --boot -o build/boot programs/boot.S
tools/mkprog.py -o build/program "$PROGRAM"

yosys -p \
"read_verilog src/pc.v src/main_mem.v src/boot_rom.v src/uart_tx.v src/uart_rx.v \
   src/decoder.v src/imm_gen.v src/regfile.v src/alu.v src/cpu_core.v \
   src/riscv_cpu.v src/top.v;
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
