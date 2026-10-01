#!/bin/bash

set -e

mkdir -p build

yosys -p \
"read_verilog src/blink.v src/top.v;
 hierarchy -top top;
 synth_gowin -top top -json build/blink.json"

~/nextpnr/build/nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=src/tang_primer_20k.cst \
  --json build/blink.json \
  --write build/blink_pnr.json

gowin_pack \
  -d GW2A-18 \
  -o build/blink.fs \
  build/blink_pnr.json
