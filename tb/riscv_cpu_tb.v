`timescale 1ns/1ps

module riscv_cpu_tb;

    reg clk;
    reg reset;

    wire [31:0] debug_x3;

    riscv_cpu uut (
        .clk(clk),
        .reset(reset),
        .debug_x3(debug_x3)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        reset = 1;

        #20;

        reset = 0;

        #50;

        $display("x3 = %d", debug_x3);

        $finish;
    end

endmodule