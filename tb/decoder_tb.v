`timescale 1ns/1ps

module decoder_tb;

    reg [31:0] instruction;

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [2:0] funct3;

    wire [3:0] alu_operation;
    wire [1:0] alu_src_a;
    wire       use_immediate;
    wire       write_enable;
    wire [1:0] wb_select;
    wire       mem_read;
    wire       mem_write;
    wire       branch;
    wire       jal;
    wire       jalr;

    integer errors;

    decoder uut (
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .funct3(funct3),
        .alu_operation(alu_operation),
        .alu_src_a(alu_src_a),
        .use_immediate(use_immediate),
        .write_enable(write_enable),
        .wb_select(wb_select),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jal(jal),
        .jalr(jalr)
    );

    // Control bits other than write_enable/use_immediate/alu_operation:
    // {alu_src_a[1:0], wb_select[1:0], mem_read, mem_write, branch, jal, jalr}
    wire [8:0] control = {alu_src_a, wb_select, mem_read, mem_write, branch, jal, jalr};

    localparam C_NONE   = 9'b00_00_00000;
    localparam C_LOAD   = 9'b00_01_10000;
    localparam C_STORE  = 9'b00_00_01000;
    localparam C_BRANCH = 9'b00_00_00100;
    localparam C_JAL    = 9'b00_10_00010;
    localparam C_JALR   = 9'b00_10_00001;
    localparam C_LUI    = 9'b10_00_00000;
    localparam C_AUIPC  = 9'b01_00_00000;

    // alu_operation is only checked for instructions that use the ALU result
    // or address (exp_op = 4'bxxxx skips the check).
    task check;
        input [8*24-1:0] name;
        input [31:0]     instr;
        input            exp_we;
        input            exp_imm;
        input [3:0]      exp_op;
        input [8:0]      exp_control;
        begin
            instruction = instr;
            #10;
            if (write_enable !== exp_we || control !== exp_control ||
                (exp_we && use_immediate !== exp_imm) ||
                (exp_op !== 4'bxxxx && alu_operation !== exp_op)) begin
                $display("FAIL: %0s  we=%b imm=%b op=%b ctl=%b (expected we=%b imm=%b op=%b ctl=%b)",
                         name, write_enable, use_immediate, alu_operation, control,
                         exp_we, exp_imm, exp_op, exp_control);
                errors = errors + 1;
            end
            else
                $display("PASS: %0s", name);
        end
    endtask

    initial begin

        errors = 0;

        // Field extraction for add x3, x1, x2
        instruction = 32'b0000000_00010_00001_000_00011_0110011;
        #10;
        if (rs1 !== 5'd1 || rs2 !== 5'd2 || rd !== 5'd3 || funct3 !== 3'b000) begin
            $display("FAIL: field extraction rs1=%0d rs2=%0d rd=%0d", rs1, rs2, rd);
            errors = errors + 1;
        end
        else
            $display("PASS: field extraction rs1=%0d rs2=%0d rd=%0d", rs1, rs2, rd);

        // R-type
        check("add",  32'b0000000_00010_00001_000_00011_0110011, 1, 0, 4'b0000, C_NONE);
        check("sub",  32'b0100000_00010_00001_000_00011_0110011, 1, 0, 4'b0001, C_NONE);
        check("sll",  32'b0000000_00010_00001_001_00011_0110011, 1, 0, 4'b0101, C_NONE);
        check("slt",  32'b0000000_00010_00001_010_00011_0110011, 1, 0, 4'b1000, C_NONE);
        check("sltu", 32'b0000000_00010_00001_011_00011_0110011, 1, 0, 4'b1001, C_NONE);
        check("xor",  32'b0000000_00010_00001_100_00011_0110011, 1, 0, 4'b0100, C_NONE);
        check("srl",  32'b0000000_00010_00001_101_00011_0110011, 1, 0, 4'b0110, C_NONE);
        check("sra",  32'b0100000_00010_00001_101_00011_0110011, 1, 0, 4'b0111, C_NONE);
        check("or",   32'b0000000_00010_00001_110_00011_0110011, 1, 0, 4'b0011, C_NONE);
        check("and",  32'b0000000_00010_00001_111_00011_0110011, 1, 0, 4'b0010, C_NONE);

        // I-type arithmetic
        check("addi",  32'b000000000101_00001_000_00011_0010011, 1, 1, 4'b0000, C_NONE);
        check("slti",  32'b000000000101_00001_010_00011_0010011, 1, 1, 4'b1000, C_NONE);
        check("sltiu", 32'b000000000101_00001_011_00011_0010011, 1, 1, 4'b1001, C_NONE);
        check("xori",  32'b000000000101_00001_100_00011_0010011, 1, 1, 4'b0100, C_NONE);
        check("ori",   32'b000000000101_00001_110_00011_0010011, 1, 1, 4'b0011, C_NONE);
        check("andi",  32'b000000000101_00001_111_00011_0010011, 1, 1, 4'b0010, C_NONE);
        check("slli",  32'b0000000_00101_00001_001_00011_0010011, 1, 1, 4'b0101, C_NONE);
        check("srli",  32'b0000000_00101_00001_101_00011_0010011, 1, 1, 4'b0110, C_NONE);
        check("srai",  32'b0100000_00101_00001_101_00011_0010011, 1, 1, 4'b0111, C_NONE);

        // Loads / stores (address = rs1 + imm via ADD)
        check("lb",  32'b000000000100_00001_000_00011_0000011, 1, 1, 4'b0000, C_LOAD);
        check("lh",  32'b000000000100_00001_001_00011_0000011, 1, 1, 4'b0000, C_LOAD);
        check("lw",  32'b000000000100_00001_010_00011_0000011, 1, 1, 4'b0000, C_LOAD);
        check("lbu", 32'b000000000100_00001_100_00011_0000011, 1, 1, 4'b0000, C_LOAD);
        check("lhu", 32'b000000000100_00001_101_00011_0000011, 1, 1, 4'b0000, C_LOAD);
        check("sb",  32'b0000000_00010_00001_000_00100_0100011, 0, 1, 4'b0000, C_STORE);
        check("sh",  32'b0000000_00010_00001_001_00100_0100011, 0, 1, 4'b0000, C_STORE);
        check("sw",  32'b0000000_00010_00001_010_00100_0100011, 0, 1, 4'b0000, C_STORE);

        // Branches
        check("beq",  32'b0000000_00010_00001_000_01000_1100011, 0, 0, 4'bxxxx, C_BRANCH);
        check("bne",  32'b0000000_00010_00001_001_01000_1100011, 0, 0, 4'bxxxx, C_BRANCH);
        check("blt",  32'b0000000_00010_00001_100_01000_1100011, 0, 0, 4'bxxxx, C_BRANCH);
        check("bge",  32'b0000000_00010_00001_101_01000_1100011, 0, 0, 4'bxxxx, C_BRANCH);
        check("bltu", 32'b0000000_00010_00001_110_01000_1100011, 0, 0, 4'bxxxx, C_BRANCH);
        check("bgeu", 32'b0000000_00010_00001_111_01000_1100011, 0, 0, 4'bxxxx, C_BRANCH);

        // Jumps and upper immediates
        check("jal",   32'h008000EF,                              1, 0, 4'bxxxx, C_JAL);
        check("jalr",  32'b000000000100_00001_000_00011_1100111,  1, 1, 4'b0000, C_JALR);
        check("lui",   32'h123450B7,                              1, 1, 4'b0000, C_LUI);
        check("auipc", 32'h00001097,                              1, 1, 4'b0000, C_AUIPC);

        // Unsupported or reserved encodings: no side effects
        check("mul (M ext)",       32'b0000001_00010_00001_000_00011_0110011, 0, 0, 4'bxxxx, C_NONE);
        check("and (f7=0100000)",  32'b0100000_00010_00001_111_00011_0110011, 0, 0, 4'bxxxx, C_NONE);
        check("slli (f7!=0)",      32'b0100000_00101_00001_001_00011_0010011, 0, 0, 4'bxxxx, C_NONE);
        check("srli (bad f7)",     32'b0000001_00101_00001_101_00011_0010011, 0, 0, 4'bxxxx, C_NONE);
        check("load funct3=011",   32'b000000000100_00001_011_00011_0000011,  0, 0, 4'bxxxx, C_NONE);
        check("store funct3=011",  32'b0000000_00010_00001_011_00100_0100011, 0, 0, 4'bxxxx, C_NONE);
        check("branch funct3=010", 32'b0000000_00010_00001_010_01000_1100011, 0, 0, 4'bxxxx, C_NONE);
        check("jalr funct3=001",   32'b000000000100_00001_001_00011_1100111,  0, 0, 4'bxxxx, C_NONE);
        check("fence",             32'h0FF0000F,                              0, 0, 4'bxxxx, C_NONE);
        check("ecall",             32'h00000073,                              0, 0, 4'bxxxx, C_NONE);
        check("unknown opcode",    32'h0000007F,                              0, 0, 4'bxxxx, C_NONE);

        if (errors == 0)
            $display("DECODER TB: ALL TESTS PASSED");
        else
            $display("DECODER TB: %0d TEST(S) FAILED", errors);

        $finish;

    end

endmodule
