# Minimal RISC-V CPU --- Tang Primer 20K

An RV32I RISC-V CPU implemented in Verilog and running on the Sipeed
Tang Primer 20K FPGA, with a UART, a bootloader, buttons, a cycle
counter and C support. The board currently runs **Topo**, a
whack-a-mole game written in assembly (`programs/topo.S`).

## Project status

The CPU implements the RV32I base integer instruction set and **runs on
the FPGA** at 27 MHz. Programs are written in C or assembly, linked
into a 16 KB RAM, and either built into the bitstream or uploaded over
UART by a bootloader without rebuilding the bitstream.

Current status:

  Stage                         Status
  ----------------------------- ------------------------------------------
  RV32I CPU                     Working (1 cycle/instr, 2 for loads)
  C / assembly → RAM image      Working (clang + `ld.lld` via Zig)
  Icarus Verilog simulation     Working (`./test.sh`, all pass)
  Yosys synthesis               Working
  nextpnr-himbaechel P&R        Working, 27 MHz met (~62 MHz max)
  gowin_pack                    Working
  FPGA SRAM programming         Working (Dock DIP switch 1 must be down)
  UART bootloader on hardware   Working: `RVBOOT`, upload, run (2026-10-05)
  C program on hardware         Working: `hello.c` output + echo (2026-10-05)
  Buttons + cycle counter       Working: `topo.S` played on the board (2026-10-06)

Hardware verification history:

-   2026-10-01, previous design (4 KB instruction ROM, no UART):
    `rv32i_test.S` passed on the board (all four LEDs steady on).
-   2026-10-05, current design: the bootloader prints `RVBOOT` after
    configuration and after S0; `tools/upload.py programs/hello.c`
    uploaded 2097 bytes (`K` reply); `hello.c` printed correct
    factorials and `1000000 / 7 = 142857 remainder 1`; typed characters
    were echoed back. `rv32i_test.S` has not yet been re-run on the
    board with the current design (it passes in simulation).
-   2026-10-06, buttons and cycle counter added, LED pins moved:
    `topo.S` preloaded in the bitstream and played on the board; the
    button/LED pairing below was checked by playing it.

## Hardware

-   Board: Sipeed Tang Primer 20K
-   FPGA: `GW2A-LV18PG256C8/I7`
-   Open-source flow family: `GW2A-18`
-   Programmer board flag: `tangprimer20k`
-   JTAG + UART interface: the Dock's on-board debugger enumerates as an
    FT2232-compatible probe (USB `0403:6010`, manufacturer `SIPEED`,
    product `JTAG Debugger`, serial `FactoryAIOT Pro`). It is reportedly
    a BL702-based FT2232 emulator. On macOS it appears as two serial
    ports: `/dev/cu.usbserial-XXXX0` (JTAG) and `/dev/cu.usbserial-XXXX1`
    (the UART).
-   **Dock DIP switch 1 must be down** (core board enabled) for
    programming to work. See "Programming" below.
-   Clock: 27 MHz on `H11`
-   LEDs (active-low) and buttons (active-low), paired by bit; see
    "FPGA top"
