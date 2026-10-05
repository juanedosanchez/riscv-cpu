module pc #(
    parameter RESET_ADDRESS = 32'd0
) (
    input wire clk,
    input wire reset,
    input wire [31:0] next_address,
    output reg [31:0] address
);
    always @(posedge clk) begin
        if (reset)
            address <= RESET_ADDRESS;
        else
            address <= next_address;
    end
endmodule
