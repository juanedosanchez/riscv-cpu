module top #(
    parameter PROGRAM      = "build/program",
    parameter BOOT_PROGRAM = "build/boot.hex",
    parameter RESET_PC     = 32'h0001_0000,
    parameter CLKS_PER_BIT = 234
) (
    input wire clk27,
    input wire btn_n0,
    output wire [3:0] led,
    output wire uart_tx,
    input wire uart_rx
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
        .PROGRAM(PROGRAM),
        .BOOT_PROGRAM(BOOT_PROGRAM),
        .RESET_PC(RESET_PC),
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) cpu (
        .clk(clk27),
        .reset(reset),
        .leds(cpu_leds),
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        .debug_x3()
    );

    // Dock LEDs are active-low: invert so a lit LED means a 1 bit.
    assign led = ~cpu_leds;

endmodule