-   Reset button: `T10` (S0, active-low)
-   UART: `uart_tx` on `M11`, `uart_rx` on `T13` (to the Dock's USB
    debugger; same pins as Sipeed's TangPrimer-20K-example UART demo),
    115200 baud, 8N1

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
├── compile_flags.txt   clangd flags for editing C in sw/ and programs/
├── build.sh            build the bitstream (bootloader + preloaded program)
├── test.sh             build test programs + run all testbenches
├── build/              (generated; gitignored, not on GitHub)
├── programs/
│   ├── boot.S          UART bootloader (boot ROM)
│   ├── topo.S          whack-a-mole game (buttons + LEDs)
│   ├── io_test.S       buttons + cycle counter test (io_tb.v)
│   ├── hello.c         C demo: UART output, mul/div, echo
│   ├── led_counter.S   default preloaded program: counts 0-15 on the LEDs
│   ├── rv32i_test.S    self-checking test of every instruction class
│   └── basic.S         the original 4-instruction program
├── sw/
│   ├── crt0.S          startup: stack, clear .bss, call main
│   ├── runtime.c       __mulsi3/__divsi3/..., memset/memcpy/memmove
│   ├── rvcpu.h         LED, UART, button and cycle counter access
│   ├── link.ld         main RAM programs (16 KB at 0)
│   └── boot.ld         bootloader (1 KB boot ROM at 0x10000)
├── tools/
│   ├── mkprog.py       C/assembly -> ELF, .bin and RAM/ROM hex images
│   └── upload.py       upload a program over UART + serial monitor
├── src/
│   ├── top.v           FPGA top: reset, CPU, LEDs, buttons, UART pins
│   ├── riscv_cpu.v     PC + memories + I/O (memory map)
│   ├── cpu_core.v      decode, registers, ALU, branches, load/store
│   ├── pc.v
│   ├── main_mem.v      16 KB RAM, fetch port + data port
│   ├── boot_rom.v      1 KB boot ROM
│   ├── uart_tx.v
│   ├── uart_rx.v
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
    ├── top_tb.v
    ├── uart_tb.v
    ├── io_tb.v
    └── boot_tb.v
```

`build/` holds generated files (`*.elf`, `*.bin`, `*.hex`, `cpu.json`,
`cpu_pnr.json`, `cpu.fs`, simulation binaries) and is ignored via
`.gitignore`.

`project_files.txt` contains some stale content from deleted datapath
files/testbenches and should not be treated as the authoritative source
tree.

## CPU architecture

RV32I. Every instruction completes in one 27 MHz cycle except loads,
which take two.

``` text
  next_pc ──► Main RAM fetch port / Boot ROM (sync read) ──► instruction
     ▲                                                          │
     │                                                          ▼
     │                    Decoder ──► Immediate generator
     │                       │                     │
     │                       ▼                     ▼
     │               Register file ──► ALU ◄── (rs2 or imm)
     │                 (rs1, rs2)       │
     │                       │          ├──► data address ──► RAM data port / LEDs / UART / buttons / cycles
     │                       ▼          │                          │
     └── Branch / jump logic (pc+4, pc+imm, rs1+imm, hold)          ▼
                                       Write back ◄── ALU / load data / pc+4
```

-   **Fetch:** both instruction memories (main RAM fetch port and boot
    ROM) are read synchronously so they map to block RAM. They are
    addressed with `next_pc` (the reset PC during reset), so the word
    registered on a clock edge is the instruction for the PC loaded on
    that same edge. A flag registered alongside selects RAM or boot ROM.
-   **Loads take two cycles:** the RAM data port is synchronous too. In
    a load's first cycle the core presents the address, holds the PC
    and suppresses write-back; in the second it writes back the data
    and advances (`load_stall` / `mem_read_done` in `cpu_core.v`).
    Stores and everything else take one cycle.
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
    Unknown or reserved encodings are no-ops too. There is no `M`
    extension: `sw/runtime.c` provides software multiply/divide.

### Memory map

| Address | Size | Contents |
|---|---|---|
| `0x0000_0000` | 16 KB | Main RAM: code, data, stack (mirrored across `0x0000_xxxx`) |
| `0x0001_0000` | 1 KB | Boot ROM: bootloader (fetch only; not readable by loads) |
| `0x1000_0000` | 1 word | LED register, bits `[3:0]`, read/write |
| `0x1000_0004` | 1 word | UART data: write = send byte, read = take received byte |
| `0x1000_0008` | 1 word | UART status: bit 0 = TX ready, bit 1 = RX byte available |
| `0x1000_000C` | 1 word | Buttons: bits `[3:0]` = S1-S4, 1 = pressed (read only, not debounced) |
| `0x1000_0010` | 1 word | Cycle counter: 27 MHz, wraps every ~159 s (read only) |

The CPU resets to `0x0001_0000` (the bootloader). Other addresses read
as 0 and ignore writes. Reset clears the PC, the LED register and the
UART state and the cycle counter, but not the registers or RAM.

Buttons pass through a 2-flop synchronizer only; programs debounce in
software (e.g. wait until all buttons have been released for 20 ms).

The UART receiver has a one-byte buffer: it is cleared when the CPU
reads the data register, and a new byte overwrites an unread one.

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

Programs are C (`.c`) or assembly (`.S`) files in `programs/`, built by
`tools/mkprog.py` with Homebrew LLVM's `clang` (`-march=rv32i
-mabi=ilp32 -O2`) and linked with `ld.lld`. macOS's Homebrew LLVM has
no `ld.lld`, so `mkprog.py` uses Zig's (`zig ld.lld`, unpacked in
`~/tools/zig-*`); `$LD_LLD` overrides it.

Main RAM programs:

-   are linked with `sw/link.ld` at address 0, after `sw/crt0.S` (stack
    at the top of RAM, `.bss` cleared, then `main`) and `sw/runtime.c`;
-   define `main` (C or a `.globl main` label in assembly);
-   can use `.text`, `.rodata`, `.data`, `.bss`, `la` and `call`;
-   use `sw/rvcpu.h` for the I/O (`led_set`, `buttons_read`,
    `cycles_read`, `CYCLES_PER_MS`, `uart_putc`, `uart_getc`,
    `uart_puts`, `uart_put_dec`, `uart_put_hex`).

`mkprog.py -o build/NAME source.c` writes `NAME.elf`, `NAME.bin` (raw
image, for upload) and `NAME.lane0..3.hex` (byte lanes for
`src/main_mem.v`). With `--boot` it links with `sw/boot.ld` at
`0x10000`, without crt0, and writes `NAME.hex` for the boot ROM. The
boot ROM is fetch-only, so the bootloader cannot use `.rodata`, `.data`
or `.bss` (the linker script asserts this).

Example (`programs/hello.c`):

``` c
#include "rvcpu.h"

int main(void)
{
    uart_puts("Hello from RISC-V!\n");
    ...
    for (;;) {
        char c = uart_getc();
        uart_putc(c);
        led_set(++counter);
    }
}
```

## Topo: whack-a-mole

`programs/topo.S` is a game in RV32I assembly using the four buttons
and LEDs. Each LED sits with one button (see "FPGA top").

1.  Idle: the LEDs alternate 0101/1010. Press any button to start.
2.  One random LED (the mole) lights up. Press its button before the
    time window ends: 1.2 s at first, 1/8 shorter after each hit, down
    to 0.3 s.
3.  A wrong button or a timeout is a miss: all LEDs flash twice.
4.  After 3 misses the game is over: the LEDs flash three times, then
    show the score (low 4 bits, binary) until a button starts a new
    game.

Hits, misses and the score are also printed on the UART
(`tools/upload.py --monitor`). Run it with:

``` bash
./build.sh programs/topo.S && openFPGALoader -b tangprimer20k build/cpu.fs
# or, with any CPU bitstream already loaded:
tools/upload.py programs/topo.S     # then press S0
```

Timing comes from the cycle counter, randomness from a 32-bit LFSR
mixed with the cycle counter (so the player's timing seeds it).

## Bootloader and uploading

`programs/boot.S` runs from the boot ROM after every reset:

1.  Prints `RVBOOT\r\n`.
2.  Waits about 0.5 s for a command byte:
    -   `'L'` `<length:u32 LE>` `<length bytes>` `<checksum:u32 LE>`:
        loads the bytes into RAM at 0 (checksum = 32-bit sum of the
        bytes), replies `'K'` and runs it, or replies `'E'` and starts
        over;
    -   `'R'`: runs the program already in RAM.
3.  On timeout, runs the program in RAM (the one preloaded in the
    bitstream, or the last one uploaded: RAM survives S0 resets).

Upload and monitor a program without rebuilding the bitstream:

``` bash
tools/upload.py programs/hello.c    # build, wait for RVBOOT, upload, monitor
tools/upload.py --monitor           # only show UART output (keys are sent)
```

`upload.py` waits for `RVBOOT`, so press S0 after starting it. It picks
the highest-numbered `/dev/cu.usbserial-*` port (the UART channel);
`--port` overrides it. It uses only the Python standard library.

## Testing

``` bash
./test.sh
```

builds the bootloader and `basic.S`, `rv32i_test.S`, `hello.c` and
`io_test.S`, then
runs every testbench in `tb/`:

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
UART TB: ALL TESTS PASSED
```

-   `rv32i_tb.v` runs `programs/rv32i_test.S` from RAM, which checks
    every instruction class and reports the number of the first failing
    check.
-   `boot_tb.v` is end to end through the FPGA top: reset, `RVBOOT`,
    upload of `build/hello.bin` over the UART pins, `K`, and the C
    program's greeting. RAM starts with a different program, so the
    greeting can only come from the upload.
-   `uart_tb.v` loops `uart_tx` into `uart_rx`.
-   `io_tb.v` runs `io_test.S`: two back-to-back cycle counter reads
    differ by 2 (a load takes two cycles), and the LEDs follow the
    buttons.
-   `top_tb.v` runs `rv32i_test.S` through the FPGA top (starting in
    RAM) and checks the LED pins, including the reset button.
-   `decoder_tb.v`, `alu_tb.v` and `cpu_core_tb.v` check the units
    directly, including reserved encodings and the two-cycle load.
-   `riscv_cpu_tb.v` runs the original 4-instruction program.

Testbenches use `CLKS_PER_BIT = 8` for the UART to keep simulation
short; the hardware uses 234 (27 MHz / 115200).

`rv32i_test.S` also runs on the board (`./build.sh
programs/rv32i_test.S`, or upload it): **all four LEDs steady on**
means pass; on failure the failing check number (low 4 bits) blinks.

## FPGA top

`src/top.v` instantiates the CPU and connects the LEDs, buttons and
UART pins:

-   **Clock:** the CPU runs directly from the 27 MHz clock. nextpnr is
    given `--freq 27`; the current design reaches about 62 MHz.
-   **Reset:** a 16-cycle power-on reset after configuration, plus the
    S0 button (`T10`, active-low) while held.
-   **LEDs:** the Dock LEDs are **active-low** (verified on hardware), so
    `top.v` drives `led = ~leds` and a lit LED means a 1 bit.

-   **Buttons:** S1-S4 are active-low; `top.v` passes `~btn_n`, so a
    pressed button reads as 1. They are in a 1.5 V bank
    (`LVCMOS15`).

| Bit | Button | Button pin | LED pin |
|---|---|---|---|
| 0 | S1 | `T3` | `N14` |
| 1 | S2 | `T2` | `N16` |
| 2 | S3 | `D7` | `A13` |
| 3 | S4 | `C7` | `C13` |

LED bit *i* sits with button bit *i*. `L16` and `L14` (used before
2026-10-06) are no longer connected. Button pins match Sipeed's LiteX
example for the Dock.

Resource use (`./build.sh programs/topo.S`, 2026-10-06): 3,433 LUT4
(16%), 458 DFF, 32 `RAM16SDP4` (register file), 17 BSRAM (36%: 16 KB
RAM + boot ROM), 12 IOB. nextpnr reports 61.85 MHz max (27 MHz
required).

## Build toolchain

The working open-source flow is:

``` text
C / assembly ──clang + ld.lld (tools/mkprog.py)──► RAM / boot ROM hex
Verilog + hex images
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
-   LLVM (Homebrew `llvm`: `clang`, `llvm-objcopy`, `llvm-size`)
-   Zig 0.16 in `~/tools/zig-x86_64-macos-0.16.0` (for `ld.lld`)
-   Python 3

The local nextpnr executable is:

``` text
~/nextpnr/build/nextpnr-himbaechel
```

## Build

From the repository root:

``` bash
./build.sh                        # preload programs/led_counter.S
./build.sh programs/topo.S        # preload the whack-a-mole game
./build.sh programs/hello.c       # preload any program (.S or .c)
openFPGALoader -b tangprimer20k build/cpu.fs
```

`build.sh` builds the bootloader (`build/boot.hex`) and the preloaded
program (`build/program.lane*.hex`), then runs Yosys, nextpnr (with
`--freq 27`) and gowin_pack to produce `build/cpu.fs`. Place and route
takes a few minutes. To try a different program, uploading it with
`tools/upload.py` is much faster than rebuilding.

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

Done: RV32I on the FPGA, a UART, a UART bootloader, C programs
linked into a 16 KB RAM, buttons, a cycle counter and the Topo game,
all running on hardware.

Possible next steps:

-   Add a Topo testbench (scripted player) to `tb/` and `test.sh`.
-   Re-run `rv32i_test.S` on the board with the current design.
-   Traps and the `Zicsr` extension; then `ECALL`/`EBREAK`.
-   The `M` extension (multiply/divide) to replace `sw/runtime.c`.
-   Pipelining, once the single-cycle design is the bottleneck.

## Repository

GitHub:

https://github.com/juanedosanchez/riscv-cpu
