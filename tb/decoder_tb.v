`timescale 1ns/1ps

module decoder_tb;

    reg [31:0] instruction;

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;

    wire [2:0] alu_operation;

    wire write_enable;
    wire use_immediate;

    integer errors;

    decoder uut (
        .instruction(instruction),

        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),

        .alu_operation(alu_operation),

        .write_enable(write_enable),
        .use_immediate(use_immediate)
    );

    // Apply an instruction and compare decoder outputs.
    // For instructions that must not write back, alu_operation is not checked.
    task check;
        input [8*24-1:0] name;
        input [31:0]     instr;
        input            exp_we;
        input            exp_imm;
        input [2:0]      exp_op;
        begin
            instruction = instr;
            #10;
            if (write_enable !== exp_we ||
                (exp_we && (use_immediate !== exp_imm || alu_operation !== exp_op))) begin
                $display("FAIL: %0s  we=%b imm=%b op=%b (expected we=%b imm=%b op=%b)",
                         name, write_enable, use_immediate, alu_operation,
                         exp_we, exp_imm, exp_op);
                errors = errors + 1;
            end
            else begin
                $display("PASS: %0s  we=%b imm=%b op=%b",
                         name, write_enable, use_immediate, alu_operation);
            end
        end
    endtask

    initial begin

        errors = 0;

        // Field extraction for add x3, x1, x2
        instruction = 32'b0000000_00010_00001_000_00011_0110011;
        #10;
        if (rs1 !== 5'd1 || rs2 !== 5'd2 || rd !== 5'd3) begin
            $display("FAIL: field extraction rs1=%0d rs2=%0d rd=%0d", rs1, rs2, rd);
            errors = errors + 1;
        end
        else
            $display("PASS: field extraction rs1=%0d rs2=%0d rd=%0d", rs1, rs2, rd);

        // Supported R-type
        check("add  x3, x1, x2", 32'b0000000_00010_00001_000_00011_0110011, 1'b1, 1'b0, 3'b000);
        check("sub  x4, x1, x2", 32'b0100000_00010_00001_000_00100_0110011, 1'b1, 1'b0, 3'b001);
        check("and  x5, x1, x2", 32'b0000000_00010_00001_111_00101_0110011, 1'b1, 1'b0, 3'b010);
        check("or   x6, x1, x2", 32'b0000000_00010_00001_110_00110_0110011, 1'b1, 1'b0, 3'b011);

        // Supported I-type arithmetic
        check("addi x1, x0, 10", 32'h00A00093,                               1'b1, 1'b1, 3'b000);
        check("andi x7, x1, 6",  32'b000000000110_00001_111_00111_0010011,  1'b1, 1'b1, 3'b010);
        check("ori  x8, x1, 5",  32'b000000000101_00001_110_01000_0010011,  1'b1, 1'b1, 3'b011);

        // Unsupported: must NOT write back
        check("xor  x3, x1, x2", 32'b0000000_00010_00001_100_00011_0110011, 1'b0, 1'b0, 3'b000);
        check("sll  x3, x1, x2", 32'b0000000_00010_00001_001_00011_0110011, 1'b0, 1'b0, 3'b000);
        check("mul  x3, x1, x2", 32'b0000001_00010_00001_000_00011_0110011, 1'b0, 1'b0, 3'b000);
        check("and(f7=0100000)", 32'b0100000_00010_00001_111_00011_0110011, 1'b0, 1'b0, 3'b000);
        check("xori x3, x1, 1",  32'b000000000001_00001_100_00011_0010011,  1'b0, 1'b0, 3'b000);
        check("slti x3, x1, 1",  32'b000000000001_00001_010_00011_0010011,  1'b0, 1'b0, 3'b000);
        check("lw   x3, 0(x1)",  32'b000000000000_00001_010_00011_0000011,  1'b0, 1'b0, 3'b000);

        if (errors == 0)
            $display("DECODER TB: ALL TESTS PASSED");
        else
            $display("DECODER TB: %0d TEST(S) FAILED", errors);

        $finish;

    end

endmodule
