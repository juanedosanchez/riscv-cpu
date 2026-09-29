module blink (
    input wire clk,
    input wire reset,
    output wire led
);

    reg [24:0] counter;

    always @(posedge clk) begin
        if (reset)
            counter <= 25'd0;
        else
            counter <= counter + 1'b1;
    end

    assign led = counter[24];

endmodule
