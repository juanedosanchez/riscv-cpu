# Agent Context --- riscv-cpu

## Mission

Continue development/debugging of:

`juanedosanchez/riscv-cpu`

The project is a hand-built minimal RISC-V CPU in Verilog targeting a
Sipeed Tang Primer 20K FPGA.

**An RV32I CPU runs on the FPGA at 27 MHz** with a 16 KB main RAM, a
1 KB boot ROM holding a UART bootloader, a UART (115200 8N1), four
LEDs, four buttons (S1-S4) and a free-running cycle counter. Programs are written in C or assembly, linked with `ld.lld`
(from Zig) into RAM images, and either preloaded in the bitstream or
uploaded over UART with `tools/upload.py` without rebuilding.

Verified on hardware 2026-10-05 (before buttons): bootloader
prints `RVBOOT`, `upload.py programs/hello.c` uploads (reply `K`),
`hello.c` prints correct output (including software mul/div) and
echoes typed characters. `rv32i_test.S` (57 checks) passes in
simulation and, on 2026-10-06, on the board with the current design
(uploaded with `upload.py`; all four LEDs steady on, reported by the
user).

2026-10-06: buttons S1-S4 and a cycle counter were added, the LED pins
were moved to sit with the buttons, and `programs/topo.S`
(whack-a-mole) runs on the board, preloaded in the bitstream. The user
played it and set the button/LED pairing; that is the only hardware
use of the buttons so far (no other hardware test of them).

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
-   Serial ports on macOS: `/dev/cu.usbserial-14200` (JTAG channel) and
    `/dev/cu.usbserial-14201` (UART channel; numbers depend on the USB
    port). `upload.py` picks the highest-numbered one.
-   **Dock DIP switch 1 must be down** (core board enabled). With it up,
    JTAG detection still works but SRAM programming hangs. See
    "Resolved: SRAM programming hang" below.
-   Clock: 27 MHz

Current constraints:

``` text
clock      H11
reset      T10 (S0, active-low)
uart_tx    M11 (FPGA -> host)
uart_rx    T13 (host -> FPGA)

bit        0    1    2    3
btn_n[i]   T3   T2   D7   C7    (S1-S4, active-low, LVCMOS15 bank)
led[i]     N14  N16  A13  C13   (active-low)
```

Button bit *i* and LED bit *i* are paired: each LED sits with its
button (the user chose this layout for `topo.S` on 2026-10-06). `L16`
and `L14`, used before, are no longer connected. Button pins match
Sipeed's LiteX example for the Dock; UART pins match Sipeed's UART
demo. The Dock LEDs are **active-low** (verified on hardware for the
old pins; the user reported no inversion on the new ones). See
`src/tang_primer_20k.cst`.

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
-   Homebrew LLVM 22.1.8 (`clang`, `llvm-objcopy`, `llvm-size`,
    `llvm-mc`, `llvm-objdump`; RISC-V target included). Homebrew LLVM
    has no `ld.lld`.
-   Zig 0.16.0 unpacked in `~/tools/zig-x86_64-macos-0.16.0`, used only
    for `zig ld.lld`. `tools/mkprog.py` finds it automatically
    (`$LD_LLD` overrides).
-   `gowin_pack`
-   openFPGALoader v1.1.1
-   nextpnr-himbaechel built locally (not on `PATH`)
-   No `timeout` command on this Mac: guard long-running loader calls
    another way.

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

------------------------------------------------------------------------

## Repository state

GitHub repository:

https://github.com/juanedosanchez/riscv-cpu

The repository is public. The GitHub repository is named `riscv-cpu`;
the local clone folder is named `riscv-cpu-tang`
(`~/Documents/Proyectos/riscv-cpu-tang`).

Current top-level structure:

``` text
riscv-cpu/
├── README.md
├── AGENT_CONTEXT.md
├── .gitignore
├── all_files.txt
├── project_files.txt
├── compile_flags.txt  clangd flags for sw/ and programs/*.c
├── build.sh        build bootloader + preloaded program + build/cpu.fs
├── test.sh         build test programs + run all testbenches
├── build/          (generated; gitignored, not on GitHub)
├── programs/       C and assembly programs, plus boot.S (bootloader)
├── sw/             crt0, runtime, rvcpu.h, linker scripts
├── tools/          mkprog.py, upload.py
├── src/            Verilog
└── tb/             testbenches
```

