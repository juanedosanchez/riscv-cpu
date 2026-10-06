`timescale 1ns/1ps

// Whack-a-mole (programs/topo.S) with a scripted player. test.sh builds
// build/topo_sim from topo.S with MS = 20 cycles instead of 27000, so a
// game takes ~2 M cycles. The player starts a game, hits 10 moles,
// presses a wrong button once, then lets two moles time out (game over),
// and starts a new game. UART output is printed as it arrives.
module topo_tb;

    reg clk = 0;
    reg reset = 1;
    reg [3:0] buttons = 4'b0000;

    wire [3:0] leds;
    wire       tx;
    wire [7:0] rx_data;
    wire       rx_valid;

    integer errors = 0;
    integer i;

    riscv_cpu #(
        .PROGRAM("build/topo_sim"),
        .RESET_PC(32'd0),
        .CLKS_PER_BIT(8)
    ) uut (
        .clk(clk),
        .reset(reset),
        .leds(leds),
        .uart_tx(tx),
        .uart_rx(1'b1),
        .buttons(buttons),
        .debug_x3()
    );

    uart_rx #(.CLKS_PER_BIT(8)) host (
        .clk(clk),
        .reset(reset),
        .rx(tx),
        .data(rx_data),
        .valid(rx_valid)
    );

    always @(posedge clk)
        if (rx_valid && rx_data != 8'h0d)
            $write("%c", rx_data);

    always #5 clk = ~clk;

    wire [31:0] score   = uut.core.register_file.registers[18];  // s2
    wire [31:0] misses  = uut.core.register_file.registers[19];  // s3
    wire        one_hot = (leds == 4'b0001 || leds == 4'b0010 ||
                           leds == 4'b0100 || leds == 4'b1000);

    task press(input [3:0] b);
        begin
            buttons = b;
            #2000;
            buttons = 4'b0000;
        end
    endtask

    task check(input [31:0] actual, input [31:0] expected, input [255:0] label);
        begin
            if (actual === expected)
                $display("PASS: %0s = %0d", label, actual);
            else begin
                $display("FAIL: %0s = %0d (expected %0d)", label, actual, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #20;
        reset = 0;

        // Idle pattern, then any button starts a game
        wait (leds == 4'b0101);
        wait (leds == 4'b1010);
        #3000;
        press(4'b0010);

        for (i = 0; i < 10; i = i + 1) begin
            wait (one_hot);
            #3000;
            press(leds);
            wait (leds == 4'b0000);
        end
        check(score, 10, "score after 10 hits");

        wait (one_hot);
        #3000;
        press(~leds);
        wait (leds == 4'b1111);
        check(misses, 1, "misses after wrong button");

        wait (leds == 4'b0000);
        wait (one_hot);
        wait (leds == 4'b1111);
        check(misses, 2, "misses after timeout");

        wait (leds == 4'b0000);
        wait (one_hot);
        wait (leds == 4'b1111);                 // third miss: game over
        wait (leds == 4'd10);
        #20000;
        check({28'd0, leds}, 10, "score on LEDs after game over");

        press(4'b0100);
        #2000;
        check(score, 0, "score reset on new game");

        $display("");
        if (errors == 0)
            $display("TOPO TB: ALL TESTS PASSED");
        else
            $display("TOPO TB: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin
        #200000000;
        $display("TOPO TB: FAIL (timeout)");
        $finish;
    end

endmodule
