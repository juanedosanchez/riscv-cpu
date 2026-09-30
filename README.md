# Minimal RISC-V CPU --- Tang Primer 20K

A minimal RV32I-style RISC-V CPU implemented in Verilog and targeted at
the Sipeed Tang Primer 20K FPGA.

## Project status

The CPU datapath currently supports a small instruction subset and has
been simulated successfully. The FPGA build pipeline also works through
bitstream generation.

The current hardware blocker is **programming the generated `.fs`
bitstream into the FPGA SRAM**: JTAG detection succeeds, but
`openFPGALoader` hangs during `Erase SRAM`.

Current status:

  Stage                       Status
  --------------------------- ------------------------------------
  Verilog modules             Working
  Icarus Verilog simulation   Working
  Yosys synthesis             Working
  nextpnr-himbaechel P&R      Working
  gowin_pack                  Working
  `.fs` generation            Working
  FPGA JTAG detection         Working
  FPGA SRAM programming       **Blocked: hangs at `Erase SRAM`**

## Hardware

-   Board: Sipeed Tang Primer 20K
-   FPGA: `GW2A-LV18PG256C8/I7`
-   Open-source flow family: `GW2A-18`
-   Programmer board flag: `tangprimer20k`
-   JTAG interface: FT2232
-   Clock: 27 MHz
-   Current LED output: `L16`
-   Current reset button: `T10`
-   Current clock pin: `H11`

Apicula's current board/device table specifies the Tang Primer 20K as
`GW2A-LV18PG256C8/I7`, with nextpnr family `GW2A-18` and pack family
`GW2A-18`. citeturn0search1turn0search6

## Repository structure

``` text
riscv-cpu/
├── build.sh
├── src/
│   ├── top.v
│   ├── blink.v
│   ├── tang_primer_20k.cst
│   ├── instruction_mem.v
│   ├── riscv_cpu.v
│   ├── cpu_core.v
│   ├── pc.v
│   ├── regfile.v
│   ├── decoder.v
│   ├── imm_gen.v
│   └── alu.v
└── tb/
    ├── decoder_tb.v
    ├── regfile_tb.v
    ├── alu_tb.v
    ├── riscv_cpu_tb.v
    └── cpu_core_tb.v
```

There are also `all_files.txt` and `project_files.txt`.
`project_files.txt` contains some stale content from deleted datapath
files/testbenches and should not be treated as the authoritative source
tree.

## CPU architecture

Current datapath:

``` text
             +----------------+
 PC -------> | Instruction    |
             | Memory         |
             +-------+--------+
                     |
                     v
             +---------------+
             | Decoder       |
             +-------+-------+
                     |
          +----------+----------+
          |                     |
          v                     v
      Register File          Immediate
          |                     |
          +----------+----------+
                     |
                     v
                   ALU
                     |
                     v
                Write Back
                     |
                     v
               Register File
```

The program counter increments by 4 every clock cycle.

The register file contains 32 × 32-bit registers. `x0` is hardwired to
zero by the read logic and writes to register zero are ignored.

## Currently implemented instructions

The instruction memory currently contains:

``` asm
addi x1, x0, 10
addi x2, x0, 3
add  x3, x1, x2
sub  x4, x1, x2
```

The expected result is:

``` text
x1 = 10
x2 = 3
x3 = 13
x4 = 7
```

The existing CPU testbench previously produced:

``` text
x3 = 13
```

Supported ALU operations currently include:

-   ADD
-   SUB
-   AND
-   OR

The decoder currently handles:

-   R-type opcode `0110011`
-   I-type arithmetic opcode `0010011`

The immediate generator currently implements the I-type immediate.

This is intentionally a minimal CPU, not yet a complete RV32I
implementation.

## FPGA blinky top

The current FPGA top-level is deliberately **not the CPU yet**. It
instantiates a simple blink module:

``` verilog
module top (
    input wire clk27,
    input wire btn_n0,
    output wire led
);
```

`blink.v` uses a 25-bit counter and drives:

``` verilog
assign led = counter[24];
```

This is being used as the hardware/programming test before putting the
CPU on the FPGA.

## Build toolchain

The working open-source flow is:

``` text
Verilog
  ↓
Yosys
  ↓
nextpnr-himbaechel
  ↓
gowin_pack / Apicula
  ↓
openFPGALoader
  ↓
Tang Primer 20K
```

Installed/verified tools:

-   Icarus Verilog: `iverilog`, `vvp`
-   Yosys
-   Apycula
-   nextpnr-himbaechel
-   openFPGALoader
-   Python 3

