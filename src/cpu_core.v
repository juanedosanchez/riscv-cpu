module cpu_core (
    input wire        clk,
    input wire        reset,
    input wire [31:0] instruction
);

    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;

    wire [2:0] alu_operation;

    wire write_enable;
    wire use_immediate;

    wire [31:0] data1;
    wire [31:0] data2;

    wire [31:0] immediate;
    wire [31:0] alu_result;
    wire [31:0] alu_b;

    decoder decoder_unit (
        .instruction(instruction),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .alu_operation(alu_operation),
        .write_enable(write_enable),
        .use_immediate(use_immediate)
    );

    imm_gen immediate_generator (
        .instruction(instruction),
        .immediate(immediate)
    );

    regfile register_file (
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .data1(data1),
        .data2(data2),
        .rd(rd),
        .write_data(alu_result),
        .write_enable(write_enable)
    );

    assign alu_b = use_immediate ? immediate : data2;

    alu alu_unit (
        .a(data1),
        .b(alu_b),
        .operation(alu_operation),
        .result(alu_result)
    );

endmodule