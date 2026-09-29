`timescale 1ns/1ps

module regfile_tb;

    reg clk;

    reg [4:0] rs1;
    reg [4:0] rs2;

    wire [31:0] data1;
    wire [31:0] data2;

    reg [4:0] rd;
    reg [31:0] write_data;
    reg write_enable;

    regfile uut (
        .clk(clk),

        .rs1(rs1),
        .rs2(rs2),

        .data1(data1),
        .data2(data2),

        .rd(rd),
        .write_data(write_data),
        .write_enable(write_enable)
    );

    // Clock: period = 10 ns
    always #5 clk = ~clk;

    initial begin

        clk = 0;

        rs1 = 0;
        rs2 = 0;

        rd = 0;
        write_data = 0;
        write_enable = 0;

        // Write 10 to x1
        #2;
        rd = 5'd1;
        write_data = 32'd10;
        write_enable = 1;

        #10;

        // Write 3 to x2
        rd = 5'd2;
        write_data = 32'd3;

        #10;

        write_enable = 0;

        // Read x1 and x2
        rs1 = 5'd1;
        rs2 = 5'd2;

        #2;

        $display("x1 = %d", data1);
        $display("x2 = %d", data2);

        // Try to write x0
        rd = 5'd0;
        write_data = 32'd123;
        write_enable = 1;

        #10;

        write_enable = 0;

        rs1 = 5'd0;

        #2;

        $display("x0 = %d", data1);

        $finish;

    end

endmodule