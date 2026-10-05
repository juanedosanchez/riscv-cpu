`timescale 1ns/1ps

// Loopback: uart_tx -> uart_rx. Every byte sent must be received intact.
module uart_tb;

    localparam CLKS_PER_BIT = 8;

    reg clk = 0;
    reg reset = 1;
    reg start = 0;
    reg [7:0] data;

    wire busy;
    wire line;
    wire [7:0] received;
    wire valid;

    integer errors = 0;
    integer i;

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) transmitter (
        .clk(clk), .reset(reset), .start(start), .data(data),
        .busy(busy), .tx(line)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) receiver (
        .clk(clk), .reset(reset), .rx(line), .data(received), .valid(valid)
    );

    always #5 clk = ~clk;

    reg [7:0] patterns [0:5];

    initial begin
        patterns[0] = 8'h00;
        patterns[1] = 8'hFF;
        patterns[2] = 8'h55;
        patterns[3] = 8'hA5;
        patterns[4] = "K";
        patterns[5] = 8'h80;

        #20 reset = 0;

        for (i = 0; i < 6; i = i + 1) begin
            @(negedge clk);
            data  = patterns[i];
            start = 1;
            @(negedge clk);
            start = 0;

            @(posedge valid);
            if (received === patterns[i])
                $display("PASS: byte 0x%02h", received);
            else begin
                $display("FAIL: sent 0x%02h, received 0x%02h", patterns[i], received);
                errors = errors + 1;
            end
            wait (!busy);
        end

        if (errors == 0)
            $display("UART TB: ALL TESTS PASSED");
        else
            $display("UART TB: %0d TEST(S) FAILED", errors);

        $finish;
    end

    initial begin
        #100000;
        $display("FAIL: timeout");
        $finish;
    end

endmodule
