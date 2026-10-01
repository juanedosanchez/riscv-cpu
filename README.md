# Minimal RISC-V CPU --- Tang Primer 20K

A single-cycle RV32I RISC-V CPU implemented in Verilog and running on
the Sipeed Tang Primer 20K FPGA.

## Project status

The CPU implements the RV32I base integer instruction set, runs
programs written in RISC-V assembly, and **runs on the FPGA** at
27 MHz. The self-checking test program (57 checks covering every
instruction class) passes in simulation and on the board (verified on
hardware 2026-10-01).

Current status:

  Stage                       Status
  --------------------------- ------------------------------------
  RV32I CPU (single-cycle)    Working
  Assembly → ROM workflow     Working (LLVM `llvm-mc`)
  Icarus Verilog simulation   Working (`./test.sh`, all pass)
  Yosys synthesis             Working
  nextpnr-himbaechel P&R      Working, 27 MHz met (~54 MHz max)
  gowin_pack                  Working
  FPGA SRAM programming       Working (Dock DIP switch 1 must be down)
  RV32I self-test on hardware Passing (all four LEDs steady on)

## Hardware

-   Board: Sipeed Tang Primer 20K
-   FPGA: `GW2A-LV18PG256C8/I7`
-   Open-source flow family: `GW2A-18`
-   Programmer board flag: `tangprimer20k`
-   JTAG interface: the Dock's on-board debugger enumerates as an
    FT2232-compatible probe (USB `0403:6010`, manufacturer `SIPEED`,
    product `JTAG Debugger`, serial `FactoryAIOT Pro`). It is reportedly
    a BL702-based FT2232 emulator.
-   **Dock DIP switch 1 must be down** (core board enabled) for
    programming to work. See "Programming" below.
-   Clock: 27 MHz on `H11`
-   LEDs (active-low): `led[3:0]` on `N16`, `N14`, `L14`, `L16`
    (Dock LED2-LED5; see "FPGA top")
-   Reset button: `T10` (S0, active-low)

Apicula's current board/device table specifies the Tang Primer 20K as
`GW2A-LV18PG256C8/I7`, with nextpnr family `GW2A-18` and pack family
`GW2A-18` (see the Apicula project's supported-boards/device table).

## Repository structure

The GitHub repository is `riscv-cpu`; the local clone folder is named
`riscv-cpu-tang`. Both refer to the same tree:

``` text
riscv-cpu/
├── README.md
├── AGENT_CONTEXT.md
├── .gitignore
├── all_files.txt
├── project_files.txt
├── build.sh            assemble a program + build the bitstream
├── test.sh             assemble test programs + run all testbenches
├── build/              (generated; gitignored, not on GitHub)
├── programs/
│   ├── led_counter.S   default demo: counts 0-15 on the LEDs
│   ├── rv32i_test.S    self-checking test of every instruction class
│   └── basic.S         the original 4-instruction program
├── tools/
│   └── asm2hex.py      .S -> instruction ROM hex (uses llvm-mc)
├── src/
│   ├── top.v           FPGA top: reset, CPU, LED outputs
│   ├── riscv_cpu.v     PC + memories + LED register (memory map)
│   ├── cpu_core.v      decode, registers, ALU, branches, load/store
│   ├── pc.v
│   ├── instruction_mem.v
│   ├── data_mem.v
│   ├── regfile.v
│   ├── decoder.v
│   ├── imm_gen.v
│   ├── alu.v
│   ├── tang_primer_20k.cst
│   └── blink.v         (old LED blink test; not built)
└── tb/
    ├── alu_tb.v
    ├── decoder_tb.v
    ├── regfile_tb.v
    ├── cpu_core_tb.v
    ├── riscv_cpu_tb.v
    ├── rv32i_tb.v
    └── top_tb.v
```

`build/` holds generated files (`*.hex`, `cpu.json`, `cpu_pnr.json`,
`cpu.fs`, simulation binaries) and is ignored via `.gitignore`.

`project_files.txt` contains some stale content from deleted datapath
files/testbenches and should not be treated as the authoritative source
tree.

## CPU architecture

Single-cycle RV32I: every instruction completes in one 27 MHz clock
cycle.

``` text
  next_pc ──► Instruction ROM (sync read) ──► instruction
     ▲                                             │
     │                                             ▼
     │                    Decoder ──► Immediate generator
     │                       │                     │
     │                       ▼                     ▼
     │               Register file ──► ALU ◄── (rs2 or imm)
     │                 (rs1, rs2)       │
     │                       │          ├──► data address ──► Data RAM / LED reg
     │                       ▼          │                          │
     └── Branch / jump logic (pc+4, pc+imm, rs1+imm)                ▼
                                       Write back ◄── ALU / load data / pc+4
```

-   **Fetch:** the instruction ROM is read synchronously so it maps to
    block RAM. It is addressed with `next_pc` (0 during reset), so the
    word registered on a clock edge is the instruction for the PC loaded
    on that same edge.
-   **Registers:** 32 × 32-bit, two asynchronous read ports, mapped to
    distributed RAM. `x0` reads as zero and writes to it are ignored.
    Registers are zeroed at FPGA configuration but **not** by the reset
    button (RISC-V does not require it; programs initialize what they
    use).
-   **Loads/stores:** the core aligns byte/halfword data and generates
    byte strobes. Misaligned accesses are not supported (they are not
    trapped; results are undefined).
-   **Not implemented:** `FENCE`, `ECALL`, `EBREAK` and CSR
    instructions execute as no-ops; there are no traps or interrupts.
    Unknown or reserved encodings are no-ops too.

### Memory map

| Address | Size | Contents |
|---|---|---|
| `0x0000_0000` | 4 KB | Instruction ROM (fetch only; not readable by loads) |
| `0x0001_0000` | 1 KB | Data RAM (mirrored across `0x0001_xxxx`) |
| `0x1000_0000` | 1 word | LED register, bits `[3:0]`, read/write |

Other addresses read as 0 and ignore writes. The LED register is
cleared by reset.

## Supported instructions

All RV32I base integer instructions except the system/fence group:

| Class | Instructions |
|---|---|
| Register ALU | `add sub sll slt sltu xor srl sra or and` |
| Immediate ALU | `addi slti sltiu xori ori andi slli srli srai` |
| Loads | `lb lh lw lbu lhu` |
| Stores | `sb sh sw` |
| Branches | `beq bne blt bge bltu bgeu` |
| Jumps | `jal jalr` |
| Upper immediate | `lui auipc` |
| No-op | `fence ecall ebreak`, CSR ops, unknown encodings |

## Writing programs

Programs are RISC-V assembly files in `programs/`, assembled by
`tools/asm2hex.py` with LLVM's `llvm-mc` (Homebrew `llvm`; already
installed). The script produces a hex image for the instruction ROM,
padded with NOPs to 1024 words.

