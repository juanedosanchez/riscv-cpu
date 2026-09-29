module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  operation,
    output reg  [31:0] result
);

    always @(*) begin
        case (operation)

            3'b000: result = a + b;  // ADD
            3'b001: result = a - b;  // SUB
            3'b010: result = a & b;  // AND
            3'b011: result = a | b;  // OR

            default: result = 32'b0;

        endcase
    end

endmodule