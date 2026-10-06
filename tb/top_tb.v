`timescale 1ns/1ps

// FPGA top running programs/rv32i_test.S. On pass the program writes 1111
// to the LED register; the Dock LEDs are active-low, so the pins read 0000.
module top_tb;

    reg clk = 0;
    reg btn_n0 = 1;

    wire [3:0] led;

    integer errors = 0;

    // Start directly in RAM (the bootloader is tested by boot_tb)
    top #(
        .PROGRAM("build/rv32i_test"),
        .RESET_PC(32'd0)
    ) uut (
        .clk27(clk),
        .btn_n0(btn_n0),
        .led(led),
        .uart_tx(),
        .uart_rx(1'b1),
        .btn_n(4'b1111)
    );

    always #5 clk = ~clk;

    task check(input [3:0] expected, input [255:0] label);
        begin
            if (led === expected)
                $display("PASS: %0s led = %b", label, led);
            else begin
                $display("FAIL: %0s led = %b (expected %b)", label, led, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Power-on reset (16 cycles), then the test program (~350 cycles).
        #10000;
        check(4'b0000, "test passed, all LEDs on");

        // Button held: CPU in reset, LED register cleared, all LEDs off.
        btn_n0 = 0;
        #50;
        check(4'b1111, "button held");

        btn_n0 = 1;
        #10000;
        check(4'b0000, "rerun after release");

        if (errors == 0)
            $display("TOP TB: ALL TESTS PASSED");
        else
            $display("TOP TB: %0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
