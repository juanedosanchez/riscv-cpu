`timescale 1ns/1ps

module riscv_cpu_tb;

    reg clk;
    reg reset;

    wire [31:0] debug_x3;

    integer errors;

    riscv_cpu #(
        .PROGRAM("build/basic.hex")
    ) uut (
        .clk(clk),
        .reset(reset),
        .leds(),
        .debug_x3(debug_x3)
    );

    always #5 clk = ~clk;

    // Hierarchical references are fine in a testbench.
    task check_reg;
        input [4:0]  idx;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual === expected)
                $display("PASS: x%0d = %0d", idx, actual);
            else begin
                $display("FAIL: x%0d = %0d (expected %0d)", idx, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        clk    = 0;
        reset  = 1;
        errors = 0;

        #20;

        reset = 0;

        // 4 instructions + margin (programs/basic.S then loops in place)
        #50;

        check_reg(1, uut.core.register_file.registers[1], 32'd10);
        check_reg(2, uut.core.register_file.registers[2], 32'd3);
        check_reg(3, uut.core.register_file.registers[3], 32'd13);
        check_reg(4, uut.core.register_file.registers[4], 32'd7);

        // debug_x3 port must match x3
        if (debug_x3 === 32'd13)
            $display("PASS: debug_x3 = %0d", debug_x3);
        else begin
            $display("FAIL: debug_x3 = %0d (expected 13)", debug_x3);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("RISCV_CPU TB: ALL TESTS PASSED");
        else
            $display("RISCV_CPU TB: %0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
