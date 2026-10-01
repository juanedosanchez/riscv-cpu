`timescale 1ns/1ps

module alu_tb;

    reg [31:0] a;
    reg [31:0] b;
    reg [3:0]  operation;

    wire [31:0] result;

    integer errors;

    alu uut (
        .a(a),
        .b(b),
        .operation(operation),
        .result(result)
    );

    task check;
        input [8*4-1:0] name;
        input [3:0]     op;
        input [31:0]    expected;
        begin
            operation = op;
            #10;
            if (result === expected)
                $display("PASS: %0s = 0x%08h", name, result);
            else begin
                $display("FAIL: %0s = 0x%08h (expected 0x%08h)", name, result, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin

        errors = 0;

        a = -32'sd7;   // 0xFFFFFFF9
        b = 32'd3;

        check("ADD",  4'b0000, 32'hFFFFFFFC);
        check("SUB",  4'b0001, 32'hFFFFFFF6);
        check("AND",  4'b0010, 32'h00000001);
        check("OR",   4'b0011, 32'hFFFFFFFB);
        check("XOR",  4'b0100, 32'hFFFFFFFA);
        check("SLL",  4'b0101, 32'hFFFFFFC8);
        check("SRL",  4'b0110, 32'h1FFFFFFF);
        check("SRA",  4'b0111, 32'hFFFFFFFF);
        check("SLT",  4'b1000, 32'd1);
        check("SLTU", 4'b1001, 32'd0);

        // Shift amount uses only b[4:0]: 35 -> 3
        b = 32'd35;
        check("SLL",  4'b0101, 32'hFFFFFFC8);

        if (errors == 0)
            $display("ALU TB: ALL TESTS PASSED");
        else
            $display("ALU TB: %0d TEST(S) FAILED", errors);

        $finish;

    end

endmodule
