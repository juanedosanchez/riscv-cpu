module riscv_cpu (
    input wire clk,
    input wire reset,
    output wire [31:0] debug_x3
);

    wire [31:0] pc_address;
    wire [31:0] instruction;

    pc program_counter (
        .clk(clk),
        .reset(reset),
        .address(pc_address)
    );

    instruction_mem instruction_memory (
        .address(pc_address),
        .instruction(instruction)
    );

    cpu_core core (
        .clk(clk),
        .reset(reset),
        .instruction(instruction)
    );

    assign debug_x3 = core.register_file.registers[3];

endmodule