Rules, because there is no linker:

-   Code starts at address 0. Only the `.text` section is used.
-   Use `li` for constants and `j`/`jal`/`ret` for control flow.
-   `la`, `call` and references to `.data` need a linker and are
    rejected (the script fails on any unresolved relocation).
-   Initialize RAM with stores at runtime (RAM is at `0x10000`; a stack
    can start at `0x10400` and grow down).
-   Write to `0x1000_0000` to drive the LEDs.

Example (`programs/led_counter.S`, the default demo):

``` asm
    li   sp, 0x00010400
    li   s0, 0x10000000         # LED register
    li   s1, 0
loop:
    sw   s1, 0(s0)
    addi s1, s1, 1
    jal  ra, delay              # ~0.2 s busy-wait
    j    loop
```

## Testing

``` bash
./test.sh
```

assembles `programs/basic.S` and `programs/rv32i_test.S` and runs every
testbench in `tb/`:

``` text
ALU TB: ALL TESTS PASSED
CPU_CORE TB: ALL TESTS PASSED
DECODER TB: ALL TESTS PASSED
regfile_tb: ran (no self-check)
RISCV_CPU TB: ALL TESTS PASSED
RV32I TB: ALL TESTS PASSED (57 checks, 253 cycles)
TOP TB: ALL TESTS PASSED
```

-   `rv32i_tb.v` runs `programs/rv32i_test.S`, which checks every
    instruction class and reports the number of the first failing check.
    (Sanity-checked by breaking `sra` in a scratch copy: it failed at
    check 12, the `sra` check.)
-   `top_tb.v` runs the same program through the FPGA top and checks the
    LED pins, including the reset button.
-   `decoder_tb.v`, `alu_tb.v` and `cpu_core_tb.v` check the units
    directly, including reserved encodings that must be no-ops.
-   `riscv_cpu_tb.v` runs the original 4-instruction program.

The same `rv32i_test.S` runs on the board: **all four LEDs steady on**
means pass; on failure the failing check number (low 4 bits) blinks.

## FPGA top

`src/top.v` instantiates the CPU and drives the LEDs from the LED
register:

-   **Clock:** the CPU runs directly from the 27 MHz clock. nextpnr is
    given `--freq 27`; the current design reaches about 54 MHz.
-   **Reset:** a 16-cycle power-on reset after configuration, plus the
    S0 button (`T10`, active-low) while held. Reset clears the PC and
    the LED register (not the registers or RAM).
