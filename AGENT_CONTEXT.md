# Agent Context --- riscv-cpu

## Mission

Continue development/debugging of:

`juanedosanchez/riscv-cpu`

The project is a hand-built minimal RISC-V CPU in Verilog targeting a
Sipeed Tang Primer 20K FPGA.

**A single-cycle RV32I CPU runs on the FPGA at 27 MHz.** Programs are
written in RISC-V assembly (`programs/*.S`), assembled with LLVM into
the instruction ROM, and built into the bitstream. The self-checking
`programs/rv32i_test.S` (57 checks, every instruction class) passes in
simulation and on hardware (all four LEDs steady on, verified
2026-10-01). The earlier SRAM programming hang is resolved (Dock DIP
switch 1 was not down; see "Resolved: SRAM programming hang").

The next objectives are in "Next steps".

Do not restart the project or redesign the CPU unless evidence requires
it.

------------------------------------------------------------------------

## Current hardware

Board:

-   Sipeed Tang Primer 20K
-   FPGA: `GW2A-LV18PG256C8/I7`
-   Gowin family used by Apicula/open-source flow: `GW2A-18`
-   Programmer board flag: `tangprimer20k`
-   JTAG: the Dock's on-board debugger enumerates as an FT2232-compatible
    probe (USB `0403:6010`, manufacturer `SIPEED`, product
    `JTAG Debugger`, serial `FactoryAIOT Pro`). It is reportedly a
    BL702-based FT2232 emulator.
-   **Dock DIP switch 1 must be down** (core board enabled). With it up,
    JTAG detection still works but SRAM programming hangs. See
    "Resolved: SRAM programming hang" below.
-   Clock: 27 MHz

Current constraints:

``` text
clock     H11
button    T10 (S0, active-low)
led[3:0]  N16 N14 L14 L16 (Dock LED2-LED5, active-low)
```

Current CST:

``` text
IO_LOC "clk27" H11;
IO_PORT "clk27" IO_TYPE=LVCMOS33;

IO_LOC "btn_n0" T10;
IO_PORT "btn_n0" IO_TYPE=LVCMOS33;

// Dock LEDs, same pins as Sipeed's TangPrimer-20K-example HDMI demo
IO_LOC "led[0]" L16;
IO_PORT "led[0]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
IO_LOC "led[1]" L14;
IO_PORT "led[1]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
IO_LOC "led[2]" N14;
IO_PORT "led[2]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
IO_LOC "led[3]" N16;
IO_PORT "led[3]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
```

LED pins match Sipeed's TangPrimer-20K-example HDMI demo. The Dock
LEDs are **active-low** (verified on hardware: driving `x3[3:0] = 1101`
directly lit only LED4). Dock LED0/LED1 (`C13`, `A13`) are not used.

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
-   Homebrew LLVM 22.1.8 (`llvm-mc`, `llvm-objcopy`, `llvm-objdump`;
    RISC-V target included). There is no `ld.lld`, so programs are
    assembled without a linker.
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

The repository is public. The GitHub repository is named `riscv-cpu`;
the local clone folder is named `riscv-cpu-tang`.

Current top-level structure:

``` text
riscv-cpu/
├── README.md
├── AGENT_CONTEXT.md
├── .gitignore
├── all_files.txt
├── project_files.txt
├── build.sh        assemble a program + build build/cpu.fs
├── test.sh         assemble test programs + run all testbenches
├── build/          (generated; gitignored, not on GitHub)
├── programs/       RISC-V assembly programs (.S)
├── tools/          asm2hex.py
├── src/            Verilog
└── tb/             testbenches
```

The GitHub tree contains everything above except `build/`. `build/`
(`*.hex`, `cpu.json`, `cpu_pnr.json`, `cpu.fs`, `*.vvp`) is a local
output directory only: it is listed in `.gitignore` (as are `*.fs` and
`*.json`).

Important:

`project_files.txt` is stale. It contains content from deleted datapath
files/testbenches. It is not authoritative for the current source tree.

Use the actual files in `src/` and `tb/` as the source of truth.

------------------------------------------------------------------------

## Current source architecture

