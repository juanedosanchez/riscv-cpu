module top #(
    parameter PROGRAM = "build/program.hex"
) (
    input wire clk27,
    input wire btn_n0,
    output wire [3:0] led
);

    // Hold reset for 16 cycles after configuration, and while the
    // button is pressed (btn_n0 is active-low).
    reg [3:0] por_count = 4'd0;
    wire      por_done  = &por_count;

    always @(posedge clk27) begin
        if (!por_done)
            por_count <= por_count + 1'b1;
    end

    wire reset = ~btn_n0 | ~por_done;

    wire [3:0] cpu_leds;

    riscv_cpu #(
        .PROGRAM(PROGRAM)
    ) cpu (
        .clk(clk27),
        .reset(reset),
        .leds(cpu_leds),
        .debug_x3()
    );

    // Dock LEDs are active-low: invert so a lit LED means a 1 bit.
    assign led = ~cpu_leds;

endmodule
