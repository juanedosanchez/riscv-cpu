// Main RAM for code, data and stack. Two synchronous ports:
//   port A: instruction fetch (read only)
//   port B: data loads/stores, with byte write strobes
// Stored as four byte lanes so each maps to block RAM and SB/SH only
// touch the selected bytes. Initial contents come from
// <INIT_PREFIX>.lane0.hex .. lane3.hex (written by tools/mkprog.py).
module main_mem #(
    parameter INIT_PREFIX = "build/program",
    parameter DEPTH       = 4096            // words (16 KB)
) (
    input wire                     clk,

    input wire [$clog2(DEPTH)-1:0] fetch_address,
    output wire [31:0]             fetch_data,

    input wire [$clog2(DEPTH)-1:0] data_address,
    input wire [31:0]              write_data,
    input wire [3:0]               write_strobe,
    output wire [31:0]             read_data
);

    reg [7:0] lane0 [0:DEPTH-1];
    reg [7:0] lane1 [0:DEPTH-1];
    reg [7:0] lane2 [0:DEPTH-1];
    reg [7:0] lane3 [0:DEPTH-1];

    initial begin
        $readmemh({INIT_PREFIX, ".lane0.hex"}, lane0);
        $readmemh({INIT_PREFIX, ".lane1.hex"}, lane1);
        $readmemh({INIT_PREFIX, ".lane2.hex"}, lane2);
        $readmemh({INIT_PREFIX, ".lane3.hex"}, lane3);
    end

    reg [7:0] fetch0, fetch1, fetch2, fetch3;
    reg [7:0] read0,  read1,  read2,  read3;

    always @(posedge clk) begin
        fetch0 <= lane0[fetch_address];
        fetch1 <= lane1[fetch_address];
        fetch2 <= lane2[fetch_address];
        fetch3 <= lane3[fetch_address];
    end

    always @(posedge clk) begin
        if (write_strobe[0]) lane0[data_address] <= write_data[7:0];
        if (write_strobe[1]) lane1[data_address] <= write_data[15:8];
        if (write_strobe[2]) lane2[data_address] <= write_data[23:16];
        if (write_strobe[3]) lane3[data_address] <= write_data[31:24];

        read0 <= lane0[data_address];
        read1 <= lane1[data_address];
        read2 <= lane2[data_address];
        read3 <= lane3[data_address];
    end

    assign fetch_data = {fetch3, fetch2, fetch1, fetch0};
    assign read_data  = {read3, read2, read1, read0};

endmodule
