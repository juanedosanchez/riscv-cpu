/*module instr_mem (
    input wire [31:0] address,
    output reg [31:0] instruction
);

    reg [31:0] memory [0:255];

    always @(*) begin

        case (address)

            32'h00000000:
                memory[0] = 32'h00A00093; // addi x1, x0, 10

            32'h00000004:
                memory[1] = 32'h00300113; // addi x2, x0, 3

            32'h00000008:
                memory[2] = 32'h002081B3; // add x3, x1, x2

            32'h0000000C:
                memory[3] = 32'h40208233; // sub x4, x1, x2

            default:
                memory[0] = 32'h00000013; // nop

        endcase

        instruction = memory[address >> 2];

    end

endmodule
*/
module instruction_mem (
    input wire [31:0] address,
    output reg [31:0] instruction
);

    always @(*) begin

        case (address)

            32'h00000000:
                instruction = 32'h00A00093; // addi x1, x0, 10

            32'h00000004:
                instruction = 32'h00300113; // addi x2, x0, 3

            32'h00000008:
                instruction = 32'h002081B3; // add x3, x1, x2

            32'h0000000C:
                instruction = 32'h40208233; // sub x4, x1, x2

            default:
                instruction = 32'h00000013; // nop

        endcase

    end

endmodule