`build/` is a local output directory only (gitignored, as are `*.fs`,
`*.json` and `__pycache__/`). It may still contain stale `*.hex` files
from the old `asm2hex.py` flow; the current flow writes
`*.lane0..3.hex` (RAM) and `boot.hex` (boot ROM).

Important:

`project_files.txt` is stale. It contains content from deleted datapath
files/testbenches. It is not authoritative for the current source tree.

Use the actual files in `src/` and `tb/` as the source of truth.

------------------------------------------------------------------------

## Current source architecture

RV32I. One instruction per 27 MHz cycle, except loads (two cycles).

### Memory map (`src/riscv_cpu.v`)

| Address | Size | Contents |
|---|---|---|
| `0x0000_0000` | 16 KB | Main RAM: code, data, stack (mirrored across `0x0000_xxxx`) |
| `0x0001_0000` | 1 KB | Boot ROM (fetch only; loads cannot read it) |
| `0x1000_0000` | 1 word | LED register, bits `[3:0]`, read/write |
| `0x1000_0004` | 1 word | UART data: write sends a byte, read takes the received byte |
| `0x1000_0008` | 1 word | UART status: bit 0 TX ready, bit 1 RX byte available |
| `0x1000_000C` | 1 word | Buttons, bits `[3:0]` = S1-S4, 1 = pressed (read only, not debounced) |
| `0x1000_0010` | 1 word | Cycle counter, 27 MHz, wraps every ~159 s (read only) |

Reset PC is `0x0001_0000` (`RESET_PC` parameter). Other addresses read
0 and ignore writes. I/O registers decode on `mem_address[31:28] == 1`
and `mem_address[4:2]`, so they are mirrored within `0x1xxx_xxxx`.

### Modules

-   `src/top.v`: FPGA top. 16-cycle power-on reset plus S0 (`btn_n0`,
    active-low). Instantiates `riscv_cpu`, drives `led = ~leds` (Dock
    LEDs are active-low), passes `buttons = ~btn_n` (S1-S4) and
    connects the UART pins. Parameters `PROGRAM` (RAM
    image prefix, default `build/program`), `BOOT_PROGRAM` (default
    `build/boot.hex`), `RESET_PC`, `CLKS_PER_BIT` (234 = 27 MHz /
    115200).
-   `src/riscv_cpu.v`: PC, boot ROM, main RAM, `cpu_core`, LED register,
    UART TX/RX with a one-byte RX buffer (cleared when the CPU's load
    of the data register completes; newest byte wins on overrun), a
    2-flop synchronizer for the buttons (no debounce: programs do it),
    a 32-bit cycle counter cleared by reset, and the address decode
    above. Fetch address is `reset ? RESET_PC :
    next_pc`; a registered `fetch_from_boot` flag selects boot ROM or
    RAM output.
-   `src/cpu_core.v`: decoder, immediate generator, register file, ALU
    operand muxes, branch comparison, next-PC selection (pc+4, pc+imm,
    (rs1+imm)&~1, or hold during a load stall), store data replication
    + byte strobes, load extraction/sign extension, write-back mux
    (ALU, load data, pc+4). **Loads take two cycles**: `load_stall`
    (first cycle) holds the PC and suppresses write-back;
    `mem_read_done` (second cycle) writes back and tells I/O the read
    completed.
-   `src/main_mem.v`: 4096 words as four byte lanes
    (`<prefix>.lane0..3.hex`), two synchronous ports: fetch (read only)
    and data (read + byte-strobed write). Maps to BSRAM.
-   `src/boot_rom.v`: 256 words, `$readmemh`, synchronous read. Maps to
    BSRAM.
-   `src/uart_tx.v`, `src/uart_rx.v`: 8N1, `CLKS_PER_BIT` parameter;
    RX has a 2-flop synchronizer and a one-cycle `valid` pulse.
-   `src/decoder.v`: full RV32I decode. Outputs `alu_operation[3:0]`,
    `alu_src_a` (rs1/pc/zero), `use_immediate`, `write_enable`,
    `wb_select` (ALU/mem/pc+4), `mem_read`, `mem_write`, `branch`, `jal`,
    `jalr`. Reserved encodings (bad funct3/funct7, M-extension, FENCE,
    SYSTEM, unknown opcodes) decode as no-ops with no side effects.
