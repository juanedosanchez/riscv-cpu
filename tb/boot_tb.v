`timescale 1ns/1ps

// End-to-end bootloader test through the FPGA top:
//   reset -> bootloader prints "RVBOOT" -> testbench uploads
//   build/hello.bin over UART ('L', length, bytes, checksum) -> bootloader
//   replies 'K' and runs it -> the C program prints "Hello from RISC-V!".
// RAM starts out holding build/basic (a different program), so the
// greeting can only come from the uploaded image.
module boot_tb;

    localparam CLKS_PER_BIT = 8;
    localparam BIT_TIME     = CLKS_PER_BIT * 10;     // ns (10 ns clock)
    localparam [15:0] CRLF  = 16'h0D0A;              // Verilog strings have no \r

    reg clk = 0;
    reg btn_n0 = 1;
    reg host_tx = 1;                                 // into the FPGA

    wire [3:0] led;
    wire board_tx;                                   // out of the FPGA

    integer errors = 0;

    top #(
        .PROGRAM("build/basic"),
        .BOOT_PROGRAM("build/boot.hex"),
        .RESET_PC(32'h0001_0000),
        .CLKS_PER_BIT(CLKS_PER_BIT)
    ) uut (
        .clk27(clk),
        .btn_n0(btn_n0),
        .led(led),
        .uart_tx(board_tx),
        .uart_rx(host_tx),
        .btn_n(4'b1111)
    );

    always #5 clk = ~clk;

    // ---- Host -> board ----------------------------------------------------
    task send_byte(input [7:0] value);
        integer b;
        begin
            host_tx = 0;
            #(BIT_TIME);
            for (b = 0; b < 8; b = b + 1) begin
                host_tx = value[b];
                #(BIT_TIME);
            end
            host_tx = 1;
            #(BIT_TIME);
        end
    endtask

    task send_u32(input [31:0] value);
        begin
            send_byte(value[7:0]);
            send_byte(value[15:8]);
            send_byte(value[23:16]);
            send_byte(value[31:24]);
        end
    endtask

    // ---- Board -> host: decode everything the board sends into `log` ------
    reg [8*256-1:0] log = 0;
    integer log_length = 0;

    always begin : receiver
        integer b;
        reg [7:0] value;
        @(negedge board_tx);
        #(BIT_TIME / 2);
        for (b = 0; b < 8; b = b + 1) begin
            #(BIT_TIME);
            value[b] = board_tx;
        end
        #(BIT_TIME);
        log = {log[8*255-1:0], value};
        log_length = log_length + 1;
    end

    // True if the last `n` received characters equal `text`
    function ends_with(input [8*32-1:0] text, input integer n);
        integer k;
        begin
            ends_with = (log_length >= n);
            for (k = 0; k < n; k = k + 1)
                if (log[8*k +: 8] !== text[8*k +: 8])
                    ends_with = 0;
        end
    endfunction

    task wait_for(input [8*32-1:0] text, input integer n, input integer timeout_ns,
                  input [8*40-1:0] label);
        integer waited;
        begin
            waited = 0;
            while (!ends_with(text, n) && waited < timeout_ns) begin
                #100;
                waited = waited + 100;
            end
            if (ends_with(text, n))
                $display("PASS: %0s", label);
            else begin
                $display("FAIL: %0s (timeout)", label);
                errors = errors + 1;
            end
        end
    endtask

    // ---- Program image -----------------------------------------------------
    reg [7:0] image [0:16383];
    integer image_length;
    integer file;
    integer i;
    reg [31:0] checksum;

    initial begin
        file = $fopen("build/hello.bin", "rb");
        if (file == 0) begin
            $display("FAIL: cannot open build/hello.bin");
            $finish;
        end
        image_length = $fread(image, file);
        $fclose(file);

        checksum = 0;
        for (i = 0; i < image_length; i = i + 1)
            checksum = checksum + image[i];

        wait_for({"RVBOOT", CRLF}, 8, 200000, "bootloader banner");

        // Corrupted upload: wrong checksum -> 'E', then the banner again
        send_byte("L");
        send_u32(4);
        send_u32(32'h12345678);
        send_u32(32'hDEADBEEF);
        wait_for({"E", "RVBOOT", CRLF}, 9, 200000, "bad checksum rejected ('E'), bootloader restarts");

        send_byte("L");
        send_u32(image_length);
        for (i = 0; i < image_length; i = i + 1)
            send_byte(image[i]);
        send_u32(checksum);

        wait_for("K", 1, 200000, "upload acknowledged ('K')");
        wait_for({"Hello from RISC-V!", CRLF}, 20, 2000000, "uploaded C program prints greeting");
        wait_for({"10! = 3628800", CRLF}, 15, 20000000, "software multiply (10!)");
        wait_for({"remainder 1", CRLF}, 13, 5000000, "software divide (1000000 / 7)");

        // Echo: type 'x', expect it back and the LED count to become 1
        wait_for({"characters):", CRLF}, 14, 2000000, "prompt");
        send_byte("x");
        wait_for("x", 1, 200000, "echo");
        if (led === 4'b1110)
            $display("PASS: LEDs count 1 character");
        else begin
            $display("FAIL: led = %b (expected 1110)", led);
            errors = errors + 1;
        end

        $display("(uploaded %0d bytes)", image_length);
        if (errors == 0)
            $display("BOOT TB: ALL TESTS PASSED");
        else
            $display("BOOT TB: %0d TEST(S) FAILED", errors);
        $finish;
    end

endmodule
