# The original hardcoded program. Used by tb/riscv_cpu_tb.v.
# Expected: x1 = 10, x2 = 3, x3 = 13, x4 = 7

    addi x1, x0, 10
    addi x2, x0, 3
    add  x3, x1, x2
    sub  x4, x1, x2

done:
    j done
