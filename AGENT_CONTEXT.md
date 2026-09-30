# Agent Context --- riscv-cpu

## Mission

Continue development/debugging of:

`juanedosanchez/riscv-cpu`

The project is a hand-built minimal RISC-V CPU in Verilog targeting a
Sipeed Tang Primer 20K FPGA.

The immediate objective is **not yet CPU functionality on hardware**.
The immediate blocker is getting even a trivial blink design programmed
into the FPGA using the open-source Gowin toolchain.

Do not restart the project or redesign the CPU unless evidence requires
it.

------------------------------------------------------------------------

## Current hardware

Board:

-   Sipeed Tang Primer 20K
-   FPGA: `GW2A-LV18PG256C8/I7`
-   Gowin family used by Apicula/open-source flow: `GW2A-18`
-   Programmer board flag: `tangprimer20k`
-   JTAG: FT2232
-   Clock: 27 MHz

Current constraints:

``` text
clock H11
button T10
LED L16
```

Current CST:

``` text
IO_LOC "clk27" H11;
IO_PORT "clk27" IO_TYPE=LVCMOS33;

IO_LOC "btn_n0" T10;
IO_PORT "btn_n0" IO_TYPE=LVCMOS33;

IO_LOC "led" L16;
IO_PORT "led" IO_TYPE=LVCMOS33 PULL_MODE=UP;
```

Apicula's device table explicitly identifies Tang Primer 20K as:

``` text
Device: GW2A-LV18PG256C8/I7
nextpnr family: GW2A-18
pack family: GW2A-18
board: tangprimer20k
```

Do not substitute `GW2A-18C` for this flow.

------------------------------------------------------------------------

## Development environment

Host:

-   Intel Mac
-   macOS Sonoma 14.8.9
-   VS Code

Tools:

-   `iverilog`
-   `vvp`
-   Yosys
-   Python 3.14.6
-   Apycula 0.33
-   `gowin_pack`
-   openFPGALoader v1.1.1
-   nextpnr-himbaechel built locally

nextpnr location:

``` text
~/nextpnr/build/nextpnr-himbaechel
```

nextpnr version previously verified:

``` text
nextpnr-0.11.1-36-g3c42800d
```

nextpnr was built with:

``` bash
cd ~/nextpnr

cmake . -B build \
  -DARCH=himbaechel \
  -DHIMBAECHEL_UARCH=gowin \
  -DHIMBAECHEL_GOWIN_DEVICES=all

cmake --build build -j$(sysctl -n hw.ncpu)
```

A direct nextpnr test succeeded:

``` bash
cd ~/nextpnr

build/nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --test
```

Result:

``` text
Program finished normally.
```

------------------------------------------------------------------------

## Repository state

GitHub repository:

https://github.com/juanedosanchez/riscv-cpu

The repository is public.

Current top-level structure:

``` text
riscv-cpu/
├── build/
├── src/
├── tb/
├── build.sh
├── .gitignore
├── all_files.txt
└── project_files.txt
```

The GitHub tree currently includes `build/`, `src/`, and `tb/`.

Important:

`project_files.txt` is stale. It contains content from deleted datapath
files/testbenches. It is not authoritative for the current source tree.

Use the actual files in `src/` and `tb/` as the source of truth.

------------------------------------------------------------------------

## Current source architecture

### `src/top.v`

Current FPGA top:

``` verilog
module top (
    input wire clk27,
    input wire btn_n0,
    output wire led
);

    blink blink_unit (
        .clk(clk27),
        .reset(~btn_n0),
        .led(led)
    );

endmodule
```

Important:

**The FPGA top currently does NOT instantiate the RISC-V CPU.**

It only instantiates `blink`.

This is intentional: blink is being used to debug the FPGA
build/programming path before putting the CPU on hardware.

### `src/blink.v`

``` verilog
module blink (
    input wire clk,
    input wire reset,
    output wire led
);

    reg [24:0] counter;

    always @(posedge clk) begin
        if (reset)
            counter <= 25'd0;
        else
            counter <= counter + 1'b1;
    end

    assign led = counter[24];

endmodule
```

### `src/pc.v`

``` verilog
module pc (
    input wire clk,
    input wire reset,
    output reg [31:0] address
);
    always @(posedge clk) begin
        if (reset)
            address <= 32'd0;
        else
            address <= address + 32'd4;
    end
endmodule
```

### `src/regfile.v`

32 registers × 32 bits.

`x0` reads as zero and writes to `x0` are ignored.

### `src/alu.v`

Current operations:

``` text
000 ADD
001 SUB
010 AND
011 OR
```

### `src/decoder.v`

Current instruction classes:

``` text
R-type: opcode 0110011
I-type arithmetic: opcode 0010011
```

