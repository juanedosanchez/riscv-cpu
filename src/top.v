module top (
    input wire clk27,
    input wire btn_n0,
    output wire led
);

    blink blink_unit (
        .clk(clk27),
        .reset(~btn_n0),
        .led(led)
    );

endmodule