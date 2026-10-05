// UART transmitter: 8 data bits, no parity, 1 stop bit.
module uart_tx #(
    parameter CLKS_PER_BIT = 234            // 27 MHz / 115200 baud
) (
    input wire       clk,
    input wire       reset,
    input wire       start,                  // ignored while busy
    input wire [7:0] data,
    output wire      busy,
    output reg       tx
);

    reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    reg [3:0]                      bit_index;   // 0 start, 1-8 data, 9 stop
    reg [9:0]                      frame;
    reg                            active;

    assign busy = active;

    always @(posedge clk) begin
        if (reset) begin
            tx     <= 1'b1;
            active <= 1'b0;
        end
        else if (!active) begin
            tx <= 1'b1;
            if (start) begin
                frame     <= {1'b1, data, 1'b0};
                bit_index <= 4'd0;
                clk_count <= 0;
                active    <= 1'b1;
                tx        <= 1'b0;
            end
        end
        else if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= 0;
            if (bit_index == 4'd9)
                active <= 1'b0;
            else begin
                bit_index <= bit_index + 1'b1;
                tx        <= frame[bit_index + 1];
            end
        end
        else
            clk_count <= clk_count + 1'b1;
    end

endmodule
