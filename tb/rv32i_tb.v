`timescale 1ns/1ps

// Runs programs/rv32i_test.S and reports its result.
// The program sets t5 (x30) to 0x600D on pass or 0xBAD on fail, with the
// failing check number in t6 (x31).
module rv32i_tb;

    reg clk;
    reg reset;

    wire [3:0] leds;

    integer cycles;

    riscv_cpu #(
        .PROGRAM("build/rv32i_test"),
        .RESET_PC(32'd0)
    ) uut (
        .clk(clk),
        .reset(reset),
        .leds(leds),
        .uart_tx(),
        .uart_rx(1'b1),
        .buttons(4'b0000),
        .debug_x3()
    );

    always #5 clk = ~clk;

    wire [31:0] result = uut.core.register_file.registers[30];
    wire [31:0] check  = uut.core.register_file.registers[31];

    initial begin
        clk    = 0;
        reset  = 1;
        cycles = 0;

        #20;
        reset = 0;

        // `li t5, 0x600D` is lui + addi, so wait for the final value
        while (result !== 32'h600D && result !== 32'hBAD && cycles < 10000) begin
            @(posedge clk);
            cycles = cycles + 1;
        end

        if (result == 32'h600D && leds === 4'hF)
            $display("RV32I TB: ALL TESTS PASSED (%0d checks, %0d cycles)", check, cycles);
        else if (result == 32'h600D)
            $display("FAIL: program passed but leds = %b (expected 1111)", leds);
        else if (result == 32'hBAD)
            $display("FAIL: check %0d failed (pc = 0x%08h)", check, uut.pc_address);
        else
            $display("FAIL: timeout after %0d cycles at check %0d (pc = 0x%08h)",
                     cycles, check, uut.pc_address);

        $finish;
    end

endmodule
