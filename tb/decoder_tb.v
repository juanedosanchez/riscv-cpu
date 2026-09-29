`timescale 1ns/1ps

module decoder_tb;

    reg [31:0] instruction;

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;

    wire [2:0] alu_operation;

    wire write_enable;

    decoder uut (
        .instruction(instruction),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_operation(alu_operation),

        .write_enable(write_enable)
    );

    initial begin

        // add x3, x1, x2
        instruction = 32'b0000000_00010_00001_000_00011_0110011;

        #10;

        $display("Instruction: ADD x3, x1, x2");
        $display("rs1 = %d", rs1);
        $display("rs2 = %d", rs2);
        $display("rd  = %d", rd);
        $display("ALU operation = %b", alu_operation);
        $display("write enable = %b", write_enable);

        $finish;

    end

endmodule