// 32 x 32-bit register file, two asynchronous read ports, one write port.
//
// No reset: this lets synthesis map it to distributed RAM instead of 1024
// flip-flops plus write logic. Registers are zeroed once at configuration
// (and at the start of simulation); a CPU reset does not clear them.
module regfile (
    input wire         clk,
    input wire         reset,       // unused, kept for interface stability
    input wire [4:0]   rs1,
    input wire [4:0]   rs2,
    output wire [31:0] data1,
    output wire [31:0] data2,
    input wire [4:0]   rd,
    input wire [31:0]  write_data,
    input wire         write_enable,
    output wire [31:0] debug_x3
);

    reg [31:0] registers [0:31];

    integer i;

    initial begin
        for (i = 0; i < 32; i = i + 1)
            registers[i] = 32'd0;
    end

    // Deliberate debug output (synthesizable; replaces hierarchical access).
    assign debug_x3 = registers[3];

    assign data1 = (rs1 == 5'd0) ? 32'd0 : registers[rs1];
    assign data2 = (rs2 == 5'd0) ? 32'd0 : registers[rs2];

    always @(posedge clk) begin
        if (write_enable && (rd != 5'd0))
            registers[rd] <= write_data;
    end

endmodule
