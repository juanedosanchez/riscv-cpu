#!/bin/bash
# Build the test programs and run every testbench in tb/.
# Exits non-zero if any testbench reports FAIL or doesn't finish.

set -e

mkdir -p build

tools/mkprog.py --boot -o build/boot programs/boot.S        > /dev/null
tools/mkprog.py -o build/basic      programs/basic.S         > /dev/null
tools/mkprog.py -o build/rv32i_test programs/rv32i_test.S    > /dev/null
tools/mkprog.py -o build/hello      programs/hello.c         > /dev/null
tools/mkprog.py -o build/io_test    programs/io_test.S       > /dev/null

# topo_tb runs the game with 1 "ms" = 20 cycles instead of 27000
sed 's/^\( *\.equ MS, *\)27000/\120/' programs/topo.S > build/topo_sim.S
grep -q '\.equ MS, *20 ' build/topo_sim.S
tools/mkprog.py -o build/topo_sim   build/topo_sim.S         > /dev/null

SOURCES="src/pc.v src/main_mem.v src/boot_rom.v src/uart_tx.v src/uart_rx.v
         src/decoder.v src/imm_gen.v src/regfile.v src/alu.v src/cpu_core.v
         src/riscv_cpu.v src/top.v"

failed=0

for tb in tb/*_tb.v; do
    name=$(basename "$tb" .v)
    iverilog -g2012 -o "build/$name.vvp" $SOURCES "$tb"
    output=$(vvp -n "build/$name.vvp")

    if echo "$output" | grep -q "FAIL"; then
        echo "$output" | grep "FAIL"
        echo "$name: FAILED"
        failed=1
    elif echo "$output" | grep -q "ALL TESTS PASSED"; then
        echo "$output" | grep "ALL TESTS PASSED"
    else
        # Print-only testbenches (e.g. regfile_tb) have no pass/fail line
        echo "$name: ran (no self-check)"
    fi
done

exit $failed
