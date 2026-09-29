module imm_gen (
    input wire [31:0] instruction,
    output reg [31:0] immediate
);

    always @(*) begin

        case (instruction[6:0])

            // I-type
            7'b0010011:
                immediate = {{20{instruction[31]}},
                            instruction[31:20]};

            default:
                immediate = 32'd0;

        endcase

    end

endmodule