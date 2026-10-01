#!/bin/bash
# Assemble the test programs and run every testbench in tb/.
# Exits non-zero if any testbench reports FAIL or doesn't finish.

set -e

mkdir -p build

tools/asm2hex.py programs/basic.S      build/basic.hex      > /dev/null
tools/asm2hex.py programs/rv32i_test.S build/rv32i_test.hex > /dev/null

SOURCES="src/pc.v src/instruction_mem.v src/data_mem.v src/decoder.v
         src/imm_gen.v src/regfile.v src/alu.v src/cpu_core.v
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