Current decoder supports:

-   ADD
-   SUB
-   AND
-   OR
-   arithmetic immediate via the I-type path

### `src/imm_gen.v`

Currently generates the sign-extended I-type immediate.

### `src/instruction_mem.v`

Current hardcoded program:

``` text
address 0x00: 00A00093  -> addi x1, x0, 10
address 0x04: 00300113  -> addi x2, x0, 3
address 0x08: 002081B3  -> add  x3, x1, x2
address 0x0C: 40208233  -> sub  x4, x1, x2
```

Expected register state:

``` text
x1 = 10
x2 = 3
x3 = 13
x4 = 7
```

### `src/cpu_core.v`

Connects:

``` text
decoder
imm_gen
regfile
ALU
```

ALU B input is selected between register `data2` and the immediate.

### `src/riscv_cpu.v`

Connects:

``` text
PC
instruction memory
CPU core
```

It currently exposes:

``` verilog
output wire [31:0] debug_x3
```

through:

``` verilog
assign debug_x3 = core.register_file.registers[3];
```

This hierarchical register access is acceptable for debugging/simulation
but should eventually be replaced with a deliberate debug/output path if
needed.

------------------------------------------------------------------------

## Simulation status

The CPU has previously been simulated successfully.

Existing testbench:

`tb/riscv_cpu_tb.v`

The previous result was:

``` text
x3 = 13
```

That confirms the current basic instruction sequence works in
simulation.

Do not treat this as proof that the CPU is FPGA-ready. Hardware
integration has not yet happened.

------------------------------------------------------------------------

## Current build script

Current GitHub `build.sh` is:

``` bash
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
  -s src/tang_primer_20k.cst \
  build/blink_pnr.json
```

Note:

The `-s src/tang_primer_20k.cst` argument to `gowin_pack` was tested as
a possible difference from the known-good reference flow.

It was then removed locally/rebuilt during debugging, but the GitHub
copy may still show the old version depending on the latest commit.
Verify the actual repository before making assumptions.

The known-good Apicula example uses:

``` bash
gowin_pack \
  -d GW2A-18 \
  -o pack.fs \
  pnrblinky.json
```

with the CST passed to nextpnr, not to gowin_pack.

------------------------------------------------------------------------

## Build results

The following stages have been successfully verified.

### Yosys

Command:

``` bash
yosys -p \
"read_verilog src/blink.v src/top.v;
 hierarchy -top top;
 synth_gowin -top top -json build/blink.json"
```

Succeeds.

### nextpnr

Command:

``` bash
~/nextpnr/build/nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=src/tang_primer_20k.cst \
  --json build/blink.json \
  --write build/blink_pnr.json
```

Succeeds:

``` text
Info: Program finished normally.
```

### gowin_pack

Command:

``` bash
gowin_pack \
  -d GW2A-18 \
  -o build/blink.fs \
  build/blink_pnr.json
```

Succeeds.

Generated file:

``` text
build/blink.fs
```

Size:

``` text
4.4M
```

------------------------------------------------------------------------

# CURRENT BLOCKER

## openFPGALoader hangs during SRAM erase

Programming command:

``` bash
openFPGALoader -b tangprimer20k --write-sram build/blink.fs
```

JTAG detection works.

The loader sees:

``` text
idcode 0x81b
manufacturer Gowin
family GW2A
model GW2A(R)-18(C)
irlength 8
```

The `.fs` file parses successfully.

Then programming reaches:

``` text
Erase SRAM
```

and hangs.

Verbose output included:

``` text
before program sram: displayReadReg 00000020
        Memory Erase
Erase SRAM before erase sram: displayReadReg 00000020
        Memory Erase
pollFlag: 20 (0)
pollFlag: 20 (0)
pollFlag: 20 (0)
...
```

The polling repeats indefinitely.

The same behavior occurred at:

``` text
6 MHz
1 MHz
500 kHz
```

Changing JTAG frequency did not solve it.

Direct FT2232 invocation also did not solve it.

The board flag:

``` bash
-b tangprimer20k
```

does detect the correct device.

------------------------------------------------------------------------

## Important: SecurityBit is NOT currently considered the root cause

The `.fs` parse output reported:

``` text
SecurityBit: ON
```

This was initially suspected.

Do not pursue that assumption without new evidence.

Known Tang Primer 20K programming logs also show `SecurityBit: ON`.

------------------------------------------------------------------------

## Important: clock issue is a separate issue

Apicula has a historical Tang Primer 20K issue concerning clocked
designs not running correctly on hardware after open-source
synthesis/P&R.

That issue is relevant later because this project uses the 27 MHz clock.

However, it is **not the current observed failure**.

