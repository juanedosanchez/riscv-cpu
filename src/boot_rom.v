// Boot ROM (fetch only), synchronous read so it maps to block RAM.
// Contents: the bootloader, one 32-bit word per line.
module boot_rom #(
    parameter INIT_FILE = "build/boot.hex",
    parameter DEPTH     = 256               // words (1 KB)
) (
    input wire                     clk,
    input wire [$clog2(DEPTH)-1:0] address,
    output reg [31:0]              data
);

    reg [31:0] memory [0:DEPTH-1];

    initial $readmemh(INIT_FILE, memory);

    always @(posedge clk)
        data <= memory[address];

endmodule
