// CPU + memories + LED register.
//
// Memory map:
//   0x0000_0000  instruction ROM (4 KB, fetch only)
//   0x0001_0000  data RAM (1 KB, mirrored across 0x0001_xxxx)
//   0x1000_0000  LED register (bits [3:0], read/write)
module riscv_cpu #(
    parameter PROGRAM = "build/program.hex"
) (
    input wire         clk,
    input wire         reset,
    output wire [3:0]  leds,
    output wire [31:0] debug_x3
);

    wire [31:0] pc_address;
    wire [31:0] next_pc;
    wire [31:0] instruction;

    wire [31:0] mem_address;
    wire [31:0] mem_write_data;
    wire [3:0]  mem_write_strobe;
    wire [31:0] mem_read_data;
    wire [31:0] ram_read_data;

    reg  [3:0]  led_reg;

    pc program_counter (
        .clk(clk),
        .reset(reset),
        .next_address(next_pc),
        .address(pc_address)
    );

    // Fetch with the address the PC is about to load (0 during reset), so
    // the registered ROM output always matches pc_address.
    instruction_mem #(
        .INIT_FILE(PROGRAM)
    ) instruction_memory (
        .clk(clk),
        .address(reset ? 32'd0 : next_pc),
        .instruction(instruction)
    );

    cpu_core core (
        .clk(clk),
        .reset(reset),
        .pc(pc_address),
        .instruction(instruction),
        .next_pc(next_pc),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_write_strobe(mem_write_strobe),
        .mem_read_data(mem_read_data),
        .debug_x3(debug_x3)
    );

    // Address decode
    wire ram_select = (mem_address[31:16] == 16'h0001);
    wire led_select = (mem_address[31:28] == 4'h1);

    data_mem data_memory (
        .clk(clk),
        .word_address(mem_address[9:2]),
        .write_data(mem_write_data),
        .write_strobe(ram_select ? mem_write_strobe : 4'b0000),
        .read_data(ram_read_data)
    );

    always @(posedge clk) begin
        if (reset)
            led_reg <= 4'd0;
        else if (led_select && mem_write_strobe[0])
            led_reg <= mem_write_data[3:0];
    end

    assign mem_read_data = ram_select ? ram_read_data :
                           led_select ? {28'd0, led_reg} :
                                        32'd0;

    assign leds = led_reg;

endmodule
