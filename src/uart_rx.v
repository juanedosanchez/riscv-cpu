// UART receiver: 8 data bits, no parity, 1 stop bit.
// `valid` pulses for one cycle with the received byte on `data`.
module uart_rx #(
    parameter CLKS_PER_BIT = 234            // 27 MHz / 115200 baud
) (
    input wire       clk,
    input wire       reset,
    input wire       rx,
    output reg [7:0] data,
    output reg       valid
);

    // Synchronize the asynchronous input
    reg rx_meta = 1'b1;
    reg rx_sync = 1'b1;

    always @(posedge clk) begin
        rx_meta <= rx;
        rx_sync <= rx_meta;
    end

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0]                      state;
    reg [$clog2(CLKS_PER_BIT)-1:0] clk_count;
    reg [2:0]                      bit_index;
    reg [7:0]                      shift;

    always @(posedge clk) begin
        valid <= 1'b0;

        if (reset) begin
            state <= IDLE;
        end
        else begin
            case (state)

                IDLE: begin
                    clk_count <= 0;
                    if (!rx_sync)
                        state <= START;
                end

                // Wait half a bit, then confirm the start bit is still low
                START: begin
                    if (clk_count == CLKS_PER_BIT / 2 - 1) begin
                        clk_count <= 0;
                        bit_index <= 3'd0;
                        state     <= rx_sync ? IDLE : DATA;
                    end
                    else
                        clk_count <= clk_count + 1'b1;
                end

                // Sample each data bit in the middle of its bit period
                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        shift     <= {rx_sync, shift[7:1]};
                        if (bit_index == 3'd7)
                            state <= STOP;
                        else
                            bit_index <= bit_index + 1'b1;
                    end
                    else
                        clk_count <= clk_count + 1'b1;
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state     <= IDLE;
                        if (rx_sync) begin          // valid stop bit
                            data  <= shift;
                            valid <= 1'b1;
                        end
                    end
                    else
                        clk_count <= clk_count + 1'b1;
                end

            endcase
        end
    end

endmodule
