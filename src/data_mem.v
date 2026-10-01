// Data RAM: asynchronous read, synchronous write with byte enables.
// Stored as four byte lanes so SB/SH only touch the selected bytes.
module data_mem #(
    parameter DEPTH = 256                   // words (1 KB)
) (
    input wire                     clk,
    input wire [$clog2(DEPTH)-1:0] word_address,
    input wire [31:0]              write_data,
    input wire [3:0]               write_strobe,
    output wire [31:0]             read_data
);

    reg [7:0] lane0 [0:DEPTH-1];
    reg [7:0] lane1 [0:DEPTH-1];
    reg [7:0] lane2 [0:DEPTH-1];
    reg [7:0] lane3 [0:DEPTH-1];

    always @(posedge clk) begin
        if (write_strobe[0]) lane0[word_address] <= write_data[7:0];
        if (write_strobe[1]) lane1[word_address] <= write_data[15:8];
        if (write_strobe[2]) lane2[word_address] <= write_data[23:16];
        if (write_strobe[3]) lane3[word_address] <= write_data[31:24];
    end

    assign read_data = {lane3[word_address], lane2[word_address],
                        lane1[word_address], lane0[word_address]};

endmodule