Single-cycle RV32I. One instruction per 27 MHz cycle.

### Memory map (`src/riscv_cpu.v`)

| Address | Size | Contents |
|---|---|---|
| `0x0000_0000` | 4 KB | Instruction ROM (fetch only; loads cannot read it) |
| `0x0001_0000` | 1 KB | Data RAM (mirrored across `0x0001_xxxx`) |
| `0x1000_0000` | 1 word | LED register, bits `[3:0]`, read/write |

Other addresses read 0 and ignore writes.

### Modules

-   `src/top.v`: FPGA top. 16-cycle power-on reset plus S0 (`btn_n0`,
    active-low). Instantiates `riscv_cpu` and drives
    `led = ~leds` (Dock LEDs are active-low). Parameter `PROGRAM`
    (default `build/program.hex`).
-   `src/riscv_cpu.v`: PC, instruction ROM, `cpu_core`, data RAM, LED
    register and the address decode above. Outputs `leds[3:0]` and
    `debug_x3`.
-   `src/cpu_core.v`: decoder, immediate generator, register file, ALU
    operand muxes, branch comparison, next-PC selection (pc+4, pc+imm,
    (rs1+imm)&~1), store data replication + byte strobes, load
    extraction/sign extension, write-back mux (ALU, load data, pc+4).
-   `src/decoder.v`: full RV32I decode. Outputs `alu_operation[3:0]`,
    `alu_src_a` (rs1/pc/zero), `use_immediate`, `write_enable`,
    `wb_select` (ALU/mem/pc+4), `mem_read`, `mem_write`, `branch`, `jal`,
    `jalr`. Reserved encodings (bad funct3/funct7, M-extension, FENCE,
    SYSTEM, unknown opcodes) decode as no-ops with no side effects.
-   `src/imm_gen.v`: I, S, B, U and J immediates.
-   `src/alu.v`: 4-bit op: `0000 ADD, 0001 SUB, 0010 AND, 0011 OR,
    0100 XOR, 0101 SLL, 0110 SRL, 0111 SRA, 1000 SLT, 1001 SLTU`.
    Shifts use `b[4:0]`.
-   `src/pc.v`: PC register, loads `next_address`, reset to 0.
-   `src/instruction_mem.v`: ROM, `$readmemh(INIT_FILE)`, 1024 words.
    **Synchronous read**, addressed with `next_pc` (0 during reset), so
    the registered output matches the PC loaded on the same edge. This
    is what lets it map to BSRAM.
-   `src/data_mem.v`: 256 words as four byte lanes, async read, sync
    write with byte strobes. Maps to `RAM16SDP4`.
-   `src/regfile.v`: 32 × 32, two async read ports, **no reset**
    (zeroed by an `initial` block at configuration/simulation start).
    Maps to `RAM16SDP4`. `x0` reads zero. `debug_x3` port kept for
    testbenches.
-   `src/blink.v`: old LED blink test, not built. The single-LED blink
    top is in git history (commit `b33ebcf` or earlier).

### Why the ROM is synchronous and the register file has no reset

The first full-RV32I build used 68% of the LUTs and failed 27 MHz
(26.35 MHz). Yosys could not put an async-read ROM in BSRAM and built
a 1024 × 32 mux tree; the register file's reset loop forced 1024 DFFs
plus per-register write logic (~8,500 cells). After the two changes
the design is ~6,100 cells, ~5,000 LUT4 (24%), 160 `RAM16SDP4`,
2 BSRAM, and nextpnr reports ~54 MHz. Keep both properties unless
there is a reason to pay that cost.

### Known limitations

-   Misaligned loads/stores are not trapped (undefined results).
-   No traps, interrupts, CSRs; FENCE/ECALL/EBREAK are no-ops.
-   The ROM cannot be read with loads (Harvard), so constants come from
    `li`, not from data tables in `.text`.
-   No linker: `la`, `call`, `.data` are rejected by `asm2hex.py`.

------------------------------------------------------------------------

## Programs and assembly workflow