-   `src/imm_gen.v`: I, S, B, U and J immediates.
-   `src/alu.v`: 4-bit op: `0000 ADD, 0001 SUB, 0010 AND, 0011 OR,
    0100 XOR, 0101 SLL, 0110 SRL, 0111 SRA, 1000 SLT, 1001 SLTU`.
    Shifts use `b[4:0]`.
-   `src/pc.v`: PC register, loads `next_address`, resets to
    `RESET_ADDRESS`.
-   `src/regfile.v`: 32 × 32, two async read ports, **no reset**
    (zeroed by an `initial` block at configuration/simulation start).
    Maps to `RAM16SDP4`. `x0` reads zero. `debug_x3` port kept for
    testbenches.
-   `src/blink.v`: old LED blink test, not built.

### Why memories are synchronous and the register file has no reset

The first full-RV32I build used 68% of the LUTs and failed 27 MHz
(26.35 MHz): Yosys could not put an async-read ROM in BSRAM and built a
1024 × 32 mux tree, and the register file's reset loop forced 1024 DFFs
plus per-register write logic. Making the ROM synchronous and dropping
the register reset fixed it. The current design keeps the same rule
for all memories (RAM fetch and data ports, boot ROM), which is why
loads take two cycles.

Current build (`./build.sh programs/topo.S`, 2026-10-06): 3,433 LUT4
(16%), 246 ALU, 458 DFF, 32 `RAM16SDP4` (register file), 17 BSRAM
(36%: 16 KB RAM + boot ROM), 12 IOB. nextpnr: 61.85 MHz max after
routing (PASS at 27 MHz).

### Known limitations

-   Misaligned loads/stores are not trapped (undefined results).
-   No traps, interrupts, CSRs; FENCE/ECALL/EBREAK are no-ops.
-   No `M` extension: clang emits calls to `__mulsi3`, `__divsi3`, etc.,
    provided by `sw/runtime.c`.
-   The boot ROM cannot be read with loads, so the bootloader uses no
    `.rodata`/`.data`/`.bss` (`sw/boot.ld` asserts this).
-   UART RX buffer is one byte; the bootloader's `getc` loop keeps up at
    115200, but a slow program can drop bytes.

------------------------------------------------------------------------

## Programs and software workflow

-   `tools/mkprog.py -o build/NAME src.c [more.S ...]`: compiles with
    Homebrew `clang --target=riscv32-unknown-elf -march=rv32i
    -mabi=ilp32 -O2 -ffreestanding -nostdlib -msmall-data-limit=0
    -mno-relax`, links `sw/crt0.S` + `sw/runtime.c` + sources with
    `sw/link.ld` (16 KB RAM at 0, stack at top, asserts ≥1 KB stack)
    using `zig ld.lld`, and writes `NAME.elf`, `NAME.bin`,
    `NAME.lane0..3.hex`. `--boot` links with `sw/boot.ld` at `0x10000`
    without crt0 and writes `NAME.hex` (256 words, NOP-padded).
-   Programs define `main` (assembly: `.globl main`). crt0 sets `sp`,
    clears `.bss` (RAM survives resets/uploads) and calls `main`.
-   `sw/rvcpu.h`: `LED_REG`, `UART_DATA`, `UART_STATUS`, `BUTTONS`,
    `CYCLES`, `CYCLES_PER_MS`, `BUTTON_S1..S4`, `led_set`,
    `buttons_read`, `cycles_read`, `uart_putc/getc/puts/put_hex/put_dec`,
    `uart_has_data`.
-   `programs/boot.S`: bootloader. Prints `RVBOOT\r\n`, waits ~0.5 s for
    `'L' len:u32 bytes sum:u32` (load at RAM 0, reply `K`/`E`) or `'R'`
    (run); on timeout runs RAM. Jumps to 0 with `jr zero`.
-   `tools/upload.py prog.c|prog.S|image.bin`: builds via mkprog, waits
    for `RVBOOT` (user presses S0), sends the `L` packet, checks `K`,
    then monitors the UART (keys are sent). `--monitor`,
    `--no-monitor`, `--port`. Standard library only (no pyserial).
