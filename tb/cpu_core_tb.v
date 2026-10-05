`timescale 1ns/1ps

// Drives cpu_core directly (no PC register or memories): instructions are
// applied one per cycle and next_pc / the data bus are checked.
module cpu_core_tb;

    reg clk;
    reg reset;
    reg [31:0] pc;
    reg [31:0] instruction;
    reg [31:0] mem_read_data;

    wire [31:0] next_pc;
    wire [31:0] mem_address;
    wire [31:0] mem_write_data;
    wire [3:0]  mem_write_strobe;
    wire        mem_read_done;
    wire [31:0] debug_x3;

    integer errors;

    cpu_core uut (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instruction(instruction),
        .next_pc(next_pc),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_write_strobe(mem_write_strobe),
        .mem_read_data(mem_read_data),
        .mem_read_done(mem_read_done),
        .debug_x3(debug_x3)
    );

    always #5 clk = ~clk;

    task check;
        input [8*32-1:0] name;
        input [31:0]     actual;
        input [31:0]     expected;
        begin
            if (actual === expected)
                $display("PASS: %0s = 0x%08h", name, actual);
            else begin
                $display("FAIL: %0s = 0x%08h (expected 0x%08h)", name, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    // Instructions change on the falling edge; the core writes back on the rising edge.
    initial begin

        clk           = 0;
        reset         = 1;
        errors        = 0;
        pc            = 32'd0;
        instruction   = 32'h00000013;  // nop
        mem_read_data = 32'd0;

        #20;
        reset = 0;

        instruction = 32'h00A00093;  // addi x1, x0, 10
        #10;
        instruction = 32'h00300113;  // addi x2, x0, 3
        #10;
        instruction = 32'h002081B3;  // add  x3, x1, x2
        #10;
        instruction = 32'h0020C2B3;  // xor  x5, x1, x2
        #10;
        instruction = 32'h02208333;  // mul  x6, x1, x2 (unsupported: must not write)
        #10;

        check("x1", uut.register_file.registers[1], 32'd10);
        check("x2", uut.register_file.registers[2], 32'd3);
        check("x3", uut.register_file.registers[3], 32'd13);
        check("x5 (xor)", uut.register_file.registers[5], 32'd9);
        check("x6 (mul ignored)", uut.register_file.registers[6], 32'd0);
        check("debug_x3", debug_x3, 32'd13);

        // next_pc: sequential, branch taken / not taken, jal, jalr
        pc = 32'h100;

        instruction = 32'h00000013;  // nop
        #1 check("next_pc nop", next_pc, 32'h104);

        instruction = 32'h00108463;  // beq x1, x1, +8
        #1 check("next_pc beq taken", next_pc, 32'h108);

        instruction = 32'h00208463;  // beq x1, x2, +8
        #1 check("next_pc beq not taken", next_pc, 32'h104);

        instruction = 32'hFE20CEE3;  // blt x1, x2, -4 (10 < 3 false)
        #1 check("next_pc blt not taken", next_pc, 32'h104);

        instruction = 32'hFE114EE3;  // blt x2, x1, -4 (3 < 10 true)
        #1 check("next_pc blt backward", next_pc, 32'hFC);

        instruction = 32'h0100006F;  // jal x0, +16
        #1 check("next_pc jal", next_pc, 32'h110);

        instruction = 32'h00B08067;  // jalr x0, 11(x1) -> (10 + 11) & ~1 = 20
        #1 check("next_pc jalr", next_pc, 32'h14);

        // Store bus: sb x2, 5(x1) -> address 15, byte lane 3
        instruction = 32'h002082A3;
        #1;
        check("sb address", mem_address, 32'd15);
        check("sb strobe",  {28'd0, mem_write_strobe}, 32'b1000);
        check("sb data",    mem_write_data, 32'h03030303);

        // Load: lb x7, 1(x0) with memory word 0x0000_8000 -> byte 0x80
        // sign-extended. Loads take two cycles: the first holds the PC and
        // must not write back, the second writes back and advances.
        mem_read_data = 32'h00008000;
        instruction   = 32'h00100383;
        #1;
        check("load cycle 1 holds pc", next_pc, 32'h100);
        check("load cycle 1 not done", {31'd0, mem_read_done}, 32'd0);
        @(posedge clk);
        #1;
        check("load cycle 1 no write", uut.register_file.registers[7], 32'd0);
        check("load cycle 2 advances", next_pc, 32'h104);
        check("load cycle 2 done", {31'd0, mem_read_done}, 32'd1);
        @(posedge clk);
        #1;
        check("lb sign-extend", uut.register_file.registers[7], 32'hFFFFFF80);

        if (errors == 0)
            $display("CPU_CORE TB: ALL TESTS PASSED");
        else
            $display("CPU_CORE TB: %0d TEST(S) FAILED", errors);

        $finish;

    end

endmodule
