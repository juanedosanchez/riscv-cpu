`timescale 1ns/1ps

module cpu_core_tb;

    reg clk;
    reg [31:0] instruction;

    cpu_core uut (
        .clk(clk),
        .instruction(instruction)
    );

    always #5 clk = ~clk;

    initial begin

        clk = 0;

        // add x3, x1, x2
        instruction = 32'h002081B3;

        // Wait for one clock cycle
        #10;

        $display("x1 = %d", uut.register_file.registers[1]);
        $display("x2 = %d", uut.register_file.registers[2]);
        $display("x3 = %d", uut.register_file.registers[3]);

        $finish;

    end

endmodule