-   `tools/asm2hex.py prog.S out.hex`: runs `llvm-mc -triple=riscv32
    -mattr=-c,-relax -filetype=obj`, fails on any `R_RISCV` relocation,
    extracts `.text` with `llvm-objcopy`, writes one little-endian word
    per line, pads to 1024 words with NOPs (`00000013`). Finds LLVM via
    `$LLVM_MC`/`$LLVM_OBJDUMP`/`$LLVM_OBJCOPY`, then `brew --prefix
    llvm`, then `PATH`.
-   `programs/led_counter.S`: default demo; counts 0-15 on the LEDs
    (~0.2 s per step) using a `delay` subroutine and the stack.
-   `programs/rv32i_test.S`: self-checking test. Uses `t6` as check
    counter, `t5` as result (`0x600D` pass, `0xBAD` fail), `t4` scratch.
    Pass: LEDs `1111` steady. Fail: failing check number (low 4 bits)
    blinks.
-   `programs/basic.S`: the original 4-instruction program
    (x1=10, x2=3, x3=13, x4=7).

------------------------------------------------------------------------

## Simulation status

`./test.sh` assembles the test programs and runs every testbench; it
exits non-zero on any `FAIL`. Current output:

``` text
ALU TB: ALL TESTS PASSED
CPU_CORE TB: ALL TESTS PASSED
DECODER TB: ALL TESTS PASSED
regfile_tb: ran (no self-check)
RISCV_CPU TB: ALL TESTS PASSED
RV32I TB: ALL TESTS PASSED (57 checks, 253 cycles)
TOP TB: ALL TESTS PASSED
```

-   `tb/rv32i_tb.v`: runs `rv32i_test.S`, waits for `t5` to become
    `0x600D`/`0xBAD` (note `li t5, 0x600D` is lui+addi, so don't stop
    at the first non-zero value). Verified to catch a deliberately
    broken `sra` (fails at check 12).
-   `tb/top_tb.v`: same program through `top`; checks LED pins
    (`0000` = all lit on pass, `1111` while S0 held, `0000` after rerun).
-   `tb/decoder_tb.v`: every RV32I instruction plus reserved encodings.
-   `tb/cpu_core_tb.v`: drives the core directly: write-back, next-PC
    for branches/jumps, store strobes, load sign extension.
-   `tb/alu_tb.v`: every ALU op. `tb/regfile_tb.v`: prints only.
-   `tb/riscv_cpu_tb.v`: `basic.S`, checks x1-x4 and `debug_x3`.

Hand-written instruction encodings in the testbenches were verified
against `llvm-mc -show-encoding`.

------------------------------------------------------------------------

## Build

``` bash
./build.sh                        # programs/led_counter.S
./build.sh programs/rv32i_test.S  # any program
openFPGALoader -b tangprimer20k build/cpu.fs
```

`build.sh` assembles the program into `build/program.hex`, then
Yosys (`synth_gowin`), nextpnr-himbaechel (`--device
GW2A-LV18PG256C8/I7 --vopt family=GW2A-18 --vopt
cst=src/tang_primer_20k.cst --freq 27`) and `gowin_pack -d GW2A-18`.
The CST is passed to nextpnr only, not gowin_pack. Place and route
takes a few minutes.

`--freq 27` matters: without it nextpnr checks timing against a 12 MHz
default, which hid the earlier 26.35 MHz failure.

------------------------------------------------------------------------

# Resolved: SRAM programming hang

## Symptom (before the fix)

`openFPGALoader -b tangprimer20k --write-sram build/blink.fs` detected
the FPGA (idcode 0x81b, GW2A(R)-18(C)), parsed the `.fs`, printed
`Erase SRAM` and then looped forever on:

``` text
pollFlag: 20 (0)
```

Lowering JTAG frequency (6 MHz, 1 MHz, 500 kHz) made no difference.

## Root cause

