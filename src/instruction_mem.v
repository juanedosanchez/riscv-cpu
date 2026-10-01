// Instruction ROM, loaded at build/simulation time from a hex file
// (one 32-bit word per line, as produced by tools/asm2hex.py).
//
// The read is synchronous so the ROM maps to block RAM. The caller
// presents the *next* PC; the word appears on `instruction` on the same
// clock edge that loads that PC into the PC register.
module instruction_mem #(
    parameter INIT_FILE = "build/program.hex",
    parameter DEPTH     = 1024              // words (4 KB)
) (
    input wire        clk,
    input wire [31:0] address,
    output reg [31:0] instruction
);

    reg [31:0] memory [0:DEPTH-1];

    initial $readmemh(INIT_FILE, memory);

    always @(posedge clk)
        instruction <= memory[address[$clog2(DEPTH)+1:2]];

endmodule