-   `programs/hello.c`: UART greeting, factorials 1-10,
    `1000000 / 7`, `names[2]` (rodata pointer table), then echo with a
    character count on the LEDs.
-   `programs/topo.S`: whack-a-mole in assembly (the game currently on
    the board). Idle: LEDs alternate 0101/1010 until any button. A
    random LED (one-hot, never the same twice in a row) lights; its
    paired button must be pressed within the window (1.2 s, shrinking
    by 1/8 per hit to 0.3 s). Wrong button or timeout = miss (all LEDs
    flash); 3 misses = game over (3 flashes, then score low 4 bits on
    the LEDs until a button starts a new game). UART text is in
    Spanish (UTF-8, user request 2026-10-06): instructions with the
    button/LED pairing in Dock names (S4-LED0, S3-LED1, S2-LED2,
    S1-LED3) at start-up, then hits, misses ("Fallos: N de 3"; the
    "3" is in the string, not taken from `LIVES`) and the score. Times come from the cycle counter
    (`.equ MS, 27000`); random numbers from a 32-bit Galois LFSR mixed
    with the cycle counter at each pick. Decimal printing uses repeated
    subtraction (no M extension). Tested by `tb/topo_tb.v`.
    Written to the board's SPI flash (2026-10-06): it boots into the
    game on power-up (verified by the user).
-   `programs/topo.c`: old UART echo placeholder, untracked; not the
    game.
-   `programs/io_test.S`: used by `tb/io_tb.v`; checks two back-to-back
    cycle counter reads differ by 2, then copies buttons to LEDs.
-   `programs/led_counter.S`: default preloaded program; counts 0-15 on
    the LEDs (~0.2 s per step).
-   `programs/rv32i_test.S`: self-checking test. Uses `t6` as check
    counter, `t5` as result (`0x600D` pass, `0xBAD` fail), `t4` scratch,
    a 16-byte `.bss` buffer for loads/stores. Pass: LEDs `1111` steady.
    Fail: failing check number (low 4 bits) blinks.
-   `programs/basic.S`: the original 4-instruction program
    (x1=10, x2=3, x3=13, x4=7).

------------------------------------------------------------------------

## Simulation status

`./test.sh` builds the test programs and runs every testbench; it
exits non-zero on any `FAIL`. Current output (2026-10-06):

``` text
ALU TB: ALL TESTS PASSED
BOOT TB: ALL TESTS PASSED
CPU_CORE TB: ALL TESTS PASSED
DECODER TB: ALL TESTS PASSED
IO TB: ALL TESTS PASSED
regfile_tb: ran (no self-check)
RISCV_CPU TB: ALL TESTS PASSED
RV32I TB: ALL TESTS PASSED (57 checks, 292 cycles)
TOP TB: ALL TESTS PASSED
TOPO TB: ALL TESTS PASSED
UART TB: ALL TESTS PASSED
```

