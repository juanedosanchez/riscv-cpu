`timescale 1ns/1ps

// Buttons and cycle counter, running programs/io_test.S: two back-to-back
// cycle counter reads differ by 2, and the LEDs follow the buttons.
module io_tb;

    reg clk = 0;
    reg reset = 1;
    reg [3:0] buttons = 4'b0000;

    wire [3:0] leds;

    integer errors = 0;

    riscv_cpu #(
        .PROGRAM("build/io_test"),
        .RESET_PC(32'd0)
    ) uut (
        .clk(clk),
        .reset(reset),
        .leds(leds),
        .uart_tx(),
        .uart_rx(1'b1),
        .buttons(buttons),
        .debug_x3()
    );

    always #5 clk = ~clk;

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

        // crt0 clears .bss and calls main; then the two counter reads
        #2000;
        check(uut.core.register_file.registers[10], 32'd2, "cycle delta (a0)");

        buttons = 4'b0101;
        #200;
        check({28'd0, leds}, 32'b0101, "leds follow buttons 0101");

        buttons = 4'b1010;
        #200;
        check({28'd0, leds}, 32'b1010, "leds follow buttons 1010");

        buttons = 4'b0000;
        #200;
        check({28'd0, leds}, 32'b0000, "leds follow buttons 0000");

        if (errors == 0)
            $display("IO TB: ALL TESTS PASSED");
        else
            $display("IO TB: %0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
