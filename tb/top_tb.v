`timescale 1ns/1ps

// FPGA top: CPU result x3[3:0] on the active-low Dock LEDs.
// led pins carry ~x3[3:0], so x3 = 13 (1101) drives 0010.
module top_tb;

    reg clk = 0;
    reg btn_n0 = 1;

    wire [3:0] led;

    integer errors = 0;

    top uut (
        .clk27(clk),
        .btn_n0(btn_n0),
        .led(led)
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
        // Power-on reset releases after 16 cycles, then the program runs.
        #400;
        check(4'b0010, "after power-on reset");

        // Button held: CPU in reset, x3 = 0, all LEDs off.
        btn_n0 = 0;
        #50;
        check(4'b1111, "button held");

        btn_n0 = 1;
        #200;
        check(4'b0010, "button released");

        if (errors == 0)
            $display("TOP TB: ALL TESTS PASSED");
        else
            $display("TOP TB: %0d TEST(S) FAILED", errors);

        $finish;
    end

endmodule