-   `tb/rv32i_tb.v`: runs `rv32i_test.S` from RAM (`RESET_PC = 0`),
    waits for `t5` to become `0x600D`/`0xBAD` (note `li t5, 0x600D` is
    lui+addi, so don't stop at the first non-zero value). Verified
    (previous design) to catch a deliberately broken `sra`.
-   `tb/boot_tb.v`: end to end through `top` with `CLKS_PER_BIT = 8`:
    `RVBOOT`, upload of `build/hello.bin`, `K`, then the greeting. RAM
    starts with `build/basic`, so the greeting proves the upload.
-   `tb/uart_tb.v`: `uart_tx` → `uart_rx` loopback.
-   `tb/io_tb.v`: runs `io_test.S`; cycle counter delta = 2, LEDs
    follow the buttons.
-   `tb/topo_tb.v`: runs `topo.S` with a scripted player. `test.sh`
    builds `build/topo_sim` from a copy of `topo.S` with `.equ MS`
    changed from 27000 to 20 (and fails if that substitution stops
    matching). Checks: 10 hits = score 10, wrong button and timeout
    count as misses, game over shows the score on the LEDs, a button
    starts a new game with score 0. About 2 M cycles, ~5 s.
-   `tb/top_tb.v`: `rv32i_test.S` through `top` starting in RAM; checks
    LED pins (`0000` = all lit on pass, `1111` while S0 held, `0000`
    after rerun).
-   `tb/decoder_tb.v`: every RV32I instruction plus reserved encodings.
-   `tb/cpu_core_tb.v`: drives the core directly: write-back, next-PC
    for branches/jumps, store strobes, two-cycle load, sign extension.
-   `tb/alu_tb.v`: every ALU op. `tb/regfile_tb.v`: prints only.
-   `tb/riscv_cpu_tb.v`: `basic.S` (after crt0), checks x1-x4 and
    `debug_x3`.

------------------------------------------------------------------------

## Build and run

``` bash
./build.sh                        # preload programs/led_counter.S
./build.sh programs/topo.S        # preload the whack-a-mole game
./build.sh programs/hello.c       # preload any program
openFPGALoader -b tangprimer20k build/cpu.fs      # SRAM: lost on power-off
openFPGALoader -b tangprimer20k -f build/cpu.fs   # SPI flash: boots on power-up
tools/upload.py programs/hello.c  # then press S0
```

The flash currently holds the `topo.S` bitstream (written 2026-10-06;
it replaced Sipeed's factory demo). An SRAM load runs until the next
power cycle, then the board boots from flash again. A program uploaded
with `upload.py` lasts until the next power cycle as well.

`build.sh` builds `build/boot.hex` and `build/program.lane*.hex`, then
Yosys (`synth_gowin`), nextpnr-himbaechel (`--device
GW2A-LV18PG256C8/I7 --vopt family=GW2A-18 --vopt
cst=src/tang_primer_20k.cst --freq 27`) and `gowin_pack -d GW2A-18`.
The CST is passed to nextpnr only, not gowin_pack. Place and route
takes a few minutes; prefer `upload.py` to try programs.

`--freq 27` matters: without it nextpnr checks timing against a 12 MHz
default, which hid the earlier 26.35 MHz failure.

Hardware check procedure used on 2026-10-05: start a UART listener on
the second `/dev/cu.usbserial-*` port, then load the bitstream; `RVBOOT`
appears right after configuration (no S0 needed). For uploads, start
`upload.py` and ask the user to press S0.

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

The 27 MHz blink design, the original RV32I CPU and the current
CPU + UART + bootloader design all run correctly on hardware, so this
is not currently a problem. If a larger clocked design programs
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
7.  Do not overstate hardware verification. Observed on hardware:
    previous design: `rv32i_test.S` pass (LEDs steady on) and the LED
    counter; 2026-10-05 design: `RVBOOT`, UART upload with `K`,
    `hello.c` output and UART echo; current design (2026-10-06):
    `RVBOOT`, upload, an assembly echo program, `rv32i_test.S` pass
    and `topo.S` played by the user, booting from SPI flash.
    Everything else is verified in simulation only.
8.  Do not drive the Dock LEDs without inverting: they are active-low.
    Do not move the LED or button pins without asking: the pairing
    (T3-N14, T2-N16, D7-A13, C7-C13) was chosen by the user.
9.  Do not make the memories async-read or add a reset loop to the
    register file without checking resource use and timing (see
    "Why memories are synchronous...").
11. Do not put `.rodata`/`.data`/`.bss` in the bootloader: the boot ROM
    is fetch-only.
12. Do not assume the UART port name: it is the higher-numbered
    `/dev/cu.usbserial-*` of the pair and depends on the USB port.
10. Do not build without `--freq 27`; the default constraint is 12 MHz.

------------------------------------------------------------------------

# Next steps

Done: full RV32I on the FPGA, UART, UART bootloader, C/assembly
toolchain with a linker script (`.data`, `la`, `call`), 16 KB RAM,
software mul/div, buttons and cycle counter; bootloader, upload,
`hello.c` and the `topo.S` whack-a-mole game run on hardware.

Possible next steps:

-   traps and `Zicsr`; then `ECALL`/`EBREAK`
-   the `M` extension (multiply/divide) to replace `sw/runtime.c`
-   a larger UART RX FIFO
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

Current state: no open failure. The RV32I CPU with UART, bootloader,
buttons and cycle counter runs on hardware; the board runs the
`topo.S` whack-a-mole game, written to SPI flash, so it boots on
power-up.
