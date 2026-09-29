`timescale 1ns/1ps

module alu_tb;

    reg [31:0] a;
    reg [31:0] b;
    reg [2:0]  operation;

    wire [31:0] result;

    alu uut (
        .a(a),
        .b(b),
        .operation(operation),
        .result(result)
    );

    initial begin

        // ADD
        a = 10;
        b = 3;
        operation = 3'b000;

        #10;
        $display("ADD: %d", result);

        // SUB
        operation = 3'b001;

        #10;
        $display("SUB: %d", result);

        // AND
        operation = 3'b010;

        #10;
        $display("AND: %d", result);

        // OR
        operation = 3'b011;

        #10;
        $display("OR: %d", result);

        $finish;

    end

endmodule