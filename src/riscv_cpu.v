// CPU + memories + I/O.
//
// Memory map:
//   0x0000_0000  main RAM, 16 KB: code, data, stack (mirrored in 0x0000_xxxx)
//   0x0001_0000  boot ROM, 1 KB: bootloader (fetch only)
//   0x1000_0000  LED register, bits [3:0] (read/write)
//   0x1000_0004  UART data: write = send byte, read = take received byte
//   0x1000_0008  UART status: bit 0 = TX ready, bit 1 = RX byte available
module riscv_cpu #(
    parameter PROGRAM      = "build/program",   // main RAM image prefix
    parameter BOOT_PROGRAM = "build/boot.hex",
    parameter RESET_PC     = 32'h0001_0000,     // boot ROM
    parameter CLKS_PER_BIT = 234                // UART: 27 MHz / 115200
) (
    input wire         clk,
    input wire         reset,
    output wire [3:0]  leds,
    output wire        uart_tx,
    input wire         uart_rx,
    output wire [31:0] debug_x3
);

    wire [31:0] pc_address;
    wire [31:0] next_pc;
    wire [31:0] instruction;

    wire [31:0] mem_address;
    wire [31:0] mem_write_data;
    wire [3:0]  mem_write_strobe;
    wire        mem_read_done;
    reg  [31:0] mem_read_data;

    pc #(
        .RESET_ADDRESS(RESET_PC)
    ) program_counter (
        .clk(clk),
        .reset(reset),
        .next_address(next_pc),
        .address(pc_address)
    );

    // Instruction fetch. Both memories are synchronous: they are addressed
    // with the PC about to be loaded, so their registered outputs match
    // pc_address. fetch_from_boot remembers which one that PC is in.
    wire [31:0] fetch_address = reset ? RESET_PC : next_pc;
    wire [31:0] ram_fetch_data;
    wire [31:0] boot_fetch_data;
    reg         fetch_from_boot;

    always @(posedge clk)
        fetch_from_boot <= (fetch_address[31:16] == 16'h0001);

    assign instruction = fetch_from_boot ? boot_fetch_data : ram_fetch_data;

    boot_rom #(
        .INIT_FILE(BOOT_PROGRAM)
    ) boot_memory (
        .clk(clk),
        .address(fetch_address[9:2]),
        .data(boot_fetch_data)
    );

    cpu_core core (
        .clk(clk),
        .reset(reset),
        .pc(pc_address),
        .instruction(instruction),
        .next_pc(next_pc),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_write_strobe(mem_write_strobe),
        .mem_read_data(mem_read_data),
        .mem_read_done(mem_read_done),
        .debug_x3(debug_x3)
    );

    // Data address decode
    wire ram_select  = (mem_address[31:16] == 16'h0000);
    wire io_select   = (mem_address[31:28] == 4'h1);
    wire led_select  = io_select && (mem_address[3:2] == 2'd0);
    wire uart_data   = io_select && (mem_address[3:2] == 2'd1);
    wire uart_status = io_select && (mem_address[3:2] == 2'd2);

    wire [31:0] ram_read_data;

    main_mem #(
        .INIT_PREFIX(PROGRAM)
    ) main_memory (
        .clk(clk),
        .fetch_address(fetch_address[13:2]),
        .fetch_data(ram_fetch_data),
        .data_address(mem_address[13:2]),
        .write_data(mem_write_data),
        .write_strobe(ram_select ? mem_write_strobe : 4'b0000),
        .read_data(ram_read_data)
    );

    // LED register
    reg [3:0] led_reg;

    always @(posedge clk) begin
        if (reset)
            led_reg <= 4'd0;
        else if (led_select && mem_write_strobe[0])
            led_reg <= mem_write_data[3:0];
    end

    assign leds = led_reg;

    // UART: one-byte receive buffer, cleared when the CPU reads it
    wire       tx_busy;
    wire [7:0] rx_byte;
    wire       rx_valid_pulse;
    reg  [7:0] rx_buffer;
    reg        rx_full;

    uart_tx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) transmitter (
        .clk(clk),
        .reset(reset),
        .start(uart_data && mem_write_strobe[0]),
        .data(mem_write_data[7:0]),
        .busy(tx_busy),
        .tx(uart_tx)
    );

    uart_rx #(
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) receiver (
        .clk(clk),
        .reset(reset),
        .rx(uart_rx),
        .data(rx_byte),
        .valid(rx_valid_pulse)
    );

    always @(posedge clk) begin
        if (reset)
            rx_full <= 1'b0;
        else if (rx_valid_pulse) begin
            rx_buffer <= rx_byte;               // newest byte wins on overrun
            rx_full   <= 1'b1;
        end
        else if (uart_data && mem_read_done)
            rx_full <= 1'b0;
    end

    // Load data (used in the load's second cycle)
    always @(*) begin
        if (ram_select)
            mem_read_data = ram_read_data;
        else if (led_select)
            mem_read_data = {28'd0, led_reg};
        else if (uart_data)
            mem_read_data = {24'd0, rx_buffer};
        else if (uart_status)
            mem_read_data = {30'd0, rx_full, !tx_busy};
        else
            mem_read_data = 32'd0;
    end

endmodule