The current failure happens before the design is successfully
programmed:

``` text
JTAG detect → OK
bitstream parse → OK
SRAM erase → HANG
```

Therefore, do not use the clock-routing issue as an explanation for the
current erase hang unless evidence connects the two.

------------------------------------------------------------------------

# Known reference flow

Apicula's Tang Primer 20K example uses:

``` bash
yosys ...
nextpnr-himbaechel \
  --device GW2A-LV18PG256C8/I7 \
  --vopt family=GW2A-18 \
  --vopt cst=primer20k.cst

gowin_pack \
  -d GW2A-18 \
  -o pack.fs \
  pnrblinky.json

openFPGALoader \
  -b tangprimer20k \
  pack.fs
```

This reference is important because it closely matches this project.

Sources:

-   Apicula Tang Primer device/family table
-   Apicula openFPGALoader board table
-   Apicula example build flow

------------------------------------------------------------------------

# Recommended debugging sequence

Do not immediately modify CPU logic.

The cleanest next experiment is to separate:

``` text
project bitstream problem
```

from:

``` text
openFPGALoader / FT2232 / board / hardware problem
```

## Step 1 --- use a known-good Tang Primer bitstream

Build a minimal known-good Apicula Tang Primer 20K blinky using the
exact documented flow.

Try programming that `.fs` with:

``` bash
openFPGALoader -b tangprimer20k --write-sram <known-good.fs>
```

Interpretation:

### If known-good also hangs at `Erase SRAM`

Focus on:

-   openFPGALoader v1.1.1
-   FT2232 communication
-   macOS/libusb interaction
-   USB cable/port
-   board power/reset/JTAG state
-   current upstream openFPGALoader behavior
-   possible need to update/rebuild openFPGALoader

Do NOT keep changing this project's Verilog.

### If known-good programs successfully

Then the programming stack is functional.

Compare:

-   `.fs` generation
-   bitstream header
-   family selection
-   pack arguments
-   design configuration
-   any configuration/security fields

between the known-good bitstream and this project.

------------------------------------------------------------------------

# openFPGALoader version

Current:

``` text
openFPGALoader v1.1.1
```

The official troubleshooting documentation explicitly mentions Tang
Primer 20K programming getting stuck and recommends checking the
openFPGALoader version.

Therefore, checking whether the installed version is current is a valid
next step.

Do not assume "JTAG detection works" means the programming path is
healthy. Detection and SRAM programming exercise different parts of the
interface.

------------------------------------------------------------------------

# What NOT to do

Avoid these unless new evidence requires them:

1.  Do not change the FPGA family to `GW2A-18C`.
2.  Do not use `--device GW2A-18C`.
3.  Do not rebuild the entire CPU to solve the SRAM erase hang.
4.  Do not keep changing JTAG frequency randomly.
5.  Do not assume `SecurityBit: ON` is the problem.
6.  Do not start loading the RISC-V CPU onto the FPGA before the trivial
    blink bitstream can be programmed.
7.  Do not treat stale `project_files.txt` as the actual source tree.
8.  Do not claim the FPGA hardware works merely because JTAG IDCODE is
    detected.
9.  Do not claim the CPU works on hardware; only simulation is currently
    verified.

------------------------------------------------------------------------

# Next CPU milestone after FPGA programming works

Once `blink.fs` successfully loads:

1.  Replace `top.v` so it instantiates `riscv_cpu`.
2.  Expose `debug_x3[3:0]` to four LEDs.
3.  Use the existing instruction ROM.
4.  Reset CPU.
5.  Verify:

``` text
x1 = 10
x2 = 3
x3 = 13
x4 = 7
```

The four LEDs should show:

``` text
1101
```

for `x3`.

After that:

-   clean up CPU reset behavior
-   create explicit LED/debug outputs
-   improve instruction memory
-   support more RV32I instructions
-   move instruction memory toward initialized block RAM
-   create an assembly-to-ROM workflow
-   eventually load arbitrary RISC-V programs into the FPGA CPU

------------------------------------------------------------------------

# Engineering philosophy for this project

The user already understands:

-   RISC-V assembly
-   basic CPU architecture
-   Verilog
-   simulation concepts

Do not teach programming from scratch.

Use a progressive hardware-engineering workflow:

``` text
one module
→ simulation
→ integration
→ synthesis
→ FPGA
→ verify
→ add next feature
```

When debugging, prefer controlled A/B experiments and identify exactly
which stage fails.

Always distinguish:

``` text
simulation failure
synthesis failure
P&R failure
packing failure
JTAG detection failure
SRAM programming failure
hardware execution failure
```

They are different problems.

Current failure category:

``` text
SRAM programming failure
```