-   **LEDs:** the Dock LEDs are **active-low** (verified on hardware), so
    `top.v` drives `led = ~leds` and a lit LED means a 1 bit.

| Bit | Pin | Dock LED |
|---|---|---|
| `led[3]` | `N16` | LED2 |
| `led[2]` | `N14` | LED3 |
| `led[1]` | `L14` | LED4 |
| `led[0]` | `L16` | LED5 |

Pins match Sipeed's TangPrimer-20K-example HDMI demo. LED0/LED1
(`C13`, `A13`) are not used.

Resource use (with `rv32i_test.S`): about 5,000 LUT4 (24%), 160
`RAM16SDP4` (register file + data RAM), 2 BSRAM (instruction ROM).

## Build toolchain

The working open-source flow is:

``` text
RISC-V assembly ──llvm-mc──► ROM hex
Verilog + ROM hex
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
-   LLVM (Homebrew `llvm`: `llvm-mc`, `llvm-objcopy`, `llvm-objdump`)
-   Python 3

The local nextpnr executable is:

``` text
~/nextpnr/build/nextpnr-himbaechel
```

## Build

From the repository root:

``` bash
./build.sh                        # programs/led_counter.S
./build.sh programs/rv32i_test.S  # any program
openFPGALoader -b tangprimer20k build/cpu.fs
```

`build.sh` assembles the program into `build/program.hex`, then runs
Yosys, nextpnr (with `--freq 27`) and gowin_pack to produce
`build/cpu.fs`. Place and route takes a few minutes.

The known-good reference flow also uses these Tang Primer 20K
parameters (see the Apicula Tang Primer 20K example).

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

SRAM programming command:

``` bash
openFPGALoader -b tangprimer20k --write-sram build/cpu.fs
```

This works: the bitstream loads, the FPGA reports `Done Final`, and
the design runs. SRAM configuration is lost on power-off; reload after
each power cycle.

### Requirement: Dock DIP switch 1 down

On the Tang Primer 20K Dock, **DIP switch 1 must be in the down
position** (core board enabled). Sipeed's wiki documents this.

With the switch up, JTAG detection still works (IDCODE and status
registers read correctly), but programming hangs forever after
`Erase SRAM` with repeated:

``` text
pollFlag: 20 (0)
```

### What the hang actually was

The hang was **not** in the SRAM erase itself. In openFPGALoader's
Gowin code (`src/gowin.cpp`), `eraseSRAM()` first sends `CONFIG_ENABLE`
(0x15) and waits for the "System Edit Mode" status bit (0x80).
`pollFlag: 20 (0)` means status was `0x20` and `status & 0x80 == 0`:
the FPGA was ignoring `CONFIG_ENABLE`. The erase command had not been
sent yet.

A working load shows the edit-mode bit set straight away:

``` text
pollFlag: 60a0 (80)
after erase sram: displayReadReg 000000a0
        Memory Erase
        System Edit Mode
...
after program sram: displayReadReg 00006020
        Memory Erase
        Done Final
        Security Final
```

If programming hangs at `pollFlag: 20 (0)` again:

1.  Check DIP switch 1 is down.
2.  Kill any stuck loader (`pkill openFPGALoader`), unplug USB for about
    10 s, and plug it directly into the Mac (no hub).
3.  Sipeed's recovery trick: start the load, and while it waits, flip
    DIP switch 1 up and back down.

Lowering the JTAG frequency does not help. Neither the bitstream nor
the openFPGALoader version (v1.1.1) was the cause.

## Debugging notes

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

3.  Lowering JTAG frequency to fix a programming hang.

    Tested down to 500 kHz; it made no difference. The real cause was
    DIP switch 1.

4.  Assuming `SecurityBit: ON` proves the bitstream is invalid.

    Known Tang Primer programming logs also report `SecurityBit: ON`,
    and this project's bitstream loads fine with it.

5.  Assuming JTAG detection proves the board is ready to program.

    IDCODE reads worked even while DIP switch 1 was up and programming
    was impossible.

## Next steps

Done: RV32I on the FPGA, an assembly-to-ROM workflow, and a self-test
that passes on hardware.

Possible next steps:

-   A UART for text output (printing results instead of reading LEDs).
-   Loading programs over UART without rebuilding the bitstream.
-   A linker script so `.data`, `la` and `call` work (needs `ld.lld`).
-   Traps and the `Zicsr` extension; then `ECALL`/`EBREAK`.
-   The `M` extension (multiply/divide).
-   Pipelining, once the single-cycle design is the bottleneck.

## Repository

GitHub:

https://github.com/juanedosanchez/riscv-cpu