**Tang Primer 20K Dock DIP switch 1 was not down.** Switch 1 down
enables the core board (documented on Sipeed's wiki). After setting it
down, the same `build/blink.fs` loaded successfully and the LED on
`L16` blinked on hardware (verified 2026-10-01).

With the switch up, JTAG IDCODE and status reads still work, so
`--detect` looks healthy, but configuration commands are ignored.

## What the log meant

From openFPGALoader's `src/gowin.cpp` (v1.1.1 / upstream master):

-   `pollFlag(mask, value)` prints `pollFlag: <status> (<status & mask>)`
    and loops until `(status & mask) == value`.
-   `programSRAM()` → `eraseSRAM()` → `enableCfg()`. `enableCfg()` sends
    `CONFIG_ENABLE` (0x15) and waits for `STATUS_SYSTEM_EDIT_MODE`
    (0x80).
-   `pollFlag: 20 (0)` = status 0x20, `0x20 & 0x80 = 0`: the FPGA never
    entered edit mode. The erase command (0x05) had not been sent yet,
    so the hang was **not** in the erase.

A successful load looks like:

``` text
pollFlag: 60a0 (80)
after erase sram: displayReadReg 000000a0
        Memory Erase
        System Edit Mode
Load SRAM: [==================================================] 100.00%
after program sram: displayReadReg 00006020
        Memory Erase
        Done Final
        Security Final
```

## If it ever hangs at `pollFlag: 20 (0)` again

1.  Check Dock DIP switch 1 is down.
2.  `pkill openFPGALoader`, unplug USB for about 10 s, plug directly
    into the Mac (no hub).
3.  Sipeed's recovery trick: start the load and, while it waits, flip
    DIP switch 1 up and back down.
4.  Only then suspect the BL702 debugger firmware (openFPGALoader issue
    #573 reports clone-firmware problems on this board; a real FTDI
    probe on the JTAG header with `-c ft2232` is the workaround).

Not causes (ruled out): the bitstream (the hang happened before any
bitstream data was sent, and the same file now loads), the
openFPGALoader version (v1.1.1 is the latest release), and JTAG
frequency.

------------------------------------------------------------------------

## SecurityBit is not a problem

The `.fs` parse output reports:

``` text
SecurityBit: ON
```

This was initially suspected. It is not an issue: this project's
bitstream loads and runs with it, and known Tang Primer 20K programming
logs also show `SecurityBit: ON`.

------------------------------------------------------------------------

## Clock issue: keep an eye on it

Apicula has a historical Tang Primer 20K issue concerning clocked
designs not running correctly on hardware after open-source
synthesis/P&R.

The 27 MHz blink design and the RV32I CPU both run correctly on
hardware, so this is not currently a problem. If a larger clocked design programs
successfully (`Done Final`) but misbehaves, consider it then.

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

This project's `build.sh` now matches it.

Sources:

-   Apicula Tang Primer device/family table
-   Apicula openFPGALoader board table
-   Apicula example build flow

------------------------------------------------------------------------

# What NOT to do

Avoid these unless new evidence requires them:

1.  Do not change the FPGA family to `GW2A-18C`.
2.  Do not use `--device GW2A-18C`.
3.  Do not change JTAG frequency to fix a programming hang; check DIP
    switch 1 first.
4.  Do not assume `SecurityBit: ON` is the problem.
5.  Do not treat stale `project_files.txt` as the actual source tree.
6.  Do not claim the FPGA is ready to program merely because JTAG
    IDCODE is detected.
7.  Do not overstate hardware verification: on hardware,
    `rv32i_test.S` passing (LEDs steady on) and the LED counter demo
    have been observed. Finer details are verified in simulation only.
8.  Do not drive the Dock LEDs without inverting: they are active-low.
9.  Do not make the instruction ROM async-read or add a reset loop to
    the register file without checking resource use and timing (see
    "Why the ROM is synchronous...").
10. Do not build without `--freq 27`; the default constraint is 12 MHz.

------------------------------------------------------------------------

# Next steps

Done: full RV32I on the FPGA, assembly-to-ROM workflow, self-test passing
on hardware.

Possible next steps:

-   UART output (print results instead of reading LEDs)
-   load programs over UART without rebuilding the bitstream
-   a linker script so `.data`, `la` and `call` work (needs `ld.lld`)
-   traps and `Zicsr`; then `ECALL`/`EBREAK`
-   the `M` extension (multiply/divide)
-   pipelining, once the single-cycle design is the bottleneck

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

Current state: no open failure. The RV32I CPU runs on hardware and
passes its self-test.