The local nextpnr executable is:

``` text
~/nextpnr/build/nextpnr-himbaechel
```

## Build

From the repository root:

``` bash
chmod +x build.sh
./build.sh
```

The current script performs:

``` bash
yosys -p \
"read_verilog src/blink.v src/top.v;
 hierarchy -top top;
 synth_gowin -top top -json build/blink.json"
```

then:

``` bash
~/nextpnr/build/nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=src/tang_primer_20k.cst \
  --json build/blink.json \
  --write build/blink_pnr.json
```

and finally:

``` bash
gowin_pack \
  -d GW2A-18 \
  -o build/blink.fs \
  build/blink_pnr.json
```

The known-good reference flow also uses these Tang Primer 20K
parameters. citeturn0search0turn0search1

## Programming

JTAG detection works:

``` bash
openFPGALoader --detect
```

It reports:

``` text
idcode       0x81b
manufacturer Gowin
family       GW2A
model        GW2A(R)-18(C)
irlength     8
```

The board is therefore visible over JTAG.

The intended SRAM programming command is:

``` bash
openFPGALoader -b tangprimer20k --write-sram build/blink.fs
```

However, this currently hangs at:

``` text
Erase SRAM
```

Verbose output showed repeated:

``` text
pollFlag: 20 (0)
```

Lowering JTAG frequency to 1 MHz and 500 kHz did not resolve it.

The loader version currently used is:

``` text
openFPGALoader v1.1.1
```

The openFPGALoader troubleshooting documentation specifically has a Tang
Primer 20K programming/stuck issue and recommends checking the loader
version. citeturn0search8

## Important debugging conclusion

Do **not** assume the CPU Verilog is causing the current programming
failure.

The FPGA test design is only:

``` text
27 MHz clock → 25-bit counter → LED
```

The design successfully passes:

``` text
Yosys
→ nextpnr
→ gowin_pack
```

and JTAG detection succeeds.

The failure happens at SRAM erase/programming.

A known Apicula example uses essentially the same open-source flow:

``` bash
yosys ...
nextpnr-himbaechel ...
gowin_pack ...
openFPGALoader -b tangprimer20k ...
```

for the Tang Primer 20K. citeturn0search0

## Known dead ends

Do not repeat these without new evidence:

1.  Changing `GW2A-18` to `GW2A-18C` in `gowin_pack`.

    This produced a family mismatch because the Tang Primer open-source
    flow uses `GW2A-18`.

2.  Using only:

    ``` bash
    --device GW2A-18C
    ```

    with nextpnr.

    This caused a speed-grade/database error.

3.  Repeatedly lowering JTAG frequency.

    Tested down to 500 kHz; the SRAM erase still hung.

4.  Assuming `SecurityBit: ON` proves the bitstream is invalid.

    Known Tang Primer programming logs also report `SecurityBit: ON`.

5.  Rebuilding the CPU datapath to solve the current programming hang.

    The hardware test currently uses `blink.v`, not the CPU.

6.  Assuming JTAG is completely broken.

    The FPGA IDCODE is successfully read.

## Recommended next debugging path

The next agent should isolate **loader/hardware vs bitstream** before
touching CPU logic.

### Test A --- known-good external bitstream

Build/program a known-good Tang Primer 20K blinky using the Apicula
example flow.

If that bitstream also hangs at:

``` text
Erase SRAM
```

the problem is likely outside this repository: programmer, FT2232
communication, openFPGALoader version/build, board state, USB
connection, or another hardware/software interaction.

If the known-good bitstream programs successfully, compare its `.fs`
generation and contents with this project's bitstream.

### Test B --- inspect openFPGALoader behavior

The exact failure is:

``` text
JTAG detection → successful
FS parsing      → successful
SRAM erase      → hangs
```

Investigate the `Memory Erase` / `pollFlag: 20` path in the installed
openFPGALoader version and compare it with current upstream behavior.

### Test C --- only after programming works

Once the blink bitstream can actually be loaded, replace the FPGA top
with the RISC-V CPU and expose a register/result on the LEDs.

A sensible first hardware CPU milestone is:

``` text
CPU executes:
addi x1, x0, 10
addi x2, x0, 3
add  x3, x1, x2

LEDs = x3[3:0]
```

Expected:

``` text
x3 = 13 = 4'b1101
```

Only after that should the project move toward loading arbitrary
assembly programs into instruction memory.

## Repository

GitHub:

https://github.com/juanedosanchez/riscv-cpu
