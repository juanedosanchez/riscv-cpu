`timescale 1ns/1ps

module cpu_core_tb;

    reg clk;
    reg reset;
    reg [31:0] instruction;

    wire [31:0] debug_x3;

    integer errors;

    cpu_core uut (
        .clk(clk),
        .reset(reset),
        .instruction(instruction),
        .debug_x3(debug_x3)
    );

    always #5 clk = ~clk;

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

    // Instructions change on the falling edge; the core writes back on the rising edge.
    initial begin

        clk         = 0;
        reset       = 1;
        errors      = 0;
        instruction = 32'h00000013;  // nop

        #20;
        reset = 0;

        instruction = 32'h00A00093;  // addi x1, x0, 10
        #10;
        instruction = 32'h00300113;  // addi x2, x0, 3
        #10;
        instruction = 32'h002081B3;  // add  x3, x1, x2
        #10;
        instruction = 32'h0020C2B3;  // xor  x5, x1, x2 (unsupported: must not write)
        #10;
        instruction = 32'h00000013;  // nop
        #10;

        check_reg(1, uut.register_file.registers[1], 32'd10);
        check_reg(2, uut.register_file.registers[2], 32'd3);
        check_reg(3, uut.register_file.registers[3], 32'd13);
        check_reg(5, uut.register_file.registers[5], 32'd0);

        if (debug_x3 === 32'd13)
            $display("PASS: debug_x3 = %0d", debug_x3);
        else begin
            $display("FAIL: debug_x3 = %0d (expected 13)", debug_x3);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("CPU_CORE TB: ALL TESTS PASSED");
        else
            $display("CPU_CORE TB: %0d TEST(S) FAILED", errors);

        $finish;

    end

endmodule
