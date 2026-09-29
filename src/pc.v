module pc (
    input wire        clk,
    input wire        reset,
    output reg [31:0] address
);

    always @(posedge clk) begin
        if (reset)
            address <= 32'd0;
        else
            address <= address + 32'd4;
    end

endmodule